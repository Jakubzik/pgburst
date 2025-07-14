pub mod change_log;
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
    str::FromStr,
};

use colorize::AnsiColor;
use notify::{Config, RecommendedWatcher, RecursiveMode, Result, Watcher};
use postgres::Client;

use crate::{conf::BurstConf, pg::PgDb};

pub(crate) fn watch(
    pg_db: &mut PgDb,
    conf: &BurstConf,
    client: &mut Client,
    files: &Vec<PathBuf>,
    tmp_folder: &str,
) -> notify::Result<()> {
    let (tx, rx) = std::sync::mpsc::channel();

    // Automatically select the best implementation for your platform.
    // You can also access each implementation directly e.g. INotifyWatcher.
    let mut watcher = RecommendedWatcher::new(tx, Config::default())?;

    // Add a path to be watched. All files and directories at that path and
    // below will be monitored for changes.
    for f in files {
        watcher.watch(Path::new(&f), RecursiveMode::NonRecursive)?;
    }

    // Create skript folder and bash files
    let sql_alterations_folder = format!(
        "{}/{}/pg_burst_skript/",
        conf.burst_folder.as_ref().unwrap_or(&".".to_string()),
        conf.db_name
    );

    std::fs::create_dir_all(&sql_alterations_folder)?;

    let mut f_do = File::create(format!("{}/apply_changes.sh", sql_alterations_folder))?;

    let mut f_undo = File::create(format!("{}/apply_changes_UNDO.sh", sql_alterations_folder))?;

    f_do.write_all(
        format!(
            "#!/bin/bash\n\nBURST_FOLDER=\"{}\"\n\n",
            sql_alterations_folder
        )
        .as_bytes(),
    )?;

    f_undo.write_all(
        format!(
            "#!/bin/bash\n\nBURST_FOLDER=\"{}\"\n\n",
            sql_alterations_folder
        )
        .as_bytes(),
    )?;

    let mut i_count: usize = 1;

    for res in rx {
        match res {
            Ok(event) => {
                let mut is_data_change: bool = false;
                let ev_kind = event.kind;
                match ev_kind {
                    notify::EventKind::Modify(modify_kind) => {
                        if modify_kind
                            == notify::event::ModifyKind::Data(notify::event::DataChange::Any)
                        {
                            // println!("Modified: {:?}", ev_kind);
                            is_data_change = true;
                        }
                    }
                    // e.g. vim replaces the file, it seems, which
                    // implies that it is removed at some point;
                    notify::EventKind::Remove(_) => {
                        // println!("Removed: {:?}", ev_kind);
                        watcher.watch(&event.paths[0], RecursiveMode::NonRecursive)?;
                        is_data_change = true;
                    }
                    _ => {}
                }
                if is_data_change {
                    execute_and_document_change(
                        pg_db,
                        client,
                        conf,
                        &event.paths[0],
                        tmp_folder,
                        &mut i_count,
                    );
                }
            }
            Err(error) => print!("Error (event): {error:?}"),
        }
    }

    Ok(())
}

pub(crate) fn execute_and_document_change(
    pg_db: &mut PgDb,
    client: &mut Client,
    conf: &BurstConf,
    s_path: &std::path::PathBuf,
    tmp_folder: &str,
    ii: &mut usize,
) {
    let content_new = match std::fs::read_to_string(s_path) {
        Ok(content) => content,
        Err(_) => "".to_string(),
    };

    // if !is_table(&s_path) {
    match client.execute(&content_new, &[]) {
        Ok(_msg) => {
            let s_msg = format!(
                "Ok -- >{}< executed against >{}< on >{}< (as user >{}<)",
                s_path.file_stem().unwrap().to_string_lossy(),
                conf.db_name,
                conf.pg_host,
                conf.pg_user,
            );

            println!("{}", s_msg.green());

            match track_change(pg_db, conf, s_path, ii, tmp_folder) {
                Ok(_) => {}
                Err(e) => {
                    println!("Change could not be tracked: {:?}", e.to_string().red());
                }
            }
        }
        Err(e) => {
            let s_info = match e.as_db_error() {
                Some(e) => format!("Error: {}, line: {:?}", e.message(), e.line()),
                None => "(No info)".to_string(),
            };
            println!("{}", s_info.red());
        }
    }
}

pub(crate) fn track_change(
    pg_db: &mut PgDb,
    conf: &BurstConf,
    s_path: &std::path::PathBuf,
    ii: &mut usize,
    tmp_folder: &str,
) -> Result<()> {
    let sql_alterations_folder = format!(
        "{}/{}/pg_burst_skript/",
        conf.burst_folder.as_ref().unwrap_or(&".".to_string()),
        conf.db_name
    );

    // We want the object here to note the number of changes
    let change_object = pg_db.get_object(s_path).unwrap();
    change_object.increase_number_of_changes();

    let s_file_stem = s_path.file_stem().unwrap_or_default().to_string_lossy();

    // This is @todo
    let change_count = change_object.number_of_changes.clone();
    if change_count > 1 {
        let old_filename = format!("{}_{}_rev{}.sql", ii, s_file_stem, (change_count - 1));

        bash_comment(
            &PathBuf::from_str(&format!("{}/apply_changes.sh", &sql_alterations_folder)).unwrap(),
            &format!(
                "\npsql -U {} -h {} {} < $BURST_FOLDER/{}",
                conf.pg_user, conf.pg_host, conf.db_name, old_filename
            ),
        )?;

        // (1) comment out calls to
        //     the file with change-number 1...current
        // (2) add new (call to filename)
        //
        // (3) omit adding a new 'UNDO' path
    }

    let mut batch = OpenOptions::new()
        .append(true)
        .open(format!("{}/apply_changes.sh", sql_alterations_folder))?;

    let mut batch_undo = OpenOptions::new()
        .append(true)
        .open(format!("{}/apply_changes_UNDO.sh", sql_alterations_folder))?;

    let new_filename = format!("{}_{}_rev{}.sql", ii, s_file_stem, change_count);

    let undo_filename = format!("{}_{}_UNDO.sql", ii, s_file_stem);

    batch.write_all(
        format!(
            "\npsql -U {} -h {} {} < $BURST_FOLDER/{}",
            conf.pg_user, conf.pg_host, conf.db_name, new_filename
        )
        .as_bytes(),
    )?;

    if change_count < 2 {
        batch_undo.write_all(
            format!(
                "\npsql -U {} -h {} {} < $BURST_FOLDER/{}",
                conf.pg_user, conf.pg_host, conf.db_name, undo_filename
            )
            .as_bytes(),
        )?;
    }

    let s1 = s_path.as_path().to_str().unwrap().to_string();
    let rel_link = &s1[s1.find(&conf.db_name).unwrap()..s1.rfind('/').unwrap()].to_string();

    let new_file = format!("{}/{}", sql_alterations_folder, new_filename);
    let undo_file = format!("{}/{}", sql_alterations_folder, undo_filename);

    std::fs::copy(s_path, new_file)?;
    let s_tmp = format!("{}/{}/{}_undo.sql", tmp_folder, rel_link, s_file_stem);

    std::fs::copy(s_tmp, undo_file)?;
    Ok(())
}

// Default in 0.3.3 is that a second change to a file
// will result in a skript-file that will *only*
// execute this second change (but leave the execution
// of the first change as commented command in the
// bash skript).
//
// Comment the line `line` in the bash
// file `file_path`
fn bash_comment(file_path: &PathBuf, line: &str) -> Result<()> {
    let mut script_file = OpenOptions::new().read(true).open(file_path)?;
    let mut file_content: String = "".to_string();
    script_file.read_to_string(&mut file_content)?;
    let mut new_content: Vec<String> = vec![];
    for l in file_content.lines() {
        // println!("Checking: \n{l}{line}\n\n");
        if l.trim() == line.trim() {
            new_content
                .push("# Uncomment if you want to reinstate the revision below.".to_string());
            new_content.push(format!("# {}", line.trim()));
        } else {
            new_content.push(l.to_string());
        }
    }

    let mut file = OpenOptions::new()
        .write(true)
        .truncate(true)
        .open(file_path)?;
    file.write(new_content.join("\n").as_bytes())?;

    Ok(())
}

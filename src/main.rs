use clap::Parser;

mod conf;
mod pg;
use pg::{PgDb, PgObjectType};
use std::{
    fs::{File, OpenOptions},
    io::Write,
    path::Path,
    time::{Instant, SystemTime, UNIX_EPOCH},
};

use colorize::AnsiColor;

/// @todo
/// - make pg connect string configurable
/// - add types
/// - make priviliges configurable
/// - add table definitions (?)
/// @ideas
/// - allow to run queries and export as markdown?
use notify::{Config, RecommendedWatcher, RecursiveMode, Result, Watcher};
use postgres::{Client, NoTls};

use crate::conf::BurstConf;

// #[derive(Parser)]
// #[command(name = "PgBurst")]
// #[command(author = "Heiko Jakubzik <heiko.jakubzik@shj-online.de>")]
// #[command(version = "0.1")]
// #[command(
//     about = "Extracts functions, views, and triggers from Postgresql databases, saves them in folders as sql-files, and (optionally) reacts to changes on those files\n",
//     long_about = "\nExample usage:
//     `pg_burst MyDb`
//     exports all functions, views, and triggers into files in the folder ./MyDb/

//     `pg_burst -s public -s web_api MyDb`
//     exports all functions, views, and triggers in schema 'public' and in schema 'web_api' into files in the folder ./MyDb/

//     `pg_burst -f login MyDb`
//     exports all functions, views, and triggers whose sql representation contains the text 'login' in ./MyDb/

//     `pg_burst MyDb views`
//     exports all views (in all schemas) to files in the folder ./MyDb/

//     `pg_burst -b ~/temp_bursts MyDb`
//     exports all functions, views, and triggers into files in the folder ~/tmp_bursts/MyDb. The folder is created if it does not yet exist.

//     `pg_burst -w MyDb`
//     exports the sql files. If a file is changed, the new contents are executed against MyDb, and the folder ./MyDb/pg_burst_skript is filled with a script intended to reproduce (or undo) the effect if executed in a different environment.
//     "
// )]
// #[derive(Default)]
// pub struct BurstConf {
//     /// Name of the database to connect to.
//     // #[arg(last = true)]
//     db_name: String,

//     /// Where to store the sql files. (Default is .)
//     #[arg(short, long)]
//     burst_folder: Option<String>,

//     /// Only export items of this schema or list of schemas (option can be used repeatedly to export more than one schema).
//     #[arg(short, long)]
//     schema_filter: Option<Vec<String>>,

//     /// Only export items of the specified type(s) (list item types separated by space).
//     #[arg(value_enum)]
//     objects_filter: Option<Vec<PgObjectType>>,

//     /// Only export items whose names contain the given text.
//     #[arg(short, long)]
//     name_filter: Option<String>,

//     /// Only export items whose sql respresentation contains the given text.
//     #[arg(short, long)]
//     find: Option<String>,

//     /// Watch the burst sql files *for changes* and execute them against the database (default: false). Cancel with C-c when you're done. Watching does not cover deletion or addition of files (yet?)!
//     #[arg(short, long)]
//     watch: bool,
// }

fn main() -> Result<()> {
    let config = BurstConf::parse();

    // the initial unchanged files are saved in a temporary folder
    // so that we can add a kind of "_undo" funcionality.
    let tmp_folder = format!(
        "{}/pg_burst_{:?}",
        std::env::temp_dir().to_string_lossy(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis()
    );

    let db_name = config.db_name.clone();

    let mut pg_db = PgDb {
        name: db_name.clone(),
        schemas: vec![],
    };

    let mut client = match Client::connect(
        &format!("host=localhost user=postgres dbname={db_name}"),
        NoTls,
    ) {
        Ok(client) => {
            let msg = format!("Connected to database >{db_name}<");
            println!("{}", msg.green());
            client
        }
        Err(e) => {
            let msg = match e.as_db_error(){
                Some( db_err) => format!(
                "Cannot connect to database >{db_name}<: {}",
                db_err.message()),
                None => format!("Cannot connect to database {db_name} -- is the server running and accepting connections? (Try pg_burst --help)")
            };
            println!("{}", msg.bold().red());
            return Ok(());
        }
    };

    analyze_db(&mut client, &mut pg_db, PgObjectType::Function);
    analyze_db(&mut client, &mut pg_db, PgObjectType::Trigger);
    analyze_db(&mut client, &mut pg_db, PgObjectType::View);

    let msg = format!(
        "Files are stored in: {}",
        config.burst_folder.as_ref().unwrap_or(&".".to_string())
    );

    println!("{}", msg.b_blue());

    let files = match pg_db.burst(&config, &tmp_folder) {
        Ok(vec_of_files) => vec_of_files,
        Err(some_err) => {
            let msg = format!("Failed to save the SQL files -- probably I have no permission to save the files in >{}<: (>{}<). Try to specify a different location using '-b'.", config.burst_folder.unwrap(), some_err);
            println!("{}", msg.red().bold());
            std::process::exit(1);
        }
    };

    // Should we watch for changes in files?
    if config.watch {
        watch(&config, &mut client, &files, &tmp_folder)?;
    }

    Ok(())
}

fn analyze_db(client: &mut Client, pg_db: &mut PgDb, pg_type: PgObjectType) {
    for row in client.query(pg_type.get_sql(), &[]).unwrap() {
        let schema: String = row.get("schema_name");
        let fname: String = row.get("obj_name");
        let fdef: String = row.get("definition");

        pg_db.add_new(schema, pg_type, fname, fdef);
    }
}

fn execute_and_document_change(
    client: &mut Client,
    conf: &BurstConf,
    s_path: &std::path::PathBuf,
    tmp_folder: &str,
    ii: &mut usize,
) {
    let content_new = std::fs::read_to_string(s_path).unwrap();

    match client.execute(&content_new, &[]) {
        Ok(_msg) => {
            let s_msg = format!(
                "Ok -- >{}< executed against >{}<",
                s_path.file_stem().unwrap().to_string_lossy(),
                conf.db_name
            );

            println!("{}", s_msg.green());

            track_change(conf, s_path, ii, tmp_folder).unwrap();
        }
        Err(e) => {
            let s_info = format!(
                "Error: {}, line: {:?}",
                e.as_db_error().unwrap().message(),
                e.as_db_error().unwrap().line()
            );

            println!("{}", s_info.red());
        }
    }
}

fn track_change(
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

    let mut batch = OpenOptions::new()
        .append(true)
        .open(format!("{}/apply_changes.sh", sql_alterations_folder))?;

    let mut batch_undo = OpenOptions::new()
        .append(true)
        .open(format!("{}/apply_changes_UNDO.sh", sql_alterations_folder))?;

    let s_file_stem = s_path.file_stem().unwrap_or_default().to_string_lossy();
    let new_filename = format!("{}_{}.sql", ii, s_file_stem);
    let undo_filename = format!("{}_{}_UNDO.sql", ii, s_file_stem);

    batch.write_all(
        format!("\npsql {} < $BURST_FOLDER/{}", conf.db_name, new_filename).as_bytes(),
    )?;

    batch_undo.write_all(
        format!("\npsql {} < $BURST_FOLDER/{}", conf.db_name, undo_filename).as_bytes(),
    )?;

    let s1 = s_path.as_path().to_str().unwrap().to_string();
    let rel_link = &s1[s1.find(&conf.db_name).unwrap()..s1.rfind('/').unwrap()].to_string();

    let new_file = format!("{}/{}", sql_alterations_folder, new_filename);
    let undo_file = format!("{}/{}", sql_alterations_folder, undo_filename);

    // println!("Alteration folder: {sql_alterations_folder}");

    std::fs::copy(s_path, new_file)?;
    let s_tmp = format!("{}/{}/{}_undo.sql", tmp_folder, rel_link, s_file_stem);

    std::fs::copy(s_tmp, undo_file)?;
    Ok(())
}

// fn watch<P: AsRef<Path>>(path: P) -> notify::Result<()> {
fn watch(
    conf: &BurstConf,
    client: &mut Client,
    files: &Vec<String>,
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
    let mut start = Instant::now();
    for res in rx {
        match res {
            Ok(event) => {
                if event.kind.is_modify() {
                    // print!("{} Pfad: {:?}", start.elapsed().as_millis(), event.paths);
                    watcher.watch(&event.paths[0], RecursiveMode::NonRecursive)?;
                    // First try: There always seems to be one modification
                    // followed by several others in 0 ms distance.
                    // Is the first one sufficient? Yes, seems so.
                    if start.elapsed().as_millis() > 10 {
                        execute_and_document_change(
                            client,
                            conf,
                            &event.paths[0],
                            tmp_folder,
                            &mut i_count,
                        );
                        i_count += 1;
                    }
                    start = Instant::now();
                }
                // print!("Change: {event:?}");
            }
            Err(error) => print!("Error: {error:?}"),
        }
    }

    Ok(())
}

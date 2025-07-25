use clap::Parser;
pub(crate) use std::process::Command;

mod conf;
mod pg;
mod watch;
use crate::pg::dump_analyzer::Tables;
use watch::watch;

use pg::{PgDb, PgObjectType};
use std::time::{SystemTime, UNIX_EPOCH};

use colorize::AnsiColor;

/// @todo
/// - make priviliges configurable
/// - add table definitions (?)
/// @ideas
/// - allow to run queries and export as markdown?
/// - allow to run queries/updates from file
/// @done
/// - add tables and constraints [0.3.1]
/// - add sequences [0.2.1]
/// - add types [0.2.0]
/// - make pg connect string configurable [0.1.2]
/// - FIX: schema ap_tests with fn tests does not come through [0.1.3]
use notify::Result;
use postgres::{Client, NoTls};

use crate::conf::BurstConf;

fn main() -> Result<()> {
    let config = BurstConf::parse();
    // panic!("Test");

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
    let db_user = config.pg_user.clone();
    let db_host = config.pg_host.clone();

    let mut pg_db = PgDb {
        name: db_name.clone(),
        schemas: vec![],
        base_folder: config.burst_folder.as_ref().unwrap().clone(),
        tmp_folder: tmp_folder.clone(),
    };

    let mut client = match Client::connect(
        &format!("host={db_host} user={db_user} dbname={db_name}"),
        NoTls,
    ) {
        Ok(client) => {
            let msg = format!("Connected to database >{db_name}<");
            println!("{}", msg.green());
            client
        }

        Err(e) => {
            let msg = match e.as_db_error() {
                Some(db_err) => format!(
                    "Cannot connect to database >{db_name}<: {}",
                    db_err.message()
                ),
                None => format!(
                    "Cannot connect to database {db_name} -- is the server running and accepting connections? (Try pg_burst --help)"
                ),
            };
            println!("{}", msg.bold().red());
            return Ok(());
        }
    };

    analyze_db(&mut client, &mut pg_db, PgObjectType::Function, None);
    analyze_db(&mut client, &mut pg_db, PgObjectType::Trigger, None);
    analyze_db(&mut client, &mut pg_db, PgObjectType::View, None);
    analyze_db(&mut client, &mut pg_db, PgObjectType::Type, None);
    analyze_db(&mut client, &mut pg_db, PgObjectType::Sequence, None);
    analyze_db(&mut client, &mut pg_db, PgObjectType::Table, Some(&db_name));

    let msg = format!(
        "Files are stored in: {}",
        config.burst_folder.as_ref().unwrap_or(&".".to_string())
    );

    println!("{}", msg.b_blue());

    let files = match pg_db.burst(&config, &tmp_folder) {
        Ok(vec_of_files) => vec_of_files,
        Err(some_err) => {
            let msg = format!(
                "Failed to save the SQL files -- probably I have no permission to save the files in >{}<: (>{}<). Try to specify a different location using '-b'.",
                config.burst_folder.unwrap(),
                some_err
            );
            println!("{}", msg.red().bold());
            std::process::exit(1);
        }
    };

    // Should we watch for changes in files?
    if config.watch {
        watch(&mut pg_db, &config, &mut client, &files, &tmp_folder)?;
    }

    Ok(())
}

fn analyze_db(client: &mut Client, pg_db: &mut PgDb, pg_type: PgObjectType, db_name: Option<&str>) {
    // Types (same as table definitions) don't deliver
    // their sql definition from the query, this
    // has to be assembled separately
    match pg_type {
        PgObjectType::Type => analyze_types(client, pg_db),
        PgObjectType::Table => analyze_tables(client, pg_db, db_name.unwrap()),
        _ => {
            // Views, functions, and triggers deliver their
            // defining sql in column "definition" and are
            // all treated the same:
            for row in client.query(pg_type.get_sql(), &[]).unwrap() {
                let schema: String = row.get("schema_name");
                let fname: String = row.get("obj_name");
                let fdef: String = row.get("definition");
                pg_db.add_new(schema, pg_type, fname, fdef);
            }
        }
    }
}

///
/// June 11, 2025
/// Need to
/// - analyze how other objects (i.e. views) are treated and stored!
///   + we need PgDb entries (Type, Name, Definition) so that .burst works
/// - call pg_dump (preferably to /tmp/whatever, or configurable location)
/// - analyze the dump for create table
/// - store things the same way they are stored for other objects
fn analyze_tables(_client: &mut Client, pg_db: &mut PgDb, db_name: &str) {
    // Starte pg_dump
    let child = get_pg_dump_process(db_name).unwrap(); // <-- needs catching
    let wo = child.wait_with_output();
    if let Err(e) = wo.as_ref() {
        panic!("Could not start `pg_dump`: {}", e.to_string());
    }

    let output = wo.unwrap();
    let mut sql_from_dump = "";
    if output.status.success() {
        sql_from_dump = std::str::from_utf8(&output.stdout).unwrap();
    }
    let mut tables = Tables { tables: vec![] };
    tables.analyze(&sql_from_dump);

    for t in tables.tables {
        pg_db.add_new(
            t.schema,
            PgObjectType::Table,
            t.name,
            format!("{}\n{}", t.create_sql, t.alterations_sql),
        );
    }
}

fn get_pg_dump_process(db_name: &str) -> Option<std::process::Child> {
    let args: Vec<String> = vec![
        // "-n".to_string(), // Restrict to Schema
        // format!("unmy_hdr from; my_hdr From: {sender}").to_string(),
        "--quote-all-identifiers".to_string(), // Schema only
        "-s".to_string(),                      // Schema only
        db_name.to_string(),                   // Schema only
                                               // format!("set realname=\"{sender_name}\"").to_string(),
                                               // "-S".to_string(), // Username
                                               // format!("set content_type=text/html").to_string(),
                                               // "-t".to_string(), // Table name pattern
                                               // format!("set content_type=text        "-s".to_string(),
                                               // subject.to_string(),
    ];

    // attachments.iter().for_each(|att| {
    //     args.push("-a".to_string());
    //     args.push(att.to_owned());
    // });

    // args.push("--".to_string());
    // args.push(recipient.to_string());

    let child_raw = Command::new("pg_dump")
        // .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .args(args)
        .spawn()
        .ok();
    child_raw
}

fn analyze_types(client: &mut Client, pg_db: &mut PgDb) {
    let mut schema_old: String = "".to_string();
    let mut obj_name_old: String = "".to_string();
    let mut fdef: String = "".to_string();
    let mut is_enum: bool = false;

    for row in client.query(PgObjectType::Type.get_sql(), &[]).unwrap() {
        let schema: String = row.get("schema_name");
        let mut obj_name: String = row.get("obj_name");

        // obj_name comes through (in the query) with the schema name when
        // it's not an enum type; this is why we're dropping the prefix
        // of the schema here:
        if obj_name.starts_with(&format!("{schema}.")) {
            obj_name = obj_name[schema.len() + 1..].to_string();
        }

        // Is this a new type or new columns for the old type?
        if (schema == schema_old) && (obj_name == obj_name_old) {
            let cname: String = row.get("column_name");
            if is_enum {
                fdef = format!("{fdef}, '{cname}'");
            } else {
                let dtype: String = row.get("data_type");
                fdef = format!("{fdef}, {cname} {dtype}");
            }
        } else {
            // If this is not the first loop
            if fdef.clone().len() > 1 {
                let s_enum = match is_enum {
                    true => "enum",
                    _ => "",
                };

                fdef = format!(
                    "-- drop type \"{schema_old}\".\"{obj_name_old}\"\n\ncreate type \"{schema_old}\".\"{obj_name_old}\" as {s_enum} ({fdef});"
                );

                pg_db.add_new(
                    schema_old.clone(),
                    PgObjectType::Type,
                    obj_name_old.clone(),
                    fdef.clone(),
                );
            }
            let cname: String = row.get("column_name");
            is_enum = row.get::<_, String>("burst_type") == "enum";
            if is_enum {
                fdef = format!("'{cname}'");
            } else {
                let dtype: String = row.get("data_type");
                fdef = format!("{cname} {dtype}");
            }
            // fdef = "".to_string();
            schema_old = schema.clone();
            obj_name_old = obj_name.clone();
        }

        // same schema and obj_name? - collect column_names [diff between burst_type]
    }
    let s_enum = match is_enum {
        true => "enum",
        _ => "",
    };
    // Final type:
    fdef = format!(
        "-- finale drop type \"{schema_old}\".\"{obj_name_old}\"\n\ncreate type \"{schema_old}\".\"{obj_name_old}\" as {s_enum} ({fdef});"
    );

    pg_db.add_new(
        schema_old.clone(),
        PgObjectType::Type,
        obj_name_old.clone(),
        fdef.clone(),
    );
}

// fn execute_and_document_change(
//     client: &mut Client,
//     conf: &BurstConf,
//     s_path: &std::path::PathBuf,
//     tmp_folder: &str,
//     ii: &mut usize,
// ) {
//     let content_new = match std::fs::read_to_string(s_path) {
//         Ok(content) => content,
//         Err(_) => "".to_string(),
//     };

//     // if !is_table(&s_path) {
//     match client.execute(&content_new, &[]) {
//         Ok(_msg) => {
//             let s_msg = format!(
//                 "Ok -- >{}< executed against >{}< on >{}< (as user >{}<)",
//                 s_path.file_stem().unwrap().to_string_lossy(),
//                 conf.db_name,
//                 conf.pg_host,
//                 conf.pg_user,
//             );

//             println!("{}", s_msg.green());

//             match track_change(conf, s_path, ii, tmp_folder) {
//                 Ok(_) => {}
//                 Err(e) => {
//                     println!("Change could not be tracked: {:?}", e.to_string().red());
//                 }
//             }
//         }
//         Err(e) => {
//             let s_info = match e.as_db_error() {
//                 Some(e) => format!("Error: {}, line: {:?}", e.message(), e.line()),
//                 None => "(No info)".to_string(),
//             };
//             println!("{}", s_info.red());
//         }
//     }
//     // } else {
//     //     let s_msg = "Ok -- alteration of table >{}< on >{}< is tracked. Please note, though, that alterations on tables are not executed!";
//     //     println!("{}", s_msg.yellow());
//     //     track_change(conf, s_path, ii, tmp_folder).unwrap();
//     // }
// }

// Deprecated -- needs more thought.
fn is_table(s_path: &std::path::PathBuf) -> bool {
    println!("{:?}", s_path);
    println!(
        "{}",
        format!(
            "/tables/{}.sql",
            s_path.file_stem().unwrap().to_string_lossy()
        )
    );
    s_path.to_string_lossy().ends_with(&format!(
        "/tables/{}.sql",
        s_path.file_stem().unwrap().to_string_lossy()
    ))
}

// fn track_change(
//     conf: &BurstConf,
//     s_path: &std::path::PathBuf,
//     ii: &mut usize,
//     tmp_folder: &str,
// ) -> Result<()> {
//     let sql_alterations_folder = format!(
//         "{}/{}/pg_burst_skript/",
//         conf.burst_folder.as_ref().unwrap_or(&".".to_string()),
//         conf.db_name
//     );

//     let mut batch = OpenOptions::new()
//         .append(true)
//         .open(format!("{}/apply_changes.sh", sql_alterations_folder))?;

//     let mut batch_undo = OpenOptions::new()
//         .append(true)
//         .open(format!("{}/apply_changes_UNDO.sh", sql_alterations_folder))?;

//     let s_file_stem = s_path.file_stem().unwrap_or_default().to_string_lossy();
//     let new_filename = format!("{}_{}.sql", ii, s_file_stem);
//     let undo_filename = format!("{}_{}_UNDO.sql", ii, s_file_stem);

//     batch.write_all(
//         format!(
//             "\npsql -U {} -h {} {} < $BURST_FOLDER/{}",
//             conf.pg_user, conf.pg_host, conf.db_name, new_filename
//         )
//         .as_bytes(),
//     )?;

//     batch_undo.write_all(
//         format!(
//             "\npsql -U {} -h {} {} < $BURST_FOLDER/{}",
//             conf.pg_user, conf.pg_host, conf.db_name, undo_filename
//         )
//         .as_bytes(),
//     )?;

//     let s1 = s_path.as_path().to_str().unwrap().to_string();
//     let rel_link = &s1[s1.find(&conf.db_name).unwrap()..s1.rfind('/').unwrap()].to_string();

//     let new_file = format!("{}/{}", sql_alterations_folder, new_filename);
//     let undo_file = format!("{}/{}", sql_alterations_folder, undo_filename);

//     // println!("Alteration folder: {sql_alterations_folder}");

//     std::fs::copy(s_path, new_file)?;
//     let s_tmp = format!("{}/{}/{}_undo.sql", tmp_folder, rel_link, s_file_stem);

//     std::fs::copy(s_tmp, undo_file)?;
//     Ok(())
// }

// fn watch(
//     conf: &BurstConf,
//     client: &mut Client,
//     files: &Vec<PathBuf>,
//     tmp_folder: &str,
// ) -> notify::Result<()> {
//     let (tx, rx) = std::sync::mpsc::channel();

//     // Automatically select the best implementation for your platform.
//     // You can also access each implementation directly e.g. INotifyWatcher.
//     let mut watcher = RecommendedWatcher::new(tx, Config::default())?;

//     // Add a path to be watched. All files and directories at that path and
//     // below will be monitored for changes.
//     for f in files {
//         watcher.watch(Path::new(&f), RecursiveMode::NonRecursive)?;
//     }

//     // Create skript folder and bash files
//     let sql_alterations_folder = format!(
//         "{}/{}/pg_burst_skript/",
//         conf.burst_folder.as_ref().unwrap_or(&".".to_string()),
//         conf.db_name
//     );

//     std::fs::create_dir_all(&sql_alterations_folder)?;

//     let mut f_do = File::create(format!("{}/apply_changes.sh", sql_alterations_folder))?;

//     let mut f_undo = File::create(format!("{}/apply_changes_UNDO.sh", sql_alterations_folder))?;

//     f_do.write_all(
//         format!(
//             "#!/bin/bash\n\nBURST_FOLDER=\"{}\"\n\n",
//             sql_alterations_folder
//         )
//         .as_bytes(),
//     )?;

//     f_undo.write_all(
//         format!(
//             "#!/bin/bash\n\nBURST_FOLDER=\"{}\"\n\n",
//             sql_alterations_folder
//         )
//         .as_bytes(),
//     )?;

//     let mut i_count: usize = 1;

//     for res in rx {
//         match res {
//             Ok(event) => {
//                 let mut is_data_change: bool = false;
//                 let ev_kind = event.kind;
//                 match ev_kind {
//                     notify::EventKind::Modify(modify_kind) => {
//                         if modify_kind
//                             == notify::event::ModifyKind::Data(notify::event::DataChange::Any)
//                         {
//                             println!("Modified: {:?}", ev_kind);
//                             is_data_change = true;
//                         }
//                     }
//                     // e.g. vim replaces the file, it seems, which
//                     // implies that it is removed at some point;
//                     notify::EventKind::Remove(_) => {
//                         println!("Removed: {:?}", ev_kind);
//                         watcher.watch(&event.paths[0], RecursiveMode::NonRecursive)?;
//                         is_data_change = true;
//                     }
//                     _ => {}
//                 }
//                 if is_data_change {
//                     execute_and_document_change(
//                         client,
//                         conf,
//                         &event.paths[0],
//                         tmp_folder,
//                         &mut i_count,
//                     );
//                 }
//             }
//             Err(error) => print!("Error (event): {error:?}"),
//         }
//     }

//     Ok(())
// }

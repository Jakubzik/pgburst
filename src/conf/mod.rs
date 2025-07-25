use clap::Parser;

use crate::pg::PgObjectType;

#[derive(Parser)]
#[command(name = "PgBurst")]
#[command(version)]
#[command(author = "Heiko Jakubzik <heiko.jakubzik@shj-online.de>")]
#[command(
    about = "Extracts objects(*) from Postgresql databases, saves them in folders as sql-files, and (optionally) reacts to changes on some of those files\n
      (*)objects are currently tables, views, functions, (composite or enum) types, sequences, and triggers.",
    long_about = "\nExample usage: 
    `pgburst MyDb`
    exports all objects(*) into files in the folder ./MyDb/

    `pgburst -s public -s web_api MyDb`
    exports all objects(*) in schema 'public' and in schema 'web_api' into files in the folder ./MyDb/

    `pgburst -f login MyDb`
    exports all objects(*) whose sql representation contains the text 'login' in ./MyDb/

    `pgburst MyDb views`
    exports all views (in all schemas) to files in the folder ./MyDb/

    `pgburst -b ~/temp_bursts MyDb`
    exports all objects(*) into files in the folder ~/tmp_bursts/MyDb. The folder is created if it does not yet exist.

    `pgburst -w MyDb`
    exports the objects(*) of MyDB. If a file is changed, the new contents are executed against MyDb, and the folder ./MyDb/pg_burst_skript is filled with a script that can be used to reproduce (or undo) the commands in a different environment.
    "
)]
#[derive(Default)]
pub struct BurstConf {
    /// Name of the database to connect to.
    // #[arg(last = true)]
    pub(crate) db_name: String,

    /// Username of postgres user connecting to the database
    #[arg(long, default_value = "postgres")]
    pub(crate) pg_user: String,

    /// Machine hosting the postgres database (default changed in 0.2.6, March 25)
    #[arg(long, default_value = "127.0.0.1")]
    pub(crate) pg_host: String,

    /// Where to store the sql files. (Default is .)
    #[arg(short, long, default_value = ".")]
    pub(crate) burst_folder: Option<String>,

    /// Only export items of this schema or list of schemas (option can be used repeatedly to export more than one schema).
    #[arg(short, long)]
    pub(crate) schema_filter: Option<Vec<String>>,

    /// Only export items of the specified type(s) (list item types separated by space).
    #[arg(value_enum)]
    pub(crate) objects_filter: Option<Vec<PgObjectType>>,

    /// Only export items whose names contain the given text.
    #[arg(short, long)]
    pub(crate) name_filter: Option<String>,

    /// Only export items whose sql representation contains the given text.
    #[arg(short, long)]
    pub(crate) find: Option<String>,

    /// Watch the burst sql files *for changes* and execute them against the database (default: false). Cancel with C-c when you're done. Watching does not cover deletion or addition of files (yet?)!
    #[arg(short, long)]
    pub(crate) watch: bool,
}

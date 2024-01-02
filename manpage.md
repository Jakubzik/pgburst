---
title: PGBURST
section: 1
header: User Manual
footer: pgburst 0.1.1
date: January 2, 2024
---
# NAME

pgburst - tool to browse functions, views, and triggers of a postgres database.

# SYNOPSIS

**pgburst** [*OPTION*] <DB_NAME> [OBJECTS_FILTER]

# DESCRIPTION

**pgburst** extracts sql-files out of your database into folders organized by schema and type (function, trigger, view). Editing is then executed using your own choice of tools.

You can select the files you would like to extract by choosing a schema, and/or an object type (function, view, or trigger), or by simply filtering for a text in the object's sql definition.

If invoked with the "-w" flag, **pgburst** will watch the files for changes, execute changed files against the database, and collect changes in the folder "pg_burst_skript."

# OPTIONS

**-h** , --help
: display help message

**-b**, --burst-folder 
: to store the sql files. (Default is .)

**-s**, --schema-filter 
: only export items of this schema or list of schemas (option can be used repeatedly to export more than one schema)

-**n** --name-filter
: only export items whose names contain the given text

**-f**, --find 
: only export items whose sql respresentation contains the given text

**-w**, --watch
: watch burst sql files *for changes* and execute them against the database (default: false). Cancel with C-c when done. **Warning**: Watching does not cover deletion or addition of files (yet?)!

**-V**, --version
: print version

**OBJECTS_FILTER**
: one of "function," "view," "trigger"

# EXAMPLES
**pgburst MyDb**
: exports all functions, views, and triggers into files in the folder ./MyDb/

**pg_burst -s public -s web_api MyDb**
: exports all functions, views, and triggers in schema 'public' and in schema 'web_api' into files in the folder ./MyDb/

**pg_burst -f sanity MyDb**
: exports all functions, views, and triggers whose sql representation contains the text 'sanity' in ./MyDb/

**pg_burst MyDb views**
: exports all views (in all schemas) to files in the folder ./MyDb/

**pg_burst -b ~/temp_bursts MyDb**
: exports all functions, views, and triggers into files in the folder ~/tmp_bursts/MyDb. The folder is created if it does not yet exist.

**pg_burst -w MyDb**
: exports all sql files as above. If a file is changed, its new contents are executed against the database MyDb, and the folder ./MyDb/pg_burst_skript is filled with a script intended to reproduce (or undo) the effect if executed in a different environment.

# AUTHORS

Written by Heiko Jakubzik, <heiko.jakubzik@shj-online.de>

# BUGS

Submit bug reports online at: <https://github.com/Jakubzik/pgburst>.

# SEE ALSO

Full documentation and sources at: <https://github.com/Jakubzik/pgburst>.

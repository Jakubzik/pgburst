# PgBurst

Extract tables, functions, views, (composite or enum) types, sequences, and triggers from your postgres database into files for editing.

## Introduction

While [pgcli](https://www.pgcli.com/install) is wonderful to select and manipulate data and edit the occasional function, one can quickly get lost trying to edit triggers or functions or views in the many different schemas of complex databases.

While there are a number of excellent GUIs for editing postgres databases, they tend to take over the entire workflow, which can be a bummer if you work best with setups like [i3](https://i3wm.org/), [lf](https://github.com/gokcehan/lf) and [nvim](https://neovim.io/) (or [awesome](https://awesomewm.org/), [ranger](https://github.com/ranger/ranger) and [helix](https://github.com/helix-editor/helix) etc.)

``pgburst`` extracts sql-files out of your database into folders organized by schema and type (function, trigger, view). Editing is then executed using your own choice of tools.

## Installation

``Cargo install pgburst``

**Archlinux**

``yay -S pgburst``

## Features

You can

- extract *all* tables, functions, views, (composite or enum) types, sequences, and triggers, or 
- those of selected schemas, or 
- those whose sql definition contains a specific text

etc., and edit these files using the workflow you work best with.

The gif below shows how just the one function is extracted from the example database "[dvdrental](https://github.com/arinpro/postgres-sample-db-dvdrental)" whose definition contains the word "sanity" (in a comment):

![Show sanity](pgburst_find.gif)

### Keeping watch, the "-w" flag

``pgburst`` can also *watch* the files for changes. 

Flag ``-w`` starts pgburst so that altered files are executed against the database as soon as they are saved.

![Show waiting](pgburst_wait.gif)

## Usage

``pgburst [OPTIONS] <DB_NAME> [OBJECTS_FILTER]``

Arguments:\
  <DB_NAME>
      Name of the database to connect to

  [OBJECTS_FILTER]...
      Only export items of the specified type(s) (list item types separated by space) [possible values: function, trigger, view, type, sequence]

Options:\
  -b, --burst-folder <BURST_FOLDER>
          Where to store the sql files. (Default is .)

  --pg-user,
          user connecting to the database (default is postgres)

  --pg-host,
          host to connect to (default is 127.0.0.1)

  -s, --schema-filter <SCHEMA_FILTER>
          Only export items of this schema or list of schemas (option can be used repeatedly to export more than one schema)

  -n, --name-filter <NAME_FILTER>
          Only export items whose names contain the given text

  -f, --find <FIND>
          Only export items whose sql respresentation contains the given text

  -w, --watch
          Watch the burst sql files *for changes* and execute them against the database (default: false). Cancel with C-c when you're done. Watching does not cover deletion or addition of files (yet?)!

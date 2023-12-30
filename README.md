# PgBurst

Extract functions, views, and triggers from your postgres database into files for editing.

## Introduction

While [pgcli](https://www.pgcli.com/install) is wonderful to select and manipulate data and edit the occasional function, one can quickly get lost trying to edit triggers or functions or views in the many different schemas of complex databases.

While there are a number of excellent GUIs for editing postgres databases, they tend to take over the entire workflow, which can be a bummer if you work best with setups like [i3](https://i3wm.org/), [lf](https://github.com/gokcehan/lf) and [nvim](https://neovim.io/) (or [awesome](https://awesomewm.org/), [ranger](https://github.com/ranger/ranger) and [helix](https://github.com/helix-editor/helix) etc.)

``pgburst`` extracts sql-files out of your database into folders organized by schema and type (function, trigger, view). Editing is then executed using your own choice of tools.

## Features

You can

- extract *all* functions, views, and triggers, or 
- those of selected schemas, or 
- those whose sql definition contains a specific text

etc., and edit these files using the workflow you work best with.

### Keeping watch

``pgburst`` can also *watch* for changes. 

If you often edit a local copy of the database and then need to play the tested alterations into the production variant, ``pgburst`` contains the ``-w``-flag: ``pgburst`` then watches all extracted files for changes, executes the changes against the database, collects the changes in a dedicated folder (together with _UNDO-files) and produces a little bash-script to execute the files.

## Usage

## 

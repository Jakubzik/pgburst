# version 0.3.3

- reorganization of code to make room for improved watching

- improved script to help transfer the commands to a new machine when files are changed more than once.

# version 0.3.2

- corrections on `watch` functionality

# version 0.3.1


- include tables and constraints, using pg_dump and analysis


# version 0.2.6

- changed default from localhost to 127.0.0.1

# version 0.2.5

- added parameter --version (-v)
- Rust edition 21->24

# version 0.2.4

- Repair musl problem, repair sha checksum problem

# version 0.2.3

- No changes.

# version 0.2.2

- Update of deps

# version 0.2.1

- Added support for postgres sequences (enum and composite)
- Fixed manpage (missing "types" here and there)

# version 0.2.0

Added support for postgres types (enum and composite)

# version 0.1.3

Added 

Changed  

Fixed
 - Omission of first function if function was schema's only item.

# version 0.1.2

Added 
 - parameters --pg-user and --pg-host (also in the pg_burst_skript folder)
 - Readme now knows about yay -S pgburst

Changed  
 - nil

Fixed
 - nil

# Unreleased

[ ] Implement help for altering tables, sequences, types(?)
[ ] Implement comments
[x] Make script log multiple changes of the same file [v0.3.3]
[ ] Improve burst_script
   [ ] insert comment: `change function etc. ...`
   [ ] if the same file is changed twice: what to do? (Ask if first change should be replaced)
[ ] Export roles
[ ] Make sure comments are included in table definition
[x] Make connection string configurable (user, host) [v0.1.2]
[/] Add export of types [v0.2.0, no range or box types]
[x] Add export of sequences [v0.2.1]
[ ] Add info for sequences as comments
[x] Add export of table
[ ] Add update/insert scripts 
[ ] Add mode for querying through wait mode and an open file
[ ] Add export of roles and privileges
[ ] React to deletion of files (possibly also addition of files?)
[ ] Add .deb package


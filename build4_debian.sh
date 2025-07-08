#!/bin/bash

dbian_folder=/home/heiko/development/pg_burst_debian/pgburst

# Copy current binary
cp ./target/x86_64-unknown-linux-musl/release/pgburst "$dbian_folder/bin/"

# Copy control file containing the updated version number
cp ./debian_control "$dbian_folder/DEBIAN/control"

# Copy License (copyright)
cp ./LICENSE.md $dbian_folder/usr/share/doc/pgburst/copyright

# Copy Changelog
rm "$dbian_folder/usr/share/doc/pgburst/changelog.Debian.gz"
cp ./CHANGELOG.md "$dbian_folder/usr/share/doc/pgburst/changelog.Debian"
gzip "$dbian_folder/usr/share/doc/pgburst/changelog.Debian"

# Copy manpage
cp ./pgburst.1.gz "$dbian_folder/usr/share/man/man1"

# Build package
dpkg-deb --root-owner-group --build $dbian_folder

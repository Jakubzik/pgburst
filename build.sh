#!/bin/bash
#
pandoc ./manpage.md -s -t man -o ./pgburst.1
gzip ./pgburst.1

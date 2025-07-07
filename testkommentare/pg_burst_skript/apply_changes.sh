#!/bin/bash

BURST_FOLDER="./testkommentare/pg_burst_skript/"


psql -U postgres -h 127.0.0.1 testkommentare < $BURST_FOLDER/1_t_test.sql
psql -U postgres -h 127.0.0.1 testkommentare < $BURST_FOLDER/1_t_test.sql
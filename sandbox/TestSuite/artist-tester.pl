#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Test::More;
use Data::Dumper;
use DBI;

require Artist;

unlink 'test_suite.db';

system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

my $dbh = DBI->connect("dbi:SQLite:test_suite.db", "", "");

Artist->dbh($dbh);

my $artist = Artist->find->with('label')->fetch;
#!/usr/bin/env perl

use 5.014;
require Artist;

use Data::Dumper;



	unlink 'test_suite.db';

	system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

	my $dbh = DBI->connect("dbi:SQLite:test_suite.db", "", "");

	Artist->dbh($dbh);


my $a = Artist->new(name => 'Metallica')->save;
say Dumper $a->_get_mixins;


my $b = Artist->find({ name => 'Metallica' })->only('name', 'mysum')->fetch;


say Dumper $b;
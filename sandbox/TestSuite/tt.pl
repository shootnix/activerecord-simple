#!/usr/bin/env perl

use 5.014;
require Artist;

use Data::Dumper;



	unlink 'test_suite.db';

	system 'sqlite3 test_suite.db < test_suite.sqlite.sql';


Artist->connect("dbi:SQLite:test_suite.db", "", "");


Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');

Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');

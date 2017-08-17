#!/usr/bin/env perl

use 5.014;
require Artist;

use Data::Dumper;



	unlink 'test_suite.db';

	system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

	my $dbh = DBI->connect("dbi:SQLite:test_suite.db", "", "");

	Artist->dbh($dbh);



Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');


my $b = Artist->find({ name => 'Metallica' })->only('name', 'mysum')->fetch;
my $c = Artist->find({ name => 'Metallica' })->fetch;

say 'Changing B:';
$b->name('Pearl Jam');
say 'b.name  = ' . $b->name;
say 'c.name  = ' . $c->name;
say 'b.mysum = ' . $b->mysum;
$b->save;
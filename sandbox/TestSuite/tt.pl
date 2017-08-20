#!/usr/bin/env perl

use 5.014;


use Data::Dumper;



	unlink 'test_suite.db';

	system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use ActiveRecord::Simple;

#ActiveRecord::Simple->connect('dbi:mysql:ars', 'shootnix', '12345');
ActiveRecord::Simple->connect("dbi:SQLite:test_suite.db", "", "");

require Artist;

say Artist->_get_table_name;
say Artist->_get_primary_key;
#require Rating;

#Artist->connect("dbi:SQLite:test_suite.db", "", "");
#Artist->connect('dbi:mysql:ars', 'shootnix', '12345');

=c
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');

Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');


my $find = Artist->find;
while (my @a = $find->next(3)) {
	say $_->id for @a;
	say '-' x 20;
}
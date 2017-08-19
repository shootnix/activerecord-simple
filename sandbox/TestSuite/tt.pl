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


#my @last = Artist->find({ name => 'Metallica' })->fetch;
my $f = Artist->find;

#say $f->next->id;
#$f->next;

while (my $n = $f->next) {
	say $n->id;
}
#my $n = $f->next;

#say 'n = ' . Dumper $n;
#say Dumper \@last;
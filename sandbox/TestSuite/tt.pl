#!/usr/bin/env perl

use 5.014;
require Artist;
require Rating;

use Data::Dumper;



	unlink 'test_suite.db';

	system 'sqlite3 test_suite.db < test_suite.sqlite.sql';


Artist->connect("dbi:SQLite:test_suite.db", "", "");


Artist->dbh->do('INSERT INTO artist (`name`, `label_id`) VALUES ("Metallica", 1)');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');

Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');
Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Magnum")');


my $a = Artist->find(1)->only('id', 'mysum')->fetch;

say Dumper $a;

my $rating = Rating->new({ range => 'asss', artist_id => 'AAA' });
$rating->save;

#say $rating->artist_id;

#my $r = Rating->find({ artist_id => 'AAA' })->fetch;
#say Dumper $r;
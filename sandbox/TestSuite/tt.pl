#!/usr/bin/env perl

use 5.014;


use Data::Dumper;



unlink 'test_suite.db';
system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use ActiveRecord::Simple;

#ActiveRecord::Simple->connect('dbi:mysql:ars', 'shootnix', '12345');
ActiveRecord::Simple->connect("dbi:SQLite:test_suite.db", "", "", { HandleError => sub {} });

use Artist;
use Label;



my $a = Artist->new(name => 'Metallica')->save;



my $b = Artist->find('artist.name = ?', 'Metallica')->fetch;
my $l = Label->new(name => 'emi')->save;


$b->label($l)->save;

#$a->label($l)->save;
#say Dumper $a;
#my $l = Label->new;

#$l->artists({ name => 'Metallica' })->fetch;


#use Rating;

#my $a = Artist->find(id => [1, 2, 3]);

#$a->albums(1);
#my $l = Label->new(name => 'EMI');

#$l->artists(1);

#$a->manager;
#$a->rating;
#require Artist;
#require Manager;
#require Label;
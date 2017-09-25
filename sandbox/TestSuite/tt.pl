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
#use Rating;

my $a = Artist->find(id => [1, 2, 3]);

say Dumper $a;
#$a->albums(1);
#my $l = Label->new(name => 'EMI');

#$l->artists(1);

#$a->manager;
#$a->rating;
#require Artist;
#require Manager;
#require Label;
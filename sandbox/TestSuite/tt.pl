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
require Artist;
require Manager;
require Label;

#require Artist;

#say Artist->_get_table_name;
#say Artist->_get_primary_key;
#require Rating;

#Artist->connect("dbi:SQLite:test_suite.db", "", "");
#Artist->connect('dbi:mysql:ars', 'shootnix', '12345');
my $manager = Manager->new({ name => 'John Doe' })->save;
my $label   = Label->new({ name => 'EMI' })->save;


#Artist->dbh->do('INSERT INTO artist (`name`) VALUES ("Metallica")');

my $artist = Artist->new({ name => 'Metallica' })->manager($manager)->label($label)->save;

use App::Benchmark;

benchmark_diag(20_000, {
	a => sub {
		my $a = Artist->find({ name => 'Metallica' })->with('manager', 'label')->fetch;
	},
	b => sub {
		my $a = Artist->find({ name => 'Metallica' })->fetch;
		my @labels = Label->find({ id => $a->label_id })->fetch;
		my @managers = Manager->find({ id => $a->manager_id })->fetch;
	}
});
#my $a = Artist->find({ name => 'Metallica' })->left_join('label', 'manager')->fetch;

#say Dumper $a;

#my $a = Artist->get(1);
#say $a->label->id;
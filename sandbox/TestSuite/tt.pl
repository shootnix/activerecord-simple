#!/usr/bin/env perl

use 5.014;


use Data::Dumper;



#unlink 'test_suite.db';
#system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use ActiveRecord::Simple;

ActiveRecord::Simple->connect('dbi:Pg:dbname=ars', 'shootnix', '12345');

use Artist;
use Label;



#say for Artist->all->fetch;
Artist->new;
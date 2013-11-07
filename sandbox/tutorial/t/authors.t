#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Test::More;
use DBI;

use lib '../lib';
use Authors;

my $dbh = DBI->connect("dbi:SQLite:../sql/blog.db", "", "");
Authors->dbh($dbh);

ok( Authors->new({ id => 1, name => 'John Doe' })->save );
ok( Authors->new({ id => 2, name => 'Jack Black' })->save );

ok my $john = Authors->find({ name => 'John Doe' })->fetch;
ok $john->is_defined; is $john->name, 'John Doe'; is $john->id, 1;
ok my $jack = Authors->find({ name => 'Jack Black' })->fetch;
ok $jack->is_defined; is $jack->name, 'Jack Black'; is $jack->id, 2;

done_testing;
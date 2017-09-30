#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use ActiveRecord::Simple::Validate qw/check/;

use Data::Dumper;
use List::Util qw/any/;

use Test::More;



ok check({ is_nullable => 1, extra => { validators => ['null'] } }, undef);
ok !check({ is_nullable => 0, extra => { validators => ['null'] } }, undef);

done_testing();
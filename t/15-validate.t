#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use ActiveRecord::Simple::Validate;

use Data::Dumper;
use List::Util qw/any/;

use Test::More;



ok my $validator = ActiveRecord::Simple::Validate->new();
isa_ok $validator, 'ActiveRecord::Simple::Validate';

#ok check({ is_nullable => 1, extra => { validators => ['null'] } }, undef);
#ok !check({ is_nullable => 0, extra => { validators => ['null'] } }, undef);

done_testing();
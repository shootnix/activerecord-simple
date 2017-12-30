#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;





package Customer;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use parent 'ActiveRecord::Simple';


__PACKAGE__->table_name('customer');
__PACKAGE__->columns(qw/id first_name last_name email/);
__PACKAGE__->primary_key('id');


package main;

use Data::Dumper;
use Test::More;

my $customer = Customer->new;

ok $customer->id(1);
is $customer->id, 1;

ok $customer->first_name('Bill');
is $customer->first_name, 'Bill';

ok $customer->last_name('Cleantone')->email('bill@cleantone.com');
is $customer->last_name, 'Cleantone';
is $customer->email, 'bill@cleantone.com';

is $customer->_get_table_name, 'customer';


done_testing();



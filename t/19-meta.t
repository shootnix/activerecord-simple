#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";


package Model;

use parent 'ActiveRecord::Simple::Model';


package Model::Customer;

our @ISA = qw/Model/;
use ActiveRecord::Simple::Field;

__PACKAGE__->setup(
	first_name  => char_field(max_length => 200),
	second_name => char_field(max_length => 200),
	age         => small_integer_field(error_messages => { null => 'Must be not null' }),
	email       => email_field(max_length => 200),
);

__PACKAGE__->_meta_->verbose_name('Customer');
__PACKAGE__->_meta_->verbose_name_plural('Customers');
__PACKAGE__->_meta_->ordering('first_name');


package main;

use Test::More;


my $customer = Model::Customer->new();

is $customer->_meta_->verbose_name, 'Customer';
is $customer->_meta_->verbose_name_plural, 'Customers';
is $customer->_meta_->primary_key_name, 'id';
is $customer->_meta_->table_name, 'customer';
is_deeply $customer->_meta_->columns_list, ['id', 'first_name', 'second_name', 'age', 'email'];
is_deeply $customer->_meta_->ordering, ['first_name'];


done_testing();
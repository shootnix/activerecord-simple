#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use ActiveRecord::Simple::Model::Field;

use Data::Dumper;
use List::Util qw/any/;

use Test::More;


# auto_field
my $auto_field_1 = ActiveRecord::Simple::Model::Field->auto_field();
is $auto_field_1->{size}, 11, 'auto_field.size = 11';
is $auto_field_1->{data_type}, 'integer', 'auto_field.data_type = integer';
is $auto_field_1->{is_nullable}, 0, 'auto_field.is_nullable = 0';
is $auto_field_1->{is_unique}, 1, 'auto_field.is_unique = 1';
is $auto_field_1->{is_auto_increment}, 1, 'auto_field.is_auto_increment = 1';
is $auto_field_1->{extra}{widget}, 'number', 'auto_field.widget is number';

ok my $auto_field_validators = $auto_field_1->{extra}{validators}, 'auto_field_1 got validators';

is ref $auto_field_validators, 'ARRAY', 'auto_field_1 validators is an ARRAYref';
ok scalar @$auto_field_validators > 0, 'auto_field_1 validators > 0';
ok any{ $_ eq 'invalid' } @$auto_field_validators;
ok any{ $_ eq 'null' } @$auto_field_validators;
ok any{ $_ eq 'blank' } @$auto_field_validators;

my $auto_field_2 = ActiveRecord::Simple::Model::Field->auto_field(primary_key => 1);
is $auto_field_2->{is_primary_key}, 1, 'auto_field_2.is_primary_key = 1';

my $auto_field_3 = ActiveRecord::Simple::Model::Field->auto_field('My Auto Field 3', primary_key => 1);
is $auto_field_3->{is_primary_key}, 1, 'auto_field_3.is_primary_key = 1';
is $auto_field_3->{extra}{verbose_name}, 'My Auto Field 3', 'auto_field_3.verbose_name = My Auto Field 3';

# big_auto_field
my $big_auto_field = ActiveRecord::Simple::Model::Field->big_auto_field;
is $big_auto_field->{data_type}, 'bigint', 'big_auto_field.data_type = bigint';

# big_integer_field
my $big_integer_field = ActiveRecord::Simple::Model::Field->big_integer_field;
is $big_integer_field->{data_type}, 'bigint', 'big_integer_field.data_type = bigint';

# binary_field


# boolean_field
my $boolean_field = ActiveRecord::Simple::Model::Field->boolean_field('my boolean field', default => 1);
is $boolean_field->{extra}{verbose_name}, 'my boolean field', 'boolean_field.verbose_name = "my boolean field"';
is $boolean_field->{data_type}, 'tinyint', 'boolean_field.data_type = tinyint';
is $boolean_field->{is_nullable}, 0, 'boolean_field.is_nullable = 0';
is $boolean_field->{extra}{is_blank}, 0, 'boolean_field.is_blank = 0';

my $boolean_field_validators = $boolean_field->{extra}{validators};
ok any {$_ eq 'null'} @$boolean_field_validators;
ok any {$_ eq 'blank'} @$boolean_field_validators;
ok any {$_ eq 'invalid'} @$boolean_field_validators;

is $boolean_field->{extra}{widget}, 'checkbox', 'boolean_field.widget = "checkbox"';
is $boolean_field->{extra}{default_value}, 1, 'boolean_field.default = 1';

#eval { ActiveRecord::Simple::Model::Field->boolean_field(default => 'invalid value'); };
#ok $@, 'got error for invalid default boolen';
#like $@, qr/Invalid value for boolean type:/i;


# char_field
my $char_field_1 = ActiveRecord::Simple::Model::Field->char_field(max_length => 10);
is $char_field_1->{data_type}, 'varchar', 'char_field_1.data_type = varchar';
is $char_field_1->{size}, 10, 'char_field_1.size = 10';
is $char_field_1->{is_nullable}, 0, 'char_field_1.is_nullable = 0';
is $char_field_1->{extra}{is_blank}, 0, 'char_field_1.is_blank = 0';
is $char_field_1->{extra}{widget}, 'text', 'char_field_1.widget = "text"';

my $char_field_2 = ActiveRecord::Simple::Model::Field->char_field('char_field_2', max_length => 10, default => 'hello');
is $char_field_2->{extra}{verbose_name}, 'char field 2', 'char_field_2.verbose_name is "char field 2"';
is $char_field_2->{extra}{default_value}, 'hello', 'char_field_2.default = "hello"';


done_testing();
#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use ActiveRecord::Simple::Validate qw/check_errors/;

use Data::Dumper;
use List::Util qw/any/;

use Test::More;




ok ! check_errors({ is_nullable => 1, extra => { validators => ['null'] } }, undef);
ok check_errors({ is_nullable => 0, extra => { validators => ['null'] } }, undef);
my $errors = check_errors({ is_nullable => 0, extra => { validators => ['null'] } }, undef);
is $errors->[0], 'NULL';

$errors = check_errors({ is_nullable => 0, extra => { validators => ['null'], error_messages => { null => 'must be not null' } } }, undef);
is $errors->[0], 'must be not null';

ok check_errors({ extra => { is_blank => 0, validators => ['blank'] } }, q//);
ok ! check_errors({ extra => { is_blank => 0, validators => ['blank'] } }, 'foo');

$errors = check_errors({ extra => { is_blank => 0, validators => ['blank'] } }, q//);
is $errors->[0], 'BLANK';

ok ! check_errors({ data_type => 'int', extra => { validators => ['invalid'] } }, 1);
ok check_errors({ data_type => 'int', extra => { validators => ['invalid'] } }, 'foo');

$errors = check_errors({ data_type => 'int', extra => { validators => ['invalid'] } }, 'foo');
is $errors->[0], 'INVALID';

$errors = check_errors({ data_type => 'int', extra => { is_blank => 0, validators => ['blank', 'invalid'] } }, q//);
is $errors->[0], 'BLANK';
is $errors->[1], 'INVALID';

ok ! check_errors({ data_type => 'tinyint', extra => { validators => ['invalid', 'boolean'] } }, 1);
ok ! check_errors({ data_type => 'tinyint', extra => { validators => ['invalid', 'boolean'] } }, 0);
ok check_errors({ data_type => 'tinyint', extra => { validators => ['invalid', 'boolean'] } }, 2);
$errors = check_errors({ data_type => 'int', extra => { validators => ['invalid', 'boolean'] } }, 'foo');

is $errors->[0], 'INVALID';
is $errors->[1], 'INVALID';

ok ! check_errors({ data_type => 'varchar', size => [2], extra => { validators => ['invalid'] } }, 'a');
ok ! check_errors({ data_type => 'varchar', size => [2], extra => { validators => ['invalid'] } }, 'ab');
ok check_errors({ data_type => 'varchar', size => [2], extra => { validators => ['invalid'] } }, 'abc');

my @valid_dates = ('2017-10-02', '1978-12-07', '2020-10-06');
for my $date (@valid_dates) {
	ok ! check_errors({ data_type => 'date', extra => { validators => ['invalid'] } }, $date);
}

my @invalid_dates = ('2010-30-50');
for my $date (@invalid_dates) {
	ok check_errors({ data_type => 'date', extra => { validators => ['invalid'] } }, $date);
}

my @valid_date_times = ('2017-10-02 10:10:19');
for my $date (@valid_date_times) {
	ok ! check_errors({ data_type => 'datetime', extra => { validators => ['invalid'] } }, $date), $date . ' is valid';
}

my @invalid_date_times = ('2017-10-02 30:39:10');
for my $date (@invalid_date_times) {
	ok check_errors({ data_type => 'datetime', extra => { validators => ['invalid'] } }, $date), $date . ' is invalid';
}

ok ! check_errors({ data_type => 'decimal', extra => { validators => ['invalid'] } }, '10.00');
ok ! check_errors({ data_type => 'decimal', extra => { validators => ['invalid'] } }, '10');
ok check_errors({ data_type => 'decimal', size => [3, 3], extra => { validators => ['invalid'] } }, 'foo');
ok check_errors({ data_type => 'decimal', size => [2, 2], extra => { validators => ['invalid'] } }, '10.001');
ok ! check_errors({ data_type => 'decimal', size => [2, 3], extra => { validators => ['invalid'] } }, '10.001');

ok ! check_errors({ data_type => 'varchar', extra => { validators => ['email'] } }, 'hello@aol.com');
ok check_errors({ data_type => 'varchar', extra => { validators => ['email'] } }, 'dummy');

ok check_errors({ data_type => 'varchar', extra => { validators => ['ip'] } }, 'dummy'), 'ip';
ok ! check_errors({ data_type => 'varchar', extra => { validators => ['ip'] } }, '0.0.0.0'), 'ip';

ok check_errors({ data_type => 'varchar', extra => { validators => ['ipv6'] } }, 'dummy'), 'ip v6';
ok ! check_errors({ data_type => 'varchar', extra => { validators => ['ipv6'] } }, '::ffff:192.0.2.1'), 'ip v6';

ok check_errors({ data_type => 'int', extra => { validators => ['positive'] } }, -10), 'positive';
ok ! check_errors({ data_type => 'int', extra => { validators => ['positive'] } }, 10), 'positive';

ok ! check_errors({ data_type => 'varchar', extra => { validators => ['invalid', 'choices'], choices => ['foo', 'bar', 'buzz'] } }, 'foo');
ok ! check_errors({ data_type => 'varchar', extra => { validators => ['invalid', 'choices'], choices => [['foo', 'Foo'], ['bar', 'Bar'], ['buzz', 'Buzz']] } }, 'foo');

ok check_errors({ data_type => 'varchar', extra => { validators => ['invalid', 'choices'], choices => ['foo', 'bar', 'buzz'] } }, 'foo1');
ok check_errors({ data_type => 'varchar', extra => { validators => ['invalid', 'choices'], choices => [['foo', 'Foo'], ['bar', 'Bar'], ['buzz', 'Buzz']] } }, 'foo1');


done_testing();
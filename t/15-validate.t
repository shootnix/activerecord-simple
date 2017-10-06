#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use ActiveRecord::Simple::Validate qw/check_errors error_messages/;

use Data::Dumper;
use List::Util qw/any/;

use Test::More;


my $INVALID = error_messages('invalid');
my $BLANK = error_messages('blank');
my $NULL = error_messages('null');


# auto
my $auto_not_null = { is_nullable => 0, extra => { kind => 'auto' } };
my $auto_null = { is_nullable => 1, extra => { kind => 'auto' } };

is check_errors($auto_not_null, undef), $NULL, "error ($NULL): auto_not_null = undef";
ok check_errors($auto_not_null, 'a'), 'error: auto_not_null = "a"';
is check_errors($auto_not_null, 'a'), $INVALID, "error is `$INVALID`";
ok ! check_errors($auto_not_null, 1), 'auto_not_null = 1';
ok ! check_errors($auto_not_null, 0), 'auto_not_null = 0';
ok check_errors($auto_not_null, -1), 'error: auto_not_null = -1';

ok ! check_errors($auto_null, undef), 'auto_null = undef';
ok ! check_errors($auto_null, 1), 'auto_null = 1';
ok check_errors($auto_null, 'a'), 'error: auto_null = "a"';


my $big_auto_not_null = { is_nullable => 0, extra => { kind => 'big_auto' } };
my $big_auto_null = { is_nullable => 1, extra => { kind => 'big_auto' } };

ok check_errors($big_auto_not_null, undef), 'error: big_auto_not_null = undef';
is check_errors($big_auto_not_null, undef), $NULL, "error is `$NULL`";
ok check_errors($big_auto_not_null, 'a'), 'error: big_auto_not_null = "a"';
is check_errors($big_auto_not_null, 'a'), $INVALID, "error is `$INVALID`";
ok ! check_errors($big_auto_not_null, 1), 'big_auto_not_null = 1';
ok ! check_errors($big_auto_not_null, 0), 'big_auto_not_null = 0';
ok check_errors($big_auto_not_null, -1), 'error: big_auto_not_null = -1';

ok ! check_errors($big_auto_null, undef), 'big_auto_null = undef';
ok ! check_errors($big_auto_null, 1), 'big_auto_null = 1';
ok check_errors($big_auto_null, 'a'), 'error: big_auto_null = "a"';

# integer
my $integer_not_null = { is_nullable => 0, extra => { kind => 'integer' } };

ok check_errors($integer_not_null, undef), 'error: integer_not_null = undef';
ok ! check_errors($integer_not_null, 0), 'integer_not_null = 0';
ok check_errors($integer_not_null, 'a'), 'error: integer_not_null = "a"';
ok check_errors($integer_not_null, 1.1), 'error: integer_not_null = 1.1';
ok check_errors($integer_not_null, '001'), 'error: integer_not_null = "001"';
ok ! check_errors($integer_not_null, -1), 'integer_not_null = -1';

is check_errors($integer_not_null, ''), $INVALID, "error ($INVALID): integer_not_null = ''";


my $integer_null = { is_nullable => 1, extra => { kind => 'integer' } };

ok ! check_errors($integer_null, undef), 'integer_null = undef';


my $integer_not_null_1_2_3 = { is_nullable => 0, extra => { kind => 'integer', choices => [1, 2, 3] } };

is check_errors($integer_not_null_1_2_3, undef), $INVALID, "error ($NULL): integer_not_null_1_2_3 = undef";
is check_errors($integer_not_null_1_2_3, 0), $INVALID, "error ($INVALID): integer_not_null_1_2_3 = 0";
ok ! check_errors($integer_not_null_1_2_3, 1), 'integer_not_null_1_2_3 = 1';
ok ! check_errors($integer_not_null_1_2_3, 2), 'integer_not_null_1_2_3 = 2';
ok ! check_errors($integer_not_null_1_2_3, 3), 'integer_not_null_1_2_3 = 3';


my $integer_null_1_2_3 = { is_nullable => 1, extra => { kind => 'integer', choices => [1, 2, 3] } };

is check_errors($integer_null_1_2_3, undef), $INVALID, "error ($INVALID): integer_null_1_2_3 = undef";


my $integer_not_null_1_2_NULL = { is_nullable => 0, extra => { kind => 'integer', choices => [1, 2, undef] } };

is check_errors($integer_not_null_1_2_NULL, undef), $NULL, "error ($NULL): integer_not_null_1_2_NULL = undef";


my $integer_not_null_1A_2B_3C = { is_nullable => 0, extra => { kind => 'integer', choices => [[1, 'A'], [2, 'B'], [3, 'C']] } };

ok ! check_errors($integer_not_null_1A_2B_3C, 1), 'integer_not_null_1A_2B_3C = 1';
ok ! check_errors($integer_not_null_1A_2B_3C, 2), 'integer_not_null_1A_2B_3C = 2';
ok ! check_errors($integer_not_null_1A_2B_3C, 3), 'integer_not_null_1A_2B_3C = 3';
is check_errors($integer_not_null_1A_2B_3C, 4), $INVALID, "error ($INVALID): integer_not_null_1A_2B_3C = 4";
is check_errors($integer_not_null_1A_2B_3C, 'a'), $INVALID, "error ($INVALID): integer_not_null_1A_2B_3C = 'a'";

my $integer_null_1A_2B_3C     = { is_nullable => 1, extra => { kind => 'integer', choices => [[1, 'A'], [2, 'B'], [3, 'C']] } };

# boolean
my $boolean = { is_nullable => 0, extra => { kind => 'boolean', choices => [0, 1] } };

is check_errors($boolean, undef), $INVALID, "error ($INVALID): boolean = undef";
is check_errors($boolean, 2), $INVALID, "error ($INVALID): boolean = 2";
is check_errors($boolean, -1), $INVALID, "error ($INVALID): boolean = -1";
is check_errors($boolean, 'foo'), $INVALID, "error ($INVALID): boolean = 'foo'";
ok ! check_errors($boolean, 1), 'boolean = 1';
ok ! check_errors($boolean, 0), 'boolean = 0';


# char
my $char_not_null_size    = { is_nullable => 0, size => [2], extra => { kind => 'char' } };

is check_errors($char_not_null_size, undef), $NULL, "error ($NULL): char_not_null_size = undef";
ok ! check_errors($char_not_null_size, ''), "char_not_null_size = ''";
ok ! check_errors($char_not_null_size, 'a'), "char_not_null_size = 'a'";
ok ! check_errors($char_not_null_size, 'ab'), "char_not_null_size = 'ab'";
is check_errors($char_not_null_size, 'abc'), $INVALID, "error ($INVALID): char_not_null_size = 'abc'";
ok ! check_errors($char_not_null_size, 10), 'char_not_null_size = 10';


my $char_not_null_no_size = { is_nullable => 0, extra => { kind => 'char' } };

ok ! check_errors($char_not_null_no_size, 'abcdefg'), 'char_not_null_no_size = abcdefg';


my $char_null_size        = { is_nullable => 1, size => [2], extra => { kind => 'char' } };

ok ! check_errors($char_null_size, undef), 'char_null_size = undef';


my $char_null_no_size     = { is_nullable => 1, extra => { kind => 'char' } };
my $char_not_null_a_b_c   = { is_nullable => 0, extra => { kind => 'char', choices => ['a', 'b', 'c'] } };

ok ! check_errors($char_not_null_a_b_c, 'a'), 'char_not_null_a_b_c = "a"';
ok ! check_errors($char_not_null_a_b_c, 'b'), 'char_not_null_a_b_c = "b"';
ok ! check_errors($char_not_null_a_b_c, 'c'), 'char_not_null_a_b_c = "c"';
is check_errors($char_not_null_a_b_c, 'd'), $INVALID, "error ($INVALID): char_not_null_a_b_c = 'd'";


my $char_null_a_b_c       = { is_nullable => 1, extra => { kind => 'char', choices => ['a', 'b', 'c'] } };
my $char_not_null_A_B_C   = { is_nullable => 0, extra => { kind => 'char', choices => [['a', 'A'], ['b', 'B'], ['c', 'C']] } };
my $char_null_A_B_C       = { is_nullable => 1, extra => { kind => 'char', choices => [['a', 'A'], ['b', 'B'], ['c', 'C']] } };

my $char_not_null_blank_size        = { is_nullable => 0, size => [2], extra => { kind => 'char', is_blank => 1 } };

ok ! check_errors($char_not_null_blank_size, ''), "char_not_null_blank_size = ''";
is check_errors($char_not_null_blank_size, undef), $NULL, "char_null_not_blank_size = undef";


my $char_not_null_blank_no_size     = { is_nullable => 0, extra => { kind => 'char', is_blank => 1 } };;
my $char_null_blank_size            = { is_nullable => 1, size => [2], extra => { kind => 'char', is_blank => 1 } };

ok ! check_errors($char_null_blank_size, undef), 'char_null_blank_size = undef';
ok ! check_errors($char_null_blank_size, ''), 'char_null_not_blank_size = ""';


my $char_null_blank_no_size         = { is_nullable => 1, extra => { kind => 'char', is_blank => 1 } };
my $char_null_not_blank_size        = { is_nullable => 1, size => [2], extra => { kind => 'char', is_blank => 0 } };

ok ! check_errors($char_null_not_blank_size, undef), 'char_null_not_blank_size = undef';
is check_errors($char_null_not_blank_size, ''), $BLANK, "error ($BLANK): char_null_not_blank_size = ''";


my $char_null_not_blank_no_size     = { is_nullable => 1, extra => { kind => 'char', is_blank => 0} };
my $char_not_null_not_blank_size    = { is_nullable => 0, size => [2], extra => { kind => 'char', is_blank => 0 } };
my $char_not_null_not_blank_no_size = { is_nullable => 0, extra => { kind => 'char', is_blank => 0 } };

is check_errors($char_not_null_not_blank_size, undef), $NULL, "error ($NULL): char_null_not_blank_size = undef";
is check_errors($char_not_null_not_blank_size, ''), $BLANK, "error ($BLANK): char_null_not_blank_size = ''";


# date
my $date_not_null = { is_nullable => 0, extra => { kind => 'date' } };

is check_errors($date_not_null, undef), $NULL, "error ($NULL): date_not_null = undef";
is check_errors($date_not_null, ''), $INVALID, "error ($INVALID): date_not_null = ''";
is check_errors($date_not_null, '2010-20-20'), $INVALID, "error ($INVALID): date_not_null = '2010-20-20'";
is check_errors($date_not_null, 'abc'), $INVALID, "error ($INVALID): date_not_null = 'abc'";
ok ! check_errors($date_not_null, '2017-01-01'), 'date_not_null = "2017-01-01"';


my $date_null     = { is_nullable => 1, extra => { kind => 'date' } };

ok ! check_errors($date_null, undef), 'date_null = undef';
is check_errors($date_null, ''), $INVALID, "error ($INVALID): date_null = ''";


my $date_not_null_choices = { is_nullable => 0, extra => { kind => 'date', choices => ['2010-10-10', '2017-01-01'] } };
my $date_null_choices     = { is_nullable => 1, extra => { kind => 'date', choices => ['2010-10-10', '2017-01-01'] } };

my $date_not_null_CHOICES = { is_nullable => 0, extra => { kind => 'date', choices => [['2010-10-10', 'Date 1'], ['2017-01-01', 'Date 2']] } };
my $date_null_CHOICES     = { is_nullable => 1, extra => { kind => 'date', choices => [['2010-10-10', 'Date 1'], ['2017-01-01', 'Date 2']] } };

# datetime
my $datetime_not_null = { is_nullable => 0, extra => { kind => 'date_time' } };

is check_errors($datetime_not_null, undef), $NULL, "error ($NULL): datetime_not_null = undef";
is check_errors($datetime_not_null, ''), $INVALID, "error ($INVALID): datetime_not_null = ''";
is check_errors($datetime_not_null, '2010-20-20'), $INVALID, "error ($INVALID): datetime_not_null = '2010-20-20'";
is check_errors($datetime_not_null, 'abc'), $INVALID, "error ($INVALID): datetime_not_null = 'abc'";
is check_errors($datetime_not_null, '2017-01-01'), $INVALID, "error ($INVALID): datetime_not_null = '2017-01-01'";
is check_errors($datetime_not_null, '2010-01-01 80:80:80'), $INVALID, "$INVALID: '2010-01-01 80:80:80'";
is check_errors($datetime_not_null, '2010-01-01 00:00'), $INVALID, "$INVALID: '2010-01-01 00:00'";
is check_errors($datetime_not_null, '2010-01-01 00:00:60'), $INVALID, "$INVALID: '2010-01-01 00:00:60'";

ok ! check_errors($datetime_not_null, '2010-01-01 00:00:00'), 'datetime_not_null = "2010-01-01 00:00:00"';


my $datetime_null     = { is_nullable => 1, extra => { kind => 'date_time' } };

ok ! check_errors($datetime_null, undef), 'datetime_null = undef';


my $datetime_not_null_choices = { is_nullable => 0, extra => { kind => 'date_time', choices => ['2010-10-10 10:10:10', '2017-01-01 01:01:01'] } };
my $datetime_null_choices     = { is_nullable => 1, extra => { kind => 'date_time', choices => ['2010-10-10 10:10:10', '2017-01-01 01:01:01'] } };

my $datetime_not_null_CHOICES = { is_nullable => 0, extra => { kind => 'date_time', choices => [['2010-10-10 10:10:10', 'Datetime 1'], ['2017-01-01 01:01:01', 'Datetime 2']] } };
my $datetime_null_CHOICES     = { is_nullable => 1, extra => { kind => 'date_time', choices => [['2010-10-10 10:10:10', 'Datetime 1'], ['2017-01-01 01:01:01', 'Datetime 2']] } };


# decimal
my $decimal_not_null_no_size = { is_nullable => 0, extra => { kind => 'decimal' } };

is check_errors($decimal_not_null_no_size, undef), $NULL, 'decimal_not_null_no_size = undef';
ok ! check_errors($decimal_not_null_no_size, '10.00'), 'decimal_not_null_no_size = 10.00';


my $decimal_null_no_size     = { is_nullable => 1, extra => { kind => 'decimal' } };

ok ! check_errors($decimal_null_no_size, undef), 'decimal_null_no_size = undef';


my $decimal_not_null_size    = { is_nullable => 0, size => [4, 2], extra => { kind => 'decimal' } };

ok ! check_errors($decimal_not_null_size, '88.88'), 'decimal_not_null_size = 88.88';
ok ! check_errors($decimal_not_null_size, '88'), 'decimal_not_null_size = 88';
ok ! check_errors($decimal_not_null_size, '88.8'), 'decimal_not_null_size = 88.8';
ok ! check_errors($decimal_not_null_size, '88.0'), 'decimal_not_null_size = 88.0';
ok ! check_errors($decimal_not_null_size, '88.00'), 'decimal_not_null_size = 88.00';
ok ! check_errors($decimal_not_null_size, '88.80'), 'decimal_not_null_size = 88.80';
is check_errors($decimal_not_null_size, '100.00'), $INVALID, "$INVALID: decimal_not_null_size = 100.00";
is check_errors($decimal_not_null_size, '88.001'), $INVALID, "$INVALID: decimal_not_null_size = 88.001";

is check_errors($decimal_not_null_size, ''), $INVALID, "$INVALID: decimal_not_null_size = ''";
is check_errors($decimal_not_null_size, '.'), $INVALID, "$INVALID: decimal_not_null_size = '.'";
is check_errors($decimal_not_null_size, '2.'), $INVALID, "$INVALID: decimal_not_null_size = '2.'";
is check_errors($decimal_not_null_size, '.2'), $INVALID, "$INVALID: decimal_not_null_size = '.2'";


my $decimal_null_size = { is_nullable => 1, size => [2, 2], extra => { kind => 'decimal' } };

ok ! check_errors($decimal_null_size, undef), 'decimal_null_size = undef';


my $decimal_not_null_choices = { is_nullable => 0, extra => { kind => 'decimal', choices => ['10.10', '20.20'] } };

ok ! check_errors($decimal_not_null_choices, '10.10'), 'decimal_not_null_choices = 10.10';
#ok ! check_errors($decimal_not_null_choices, '10.1'), 'decimal_not_null_choices = 10.1';


my $decimal_null_choices     = { is_nullable => 1, extra => { kind => 'decimal', choices => ['10.10', '20.20'] } };

# email
my $email_not_null_not_blank = { is_nullable => 0, extra => { kind => 'email', is_blank => 0 } };

is check_errors($email_not_null_not_blank, undef), $NULL, "$NULL: email_not_null_not_blank = undef";
is check_errors($email_not_null_not_blank, ''), $BLANK, "$BLANK: email_not_null_not_blank = ''";


my $email_not_null_blank = { is_nullable => 0, extra => { kind => 'email', is_blank => 1 } };

is check_errors($email_not_null_blank, undef), $NULL, "$NULL: email_not_null_blank = undef";
ok ! check_errors($email_not_null_blank, ''), "email_not_null_blank = ''";
is check_errors($email_not_null_blank, 'foo'), $INVALID, "$INVALID: email_not_null_blank = 'foo'";
is check_errors($email_not_null_blank, 'foo.com'), $INVALID, "$INVALID: email_not_null_blank = 'foo.com'";
ok ! check_errors($email_not_null_blank, 'foo@bar'), 'email_not_null_blank = "foo@bar"';


my $email_null = { is_nullable => 1, extra => { kind => 'email' } };

ok ! check_errors($email_null, undef), "email_null = undef";

my $email_null_not_blank = { is_nullable => 1, extra => { kind => 'email', is_blank => 0 } };

is check_errors($email_null_not_blank, ''), $BLANK, "email_null_not_blank = ''";


# generic_ip_address
my $generic_ip_address = { extra => { kind => 'generic_ip_address' } };




# generic_ipv6_address
my $generic_ipv6_address = { extra => { kind => 'generic_ipv6_address' } };

# null_boolean
my $null_boolean = { is_nullable => 1, extra => { kind => 'null_boolean', choices => [[undef, 'unknown'], [1, 'yes'], [0, 'no']] } };

# positive_integer
my $positive_integer = { extra => { kind => 'positive_integer' } };

# foreign_key
my $foreign_key = { is_nullable => 0, extra => { kind => 'foreign_key' } };

# small_integer
my $small_integer = { extra => { kind => 'small_integer' } };

# time
my $time = { extra => { kind => 'time' } };


=c

ok ! check_errors({ is_nullable => 1 }, undef);
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

ok ! check_errors({ data_type => 'int', is_nullable => 1, extra => { validators => ['null', 'blank', 'invalid'] } }, undef);


=cut

done_testing();
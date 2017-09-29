package ActiveRecord::Simple::Field;

use strict;
use warnings;
use 5.010;

use Carp qw/croak carp/;
use List::Util qw/any/;

require Exporter;
our @ISA = qw/Exporter/;

our @EXPORT = qw/
	auto_field
	boolean_field
	char_field
	big_integer_field
	big_auto_field
	binary_field
	date_field
	date_time_field
	decimal_field
	duration_field
	email_field
	file_field
	file_path_field
	float_field
	image_field
	integer_field
	generic_ip_address_field
	generic_ipv6_address_field
	null_boolean_field
	positive_integer_field
	positive_small_integer_field
	small_integer_field
	slug_field
	text_field
	time_field
	url_field
	uuid_field
	current_date
	current_date_time

	foreign_key
/;

use Data::Dumper;


sub _params {
	my $verbose_name = scalar @_ % 2 ? shift @_ : undef;

	return (_convert_verbose_name($verbose_name), @_);
}

sub _convert_verbose_name {
	my ($str) = @_;

	return undef unless $str;

	my $verbose_name = join q/ /, split q/_/, $str;

	return $verbose_name;
}

sub _generic_field {
	my ($verbose_name, %opts) = _params(@_);

	my $field = {
		is_nullable => $opts{null} // 0,
		is_unique   => $opts{unique} // 0,

		extra => {

			verbose_name  => $verbose_name,
			verbose_name_plural => undef,
			is_blank      => $opts{blank} // 0,
			default_value => $opts{default} // undef,
			help_text     => $opts{help_text},
			choices       => $opts{choices} // undef,
			db_column     => $opts{db_column} // undef,
			editable      => $opts{editable} // 1,

			error_messages => {
				null     => 'NULL',
				blank    => 'BLANK',
				invalid  => 'INVALID',
				positive => 'POSITIVE',
				email    => 'EMAIL',
				ip       => 'IP',
				ipv6     => 'IPv6',
				slug     => 'SLUG',
				uuid     => 'UUID',
			},

			validators => [],
		},
	};

	return ($field, \%opts);
}

sub auto_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'integer';
	$field->{is_auto_increment} = 1;
	$field->{size} = $opts->{max_length} // 11;
	$field->{is_unique} = 1;
	$field->{is_primary_key} = $opts->{primary_key} // 0;

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	$field->{extra}{widget} = 'number';

	return $field;
}

sub big_auto_field {
	my $field = auto_field(@_);

	$field->{data_type} = 'bigint';

	return $field;
}


sub big_integer_field {
	my $field = integer_field(@_);

	$field->{data_type} = 'bigint';

	return $field;
}

sub binary_field {
	my ($field, $opts) = (@_);

	$field->{data_type} = 'blob';
	$field->{extra}{widget} = 'file';

	return $field;
}

sub boolean_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{size} = 1;
	$field->{data_type} = 'tinyint';
	$field->{extra}{widget} = 'checkbox';

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}

sub char_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'varchar';
	$field->{size} = [$opts->{max_length}];
	$field->{extra}{widget} = 'text';

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}
sub comma_separated_integer_field { char_field(@_); }

sub date_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'date';
	$field->{extra}{widget} = 'date';
	$field->{extra}{default_value} = \&current_date;

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}

sub date_time_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'datetime';
	$field->{extra}{widget} = 'date';
	$field->{extra}{default_value} = \&current_date_time;

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}

sub decimal_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'decimal';
	$field->{size} = [$opts->{max_digits} || 1, $opts->{decimal_places} || 2];
	$field->{extra}{widget} = 'text';
	$field->{extra}{default_value} = '0.0';

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}

sub duration_field { big_integer_field(@_); }

sub email_field {
	my $field = char_field(@_);

	push @{ $field->{extra}{validators} }, 'email';

	return $field;
}
sub file_field { my ($field) = char_field(@_); $field->{extra}{widget} = 'file' }

sub file_path_field { file_field(@_); }

sub float_field { decimal_field(@_); }

sub image_field { file_field(@_); }

sub integer_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'integer';
	$field->{size} = [11];

	push @{ $field->{extra}{validators} }, qw/invalid null blank/;

	return $field;
}
sub generic_ip_address_field {
	my ($field) = _char_field(@_);

	$field->{size} = [19];
	push @{ $field->{extra}{validators} }, 'ip';

	return $field;
}
sub generic_ipv6_address_field {
	my ($field) = _char_field(@_);

	$field->{size} = [45];
	push @{ $field->{extra}{validators} }, 'ipv6';

	return $field;
}

sub null_boolean_field {
	my ($field) = boolean_field(@_);

	$field->{is_nullable} = 1;

	return $field;
}

sub positive_integer_field {
	my ($field) = integer_field(@_);

	$field->{is_unsigned} = 1;
	push @{ $field->{extra}{validators} }, 'positive';

	return $field;
}
sub positive_small_integer_field {
	my ($field) = positive_integer_field(@_);

	$field->{data_type} = 'smallint';

	return $field;
}

sub foreign_key {
	my ($field, $opts) = positive_integer_field(@_);

	$field->{is_foreign_key} = 1;

	return $field;
}

sub slug_field { my ($field) = char_field(@_); push @{ $field->{extra}{validators} }, 'slug' }

sub small_integer_field {
	my ($field) = integer_field(@_);

	$field->{data_type} = 'smallint';

	return $field;
}

sub text_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'text';
	$field->{size} = [$opts->{max_length}];
	$field->{extra}{widget} = 'textarea';

	return $field;
}

sub time_field { big_integer_field(@_); }

sub url_field {  my ($field) = char_field(@_); push @{ $field->{extra}{validators} }, 'url' }

sub uuid_field { my ($field) = char_field(@_); push @{ $field->{extra}{validators} }, 'uuid' }

### Private

sub current_date {
	my ($time) = @_;

	$time ||= time();
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);

	my $date = sprintf "%.4d-%.2d-%2d", $year+1900, $mon+1, $mday;

	return $date;
}

sub current_date_time {
	my ($time) = @_;

	$time ||= time();
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);

	my $datetime = sprintf "%.4d-%.2d-%2d %.2d:%.2d:%.2d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

	return $datetime;
}


1;
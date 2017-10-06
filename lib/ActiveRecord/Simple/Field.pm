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


our $VERSION = '0.01';


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
			verbose_name_plural => $opts{verbose_name_plural},
			#is_blank      => $opts{blank} // 0,
			default_value => $opts{default} // undef,
			help_text     => $opts{help_text},
			choices       => $opts{choices} // undef,
			db_column     => $opts{db_column} // undef,
			editable      => $opts{editable} // 1,
			widget        => $opts{widget} || 'text', ### default widget is input type="text"

			error_messages => {
				null     => $opts{error_messages}{null} || 'NULL',
				blank    => $opts{error_messages}{blank} || 'BLANK',
				invalid  => $opts{error_messages}{invalid} || 'INVALID',
			},
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
	$field->{extra}{kind} = 'auto';

	$field->{extra}{widget} = 'number';

	return $field;
}

sub big_auto_field {
	my $field = auto_field(@_);

	$field->{data_type} = 'bigint';
	$field->{extra}{kind} = 'big_auto';

	return $field;
}


sub big_integer_field {
	my $field = integer_field(@_);

	$field->{data_type} = 'bigint';
	$field->{extra}{kind} = 'big_integer';

	return $field;
}

sub binary_field {
	my ($field, $opts) = (@_);

	$field->{data_type} = 'blob';
	$field->{extra}{widget} = 'file';
	$field->{extra}{kind} = 'binary';

	$field->{is_nullable} = $opts->{null} || 0;
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field;
}

sub boolean_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{size} = [1];
	$field->{data_type} = 'tinyint';

	$field->{extra}{kind} = 'boolean';
	$field->{extra}{widget} = $opts->{widget} || 'checkbox';
	$field->{extra}{choices} = [0, 1];

	return $field;
}

sub char_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'varchar';
	$field->{extra}{kind} = 'char';
	$field->{size} = [$opts->{max_length}];

	$field->{is_nullable} = $opts->{null} || 0;
	$field->{extra}{is_blank} = $opts->{blank} || 0;


	if ($opts->{choices}) {
		$field->{extra}{choices} = $opts->{choices};
		$field->{extra}{widget} = $opts->{widget} || 'select';
		if ($field->{extra}{widget} eq 'radio') {
			carp 'Warning: you\'re using "radio" widget without default value and "null" attribute set to 0'
				if $field->{is_nullable} == 0 && ! defined $field->{extra}{default_value};
		}
	}

	return $field;
}
sub comma_separated_integer_field { char_field(@_); }

sub date_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'date';
	$field->{extra}{kind} = 'date';
	$field->{extra}{widget} = 'date';
	#$field->{extra}{default_value} = \&current_date;

	$field->{is_nullable} = $opts->{null} || 0;
	#$field->{extra}{is_blank} = $opts->{blank} || 0;

	if ($opts->{choices}) {
		$field->{extra}{choices} = $opts->{choices};
		$field->{extra}{widget} = 'select';
	}

	return $field;
}

sub date_time_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'datetime';
	$field->{extra}{kind} = 'date_time';
	$field->{extra}{widget} = 'datetime';

	$field->{is_nullable} = $opts->{null} || 0;
	#$field->{extra}{is_blank} = $opts->{blank} || 0;

	if ($opts->{choices}) {
		$field->{extra}{choices} = $opts->{choices};
		$field->{extra}{widget} = 'select';
	}

	return $field;
}

sub decimal_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'decimal';
	$field->{extra}{kind} = 'decimal';
	$field->{size} = [$opts->{max_digits} || 4, $opts->{decimal_places} || 2];

	$field->{is_nullable} = $opts->{null} || 0;
	#$field->{extra}{is_blank} = $opts->{blank} || 0;

	if ($opts->{choices}) {
		$field->{extra}{choices} = $opts->{choices};
		$field->{extra}{widget} = 'select';
	}

	return $field;
}

sub duration_field { big_integer_field(@_); }

sub email_field {
	my $field = char_field(@_);

	$field->{extra}{kind} = 'email';
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field;
}
sub file_field {
	my ($field) = char_field(@_);

	$field->{extra}{widget} = 'file';
	$field->{extra}{kind} = 'file';

	return $field;
}

sub file_path_field {
	my ($field) = file_field(@_);

	$field->{extra}{kind} = 'file_path';
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field;
}

sub float_field { decimal_field(@_); }

sub image_field {
	my ($field) = file_field(@_);

	$field->{extra}{kind} = 'image';
}

sub integer_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'integer';
	$field->{extra}{kind} = 'integer';
	$field->{size} = [11];

	$field->{extra}{widget} = 'number';

	$field->{is_nullable} = $opts->{null} || 0;

	if ($opts->{choices}) {
		$field->{extra}{choices} = $opts->{choices};
		$field->{extra}{widget} = $opts->{widget} || 'select';
		if ($field->{extra}{widget} eq 'radio') {
			carp 'Warning: you\'re using "radio" widget without default value and "null" attribute set to 0'
				if $field->{is_nullable} == 0 && ! defined $field->{extra}{default_value};
		}
	}

	return $field;
}
sub generic_ip_address_field {
	my ($field) = char_field(@_);

	$field->{size} = [19];
	$field->{extra}{kind} = 'generic_ip_address';
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field;
}
sub generic_ipv6_address_field {
	my ($field) = char_field(@_);

	$field->{extra}{kind} = 'generic_ipv6_address';
	$field->{size} = [45];
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field;
}

sub null_boolean_field {
	my ($field) = boolean_field(@_);

	$field->{is_nullable} = 1;
	$field->{extra}{widget} = $field->{extra}{widget} eq 'radio' ? $field->{extra}{widget} : 'select';
	$field->{extra}{choices} //= [[undef, 'Unknown'], [1, 'Yes'], [0, 'No']];

	$field->{extra}{kind} = 'null_boolean';

	return $field;
}

sub positive_integer_field {
	my ($field) = integer_field(@_);

	$field->{is_unsigned} = 1;
	$field->{extra}{kind} = 'positive_integer';

	return $field;
}
sub positive_small_integer_field {
	my ($field) = positive_integer_field(@_);

	$field->{data_type} = 'smallint';
	$field->{extra}{kind} = 'positive_small_integer';

	return $field;
}

sub foreign_key {
	my ($field, $opts) = positive_integer_field(@_);

	$field->{is_foreign_key} = 1;
	$field->{extra}{kind} = 'foreign_key';

	return $field;
}

sub slug_field { my ($field) = char_field(@_); }

sub small_integer_field {
	my ($field) = integer_field(@_);

	$field->{data_type} = 'smallint';
	$field->{extra}{kind} = 'small_integer';

	return $field;
}

sub text_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'text';
	$field->{extra}{kind} = 'text';
	$field->{size} = [$opts->{max_length}];
	$field->{extra}{widget} = 'textarea';

	$field->{extra}{is_blank} = $opts->{blank} || 0;
	$field->{is_nullable} = $opts->{null} || 0;

	return $field;
}

sub time_field {
	my ($field) = big_integer_field(@_);

	$field->{extra}{kind} = 'time';

	return $field;
}

sub url_field {
	my ($field) = char_field(@_);

	$field->{extra}{kind} = 'url';
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field
}

sub uuid_field {
	my ($field) = char_field(@_);

	$field->{extra}{kind} = 'uuid';
	$field->{extra}{is_blank} = $opts->{blank} || 0;

	return $field
}


sub current_date {
	my ($time) = @_;

	$time ||= time();
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);

	my $date = sprintf "%.4d-%.2d-%.2d", $year+1900, $mon+1, $mday;

	return $date;
}

sub current_date_time {
	my ($time) = @_;

	$time ||= time();
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);

	my $datetime = sprintf "%.4d-%.2d-%.2d %.2d:%.2d:%.2d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

	return $datetime;
}


1;
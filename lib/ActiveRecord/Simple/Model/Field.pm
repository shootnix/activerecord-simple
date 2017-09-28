package ActiveRecord::Simple::Model::Field;

use strict;
use warnings;
use 5.010;

use Carp qw/croak carp/;
use List::Util qw/any/;

use Data::Dumper;


sub _params {
	my $model = shift;
	my $verbose_name = scalar @_ % 2 ? shift @_ : undef;

	return ($model, _convert_verbose_name($verbose_name), @_);
}

sub _convert_verbose_name {
	my ($str) = @_;

	return undef unless $str;

	my $verbose_name = join q/ /, split q/_/, $str;

	return $verbose_name;
}

sub _generic_field {
	my ($model, $verbose_name, %opts) = _params(@_);

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
				null            => 'NULL',
				blank           => 'BLANK',
				invalid         => 'INVALID',
				invalid_choice  => 'INVALID CHOICE',
				unique          => 'UNIQUE',
				unique_for_date => 'UNIQUE FOR DATE',
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
	# ...
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
	$field->{size} = $opts->{max_length};
	$field->{extra}{widget} = 'text';

	return $field;
}
sub comma_separated_integer_field {

}
sub date_field {

}
sub date_time_field {

}
sub decimal_field {

}
sub duration_field {}
sub email_field {
	my $field = char_field(@_);

	push @{ $field->{extra}{validators} }, 'email';

	return $field;
}
sub file_field {}
#FileField and FieldFile
sub file_path_field {}
sub float_field {}
sub image_field {}

sub integer_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'integer';
	$field->{size} = 11;

	return $field;
}
sub generic_ip_address_field {
	my ($field) = _char_field(@_);

	$field->{size} = 19;
	push @{ $field->{extra}{validators} }, 'ip';

	return $field;
}
sub generic_ipv6_address_field {
	my ($field) = _char_field(@_);

	$field->{size} = 45;
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

	push @{ $field->{extra}{validators} }, 'positive';

	return $field;
}
sub positive_small_integer_field {
	my ($field) = positive_integer_field(@_);

	$field->{data_type} = 'smallint';

	return $field;
}

sub slug_field {}

sub small_integer_field {
	my ($field) = integer_field(@_);

	$field->{data_type} = 'smallint';

	return $field;
}

sub text_field {
	my ($field, $opts) = _generic_field(@_);

	$field->{data_type} = 'text';
	$field->{size} = $opts->{max_length};
	$field->{extra}{widget} = 'textarea';

	return $field;
}

sub time_field {}
sub url_field {}
sub uuid_field {}

sub foreign_key {}


1;
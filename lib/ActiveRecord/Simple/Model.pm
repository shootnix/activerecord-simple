package ActiveRecord::Simple::Model;

use strict;
use warnings;
use 5.010;

use parent 'ActiveRecord::Simple';
use ActiveRecord::Simple::Field;
use ActiveRecord::Simple::Utils;
use ActiveRecord::Simple::Validate;
use Module::Load;

use Data::Dumper;


our $VERSION = '0.01';


sub setup {
	my ($class, $fields) = @_;

	my @columns;
	my $primary_key;
	my $table_name = lc pop [split qw/::/, $class];
	my %schema;

	for (my $i=0; $i<@$fields; $i++) {
		my $verbose_name = $fields->[$i];
		$i++;
		my $field = $fields->[$i];
		my $column_name = $field->{extra}{db_column} || $verbose_name;
		unless ($field->{extra}{verbose_name}) {
			$field->{extra}{verbose_name} = lc join q/ /, split q/_/, $verbose_name;
		}

		push @columns, $column_name;
		$schema{$column_name} = $field;

		$primary_key = $column_name if $field->{is_primary_key};
	}

	if (!$primary_key) {
		my $pk_field = auto_field(primary_key => 1, editable => 0);
		$schema{id} = $pk_field;

		unshift @columns, 'id';
		$primary_key = 'id';
	}

	$class->columns(\@columns);
	$class->table_name($table_name);
	$class->primary_key($primary_key);
	$class->_mk_attribute_getter('_get_model_table_schema', \%schema);
}

sub new {
	my $self = shift->SUPER::new(@_);

	COLUMN_NAME:
	for my $column_name (@{ $self->_get_columns }) {
		next COLUMN_NAME if defined $self->$column_name;

		my $default_value = $self->_get_model_table_schema->{$column_name}{extra}{default_value};
		if ($default_value) {
			if (ref $default_value eq 'CODE') {
				$self->$column_name($default_value->());
			}
			else {
				$self->$column_name($default_value);
			}
		}
	}

	return $self;
}

sub save {
	my ($self) = @_;

	my %validation_errors; my $n_errors = 0; my $save_result;
	COLUMN_NAME:
	for my $column_name (@{ $self->_get_columns }) {
		my $fld = $self->_get_model_table_schema->{$column_name};
		next COLUMN_NAME unless $fld->{extra}{editable};

		my ($validation_ok, $errors) = ActiveRecord::Simple::Validate::check($fld, $self->$column_name);
		next COLUMN_NAME if $validation_ok;

		$validation_errors{$column_name} = $errors;
		$n_errors++;
	}

	if ($n_errors > 0) {
		return wantarray ? (undef, \%validation_errors) : undef;
	}

	# save
	$self::SUPER->save();

	return wantarray ? (1, undef) : 1;
}

1;
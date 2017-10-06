package ActiveRecord::Simple::Model;

use strict;
use warnings;
use 5.010;

use parent 'ActiveRecord::Simple';
use ActiveRecord::Simple::Field;
use ActiveRecord::Simple::Utils;
use ActiveRecord::Simple::Validate qw/check_errors/;
use ActiveRecord::Simple::Meta;

use Carp qw/croak carp/;


use Data::Dumper;

our $VERSION = '0.01';


sub setup {
	my ($class, @fields) = @_;

	my %schema;
	if (!@fields) {
		$class->_auto_load();
		for my $column_name (@{ $class->_get_columns }) {
			my ($field) = ActiveRecord::Simple::Field::_generic_field($column_name);
			$schema{$column_name} = $field;
		}
	}
	else {

		my @columns;
		my $primary_key;
		my $table_name = ActiveRecord::Simple::Utils::class_to_table_name($class);

		for (my $i=0; $i<@fields; $i++) {
			my $verbose_name = $fields[$i];
			$i++;
			my $field = $fields[$i];
			my $column_name = $field->{extra}{db_column} || $verbose_name;
			unless ($field->{extra}{verbose_name}) {
				$field->{extra}{verbose_name} =
					lc ActiveRecord::Simple::Utils::class_to_table_name($class) . q/'s / . join q/ /, split q/_/, $verbose_name;
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
	}

	$class->_mk_attribute_getter('_get_model_table_schema', \%schema);
}

sub new {
	my $class = shift;
	my %params = _deref_params(@_);

	my $self = $class->SUPER::new();

	COLUMN_NAME:
	for my $column_name (@{ $self->_meta_->columns_list }) {
		next COLUMN_NAME if defined $self->$column_name;

		defined $params{$column_name}
			? $self->$column_name($params{$column_name})
			: $self->_set_default_value($column_name);
	}

	return $self;
}

sub strict_types {
	my ($class, $val) = @_;

	$class->_mk_attribute_getter('_use_strict_types')
}

sub _deref_params {

	return if scalar @_ == 0;

	if (scalar @_ == 1) {
		my $arg = $_[0];
		if (ref $arg && ref $arg eq 'HASH') {
			return %$arg;
		}
		elsif (ref $arg && ref $arg eq 'ARRAY') {
			return @$arg;
		}
		else {
			return ($arg);
		}
	}
	else {
		return @_;
	}
}

sub _set_default_value {
	my ($self, $column_name) = @_;

	my $default_value = $self->_get_model_table_schema->{$column_name}{extra}{default_value}
		or return;

	if (ref $default_value eq 'CODE') {
		$self->$column_name($default_value->());
	}
	else {
		$self->$column_name($default_value);
	}
}

sub save {
	my ($self) = @_;

	# validate before save:
	my %validation_errors; my $n_errors = 0;
	COLUMN_NAME:
	for my $column_name (@{ $self->_get_columns }) {

		my $fld = $self->_get_model_table_schema->{$column_name};
		next COLUMN_NAME unless $fld->{extra}{editable};
		if (my $errors = check_errors($fld, $self->$column_name)) {
			$n_errors++;
			$validation_errors{$column_name} = $errors;
		}
	}

	if ($n_errors > 0) {
		return wantarray ? (undef, \%validation_errors) : undef;
	}

	$self->SUPER::save();
}

sub _meta_ {
    my ($self) = @_;

    if (!$self->can('_get_meta_data')) {
        my ($pkey_val, $caller);
        my $pkey = $self->_get_primary_key;
        my $relations;
        if ($self->can('_get_relations')) {
            $relations = $self->_get_relations;
        }
        my $meta = ActiveRecord::Simple::Meta->new({
            table_name => $self->_get_table_name,
            primary_key_name => $pkey,
            columns_list => $self->_get_columns,
            relations => $relations,
            schema => $self->can('_get_model_table_schema') ? $self->_get_model_table_schema : undef,
            caller => $caller,
        });

        my $class = blessed $self ? ref $self : $self;

        my $verbose_name = ActiveRecord::Simple::Utils::class_to_table_name($class);
        $meta->verbose_name($verbose_name);

        $class->_mk_attribute_getter('_get_meta_', $meta);
    }

    return $self->_get_meta_;
}

sub _mk_accessors {
    my ($class, $fields) = @_;

    my $super = caller;
    return unless $fields;

    no strict 'refs';
    FIELD:
    for my $f (@$fields) {
        my $pkg_accessor_name = $class . '::' . $f;
        next FIELD if $class->can($pkg_accessor_name);
        *{$pkg_accessor_name} = sub {
            if ( scalar @_ > 1 ) {
                my $data_type = $_[0]->_meta_->schema->{$f}{data_type};
                my $val = $_[1];
                $val = undef if defined $val && $val eq q// && ActiveRecord::Simple::Utils::is_numeric($data_type);
                my $field = $_[0]->_meta_->schema->{$f};
                if ($field->{size}) {
                	my $msize = $field->{size}[1];
                	$val = sprintf "%0." . $msize . "f", $val;
                }

                my $errors = check_errors($_[0]->_meta_->schema->{$f}, $val)
                	if $class->can('_use_strict_types') && $class->_use_strict_types == 1;
                croak "Validate Errors for $f = $val: $errors->[0]" if $errors && ref $errors && ref $errors eq 'ARRAY';

                $_[0]->{$f} = $val;

                return $_[0];
            }

            return $_[0]->{$f};
        }
    }
    use strict 'refs';

    return 1;
}

1;
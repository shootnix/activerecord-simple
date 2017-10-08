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

	@fields or @fields = ();
	my (%schema, @columns, $primary_key);
	my $table_name = ActiveRecord::Simple::Utils::class_to_table_name($class);


	if (scalar @fields == 0) {
		# 0. check the name
    	my $table_info_sth = $class->dbh->table_info('', '%', $table_name, 'TABLE');
    	$table_info_sth->fetchrow_hashref or croak "Can't find table '$table_name' in the database";

    	# 1. check the primary key
    	my $primary_key_sth = $class->dbh->primary_key_info(undef, undef, $table_name);
    	my $primary_key_data = $primary_key_sth->fetchrow_hashref;
    	$primary_key = ($primary_key_data) ? $primary_key_data->{COLUMN_NAME} : undef;

    	push @fields, $primary_key, auto_field(primary_key => 1) if $primary_key;

    	# 2. check columns
    	my $column_info_sth = $class->dbh->column_info(undef, undef, $table_name, undef);
    	my $cols = $column_info_sth->fetchall_arrayref({});

    	COLUMN:
    	for my $col (@$cols) {
    		my $name = $col->{COLUMN_NAME};
    		next COLUMN if $primary_key && $name eq $primary_key;
    		my ($data_type, $ATTR) = split q/ /, $col->{TYPE_NAME};
    		my $field = ActiveRecord::Simple::Field::_generic_field(
    			db_column => $name,
    			null      => $col->{NULLABLE},
    			default   => $col->{COLUMN_DEF},
    		);
    		$field->{data_type} = $data_type;
    		$field->{is_auto_increment} = 1 if $ATTR && $ATTR eq 'AUTO_INCREMENT';
    		$field->{size} = [$col->{COLUMN_SIZE}] if defined $col->{COLUMN_SIZE};
    		if ($data_type eq 'decimal' || $data_type eq 'numeric') {
    			push @{ $field->{size} }, $col->{DECIMAL_DIGITS};
    		}
    		set_kind($field);

    		push @fields, $name, $field;
    	}
	}

	for (my $i=0; $i<@fields; $i++) {
		my $verbose_name = $fields[$i];
		$i++;
		my $field = $fields[$i];
		my $column_name = $field->{extra}{db_column} || $verbose_name;

		$field->{extra}{verbose_name} ||= lc $table_name . q/'s / . join q/ /, split q/_/, $verbose_name;

		push @columns, $column_name;
		$schema{$column_name} = $field;

		$primary_key = $column_name if $field->{is_primary_key};
	}

	if (!$primary_key) {
		my $pk_field = auto_field(primary_key => 1);
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

sub strict_validation {
	my ($class, $val) = @_;

	$class->_mk_attribute_getter('_use_strict_validation', $val)
}

sub warn_validation {
	my ($class, $val) = @_;

	if ($class->can('_use_strict_validation') && $class->_use_strict_validation == 1) {
		carp "Hmm.. You're already using a strict_validation for this model. Using warn_validation doesn't make sence.";
		return;
	}

	$class->_mk_attribute_getter('_use_warn_validation', $val);
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
    	my $class = blessed $self ? ref $self : $self;

    	if (!$self->can('_get_primary_key') && !$self->can('_get_table_name') && !$self->can('_get_columns')) {
    		croak "Can't get any information about class $class.\nMost likely, you forgot to setup it erlier. Use __PACKAGE__->setup() in the class";
    	}

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
        });



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

                if ($field->{data_type} eq 'decimal' && defined $val) {
                	my $msize = $field->{size}[1];
                	$val = sprintf "%0." . $msize . "f", $val if $msize;
                }

                if ($class->can('_use_strict_validation') && $class->_use_strict_validation == 1) {
                	my $is_invalid = check_errors($field, $val);
                	croak "Invalid value for field `$f`: $is_invalid" if $is_invalid;
                }

                if ($class->can('_use_warn_validation') && $class->_use_warn_validation == 1) {
                	my $is_invalid = check_errors($field, $val);
                	carp "Invalid value for field `$f`: $is_invalid" if $is_invalid;
                }

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
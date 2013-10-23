package ActiveRecord::Simple;

use 5.010;
use strict;
use warnings;

=head1 NAME

ActiveRecord::Simple - Simple to use lightweight implementation of ActiveRecord pattern.

=head1 VERSION

Version 0.40

=cut

our $VERSION = '0.40';

use utf8;
use Encode;
use Module::Load;
use Carp;
use Storable qw/freeze/;

my $dbhandler = undef;
my $TRACE     = defined $ENV{ACTIVE_RECORD_SIMPLE_TRACE} ? 1 : undef;

sub new {
    my ($class, $param) = @_;

    $class->_mk_accessors($class->get_columns());

    if ($class->can('get_relations')) {
        my $relations = $class->get_relations();

	no strict 'refs';

        RELNAME:
        for my $relname ( keys %{ $relations } ) {
            my $pkg_method_name = $class . '::' . $relname;

            next RELNAME if $class->can($pkg_method_name);

            *{$pkg_method_name} = sub {
                my $self = shift;

                unless ( $self->{"relation_instance_$relname"} ) {
                    my $rel  = $class->get_relations->{$relname};
                    my $fkey = $rel->{foreign_key} || $rel->{key};

                    my $type = $rel->{type} . '_to_';
                    my $rel_class = ( ref $rel->{class} eq 'HASH' ) ?
                        ( %{ $rel->{class} } )[1]
                        : $rel->{class};

                    load $rel_class;

                    while ( my ($rel_key, $rel_opts) = each %{ $rel_class->get_relations } ) {
                        my $rel_opts_class = ( ref $rel_opts->{class} eq 'HASH' ) ?
                            ( %{ $rel_opts->{class} } )[1]
                            : $rel_opts->{class};
                        $type .= $rel_opts->{type} if $rel_opts_class eq $class;
                    }

                    if ( $type eq 'one_to_many' or $type eq 'one_to_one' ) {
                        my ($pkey, $fkey_val);
                        if ( $rel_class->can('get_primary_key') ) {
                            $pkey = $rel_class->get_primary_key;
                            $fkey_val = $self->$fkey;
                        }
                        else {
                            $pkey = $fkey;
                            my $self_pkey = $self->get_primary_key;
                            $fkey_val = $self->$self_pkey;
                        }

                        $self->{"relation_instance_$relname"} = $rel_class->find(
                            "$pkey = ?",
                            $fkey_val
                        )->fetch();
                    }
                    elsif ( $type eq 'many_to_one' ) {
                        unless ( $self->can('get_primary_key') ) {
                            return $rel_class->new();
                        }

                        my $pkey = $self->get_primary_key;
                        $self->{"relation_instance_$relname"} =
			    $rel_class->find(
				"$fkey = ?",
				$self->$pkey,
			    );
                    }
                    elsif ( $type eq 'many_to_many' ) {
                        $self->{"relation_instance_$relname"} =
                            $rel_class->_find_many_to_many({
                                root_class => $class,
                                m_class    => ( %{ $rel->{class} } )[0],
                                self       => $self,
                            });
                    }
                }

                $self->{"relation_instance_$relname"};
            }
        }
        use strict 'refs';
    }

    $class->use_smart_saving(0);

    return bless $param || {}, $class;
}

sub _find_many_to_many {
    my ($class, $param) = @_;

    return unless $class->dbh && $param;

    my $mc_fkey;
    my $class_opts = {};
    my $root_class_opts = {};

    for my $opts ( values %{ $param->{m_class}->get_relations } ) {
        if ($opts->{class} eq $param->{root_class}) {
            $root_class_opts = $opts;
        }
        elsif ($opts->{class} eq $class) {
            $class_opts = $opts;
        }
    }

    my $connected_table_name = $class->get_table_name;
    my $sql_stm;
    $sql_stm .=
        'select ' .
        "$connected_table_name\.*" .
        ' from ' .
        $param->{m_class}->get_table_name .
        ' join ' .
        $connected_table_name .
        ' on ' .
        $connected_table_name . '.' . $class->get_primary_key .
        ' = ' .
        $param->{m_class}->get_table_name . '.' . $class_opts->{key} .
        ' where ' .
        $root_class_opts->{key} .
        ' = ' .
        $param->{self}->{ $param->{root_class}->get_primary_key };

    my $container_class = $class->new();
    do {
        my $SQL_REQUEST = _quote_string($sql_stm, $class->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
    } if $TRACE;

    my $resultset = $class->dbh->selectall_arrayref($sql_stm, { Slice => {} });
    my @bulk_objects;
    for my $params (@$resultset) {
        my $obj = $class->new($params);

        $obj->{isin_database} = 1;
        push @bulk_objects, $obj;
    }

    $container_class->{_objects} = \@bulk_objects;

    return $container_class;
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
                $_[0]->{$f} = $_[1];

		return $_[0];
	    }

	    return $_[0]->{$f};
	}
    }
    use strict 'refs';

    return 1;
}

sub columns {
    my ($class, $columns) = @_;

    $class->_mk_attribute_getter('get_columns', $columns);
}

sub primary_key {
    my ($class, $primary_key) = @_;

    $class->_mk_attribute_getter('get_primary_key', $primary_key);
}

sub table_name {
    my ($class, $table_name) = @_;

    $class->_mk_attribute_getter('get_table_name', $table_name);
}

sub use_smart_saving {
    my ($class, $is_on) = @_;

    $is_on = 1 if not defined $is_on;

    $class->_mk_attribute_getter('smart_saving_used', $is_on);
}

sub relations {
    my ($class, $relations) = @_;

    $class->_mk_attribute_getter('get_relations', $relations);
}

sub _mk_attribute_getter {
    my ($class, $method_name, $return) = @_;

    my $pkg_method_name = $class . '::' . $method_name;
    unless ( $class->can($pkg_method_name) ) {
	no strict 'refs';
	*{$pkg_method_name} = sub { $return };
    }
}

sub dbh {
    my ($self, $dbh) = @_;

    if ($dbh) {
        $dbhandler = $dbh;
    }

    return $dbhandler;
}

sub _quote_string {
    my ($string, $driver_name) = @_;

    $driver_name ||= 'Pg';
    my $quotes_map = {
        Pg     => q/"/,
	mysql  => q/`/,
	SQLite => q/`/,
    };
    my $quote = $quotes_map->{$driver_name};

    $string =~ s/"/$quote/g;

    return $string;
}

sub save {
    my ($self) = @_;

    return unless $self->dbh;

    return 1 if $self->smart_saving_used
        and defined $self->{snapshoot}
        and $self->{snapshoot} eq freeze $self->to_hash;

    my $save_param = {};
    my $fields = $self->get_columns;
    my $pkey;
    if ( $self->can('get_primary_key') ) {
        $pkey   = $self->get_primary_key;
    }

    FIELD:
    for my $field (@$fields) {
        next FIELD if $pkey && $field eq $pkey && !$self->{$pkey};
        $save_param->{$field} = $self->{$field};
    }

    my $result;
    if ( $self->{isin_database} ) {
	$result = $self->_update($save_param);
    }
    else {
        $result = $self->_insert($save_param);
    }
    $self->{need_to_save} = 0 if $result;

    return $result;
}

sub _insert {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name      = $self->get_table_name;
    my @field_names     = grep { defined $param->{$_} } sort keys %$param;
    my $primary_key;
    if ( $self->can('get_primary_key') ) {
        $primary_key = $self->get_primary_key;
    }

    my $field_names_str = join q/, /, map { q/"/ . $_ . q/"/ } @field_names;
    my $values          = join q/, /, map { '?' } @field_names;
    my @bind            = map { $param->{$_} } @field_names;

    my $pkey_val;
    my $sql_stm = qq{
        insert into "$table_name" ($field_names_str)
        values ($values)
    };

    if ( $self->dbh->{Driver}{Name} eq 'Pg' ) {
        $sql_stm .= ' returning ' . $primary_key if $primary_key;

        do {
            my $SQL_REQUEST = _quote_string($sql_stm, $self->dbh->{Driver}{Name});
            carp $SQL_REQUEST;
            carp 'bind: ' . join q/, /, @bind;
        } if $TRACE;

	$pkey_val = $self->dbh->selectrow_array(
            _quote_string($sql_stm, $self->dbh->{Driver}{name}),
            undef, @bind
        );
    }
    else {
        do {
            my $SQL_REQUEST = _quote_string($sql_stm, $self->dbh->{Driver}{Name});
            carp $SQL_REQUEST;
            carp 'bind: ' . join q/, /, @bind;
        } if $TRACE;
	my $sth = $self->dbh->prepare(_quote_string($sql_stm, $self->dbh->{Driver}{Name}));
        $sth->execute(@bind);

	if ( $primary_key && defined $self->{$primary_key} ) {
	    $pkey_val = $self->{$primary_key};
	}
	else {
	    $pkey_val = $self->dbh->last_insert_id(
	        undef,
		undef,
		$table_name,
		undef
	    );
	}
    }

    if ( $primary_key && $self->can($primary_key) && $pkey_val ) {
        $self->$primary_key($pkey_val);
    }
    $self->{isin_database} = 1;

    return $pkey_val;
}

sub _update {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name      = $self->get_table_name;
    my @field_names     = sort keys %$param;
    my $primary_key     = $self->get_primary_key;

    my $setstring = join ', ', map { "$_ = ?" } @field_names;
    my @bind = map { $param->{$_} } @field_names;
    push @bind, $self->{$primary_key};

    my $sql_stm = qq{
        update "$table_name" set $setstring
        where
            $primary_key = ?
    };
    do {
        my $SQL_REQUEST = _quote_string($sql_stm, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
        carp 'bind: ' . join q/, /, @bind;
    } if $TRACE;

    return $self->dbh->do(
        _quote_string($sql_stm, $self->dbh->{Driver}{Name}),
        undef,
        @bind
    );
}

# param:
#     cascade => 1
sub delete {
    my ($self, $param) = @_;

    return unless $self->dbh;

    my $table_name = $self->get_table_name;
    my $pkey = $self->get_primary_key;
    return unless $self->{$pkey};

    my $sql = qq{
        delete from "$table_name" where $pkey = ?
    };
    $sql .= ' cascade ' if $param && $param->{cascade};

    my $res = undef;
    my $driver_name = $self->dbh->{Driver}{Name};
    do {
        my $SQL_REQUEST = _quote_string($sql, $driver_name);
        carp $SQL_REQUEST;
    } if $TRACE;
    if ( $self->dbh->do(_quote_string($sql, $driver_name), undef, $self->{$pkey}) ) {
	$self->{isin_database} = undef;
	delete $self->{$pkey};

	$res = 1;
    }

    return $res;
}

sub find {
    my ($class, @param) = @_;

    my $self = $class->new();
    $self->{prep_request_method} = undef;
    $self->{prep_request_params} = \@param;

    if (!ref $param[0] && scalar @param == 1) {
        $self->{prep_request_method} = '_find_one_by_primary_key';
    }
    elsif (!ref $param[0] && scalar @param == 0) {
        $self->{prep_request_method} = '_find_all';
    }
    elsif (ref $param[0] && ref $param[0] eq 'HASH') {
        $self->{prep_request_method} = '_find_many_by_params';
    }
    elsif (ref $param[0] && ref $param[0] eq 'ARRAY') {
        $self->{prep_request_method} = '_find_many_by_primary_keys';
    }
    else {
        $self->{prep_request_method} = '_find_many_by_condition';
    }

    return $self;
}

sub fetch {
    my ($self, $limit) = @_;

    return $self->_get_slice($limit) if defined $self->{_objects};

    my $resultset = $self->_find_many_by_prepared_statement();

    my @bulk_objects;
    if (defined $resultset && ref $resultset eq 'ARRAY' && scalar @$resultset > 0) {
        my $class = ref $self;
        for my $object_data (@$resultset) {
            my $obj = $class->new();
            $obj->_fill_params($object_data);

            if ($obj->smart_saving_used) {
                $obj->{snapshoot} = freeze($object_data);
            }

            $obj->{isin_database} = 1;

            push @bulk_objects, $obj;
        }
    }
    elsif (defined $resultset && ref $resultset eq 'HASH') {
        #$self->_fill_params($resultset);
        my $class = ref $self;
        my $obj = $class->new();
        $obj->_fill_params($resultset);
        $obj->{isin_database} = 1;

        push @bulk_objects, $obj;
    }
    else {
        push @bulk_objects, $self;
    }

    $self->{_objects} = \@bulk_objects;

    $self->_get_slice($limit);
}

sub order_by {
    my ($self, @param) = @_;

    return if not defined $self->{prep_request_method};

    $self->{prep_order_by} = \@param;

    return $self;
}

sub desc {
    my ($self) = @_;

    return if not defined $self->{prep_request_method};

    $self->{prep_desc} = 1;

    return $self;
}

sub asc {
    my ($self, @param) = @_;

    return if not defined $self->{prep_request_method};

    $self->{prep_asc} = 1;

    return $self;
}

sub limit {
    my ($self, $limit) = @_;

    return if not defined $self->{prep_request_method};

    $self->{prep_limit} = $limit;

    return $self;
}

sub offset {
    my ($self, $offset) = @_;

    return if not defined $self->{prep_request_method};

    $self->{prep_offset} = $offset;

    return $self;
}

sub _get_slice {
    my ($self, $time) = @_;

    return unless $self->{_objects} && ref $self->{_objects} eq 'ARRAY';

    if (wantarray) {
        $time ||= scalar @{ $self->{_objects} };

        return splice @{ $self->{_objects} }, 0, $time;
    }
    else {
        return shift @{ $self->{_objects} };
    }
}

sub _fill_params {
    my ($self, $params) = @_;

    return unless $params;

    FIELD:
    for my $field ( sort keys %$params ) {
        $self->{$field} = $params->{$field};
    }

    return $self;
}

sub _find_many_by_prepared_statement {
    my ($self) = @_;

    return unless $self->{prep_request_method} && $self->{prep_request_params};

    my $method = $self->{prep_request_method};
    my @params = @{ $self->{prep_request_params} };

    my $resultset = $self->$method(@params);

    return $resultset;
}

sub _find_all {
    my ($self) = @_;

    my $table_name = $self->get_table_name;
    my $sql_stmt = qq{
        select * from "$table_name"
    };

    $self->_finish_sql_stmt(\$sql_stmt);
    do {
        my $SQL_REQUEST = _quote_string($sql_stmt, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
    } if $TRACE;

    return
        $self->dbh->selectall_arrayref(
            _quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
            { Slice => {} }
        );
}

sub _find_many_by_primary_keys {
    my ($self, $pkeyvals) = @_;

    return unless $pkeyvals && ref $pkeyvals eq 'ARRAY' && scalar @$pkeyvals > 0;

    my $table_name = $self->get_table_name;
    my $pkey = $self->get_primary_key;
    my $whereinstr = join ', ', @$pkeyvals;

    my $sql_stmt = qq{
	    select * from "$table_name"
	    where
	        "$pkey" in ($whereinstr)
    };

    $self->_finish_sql_stmt(\$sql_stmt);
    do {
        my $SQL_REQUEST = _quote_string($sql_stmt, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
    } if $TRACE;

    return
        $self->dbh->selectall_arrayref(
            _quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
            { Slice => {} }
        );
}

sub _finish_sql_stmt {
    my ($self, $sql_stmt) = @_;

    if (defined $self->{prep_order_by}) {
        $$sql_stmt .= ' order by ';
        $$sql_stmt .= join q/, /, map { q/"/.$_.q/"/ } @{ $self->{prep_order_by} };
    }

    if (defined $self->{prep_desc}) {
        $$sql_stmt .= ' desc';
    }

    if (defined $self->{prep_asc}) {
        $$sql_stmt .= ' asc';
    }

    if (defined $self->{prep_limit}) {
        $$sql_stmt .= ' limit ' . $self->{prep_limit};
    }

    if (defined $self->{prep_offset}) {
        $$sql_stmt .= ' offset ' . $self->{prep_offset};
    }

    $self->_delete_keys(qr/^prep\_/);
}

sub _delete_keys {
    my ($self, $rx) = @_;

    map { delete $self->{$_} if $_ =~ $rx } keys %$self;
}

sub _find_many_by_condition {
    my ($self, @param) = @_;

    return unless $self->dbh;

    my $wherestr = shift @param;
    my $table_name = $self->get_table_name;

    my $sql_stmt = qq{
	select * from "$table_name"
        where
            $wherestr
    };

    $self->_finish_sql_stmt(\$sql_stmt);

    do {
        my $SQL_REQUEST = _quote_string($sql_stmt, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
        carp 'bind: ' . join q/, /, @param;
    } if $TRACE;

    return $self->dbh->selectall_arrayref(
	_quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	{ Slice => {} },
	@param
    );
}

sub _find_many_by_params {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name = $self->get_table_name;
    my $where_str = join q/ and /, map { q/"/ . $_ . q/"/ .' = ?' } keys %$param;
    my @bind = values %$param;

    my $sql_stmt = qq{
        select * from "$table_name"
        where
            $where_str
    };

    $self->_finish_sql_stmt(\$sql_stmt);

    do {
        my $SQL_REQUEST = _quote_string($sql_stmt, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
        carp 'bind: ' . join q/, /, @bind;
    } if $TRACE;

    return $self->dbh->selectall_arrayref(
	_quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	{ Slice => {} },
	@bind
    );
}

sub _find_one_by_primary_key {
    my ($self, $pkeyval) = @_;

    return unless $self->dbh;

    my $table_name = $self->get_table_name;

    my $pkey = $self->get_primary_key;

    my $sql_stmt = qq{
	select * from "$table_name"
        where
            "$pkey" = ?
    };

    $self->_finish_sql_stmt(\$sql_stmt);

    do {
        my $SQL_REQUEST = _quote_string($sql_stmt, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
    } if $TRACE;

    return $self->dbh->selectrow_hashref(
	_quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	undef,
	$pkeyval
    );
}

sub is_defined {
    my ($self) = @_;

    return grep { defined $self->{$_} } @{ $self->get_columns };
}

# param:
#      name => .., id => .., <something_else> => ...
sub is_exists_in_database {
    my ($self, $param) = @_;

    return unless $self->dbh;

    $param ||= $self->to_hash({ only_defined_fields => 1 });

    my $table_name = $self->get_table_name;
    my @fields = sort keys %$param;
    my $where_str = join q/ and /, map { q/"/. $_ . q/"/ .' = ?' } @fields;
    my @bind;
    for my $f (@fields) {
        push @bind, $self->$f;
    }
    #= values %$param;

    my $sql = qq{
        select 1 from "$table_name"
        where
            $where_str
    };

    do {
        my $SQL_REQUEST = _quote_string($sql, $self->dbh->{Driver}{Name});
        carp $SQL_REQUEST;
        carp 'bind: ' . join q/, /, @bind;
    } if $TRACE;

    return $self->dbh->selectrow_array(
	    _quote_string($sql, $self->dbh->{Driver}{Name}),
	    undef,
	    @bind
    );
}

sub get {
    my ($class, $pkeyval) = @_;

    #my $resultset = $class->_find_one_by_primary_key($pkeyval);
    my $self = $class->new();
    my $resultset = $self->_find_one_by_primary_key($pkeyval);
    $self->_fill_params($resultset);

    return $self;
}

# param:
#     only_defined_fields => 1
###  TODO: refactor this
sub to_hash {
    my ($self, $param) = @_;

    my $field_names = $self->get_columns;
    my $attrs = {};

    for my $field (@$field_names) {
        if ( $param && $param->{only_defined_fields} ) {
            $attrs->{$field} = $self->{$field} if $self->$field;
        }
        else {
            $attrs->{$field} = $self->{$field};
        }
    }

    return $attrs;
}

sub DESTROY {
    my ($self) = @_;

    if ($self->smart_saving_used) {
        $self->save() if not exists $self->{'_objects'};
    }
}

1;

__END__;

=head1 NAME

ActiveRecord::Simple

=head1 VERSION

0.40

=head1 DESCRIPTION

ActiveRecord::Simple is a simple lightweight implementation of ActiveRecord
pattern. It's fast, very simple and very light.

=head1 SYNOPSIS

    package MyModel:Person;

    use base 'ActiveRecord::Simple';

    __PACKAGE__->table_name('persons');
    __PACKAGE__->columns(['id', 'name']);
    __PACKAGE__->primary_key('id');

    1;

That's it! Now you're ready to use your active-record class in the application:

    use MyModel::Person;

    # to create a new record:
    my $person = MyModel::Person->new({ name => 'Foo' })->save();

    # to update the record:
    $person->name('Bar')->save();

    # to find a record (by primary key):
    my $person = MyModel::Person->get(1);

    # to find many records by parameters:
    my @persons = MyModel::Person->find({ name => 'Foo' })->fetch();

    # to find records by sql-condition:
    my @persons = MyModel::Person->find('name = ?', 'Foo')->fetch();

    # also you can do something like this:
    my $persons = MyModel::Person->find('name = ?', 'Foo');
    while ( my $person = $persons->fetch() ) {
        say $person->name;
    }

    # You can add any relationships to your tables:
    __PACKAGE__->relations({
        cars => {
            class => 'MyModel::Car',
            key   => 'id_person',
            type  => 'many',
        },
        wife => {
            class => 'MyModel::Wife',
            key   => 'id_person',
            type  => 'one',
        }
    });

    # And then, you're ready to go:
    say $person->cars->fetch->id; # if the relation is one to many
    say $person->wife->name; # if the relation is one to one

=head1 METHODS

ActiveRecord::Simple provides a variety of techniques to make your work with
data little easier. It contains only a basic set of operations, such as
search, create, update and delete data.

If you realy need more complicated solution, just try to expand on it with your
own methods.

=head1 Class Methods

Class methods mean that you can't do something with a separate row of the table,
but they need to manipulate of the table as a whole object. You may find a row
in the table or keep database handler etc.

=head2 new

Creates a new object, one row of the data.

    MyModel::Person->new({ name => 'Foo', second_name => 'Bar' });

It's a constructor of your class and it doesn't save a data in the database,
just creates a new record in memory.

=head2 columns

    __PACKAGE__->columns([qw/id_person first_name second_name]);

Set names of the table columns and add accessors to object of the class. This
method is required to use in the child (your model) classes.

=head2 primary_key

    __PACKAGE__->primary_key('id_person');

Set name of the primary key. This method is not required to use in the child
(your model) classes.

=head2 table_name

    __PACKAGE__->table_name('persons');

Set name of the table. This method is required to use in the child (your model)
classes.

=head2 relations

    __PACKAGE__->relations({
        cars => {
            class => 'MyModel::Car',
            key   => 'id_person',
            type  => 'many'
        },
    });

It's not a required method and you don't have to use it if you don't want to use
any relationships in your tables and objects. However, if you need to,
just keep this simple schema in youre mind:

    __PACKAGE__->relations({
        [relation key] => {
            class => [class name],
            key   => [column that refferers to the table],
            type  => [many or one]
        },
    })

    [relation key] - this is a key that will be provide the access to instance
    of the another class (which is specified in the option "class" below),
    associated with this relationship. Allowed to use as many keys as you need:

    $package_instance->[relation key]->[any method from the related class];

=head2 use_smart_saving

This method provides two features:

   1. Check the changes of object's data before saving in the database.
      Won't save if data didn't change.

   2. Automatic save on object destroy (You don't need use "save()" method
      anymore).

    __PACKAGE__->use_smart_saving;

=head2 get_all

You can get a whole table as an arrayref of hashref's:

    my $table = Person->get_all();

You also may specify which rows you want to use:

    my $table = Person->get_all(['name']);

=head2 find

There are several ways to find someone in your database using ActiveRecord::Simple:

    # by primary key:
    my $person = MyModel::Person->find(1)->fetch;

    # by multiple primary keys
    my @persons = MyModel::Person->find([1, 2, 5])->fetch;

    # by simple condition:
    my @persons = MyModel::Person->find({ name => 'Foo' })->fetch;

    # by where-condtions:
    my @persons = MyModel::Person->find('first_name = ? and id_person > ?', 'Foo', 1);

If you want to get a few instances by primary keys, you should put it as arrayref,
and then fetch from resultset:

    my @persons = MyModel::Person->find([1, 2])->fetch();

    # you don't have to fetch it immidiatly, of course:
    my $resultset = MyModel::Person->find([1, 2]);
    while ( my $person = $resultset->fetch() ) {
        say $person->first_name;
    }

To find some rows by simple condition, use a hashref:

    my @persons = MyModel::Person->find({ first_name => 'Foo' })->fetch();

Simple condition means that you can use only this type of it:

    { first_name => 'Foo' } goes to "first_type = 'Foo'";
    { first_name => 'Foo', id_person => 1 } goes to "first_type = 'Foo' and id_person = 1";

If you want to use a real sql where-condition:

    my $res = MyModel::Person->find('first_name = ? or id_person > ?', 'Foo', 1);
    # select * from persons where first_name = "Foo" or id_person > 1;

You can use the ordering of results, such as ORDER BY, ASC and DESC:

    my @persons = MyModel::Person->find('age > ?', 21)->order_by('name')->desc->fetch();
    my @persons = MyModel::Person->find('age > ?', 21)->order_by('name', 'age')->fetch();

=head2 get

This is shortcut method for "find":

    my $person = MyModel::Person->get(1);
    ### is the same:
    my $person = MyModel::Person->find(1)->fetch;

=head2 order_by

Order your results by specified fields:

    my @persons = MyModel::Person->find({ city => 'NY' })->order_by('name')->fetch();

This method uses as many fields as you want:

    my @fields = ('name', 'age', 'zip');
    my @persons = MyModel::Person->find({ city => 'NY' })->order_by(@fields)->fetch();

=head2 asc

Use this attribute to order your results ascending:

    MyModel::Person->find([1, 3, 5, 2])->order_by('id')->asc->fetch();

=head2 desc

Use this attribute to order your results ascending:

    MyModel::Person->find([1, 3, 5, 2])->order_by('id')->desc->fetch();

=head2 dbh

Keeps a database connection handler. It's not a class method actually, this is
an attribute of the base class and you can put your database handler in any
class:

    Person->dbh($dbh);

Or even rigth in base class:

    ActiveRecord::Simple->dbh($dht);

This decision is up to you. Anyway, this is a singleton value, and keeps only
once at the session.

=head1 Object Methods

Object methods usefull to manipulating single rows as a separate objects.

=head2 save

To insert or update data in the table, use only one method. It detects
automatically what do you want to do with it. If your object was created
by the new method and never has been saved before, method will insert your data.

If you took the object using the find method, "save" will mean "update".

    my $person = MyModel::Person->new({
        first_name => 'Foo',
        secnd_name => 'Bar',
    });

    $person->save() # -> insert

    $person->first_name('Baz');
    $person->save() # -> now it's update!

    ### or

    my $person = MyModel::Person->find(1);
    $person->first_name('Baz');
    $person->save() # update

=head2 delete

    $person->delete();

Delete row from the table.

=head2 is_exists_in_database

Checks for a record in the database corresponding to the object:

    my $person = MyModel::Person->new({
        first_name => 'Foo',
        secnd_name => 'Bar',
    });

    $person->save() unless $person->is_exists_in_database;

=head2 to_hash

Convert objects data to the simple perl hash:

    use JSON::XS;

    say encode_json({ person => $peron->to_hash });

=head2 is_defined

Checks weather an object is defined:

    my $person = MyModel::Person->find(1);
    return unless $person->is_defined;

=head2 fetch

When you use the "find" method to get a few rows from the table, you get the
meta-object with a several objects inside. To use all of them or only a part,
use the "fetch" method:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch();

You can also specify how many objects you want to use:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch(2);
    # fetching only 2 objects.

=head1 TRACING QUERIES

   use ACTIVE_RECORD_SIMPLE_TRACE=1 environment variable:

   $ ACTIVE_RECORD_SIMPLE_TRACE=1 perl myscript.pl

=head1 AUTHOR

shootnix, C<< <shootnix at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<shootnix@cpan.org>, or through
the github: https://github.com/shootnix/activerecord-simple/issues

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ActiveRecord::Simple


You can also look for information at:

=over 1

=item * Github wiki:

L<https://github.com/shootnix/activerecord-simple/wiki>

=back

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 shootnix.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

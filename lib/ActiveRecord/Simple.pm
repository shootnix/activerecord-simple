package ActiveRecord::Simple;

use 5.010;
use strict;
use warnings;

=head1 NAME

ActiveRecord::Simple - Simple to use lightweight implementation of ActiveRecord pattern.

=head1 VERSION

Version 0.64

=cut

our $VERSION = '0.64';

use utf8;
use Encode;
use Module::Load;
use Carp;
use Storable qw/freeze/;

my $dbhandler = undef;
my $TRACE     = defined $ENV{ACTIVE_RECORD_SIMPLE_TRACE} ? 1 : undef;

sub new {
    my ($class, $param) = @_;

    $class->_mk_accessors($class->_get_columns());

    if ($class->can('_get_relations')) {
        my $relations = $class->_get_relations();

        no strict 'refs';

        RELNAME:
        for my $relname ( keys %{ $relations } ) {
            my $pkg_method_name = $class . '::' . $relname;

            next RELNAME if $class->can($pkg_method_name);

            *{$pkg_method_name} = sub {
                my ($self, @rels) = @_;

                my $rel = $class->_get_relations->{$relname};
                my $fkey = $rel->{foreign_key} || $rel->{key};
                ### else
                if (!$self->{"relation_instance_$relname"}) {
                    my $rel  = $class->_get_relations->{$relname};
                    my $fkey = $rel->{foreign_key} || $rel->{key};

                    my $type = $rel->{type} . '_to_';
                    my $rel_class = ( ref $rel->{class} eq 'HASH' ) ?
                        ( %{ $rel->{class} } )[1]
                        : $rel->{class};

                    load $rel_class;

                    ### TODO: check for relation existing
                    while (my ($rel_key, $rel_opts) = each %{ $rel_class->_get_relations }) {
                        my $rel_opts_class = (ref $rel_opts->{class} eq 'HASH') ?
                            (%{ $rel_opts->{class} })[1]
                            : $rel_opts->{class};
                        $type .= $rel_opts->{type} if $rel_opts_class eq $class;
                    }

                    if ($type eq 'one_to_many' or $type eq 'one_to_one' or $type eq 'one_to_only') {
                        my $fkey = $rel->{params}{fk};
                        my $pkey = $rel->{params}{pk};

                        $self->{"relation_instance_$relname"} =
                            $rel_class->find("$pkey = ?", $self->$fkey)->fetch // $rel_class;
                    }
                    elsif ($type eq 'only_to_one') {
                        my $fkey = $rel->{params}{fk};
                        my $pkey = $rel->{params}{pk};

                        $self->{"relation_instance_$relname"} =
                            $rel_class->find("$fkey = ?", $self->$pkey)->fetch;
                    }
                    elsif ($type eq 'many_to_one') {
                        return $rel_class->new() if not $self->can('_get_primary_key');
                        my $fkey = $rel->{params}{fk};
                        my $pkey = $rel->{params}{pk};

                        $self->{"relation_instance_$relname"}
                            = $rel_class->find("$fkey = ?", $self->$pkey);
                    }
                    elsif ( $type eq 'many_to_many' ) {
                        $self->{"relation_instance_$relname"} =
                            $rel_class->_find_many_to_many({
                                root_class => $class,
                                m_class    => (%{ $rel->{class} })[0],
                                self       => $self,
                            });
                    }
                    elsif ($type eq 'generic_to_generic') {
                        my %find_attrs;
                        while (my ($k, $v) = each %{ $rel->{key} }) {
                            $find_attrs{$v} = $self->$k;
                        }
                        $self->{"relation_instance_$relname"} =
                            $rel_class->find(\%find_attrs);
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

    load $param->{m_class};

    for my $opts ( values %{ $param->{m_class}->_get_relations } ) {
        if ($opts->{class} eq $param->{root_class}) {
            $root_class_opts = $opts;
        }
        elsif ($opts->{class} eq $class) {
            $class_opts = $opts;
        }
    }

    my $connected_table_name = $class->_get_table_name;
    my $sql_stm;
    $sql_stm .=
        'select ' .
        "$connected_table_name\.*" .
        ' from ' .
        $param->{m_class}->_get_table_name .
        ' join ' .
        $connected_table_name .
        ' on ' .
        $connected_table_name . '.' . $class->_get_primary_key .
        ' = ' .
        $param->{m_class}->_get_table_name . '.' . $class_opts->{params}{fk} .
        ' where ' .
        $root_class_opts->{params}{fk} .
        ' = ' .
        $param->{self}->{ $param->{root_class}->_get_primary_key };

    my $container_class = $class->new();
    my $self = bless {}, $class;
    $self->{SQL} = $sql_stm; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;

    my $resultset = $class->dbh->selectall_arrayref($self->{SQL}, { Slice => {} });
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
                $class->_validate_field($f, $_[1])
                    or croak "Validation error for `$f`: " . $class->_get_validation_error;


                $_[0]->{$f} = $_[1];

                return $_[0];
            }

            return $_[0]->{$f};
        }
    }
    use strict 'refs';

    return 1;
}

sub _validate_field {
    my ($class, $name, $val) = @_;

    return 1 unless $class->can('_get_schema_table');

    my $fld = $class->_get_schema_table->get_field($name);

    my $check_result = _check($val, {
        data_type     => $fld->{data_type},
        is_nullable   => $fld->{is_nullable},
        size          => $fld->{size},
        default_value => $fld->{default_value},
    });

    if ($check_result->{error}) {
        $class->_mk_attribute_getter('_get_validation_error', $check_result->{error});

        return;
    }

    return 1;
}

sub _check {
    my ($val, $fld) = @_;

    if (exists $fld->{is_nullable}) {
        _check_for_null(
            $val,
            $fld->{is_nullable},
            (exists $fld->{default_value} && defined $fld->{default_value})
        )
        or return { error => "Can't be null" };
    }

    if (exists $fld->{data_type}) {
        _check_for_data_type($val, $fld->{data_type}, $fld->{size})
            or return { error => "Invalid value for type " . $fld->{data_type} };
    }

    return { result => 1 };
}

sub belongs_to {
    my ($class, $rel_name, $rel_class, $params) = @_;

    my $new_relation = {
        class => $rel_class,
        type => 'one',
        #params => $params
    };

    my $primary_key = $params->{pk} ||
        $params->{primary_key} ||
        _guess(primary_key => $class);

    my $foreign_key = $params->{fk} ||
        $params->{foreign_key} ||
        _guess(foreign_key => $rel_class);

    $new_relation->{params} = {
        pk => $primary_key,
        fk => $foreign_key,
    };

    if ($class->can('_get_schema_table') && $class->can('_get_primary_key')) {
        load $rel_class;
        $class->_get_schema_table->add_constraint(
            type => 'foreign_key',
            fields => $params, ### TODO: !!!this is wrong!!!
            reference_fields => $class->_get_primary_key,
            reference_table => $rel_class->_get_table_name,
            on_delete => 'cascade'
        );
    }

    return $class->_append_relation($rel_name => $new_relation);
}

sub has_many {
    my ($class, $rel_name, $rel_class, $params) = @_;

    my $new_relation = {
        class => $rel_class,
        type => 'many',
    };

    $params ||= {};
    #my ($primary_key, $foreign_key);
    my $primary_key = $params->{pk} ||
        $params->{primary_key} ||
        _guess(primary_key => $class);

    my $foreign_key = $params->{fk} ||
        $params->{foreign_key} ||
        _guess(foreign_key => $class);

    $new_relation->{params} = {
        pk => $primary_key,
        fk => $foreign_key,
    };

    return $class->_append_relation($rel_name => $new_relation);
}

sub _guess {
    my ($what_key, $class) = @_;

    return 'id' if $what_key eq 'primary_key';

    load $class;

    my $table_name = $class->_get_table_name;
    return ($what_key eq 'foreign_key') ? "$table_name\_id" : undef;
}

sub has_one {
    my ($class, $rel_name, $rel_class, $params) = @_;

    my $new_relation = {
        class => $rel_class,
        type => 'only',
    };

    $params ||= {};
    #my ($primary_key, $foreign_key);
    my $primary_key = $params->{pk} ||
        $params->{primary_key} ||
        _guess(primary_key => $class);

    my $foreign_key = $params->{fk} ||
        $params->{foreign_key} ||
        _guess(foreign_key => $class);

    $new_relation->{params} = {
        pk => $primary_key,
        fk => $foreign_key,
    };

    #$class->_mk_attribute_getter('_get_secondary_key', $key);
    ### TODO: add schema constraints
    $class->_append_relation($rel_name => $new_relation);
}

sub as_sql {
    my ($class, $producer_name, %args) = @_;

    eval { require SQL::Translator }
      || croak('Please install SQL::Translator to use this feature.');

    $class->can('_get_schema_table')
        or return;

    my $t = SQL::Translator->new;
    my $schema = $t->schema;
    $schema->add_table($class->_get_schema_table);

    $t->producer($producer_name || 'PostgreSQL', %args);

    return $t->translate;
}

sub generic {
    my ($class, $rel_name, $rel_class, $key) = @_;

    my $new_relation = {
        class => $rel_class,
        type => 'generic',
        key => $key
    };

    return $class->_append_relation($rel_name => $new_relation);
}

sub _append_relation {
    my ($class, $rel_name, $rel_hashref) = @_;

    if ($class->can('_get_relations')) {
        my $relations = $class->_get_relations();

        $relations->{$rel_name} = $rel_hashref;
        $class->relations($relations);
    }
    else {
        $class->relations({ $rel_name => $rel_hashref });
    }

    return;
}

sub columns {
    my ($class, @we_got) = @_;

    my $columns = [];
    if (scalar @we_got == 1) {
        #$columns = $we_got[0];
        if (ref $we_got[0] && ref $we_got[0] eq 'ARRAY') {
            $columns = $we_got[0];
        }
        elsif (ref $we_got[0] && ref $we_got[0] eq 'HASH') {
            $columns = [keys %{ $we_got[0] }];
            $class->fields(%{ $we_got[0] });
        }
        else {
            # just one column?
            push @$columns, @we_got;
        }
    }
    elsif (scalar @we_got > 1) {

        if (ref $we_got[1] && ref $we_got[1] eq 'HASH') {
            # hash of hashes
            push @$columns, keys my %fields = @we_got;
            $class->fields(%fields);
        }
        else {
            # or plain array?
            push @$columns, @we_got;
        }

    }

    $class->_mk_attribute_getter('_get_columns', $columns);
}

sub fields {
    my ($class, %fields) = @_;

    eval { require SQL::Translator }
      || croak('Please install SQL::Translator to use this feature. ');

    my $sql_translator = SQL::Translator->new(no_comments => 1);
    my $schema = $sql_translator->schema;
    my $table = $schema->add_table(name => $class->_get_table_name);

    FIELD:
    for my $field (keys %fields) {
        $table->add_field(name => $field, %{ $fields{$field} });
    }

    $class->_mk_attribute_getter('_get_schema_table', $table);
    $class->columns([keys %fields]);
}

sub index {
    my ($class, $index_name, $fields) = @_;

    if ($class->can('_get_schema_table')) {
        $class->_get_schema_table->add_index(
            name => $index_name,
            fields => $fields
        );
    }
}

sub primary_key {
    my ($class, $primary_key) = @_;

    $class->_mk_attribute_getter('_get_primary_key', $primary_key);
    $class->_get_schema_table->primary_key($primary_key)
        if $class->can('_get_schema_table')
}

sub secondary_key {
    my ($class, $key) = @_;

    $class->_mk_attribute_getter('_get_secondary_key', $key);
}

sub table_name {
    my ($class, $table_name) = @_;

    $class->_mk_attribute_getter('_get_table_name', $table_name);
}

sub use_smart_saving {
    my ($class, $is_on) = @_;

    $is_on = 1 if not defined $is_on;

    $class->_mk_attribute_getter('_smart_saving_used', $is_on);
}

sub relations {
    my ($class, $relations) = @_;

    $class->_mk_attribute_getter('_get_relations', $relations);
}

sub _mk_attribute_getter {
    my ($class, $method_name, $return) = @_;

    my $pkg_method_name = $class . '::' . $method_name;
    if ( !$class->can($pkg_method_name) ) {
        no strict 'refs';
        *{$pkg_method_name} = sub { $return };
    }
}

sub dbh {
    my ($self, $dbh) = @_;

    $dbhandler = $dbh if defined $dbh;

    return $dbhandler;
}

sub count {
    my ($class, @param) = @_;

    my $self = bless {}, $class;
    my $table_name = $class->_get_table_name;
    my ($count, $sql, @bind);
    if (scalar @param == 0) {
        $self->{SQL} = qq/select count(*) from "$table_name"/;
    }
    elsif (scalar @param == 1) {
        my $params_hash = shift @param;
        return unless ref $params_hash eq 'HASH';

        my $wherestr = join q/ and /, map { q/"/ . $_ . q/"/ .' = ?' } keys %{ $params_hash };
        @bind = values %{ $params_hash };
        $self->{SQL} = qq/select count(*) from "$table_name" where $wherestr/;
    }
    elsif (scalar @param > 1) {
        my $wherestr = shift @param;
        @bind = @param;

        $self->{SQL} = qq/select count(*) from "$table_name" where $wherestr/;
    }
    $self->_quote_sql_stmt;
    $count = $self->dbh->selectrow_array($self->{SQL}, undef, @bind);

    return $count;
}

sub exists {
    my ($ref, @params) = @_;

    if (ref $ref) {
        ### object method
        return $ref->_is_exists_in_database;
    }
    # else
    return $ref->find(@params)->fetch;
}

sub first {
    my ($class, $limit) = @_;

    $class->can('_get_primary_key') or croak 'Can\'t use "first" without primary key';
    my $primary_key = $class->_get_primary_key;
    $limit //= 1;

    return $class->find->order_by($primary_key)->limit($limit);
}

sub last {
    my ($class, $limit) = @_;

    $class->can('_get_primary_key') or croak 'Can\'t use "first" without primary key';
    my $primary_key = $class->_get_primary_key;
    $limit //= 1;

    return $class->find->order_by($primary_key)->desc->limit($limit);
}

sub _quote_sql_stmt {
    my ($self) = @_;

    return unless $self->{SQL} && $self->dbh;

    my $driver_name = $self->dbh->{Driver}{Name};
    $driver_name //= 'Pg';
    my $quotes_map = {
        Pg => q/"/,
        mysql => q/`/,
        SQLite => q/`/,
    };
    my $quote = $quotes_map->{$driver_name};

    $self->{SQL} =~ s/"/$quote/g;

    return 1;
}

sub save {
    my ($self) = @_;

    return unless $self->dbh;

    return 1 if $self->_smart_saving_used
        and defined $self->{snapshoot}
        and $self->{snapshoot} eq freeze $self->to_hash;

    croak 'Object is read-only'
        if exists $self->{read_only} && $self->{read_only} == 1;

    my $save_param = {};
    my $fields = $self->_get_columns;
    my $pkey = ($self->can('_get_primary_key')) ? $self->_get_primary_key : undef;

    FIELD:
    for my $field (@$fields) {
        next FIELD if defined $pkey && $field eq $pkey && !$self->{$pkey};
        $save_param->{$field} = $self->{$field};
    }

    my $result;
    if ($self->{isin_database}) {
        $result = $self->_update($save_param);
    }
    else {
        $result = $self->_insert($save_param);
    }
    $self->{need_to_save} = 0 if $result;

    return (defined $result) ? $self : undef;
}

sub _insert {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name  = $self->_get_table_name;
    my @field_names  = grep { defined $param->{$_} } sort keys %$param;
    my $primary_key = ($self->can('_get_primary_key')) ? $self->_get_primary_key :
                      ($self->can('_get_secondary_key')) ? $self->_get_secondary_key : undef;

    my $field_names_str = join q/, /, map { q/"/ . $_ . q/"/ } @field_names;
    my $values          = join q/, /, map { '?' } @field_names;
    my @bind            = map { $param->{$_} } @field_names;

    my $pkey_val;
    my $sql_stm = qq{
        insert into "$table_name" ($field_names_str)
        values ($values)
    };

    if ( $self->dbh->{Driver}{Name} eq 'Pg' ) {
        if ($primary_key) {
            $sql_stm .= ' returning ' . $primary_key if $primary_key;
            $self->{SQL} = $sql_stm; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;

            $pkey_val = $self->dbh->selectrow_array($self->{SQL}, undef, @bind);
        }
        else {
            $self->{SQL} = $sql_stm; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;
            my $sth = $self->dbh->prepare($self->{SQL});

            $sth->execute(@bind);
        }
    }
    else {
        $self->{SQL} = $sql_stm; $self->_quote_sql_stmt(); say $self->{SQL} if $TRACE;

        my $sth = $self->dbh->prepare($self->{SQL});
        $sth->execute(@bind);

        if ( $primary_key && defined $self->{$primary_key} ) {
            $pkey_val = $self->{$primary_key};
        }
        else {
            $pkey_val = $self->dbh->last_insert_id(undef, undef, $table_name, undef);
        }
    }

    if (defined $primary_key && $self->can($primary_key) && $pkey_val) {
        $self->$primary_key($pkey_val);
    }
    $self->{isin_database} = 1;

    return $pkey_val;
}

sub _update {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name      = $self->_get_table_name;
    my @field_names     = sort keys %$param;
    my $primary_key     = ($self->can('_get_primary_key')) ? $self->_get_primary_key :
                          ($self->can('_get_secondary_key')) ? $self->_get_secondary_key : undef;

    my $setstring = join ', ', map { "$_ = ?" } @field_names;
    my @bind = map { $param->{$_} } @field_names;
    push @bind, $self->{$primary_key};

    my $sql_stm = qq{
        update "$table_name" set $setstring
        where
            $primary_key = ?
    };
    $self->{SQL} = $sql_stm; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;

    return $self->dbh->do($self->{SQL}, undef, @bind);
}

# param:
#     cascade => 1
sub delete {
    my ($self, $param) = @_;

    return unless $self->dbh;

    my $table_name = $self->_get_table_name;
    my $pkey = $self->_get_primary_key;
    return unless $self->{$pkey};

    my $sql = qq{
        delete from "$table_name" where $pkey = ?
    };
    $sql .= ' cascade ' if $param && $param->{cascade};

    my $res = undef;
    $self->{SQL} = $sql; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;
    if ( $self->dbh->do($self->{SQL}, undef, $self->{$pkey}) ) {
        $self->{isin_database} = undef;
        delete $self->{$pkey};

        $res = 1;
    }

    return $res;
}

sub find {
    my ($class, @param) = @_;

    my $self = $class->new();

    my $table_name = ($self->can('_get_table_name'))  ? $self->_get_table_name  : undef;
    my $pkey       = ($self->can('_get_primary_key')) ? $self->_get_primary_key : undef;

    if (!ref $param[0] && scalar @param == 1) {
        # find one by primary key
        $self->{SQL} = qq{
            select * from "$table_name"
                where
                    "$pkey" = ?
        };
        $self->{BIND} = \@param
    }
    elsif (!ref $param[0] && scalar @param == 0) {
        # find all
        $self->{SQL} = qq{
            select * from "$table_name"
        };
        $self->{BIND} = undef;
    }
    elsif (ref $param[0] && ref $param[0] eq 'HASH') {
        # find many by params
        my $where_str = join q/ and /, map { q/"/ . $_ . q/"/ .' = ?' } keys %{ $param[0] };
        my @bind = values %{ $param[0] };

        $self->{SQL} = qq{
            select * from "$table_name"
            where
                $where_str
        };
        $self->{BIND} = \@bind;
    }
    elsif (ref $param[0] && ref $param[0] eq 'ARRAY') {
        # find many by primary keys
        my $whereinstr = join ', ', @{ $param[0] };

        $self->{SQL} = qq{
            select * from "$table_name"
            where
                "$pkey" in ($whereinstr)
        };
        $self->{BIND} = undef;
    }
    else {
        # find many by condition
        my $wherestr = shift @param;
        $self->{SQL} = qq{
            select * from "$table_name"
            where
                $wherestr
        };
        $self->{BIND} = \@param;
    }

    return $self;
}

sub only {
    my ($self, @fields) = @_;

    scalar @fields > 0 or croak 'Not defined fields for method "only"';
    exists $self->{SQL} or croak 'Not executed method "find" before "only"';

    if ($self->can('_get_primary_key')) {
        push @fields, $self->_get_primary_key;
    }

    my $fields_str = join q/, /, map { q/"/ . $_ . q/"/ } @fields;
    $self->{SQL} =~ s/\*/$fields_str/;

    return $self;
}

sub to_sql {
    my ($self) = @_;

    $self->_finish_sql_stmt();
    $self->_quote_sql_stmt();

    return wantarray ? ($self->{SQL}, $self->{BIND}) : $self->{SQL};
}

sub fetch {
    my ($self, $param) = @_;

    my ($read_only, $limit);
    if (ref $param eq 'HASH') {
        $limit     = $param->{limit};
        $read_only = $param->{read_only};
    }
    else {
        $limit = $param;
    }

    if (not exists $self->{_objects}) {
        $self->_finish_sql_stmt();
        $self->_quote_sql_stmt();
        say $self->{SQL} if $TRACE;

        my @objects;
        my $resultset =
            $self->dbh->selectall_arrayref(
                $self->{SQL},
                { Slice => {} },
                @{ $self->{BIND}}
            );

        return unless defined $resultset
                      && ref $resultset eq 'ARRAY'
                      && scalar @$resultset > 0;

        my $class = ref $self;
        for my $object_data (@$resultset) {
            my $obj = bless $object_data, $class;
            $obj->{read_only} = 1 if defined $read_only;
            $obj->{snapshoot} = freeze($object_data) if $obj->_smart_saving_used;
            $obj->{isin_database} = 1;

            push @objects, $obj;
        }

        $self->{_objects} = \@objects;
    }

    return $self->_get_slice($limit);
}

sub _get_slice {
    my ($self, $time) = @_;

    return unless $self->{_objects}
        && ref $self->{_objects} eq 'ARRAY'
        && scalar @{ $self->{_objects} } > 0;

    if (wantarray) {
        $time ||= scalar @{ $self->{_objects} };
        return splice @{ $self->{_objects} }, 0, $time;
    }
    else {
        return shift @{ $self->{_objects} };
    }
}

sub order_by {
    my ($self, @param) = @_;

    return if not defined $self->{SQL};
    return $self if exists $self->{prep_order_by};

    $self->{prep_order_by} = \@param;

    return $self;
}

sub desc {
    my ($self) = @_;

    return if not defined $self->{SQL};
    return $self if exists $self->{prep_desc};

    $self->{prep_desc} = 1;

    return $self;
}

sub asc {
    my ($self, @param) = @_;

    return if not defined $self->{SQL};
    return $self if exists $self->{prep_asc};

    $self->{prep_asc} = 1;

    return $self;
}

sub limit {
    my ($self, $limit) = @_;

    return if not defined $self->{SQL};
    return $self if exists $self->{prep_limit};

    $self->{prep_limit} = $limit;

    return $self;
}

sub offset {
    my ($self, $offset) = @_;

    return if not defined $self->{SQL};
    return $self if exists $self->{prep_offset};

    $self->{prep_offset} = $offset;

    return $self;
}

sub _finish_sql_stmt {
    my ($self) = @_;

    if (defined $self->{prep_order_by}) {
        $self->{SQL} .= ' order by ';
        $self->{SQL} .= join q/, /, map { q/"/.$_.q/"/ } @{ $self->{prep_order_by} };
    }

    if (defined $self->{prep_desc}) {
        $self->{SQL} .= ' desc';
    }

    if (defined $self->{prep_asc}) {
        $self->{SQL} .= ' asc';
    }

    if (defined $self->{prep_limit}) {
        $self->{SQL} .= ' limit ' . $self->{prep_limit};
    }

    if (defined $self->{prep_offset}) {
        $self->{SQL} .= ' offset ' . $self->{prep_offset};
    }

    $self->_delete_keys(qr/^prep\_/);
}

sub _delete_keys {
    my ($self, $rx) = @_;

    map { delete $self->{$_} if $_ =~ $rx } keys %$self;
}

sub is_defined {
    my ($self) = @_;

    return grep { defined $self->{$_} } @{ $self->_get_columns };
}

# param:
#      name => .., id => .., <something_else> => ...
sub _is_exists_in_database {
    my ($self, $param) = @_;

    return unless $self->dbh;

    $param ||= $self->to_hash({ only_defined_fields => 1 });

    my $table_name = $self->_get_table_name;
    my @fields = sort keys %$param;
    my $where_str = join q/ and /, map { q/"/. $_ . q/"/ .' = ?' } @fields;
    my @bind;
    for my $f (@fields) {
        push @bind, $self->$f;
    }

    my $sql = qq{
        select 1 from "$table_name"
        where
            $where_str
    };
    $self->{SQL} = $sql; $self->_quote_sql_stmt; say $self->{SQL} if $TRACE;

    return $self->dbh->selectrow_array($self->{SQL}, undef, @bind);
}

sub get {
    my ($class, $pkeyval) = @_;

    return $class->find($pkeyval)->fetch();
}

# param:
#     only_defined_fields => 1
###  TODO: refactor this
sub to_hash {
    my ($self, $param) = @_;

    my $field_names = $self->_get_columns;
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

sub increment {
    my ($self, @fields) = @_;

    FIELD:
    for my $field (@fields) {
        next FIELD if not exists $self->{$field};
        $self->{$field} += 1;
    }

    return $self;
}

sub decrement {
    my ($self, @fields) = @_;

    FIELD:
    for my $field (@fields) {
        next FIELD if not exists $self->{$field};
        $self->{$field} -= 1;
    }

    return $self;
}

sub _check_for_null {
    my ($val, $is_nullable, $has_default_value) = @_;

    if ($is_nullable == 0 && (not defined $val or $val eq '')) {
        return $has_default_value ? 1 : undef;
    }
    # else
    return 1;
}

sub _check_for_data_type {
    my ($val, $data_type, $size) = @_;

    return 1 unless $data_type;

    my %TYPE_CHECKS = (
        int      => \&_check_int,
        integer  => \&_check_int,
        tinyint  => \&_check_int,
        smallint => \&_check_int,
        bigint   => \&_check_int,

        double => \&_check_numeric,
       'double precision' => \&_check_numeric,

        decimal => \&_check_numeric,
        dec => \&_check_numeric,
        numeric => \&_check_numeric,

        real => \&_check_float,
        float => \&_check_float,

        bit => \&_check_bit,

        date => \&_check_DUMMY, # DUMMY
        datetime => \&_check_DUMMY, # DUMMY
        timestamp => \&_check_DUMMY, # DUMMY
        time => \&_check_DUMMY, # DUMMY

        char => \&_check_char,
        varchar => \&_check_varchar,

        binary => \&_check_DUMMY, # DUMMY
        varbinary => \&_check_DUMMY, # DUMMY
        tinyblob => \&_check_DUMMY, # DUMMY
        blob => \&_check_DUMMY, # DUMMY
        text => \&_check_DUMMY,
    );

    return (exists $TYPE_CHECKS{$data_type}) ? $TYPE_CHECKS{$data_type}->($val, $size) : 1;
}

sub _check_DUMMY { 1 }
sub _check_int { shift =~ /^\d+$/ }
sub _check_varchar {
    my ($val, $size) = @_;

    return length $val <= $size->[0];
}
sub _check_char {
    my ($val, $size) = @_;

    return length $val == $size->[0];
}
sub _check_float { shift =~ /^\d+\.\d+$/ }

sub _check_numeric {
    my ($val, $size) = @_;

    return 1 unless
        defined $size &&
        ref $size eq 'ARRAY' &&
        scalar @$size == 2;

    my ($first, $last) = $val =~ /^(\d+)\.(\d+)$/;

    $first && length $first <= $size->[0] or return;
    $last && length $last <= $size->[1] or return;

    return 1;
}

sub _check_bit {
    my ($val) = @_;

    return ($val == 0 || $val == 1) ? 1 : undef;
}

1;

__END__;

=head1 NAME

ActiveRecord::Simple

=head1 VERSION

0.64

=head1 DESCRIPTION

ActiveRecord::Simple is a simple lightweight implementation of ActiveRecord
pattern. It's fast, very simple and very light.

=head1 SYNOPSIS

    package MyModel:Person;

    use base 'ActiveRecord::Simple';

    __PACKAGE__->table_name('persons');
    __PACKAGE__->columns('id', 'name');
    __PACKAGE__->primary_key('id');

    1;

That's it! Now you're ready to use your active-record class in the application:

    use MyModel::Person;

    # to create a new record:
    my $person = MyModel::Person->new({ name => 'Foo' })->save();

    # to update the record:
    $person->name('Bar')->save();

    # to get the record (using primary key):
    my $person = MyModel::Person->get(1);

    # to get the record with specified fields:
    my $person = MyModel::Person->find(1)->only('name', 'age')->fetch;

    # to find records by parameters:
    my @persons = MyModel::Person->find({ name => 'Foo' })->fetch();

    # to find records by sql-condition:
    my @persons = MyModel::Person->find('name = ?', 'Foo')->fetch();

    # also you can do something like this:
    my $persons = MyModel::Person->find('name = ?', 'Foo');
    while ( my $person = $persons->fetch() ) {
        say $person->name;
    }

    # You can add any relationships to your tables:
    __PACKAGE__->has_many(cars => 'MyModel::Car' => 'id_preson');
    __PACKAGE__->belongs_to(wife => 'MyModel::Wife' => 'id_person');

    # And then, you're ready to go:
    say $person->cars->fetch->id; # if the relation is one to many
    say $person->wife->name; # if the relation is one to one
    $person->wife(Wife->new({ name => 'Jane', age => '18' })->save)->save; # change wife ;-)

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
    # or
    __PACKAGE__->columns('id_person', 'first_name', 'second_name');
    # or
    __PACKAGE__->columns({
        id_person => {
            # ...
        },
        first_name => {
            # ...
        },
        second_name => {
            # ...
        }
    });
    # or
    __PACKAGE__->columns(
        id_person => {
            # ...
        },
        first_name => {
            # ...
        },
        second_name => {
            # ...
        }
    );

This method is required.
Set names of the table columns and add accessors to object of the class.
If you set a hash or a hashref with additional parameters, the method will be dispatched to
another method, "fields".

=head2 fields

    __PACKAGE__->fields(
        id_person => {
            data_type => 'int',
            is_auto_increment => 1,
            is_primary_key => 1
        },
        first_name => {
            data_type => 'varchar',
            size => 64,
            is_nullable => 0
        },
        second_name => {
            data_type => 'varchar',
            size => 64,
            is_nullable => 0,
        }
    );

This method requires L<SQL::Translator> to be installed.
Create SQL-Schema and data type validation for each specified field using SQL::Translator features.
You don't need to call "columns" method explicitly, if you use "fields".

See L<SQL::Translator> for more information about schema and L<SQL::Translator::Field>
for information about available data types.

=head2 primary_key

    __PACKAGE__->primary_key('id_person');

Set name of the primary key. This method is not required to use in the child
(your model) classes.

=head2 secondary_key

    __PACKAGE__->secondary_key('some_id');

If you don't need to use primary key, but need to insert or update data, using specific
parameters, you can try this one: secondary key. It doesn't reflect schema, it's just about
the code.

=head2 index

    __PACKAGE__->index('index_id_person', ['id_person']);

Create an index and add it to the schema. Works only when method "fields" is using.

=head2 table_name

    __PACKAGE__->table_name('persons');

Set name of the table. This method is required to use in the child (your model)
classes.

=head2 relations [!OLD!, may be deprecated in the future]

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

=head2 belongs_to

    __PACKAGE__->belongs_to(home => 'Home');

This method describes one-to-one objects relationship. By default ARS think
that primary key name is "id", foreign key name is "[table_name]_id".
You can specify it by parameters:

    __PACKAGE__->belongs_to(home => 'Home', {
        primary_key => 'id',
        foreign_key => 'home_id'
    });

=head2 has_many

    __PACKAGE__->has_many(cars => 'Car');
    __PACKAGE__->has_many(cars => 'Car', {
        primary_key => 'id',
        foreign_key => 'car_id'
    })

This method describes one-to-many objects relationship.

=head2 has_one

    __PACKAGE__->has_one(wife => 'Wife');
    __PACKAGE__->has_one(wife => 'Wife', {
        primary_key => 'id',
        foreign_key => 'wife_id'
    });

You can specify one object via another one using "has_one" method. It works like that:

    say $person->wife->name; # SELECT name FROM Wife WHERE person_id = $self._primary_key

=head2 generic

    __PACKAGE__->generic(photos => { release_date => 'pub_date' });

    Creates a generic relations.

    my $single = Song->find({ type => 'single' })->fetch();
    my @photos = $single->photos->fetch();  # fetch all photos with pub_date = single.release_date

=head2 use_smart_saving

This method provides two features:

   1. Check the changes of object's data before saving in the database.
      Won't save if data didn't change.

   2. Automatic save on object destroy (You don't need use "save()" method
      anymore).

    __PACKAGE__->use_smart_saving;

=head2 find

There are several ways to find someone in your database using ActiveRecord::Simple:

    # by "nothing"
    # just leave attributes blank to recieve all rows from the database:
    my @all_persons = MyModel::Person->find()->fetch;

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

=head2 count

Returns count of records that match the rule:

    say MyModel::Person->count;
    say MyModel::Person->count({ zip => '12345' });
    say MyModel::Person->count('age > ?', 55);

=head2 exists

Returns 1 if record is exists in database:

    say "Exists" if MyModel::Person->exists({ zip => '12345' });
    say "Exists" if MyModel::Person->exists('age > ?', 55);

=head2 first

Returns the first record (records) ordered by the primary key:

    my $first_person = MyModel::Person->first->fetch;
    my @ten_persons  = MyModel::Person->first(10)->fetch;

=head2 last

Returns the last record (records) ordered by the primary key:

    my $last_person = MyModel::Person->last->fetch;
    my @ten_persons = MyModel::Person->last(10)->fetch;

=head2 increment

Increment the field value:

    my $person = MyModel::Person->get(1);
    say $person->age;  # prints e.g. 99
    $person->increment('age');
    say $person->age; # prints 100

=head2 decrement

Decrement the field value:

    my $person = MyModel::Person->get(1);
    say $person->age;  # prints e.g. 100
    $person->decrement('age');
    say $person->age; # prints 99

=head2 as_sql

    say MyModel::Person->as_sql('PostgreSQL');

This method requires L<SQL::Translator> to be installed.
Create an SQL-schema using method "fields". See SQL::Translator for more details.

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

=head2 only

Get only those fields that are needed:

    my $person = MyModel::Person->find({ name => 'Alex' })->only('address', 'email')->fetch;
    ### SQL:
    ###     SELECT `address`, `email` from `persons` where `name` = "Alex";

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

Use this attribute to order your results descending:

    MyModel::Person->find([1, 3, 5, 2])->order_by('id')->desc->fetch();

=head2 limit

Use this attribute to limit results of your requests:

    MyModel::Person->find()->limit(10)->fetch; # select only 10 rows

=head2 offset

Offset of results:

    MyModel::Person->find()->offset(10)->fetch; # all next after 10 rows

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

=head2 exists

Checks for a record in the database corresponding to the object:

    my $person = MyModel::Person->new({
        first_name => 'Foo',
        secnd_name => 'Bar',
    });

    $person->save() unless $person->exists;

=head2 to_hash

Convert objects data to the simple perl hash:

    use JSON::XS;

    say encode_json({ person => $peron->to_hash });

=head2 to_sql

Convert aobject to SQL-query:

    my $sql = Person->find({ name => 'Bill' })->limit(1)->to_sql;
    # select * from persons where name = ? limit 1;

    my ($sql, $binds) = Person->find({ name => 'Bill' })->to_sql;
    # sql: select * from persons where name = ? limit 1;
    # binds: ['Bill']

=head2 is_defined

Checks weather an object is defined:

    my $person = MyModel::Person->find(1);
    return unless $person->is_defined;

=head2 fetch

When you use the "find" method to get a few rows from the table, you get the
meta-object with a several objects inside. To use all of them or only a part,
use the "fetch" method:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch();

You can also specify how many objects you want to use at a time:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch(2);
    # fetching only 2 objects.

Another syntax of command "fetch" allows you to make read-only objects:

    my @persons = MyModel::Person->find->fetch({ read_only => 1, limit => 2 });
    # all two object are read-only

=head1 TRACING QUERIES

   use ACTIVE_RECORD_SIMPLE_TRACE=1 environment variable:

   $ ACTIVE_RECORD_SIMPLE_TRACE=1 perl myscript.pl

=head1 SEE ALSO

    L<DBIx::ActiveRecord>, L<SQL::Translator>


=head1 MORE INFO

    perldoc ActiveRecord::Simple::Tutorial

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

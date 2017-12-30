package ActiveRecord::Simple;

use 5.010;
use strict;
use warnings;

our $VERSION = '1.00';

use utf8;
use Carp;
use Module::Load;
use Scalar::Util qw/blessed/;
use List::Util qw/any/;

use ActiveRecord::Simple::Find;
use ActiveRecord::Simple::Utils;
use ActiveRecord::Simple::Connect;

our $connector;


sub new {
    my $class = shift;
    my $params = (scalar @_ > 1) ? {@_} : $_[0];

    # mixins
    if ($class->can('_get_mixins')) {
        my @keys = keys %{ $class->_get_mixins };
        $class->_mk_ro_accessors(\@keys);
    }

    # columns
    if ($class->can('_is_auto_loaded') && $class->_is_auto_loaded) {
        $class->_auto_load;
    }
    else {
        my $columns = $class->can('_get_columns') ? $class->_get_columns : [];

       # warn "columns: $columns";

        $class->_mk_accessors($columns);
    }

    # relations
    $class->_mk_relations_accessors if $class->can('_get_relations');

    return bless $params || {}, $class;
}

sub auto_load {
    my ($class) = @_;

    $class->_auto_load();
}

sub load_info {
    carp '[DEPRECATED] This method is deprecated and will be remowed in the feature. Use method "auto_load" instead.';
    $_[0]->auto_load;
}

sub sql_fetch_all {
    my ($class, $sql, @bind) = @_;

    my $data = $class->dbh->selectall_arrayref($sql, { Slice => {} }, @bind);
    my @list;
    for my $row (@$data) {
        my @fields;
        for my $fld (keys %$row) {
            push @fields, $fld;
        }
        $class->_mk_ro_accessors(\@fields);
        bless $row, $class;
        push @list, $row;
    }

    return \@list;
}

sub sql_fetch_row {
    my ($class, $sql, @bind) = @_;

    my $row = $class->dbh->selectrow_hashref($sql, undef, @bind);
    my @fields;
    for my $fld (keys %$row) {
        push @fields, $fld;
    }
    $class->_mk_ro_accessors(\@fields);
    bless $row, $class;

    return $row;
}

sub connect {
    my ($class, $dsn, $username, $password, $options) = @_;

    eval { require DBIx::Connector };

    $options->{HandleError} = sub {
        my ($error_message, $DBI_st) = @_;

        $error_message or return;
        croak $error_message;

    } if ! exists $options->{HandleError};

    if ($@) {
        $connector = ActiveRecord::Simple::Connect->new($dsn, $username, $password, $options);
        $connector->db_connect;
    }
    else {
        $connector = DBIx::Connector->new($dsn, $username, $password, $options);
    }

    return 1;
}

sub belongs_to {
    my ($class, $rel_name, $rel_class, $params) = @_;

    my $new_relation = {
        class => $rel_class,
        type => 'one',
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

    $new_relation->{via_table} = $params->{via} if $params->{via};

    $class->_append_relation($rel_name => $new_relation);
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

    return $class->_append_relation($rel_name => $new_relation);
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

sub columns {
    my ($class, @columns_list) = @_;

    croak "Error: array-ref no longer supported for 'columns' method, sorry"
        if scalar @columns_list == 1 && ref $columns_list[0] eq 'ARRAY';

    $class->_mk_attribute_getter('_get_columns', \@columns_list);
}

sub make_columns_accessors {
    my ($class, $flag) = @_;

    $flag //= 1; # default value

    $class->_mk_attribute_getter('_make_columns_accessors', $flag);
}

sub mixins {
    my ($class, %mixins) = @_;

    $class->_mk_attribute_getter('_get_mixins', \%mixins);
}

sub primary_key {
    my ($class, $primary_key) = @_;

    $class->_mk_attribute_getter('_get_primary_key', $primary_key);
}

sub secondary_key {
    my ($class, $key) = @_;

    $class->_mk_attribute_getter('_get_secondary_key', $key);
}

sub table_name {
    my ($class, $table_name) = @_;

    $class->_mk_attribute_getter('_get_table_name', $table_name);
}

sub relations {
    my ($class, $relations) = @_;

    $class->_mk_attribute_getter('_get_relations', $relations);
}

sub dbh {
    my ($self, $dbh) = @_;

    if ($dbh) {
        if ($connector) {
            $connector->dbh($dbh);
        }
        else {
            $connector = ActiveRecord::Simple::Connect->new();
            $connector->dbh($dbh);
        }
    }

    return $connector->dbh;
}

sub save {
    my ($self) = @_;

    #return unless $self->dbh;
    croak "Undefined database handler" unless $self->dbh;

    croak 'Object is read-only'
        if exists $self->{read_only} && $self->{read_only} == 1;

    my $save_param = {};
    my $fields = $self->_get_columns;

    my $pkey = ($self->can('_get_primary_key')) ? $self->_get_primary_key : undef;

    FIELD:
    for my $field (@$fields) {
        next FIELD if defined $pkey && $field eq $pkey && !$self->{$pkey};
        next FIELD if ref $field && ref $field eq 'HASH';
        $save_param->{$field} = $self->{$field};
    }

    ### Get additional fields from related objects:
    for my $field (keys %$self) {
        next unless ref $self->{$field};
        next unless $self->can('_get_relations');
        next unless grep { $_ eq $field } keys %{ $self->_get_relations };

        my $relation = $self->_get_relations->{$field} or next;
        next unless $relation->{type} && $relation->{type} eq 'one';

        my $fk = $relation->{params}{fk};
        my $pk = $relation->{params}{pk};

        $save_param->{$fk} = $self->{$field}->$pk;
    }

    my $result;
    if ($self->{isin_database}) {
        $result = $self->_update($save_param);
    }
    else {
        $result = $self->_insert($save_param);
    }
    $self->{need_to_save} = 0 if $result;
    delete $self->{SQL} if $result;

    return (defined $result) ? $self : undef;
}

sub update {
    my ($self, $params) = @_;

    my $fields = $self->_get_columns();
    FIELD:
    for my $field (@$fields) {
        next FIELD if ! exists $params->{$field};
        next FIELD if ! $params->{$field};

        $self->$field($params->{$field});
    }

    return $self;
}

# param:
#     cascade => 1
sub delete {
    my ($self, $param) = @_;

    return unless $self->dbh;

    my $table_name = $self->_table_name;
    my $pkey = $self->_get_primary_key;

    return unless $self->{$pkey};

    my $sql = qq{
        DELETE FROM "$table_name" WHERE $pkey = ?
    };
    $sql .= ' CASCADE ' if $param && $param->{cascade};

    my $res = undef;
    $sql = ActiveRecord::Simple::Utils::quote_sql_stmt($sql, $self->dbh->{Driver}{Name});

    if ( $self->dbh->do($sql, undef, $self->{$pkey}) ) {
        $self->{isin_database} = undef;
        delete $self->{$pkey};

        $res = 1;
    }

    return $res;
}

sub is_defined {
    my ($self) = @_;

    return grep { defined $self->{$_} } @{ $self->_get_columns };
}

# param:
#     only_defined_fields => 1
###  TODO: refactor this
sub to_hash {
    my ($self, $param) = @_;

    my $field_names = $self->_get_columns;
    push @$field_names, keys %{ $self->_get_mixins } if $self->can('_get_mixins');
    my $attrs = {};

    for my $field (@$field_names) {
        next if ref $field;
        if ( $param && $param->{only_defined_fields} ) {
            $attrs->{$field} = $self->{$field} if defined $self->$field;
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

#### Find ####

sub find   { ActiveRecord::Simple::Find->new(shift, @_) }
sub all    { shift->find() }
sub get    { shift->find(@_)->fetch } ### TODO: move to Finder
sub count  { ActiveRecord::Simple::Find->count(shift, @_) }

sub exists {
    my $first_arg = shift;

    my ($class, @search_criteria);
    if (ref $first_arg) {
        # FIXME: Ugly solution, need some beautifulness =)
        # object method
        $class = ref $first_arg;

        if ($class eq 'ActiveRecord::Simple::Find') {
            return $first_arg->exists;
        }
        else {
            return ActiveRecord::Simple::Find->new($class, $first_arg->to_hash({ only_defined_fields => 1 }))->exists;
        }
    }
    else {
        carp '[DEPRECATED] This way of using method "exists" is deprecated. Please, see documentation to know how does it work now.';
        $class = $first_arg;
        @search_criteria = @_;
        return (defined $class->find(@search_criteria)->fetch) ? 1 : 0;
    }
}

sub first  { croak '[DEPRECATED] Using method "first" as a class-method is deprecated. Sorry about that. Please, use "first" in this way: "Model->find->first".'; }
sub last   { croak '[DEPRECATED] Using method "last" as a class-method is deprecated. Sorry about that. Please, use "last" in this way: "Model->find->last".'; }
sub select { ActiveRecord::Simple::Find->select(shift, @_) }

sub _find_many_to_many { ActiveRecord::Simple::Find->_find_many_to_many(shift, @_) }

sub DESTROY {}


### Private

sub _get_primary_key_value {
    my ($self) = @_;

    croak "Sory, you can call method '_get_primary_key_value' on unblessed scalar."
        unless blessed $self;

    my $pk = $self->_get_primary_key;
    return $self->$pk;
}


sub _get_relation_type {
    my ($class, $relation) = @_;

    my $type = $relation->{type};
    $type .= '_to_';

    my $related_class = _get_related_class($relation);

    eval { load $related_class }; ### TODO: check module is loaded

    my $rel_type = undef;
    while (my ($rel_key, $rel_opts) = each %{ $related_class->_get_relations }) {
        next if $class ne _get_related_class($rel_opts);
        $rel_type = $rel_opts->{type};
    }

    croak 'Oops! Looks like related class ' . $related_class . ' has no relations with ' . $class unless $rel_type;

    $type .= $rel_type;

    return $type;
}

sub _get_related_subclass {
    my ($relation) = @_;

    return undef if !ref $relation->{class};

    my $subclass;
    if (ref $relation->{class} eq 'HASH') {
        $subclass = (keys %{ $relation->{class} })[0];
    }
    elsif (ref $relation->{class} eq 'ARRAY') {
        $subclass = $relation->{class}[0];
    }

    return $subclass;
}

sub _get_related_class {
    my ($relation) = @_;

    return $relation->{class} if !ref $relation->{class};

    my $related_class;
    if (ref $relation->{class} eq 'HASH') {
        $related_class = ( %{ $relation->{class} } )[1]
    }
    elsif (ref $relation->{class} eq 'ARRAY') {
        $related_class = $relation->{class}[1];
    }

    return $related_class;
}

sub _insert {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name  = $self->_table_name;
    my @field_names  = grep { defined $param->{$_} } sort keys %$param;
    my $primary_key = ($self->can('_get_primary_key')) ? $self->_get_primary_key :
                      ($self->can('_get_secondary_key')) ? $self->_get_secondary_key : undef;

    my $field_names_str = join q/, /, map { q/"/ . $_ . q/"/ } @field_names;

    my (@bind, @values_list);
    for (@field_names) {
        if (ref $param->{$_} eq 'SCALAR') {
            push @values_list, ${ $param->{$_} };
        }
        else {
            push @values_list, '?';
            push @bind, $param->{$_};
        }
    }
    my $values = join q/, /, @values_list;
    my $pkey_val;
    my $sql_stm = qq{
        INSERT INTO "$table_name" ($field_names_str)
        VALUES ($values)
    };

    if ( $self->dbh->{Driver}{Name} eq 'Pg' ) {
        if ($primary_key) {
            $sql_stm .= ' RETURINIG ' . $primary_key if $primary_key;
            $sql_stm = ActiveRecord::Simple::Utils::quote_sql_stmt($sql_stm, $self->dbh->{Driver}{Name});
            $pkey_val = $self->dbh->selectrow_array($sql_stm, undef, @bind);
        }
        else {
            my $sth = $self->dbh->prepare(
                ActiveRecord::Simple::Utils::quote_sql_stmt($sql_stm, $self->dbh->{Driver}{Name})
            );

            $sth->execute(@bind);
        }
    }
    else {

        my $sth = $self->dbh->prepare(
            ActiveRecord::Simple::Utils::quote_sql_stmt($sql_stm, $self->dbh->{Driver}{Name})
        );
        $sth->execute(@bind);

        if ( $primary_key && defined $self->{$primary_key} ) {
            $pkey_val = $self->{$primary_key};
        }
        else {
            $pkey_val =
                exists $sth->{mysql_insertid} # mysql only
                    ? $sth->{mysql_insertid}
                    : $self->dbh->last_insert_id(undef, undef, $table_name, undef);
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

    my $table_name      = $self->_table_name;
    my @field_names     = sort keys %$param;
    my $primary_key     = ($self->can('_get_primary_key')) ? $self->_get_primary_key :
                          ($self->can('_get_secondary_key')) ? $self->_get_secondary_key : undef;

    my (@set_list, @bind);
    for (@field_names) {
        if (ref $param->{$_} eq 'SCALAR') {
            push @set_list, $_ . ' = ' . ${ $param->{$_} };
        }
        else {
            push @set_list, "$_ = ?";
            push @bind, $param->{$_};
        }
    }
    my $setstring = join q/, /, @set_list;
    push @bind, $self->{$primary_key};

    my $sql_stm = ActiveRecord::Simple::Utils::quote_sql_stmt(
        qq{
            UPDATE "$table_name" SET $setstring
            WHERE
                $primary_key = ?
        },
        $self->dbh->{Driver}{Name}
    );

    return $self->dbh->do($sql_stm, undef, @bind);
}

sub _mk_accessors {
    my ($class, $fields) = @_;

    return unless $fields;
    return if $class->can('_make_columns_accessors') && $class->_make_columns_accessors == 0;

    # FIXME
    my @methods;
    for my $method_name (@$fields) {
        push @methods, $method_name unless $class->can($method_name);
    }

    eval join "\n", "package $class;", map {
        "sub $_ { if (\@_ > 1) { \$_[0]->{$_} = \$_[1]; return \$_[0] } return \$_[0]->{$_} }"
    } @methods;

    return 1;
}


sub _mk_ro_accessors {
    my ($class, $fields) = @_;

    return unless $fields;
    return if $class->can('_make_columns_accessors') && $class->_make_columns_accessors == 0;

    # FIXME
    my @methods;
    for my $method_name (@$fields) {
        push @methods, $method_name unless $class->can($method_name);
    }

    eval join "\n", "package $class;", map {
        "sub $_ { \$_[0]->{$_} = \$_[1] if \@_ > 1; return \$_[0]->{$_} }";
    } @$fields;

    return 1;
}

sub _guess {
    my ($what_key, $class) = @_;

    return 'id' if $what_key eq 'primary_key';

    eval { load $class };

    my $table_name = $class->_table_name;
    $table_name =~ s/s$// if $what_key eq 'foreign_key';

    return ($what_key eq 'foreign_key') ? "$table_name\_id" : undef;
}

sub _delete_keys {
    my ($self, $rx) = @_;

    map { delete $self->{$_} if $_ =~ $rx } keys %$self;
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

    return $rel_hashref;
}

sub _table_name {
    my $class = ref $_[0] ? ref $_[0] : $_[0];

    croak 'Invalid data class' if $class =~ /^ActiveRecord::Simple/;

    my $table_name =
        $class->can('_get_table_name') ?
            $class->_get_table_name
            : ActiveRecord::Simple::Utils::class_to_table_name($class);

    return $table_name;
}

sub _mk_attribute_getter {
    my ($class, $method_name, $return) = @_;

    eval "package $class; \n sub $method_name { \$return }";
}

sub _mk_relations_accessors {
    my ($class) = @_;

    my $relations = $class->_get_relations;

    no strict 'refs';
    RELATION_NAME:
    for my $relation_name ( keys %{ $relations }) {
        my $pkg_method_name = $class . '::' . $relation_name;
        next RELATION_NAME if $class->can($pkg_method_name); ### FIXME: orrrr $relation_name???

        my $relation           = $relations->{$relation_name};
        my $full_relation_type = _get_relation_type($class, $relation);
        my $related_class      = _get_related_class($relation);

        ### TODO: check for error if returns undef
        my $pk = $relation->{params}{pk};
        my $fk = $relation->{params}{fk};

        my $instance_name = "relation_instance_$relation_name";

        if (any { $full_relation_type eq $_ } qw/one_to_many one_to_one one_to_only/) {
            *{$pkg_method_name} = sub {
                my ($self, @args) = @_;
                if (@args) {
                    my $object = shift @args;
                    croak "Using unblessed scalar as an object reference"
                        unless blessed $object;

                    $object->save() if ! exists $object->{isin_database} && !$object->{isin_database} == 1;

                    $self->$fk($object->$pk);
                    $self->{$instance_name} = $object;

                    return $self;
                }
                # else
                if (!$self->{$instance_name}) {
                    $self->{$instance_name} = $related_class->get($self->$fk) // $related_class;
                }

                return $self->{$instance_name};
            }
        }
        elsif ($full_relation_type eq 'only_to_one') {
            *{$pkg_method_name} = sub {
                my ($self, @args) = @_;

                if (!$self->{$instance_name}) {
                    $self->{$instance_name} = $related_class->find("$fk = ?", $self->$pk)->fetch;
                }

                return $self->{$instance_name};
            }
        }
        elsif ($full_relation_type eq 'many_to_one') {
            *{$pkg_method_name} = sub {
                my ($self, @args) = @_;

                if (@args) {

                    unless (List::Util::all { blessed $_ } @args) {
                        return $related_class->find(@args)->left_join($self->_get_table_name);
                    }

                    OBJECT:
                    for my $object (@args) {
                        next OBJECT if !blessed $object;

                        my $pk = $self->_get_primary_key;
                        $object->$fk($self->$pk)->save;
                    }

                    return $self;
                }
                # else
                return $related_class->new() if not $self->can('_get_primary_key');

                if (!$self->{$instance_name}) {
                    $self->{$instance_name} = $related_class->find("$fk = ?", $self->$pk);
                }

                return $self->{$instance_name};
            }
        }
        elsif ($full_relation_type eq 'many_to_many') {
            *{$pkg_method_name} = sub {
                my ($self, @args) = @_;

                if (@args) {

                    my $related_subclass = _get_related_subclass($relation);

                    unless (List::Util::all { blessed $_ } @args) {
                        return  $related_class->_find_many_to_many({
                            root_class => $class,
                            via_table  => $relation->{via_table},
                            m_class    => $related_subclass,
                            self       => $self,
                            where_statement => \@args,
                        });
                    }


                    if (defined $related_subclass) {
                        my ($fk1, $fk2);

                        $fk1 = $fk;

                        RELATED_CLASS_RELATION:
                        for my $related_class_relation (values %{ $related_class->_get_relations }) {
                            next RELATED_CLASS_RELATION
                                unless _get_related_subclass($related_class_relation)
                                    && $related_subclass eq _get_related_subclass($related_class_relation);

                            $fk2 = $related_class_relation->{params}{fk};
                        }

                        my $pk1_name = $self->_get_primary_key;
                        my $pk1 = $self->$pk1_name;

                        defined $pk1 or croak 'You are trying to create relations between unsaved objects. Save your ' . $class . ' object first';

                        OBJECT:
                        for my $object (@args) {
                            next OBJECT if !blessed $object;

                            my $pk2_name = $object->_get_primary_key;
                            my $pk2 = $object->$pk2_name;

                            $related_subclass->new($fk1 => $pk1, $fk2 => $pk2)->save;
                        }
                    }
                    else {
                        my ($fk1, $fk2);
                        $fk1 = $fk;

                        $fk2 = ActiveRecord::Simple::Utils::class_to_table_name($related_class) . '_id';

                        my $pk1_name = $self->_get_primary_key;
                        my $pk1 = $self->$pk1_name;

                        my $via_table = $relation->{via_table};

                        OBJECT:
                        for my $object (@args) {
                            next OBJECT if !blessed $object;

                            my $pk2_name = $object->_get_primary_key;
                            my $pk2 = $object->$pk2_name;

                            my $sql = qq/INSERT INTO "$via_table" ("$fk1", "$fk2") VALUES (?, ?)/;
                            $self->dbh->do($sql, undef, $pk1, $pk2);
                        }
                    }

                    return $self;
                }
                # else

                if (!$self->{$instance_name}) {
                    $self->{$instance_name} = $related_class->_find_many_to_many({
                        root_class => $class,
                        m_class    => _get_related_subclass($relation),
                        via_table  => $relation->{via_table},
                        self       => $self,
                    });
                }

                return $self->{$instance_name};
            }
        }
        elsif ($full_relation_type eq 'generic_to_generic') {
            *{$pkg_method_name} = sub {
                my ($self, @args) = @_;

                if (!$self->{$instance_name}) {
                    my %find_attrs;
                    while (my ($k, $v) = each %{ $relation->{key} }) {
                        $find_attrs{$v} = $self->$k;
                    }
                    $self->{$instance_name} = $related_class->find(\%find_attrs);
                }

                return $self->{$instance_name};
            }
        }
    }

    use strict 'refs';
}

sub _auto_load {
    my ($class) = @_;

    #my @class_name_parts = split q/::/, $class;
    #my $class_name = $class_name_parts[-1];

    my $table_name = ActiveRecord::Simple::Utils::class_to_table_name($class);

    # 0. check the name
    my $table_info_sth = $class->dbh->table_info('', '%', $table_name, 'TABLE');
    $table_info_sth->fetchrow_hashref or croak "Can't find table '$table_name' in the database";

    # 1. columns list
    my $column_info_sth = $class->dbh->column_info(undef, undef, $table_name, undef);
    my $cols = $column_info_sth->fetchall_arrayref({});

    my @columns = ();
    push @columns, $_->{COLUMN_NAME} for @$cols;

    # 2. Primary key
    my $primary_key_sth = $class->dbh->primary_key_info(undef, undef, $table_name);
    my $primary_key_data = $primary_key_sth->fetchrow_hashref;
    my $primary_key = ($primary_key_data) ? $primary_key_data->{COLUMN_NAME} : undef;

    $class->table_name($table_name) if $table_name;
    $class->primary_key($primary_key) if $primary_key;
    $class->columns(@columns) if @columns;
}



1;

__END__;

=head1 NAME

ActiveRecord::Simple

=head1 DESCRIPTION

ActiveRecord::Simple is a simple lightweight implementation of ActiveRecord
pattern. It's fast, very simple and very light.

=head1 SYNOPSIS

    
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

Copyright 2013-2018 shootnix.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

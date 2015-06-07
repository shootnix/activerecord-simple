package ActiveRecord::Simple::Find;

use 5.010;
use strict;
use warnings;
use Carp;
use Storable qw/freeze/;

use parent 'ActiveRecord::Simple';


sub new {
    my ($find, $class, @param) = @_;

    #my $self = $class->new();
    my $self = { class => $class };

    my $table_name = ($self->{class}->can('_get_table_name'))  ? $self->{class}->_get_table_name  : undef;
    my $pkey       = ($self->{class}->can('_get_primary_key')) ? $self->{class}->_get_primary_key : undef;

    $self->{prep_select_fields} //= [];
    $self->{prep_select_from}   //= [];
    $self->{prep_select_where}  //= [];

    my ($fields, $from, $where);

    if (!ref $param[0] && scalar @param == 1) {
        $fields = qq/"$table_name".*/;
        $from   = qq/"$table_name"/;
        $where  = qq/"$table_name"."$pkey" = ?/;

        $self->{BIND} = \@param
    }
    elsif (!ref $param[0] && scalar @param == 0) {
        $fields = qq/"$table_name".*/;
        $from   = qq/"$table_name"/;

        $self->{BIND} = undef;
    }
    elsif (ref $param[0] && ref $param[0] eq 'HASH') {
        # find many by params
        my ($where_str, @bind, @condition_pairs);
        for my $param_name (keys %{ $param[0] }) {
            if (ref $param[0]{$param_name}) {
                my $instr = join q/, /, map { '?' } @{ $param[0]{$param_name} };
                push @condition_pairs, qq/"$table_name"."$param_name" IN ($instr)/;
                push @bind, @{ $param[0]{$param_name} };
            }
            else {
                push @condition_pairs, qq/"$table_name"."$param_name" = ?/;
                push @bind, $param[0]{$param_name};
            }
        }
        $where_str = join q/ AND /, @condition_pairs;

        $fields = qq/"$table_name".*/;
        $from   = qq/"$table_name"/;
        $where  = $where_str;

        $self->{BIND} = \@bind;
    }
    elsif (ref $param[0] && ref $param[0] eq 'ARRAY') {
        # find many by primary keys
        my $whereinstr = join ', ', @{ $param[0] };

        $fields = qq/"$table_name".*/;
        $from   = qq/"$table_name"/;
        $where  = qq/"$table_name"."$pkey" IN ($whereinstr)/;

        $self->{BIND} = undef;
    }
    else {
        # find many by condition
        my $wherestr = shift @param;

        $fields = qq/"$table_name".*/;
        $from   = qq/"$table_name"/;
        $where  = $wherestr;

        $self->{BIND} = \@param;
    }

    push @{ $self->{prep_select_fields} }, $fields if $fields;
    push @{ $self->{prep_select_from} }, $from if $from;
    push @{ $self->{prep_select_where} }, $where if $where;

    return bless $self, $find;
}

sub only {
    my ($self, @fields) = @_;

    scalar @fields > 0 or croak 'Not defined fields for method "only"';
    #exists $self->{prep_select_fields}
    #    or croak 'Not executed method "find" before "only"';

    if ($self->can('_get_primary_key')) {
        push @fields, $self->{class}->_get_primary_key;
    }

    my $table_name = $self->{class}->_get_table_name;

    my @filtered_prep_select_fields =
        grep {
            $_ ne qq/"$table_name".*/
        }
        @{ $self->{prep_select_fields} };
    push @filtered_prep_select_fields, map { qq/"$table_name"."$_"/ } @fields;
    $self->{prep_select_fields} = \@filtered_prep_select_fields;

    return $self;
}

sub order_by {
    my ($self, @param) = @_;

    #return if not defined $self->{SQL}; ### TODO: die
    return $self if exists $self->{prep_order_by};

    $self->{prep_order_by} = \@param;

    return $self;
}

# same as "with"
sub left_join { shift->with(@_) }

sub desc {
    my ($self) = @_;

    #return if not defined $self->{SQL};
    return $self if exists $self->{prep_desc};

    $self->{prep_desc} = 1;

    return $self;
}

sub asc {
    my ($self, @param) = @_;

    #return if not defined $self->{SQL};
    return $self if exists $self->{prep_asc};

    $self->{prep_asc} = 1;

    return $self;
}

sub limit {
    my ($self, $limit) = @_;

    #return if not defined $self->{SQL};
    return $self if exists $self->{prep_limit};

    $self->{prep_limit} = $limit; ### TODO: move $limit to $self->{BIND}

    return $self;
}

sub offset {
    my ($self, $offset) = @_;

    #return if not defined $self->{SQL};
    return $self if exists $self->{prep_offset};

    $self->{prep_offset} = $offset; ### TODO: move $offset to $self->{BIND}

    return $self;
}

sub with {
    my ($self, @rels) = @_;

    return $self if exists $self->{prep_left_joins};
    return $self unless @rels;

    $self->{class}->can('_get_relations')
        or die "Class doesn't have any relations";

    my $table_name = $self->{class}->_get_table_name;

    $self->{prep_left_joins} = [];
    $self->{with} = \@rels;
    RELATION:
    for my $rel_name (@rels) {
        my $relation = $self->{class}->_get_relations->{$rel_name}
            or next RELATION;

        next RELATION unless grep { $_ eq $relation->{type} } qw/one only/;
        my $rel_table_name = $relation->{class}->_get_table_name;

        my $rel_columns = $relation->{class}->_get_columns;

        #push @{ $self->{prep_select_fields} }, qq/"$rel_table_name".*/;
        push @{ $self->{prep_select_fields} },
            map { qq/"$rel_table_name"."$_" AS "JOINED_$rel_name\_$_"/  }
                @{ $relation->{class}->_get_columns };

        if ($relation->{type} eq 'one') {
            my $join_sql = qq/LEFT JOIN "$rel_table_name" ON /;
            $join_sql .= qq/"$rel_table_name"."$relation->{params}{pk}"/;
            $join_sql .= qq/ = "$table_name"."$relation->{params}{fk}"/;

            push @{ $self->{prep_left_joins} }, $join_sql;
        }
    }

    return $self;
}

sub abstract {
    my ($self, $opts) = @_;

    return $self if ! ref $opts && ref $opts ne 'HASH';

    while (my ($method, $param) = each %$opts) {
        my @p = (ref $param) ? @$param : ($param);
        $self->$method(@p);
    }

    return $self;
}


sub _finish_sql_stmt {
    my ($self) = @_;

    $self->{SQL} = "SELECT " . (join q/, /, @{ $self->{prep_select_fields} }) . "\n";
    $self->{SQL} .= "FROM " . (join q/, /, @{ $self->{prep_select_from} }) . "\n";

    if (defined $self->{prep_left_joins}) {
        $self->{SQL} .= "$_\n" for @{ $self->{prep_left_joins} };
        $self->{has_joined_table} = 1;
    }

    if (
        defined $self->{prep_select_where}
        && ref $self->{prep_select_where} eq 'ARRAY'
        && scalar @{ $self->{prep_select_where} } > 0
    ) {
        $self->{SQL} .= "WHERE\n";
        $self->{SQL} .= join " AND ", @{ $self->{prep_select_where} };
    }

    if (defined $self->{prep_order_by}) {
        $self->{SQL} .= ' ORDER BY ';
        $self->{SQL} .= join q/, /, map { q/"/.$_.q/"/ } @{ $self->{prep_order_by} };
    }

    if (defined $self->{prep_desc}) {
        $self->{SQL} .= ' DESC';
    }

    if (defined $self->{prep_asc}) {
        $self->{SQL} .= ' ACS';
    }

    if (defined $self->{prep_limit}) {
        $self->{SQL} .= ' LIMIT ' . $self->{prep_limit};
    }

    if (defined $self->{prep_offset}) {
        $self->{SQL} .= ' OFFSET ' . $self->{prep_offset};
    }

    $self->_delete_keys(qr/^prep\_/);
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

        my $class = $self->{class};
        for my $object_data (@$resultset) {
            my $obj = bless $object_data, $class;

            if ($self->{has_joined_table}) {
                RELATION:
                for my $rel_name (@{ $self->{with} }) {
                    my $relation = $self->{class}->_get_relations->{$rel_name}
                        or next RELATION;

                    my %pairs =
                        map { $_, $object_data->{$_} }
                            grep { $_ =~ /^JOINED\_$rel_name\_/ }
                                keys %$object_data;

                    next RELATION unless %pairs;

                    for my $key (keys %pairs) {
                        my $val = delete $pairs{$key};
                        $key =~ s/^JOINED\_$rel_name\_//;
                        $pairs{$key} = $val;
                    }
                    $obj->{"relation_instance_$rel_name"} =
                        $relation->{class}->new(\%pairs);
                        #bless \%pairs, $relation->{class};

                    $obj->_delete_keys(qr/^JOINED\_$rel_name/);
                }

                delete $self->{has_joined_table};
            }

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

sub to_sql {
    my ($self) = @_;

    $self->_finish_sql_stmt();
    $self->_quote_sql_stmt();

    return wantarray ? ($self->{SQL}, $self->{BIND}) : $self->{SQL};
}

sub _delete_keys {
    my ($self, $rx) = @_;

    map { delete $self->{$_} if $_ =~ $rx } keys %$self;
}

1;



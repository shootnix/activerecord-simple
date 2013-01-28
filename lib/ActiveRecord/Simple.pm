package ActiveRecord::Simple;

use 5.010;
use strict;
use warnings;

=head1 NAME

ActiveRecord::Simple - Simple to use lightweight implementation of
ActiveRecord pattern.

=head1 VERSION

Version 0.21

=cut

our $VERSION = '0.21';

use Data::Dumper;
use utf8;
use Encode;
use Module::Load;

my $dbhandler = undef;

sub new {
    my ($class, $param) = @_;

    $class->mk_accessors( $class->get_columns );

    if ( $class->can('get_relations') ) {
        my $relations = $class->get_relations;
	no strict 'refs';
        RELNAME:
        for my $relname ( keys %{ $relations } ) {
            my $pkg_method_name = $class . '::' . $relname;
            next RELNAME if $class->can($pkg_method_name);

            *{$pkg_method_name} = sub {
                my $self = shift;
                unless ( $self->{"relation_instance_$relname"} ) {
                    my $relation = $class->get_relations->{$relname};
                    my $pkey = $self->get_primary_key;

                    load $relation->{class};

                    my $type = $relation->{type};
                    my $fkey = $relation->{foreign_key};

                    if ( $type eq 'one' ) {
                        $self->{"relation_instance_$relname"} =
			    $relation->{class}->find(
                                "$fkey = ?",
                                $self->$pkey
                            )->fetch();
                    }
                    elsif ( $type eq 'many' ) {
                        $self->{"relation_instance_$relname"} =
			    $relation->{class}->find(
				"$fkey = ?",
				$self->$pkey,
			    );
                    }
                }

                $self->{"relation_instance_$relname"};
            }
        }
        use strict 'refs';
    }

    $param->{is_recorded} = undef;

    return bless $param || {}, $class;
}

sub mk_accessors {
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

    $class->mk_attribute_getter('get_columns', $columns);
}

sub primary_key {
    my ($class, $primary_key) = @_;

    $class->mk_attribute_getter('get_primary_key', $primary_key);
}

sub table_name {
    my ($class, $table_name) = @_;

    $class->mk_attribute_getter('get_table_name', $table_name);
}

sub relations {
    my ($class, $relations) = @_;

    $class->mk_attribute_getter('get_relations', $relations);
}

sub mk_attribute_getter {
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

sub quote_string {
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

    my $save_param = {};
    my $fields = $self->get_columns;
    my $pkey   = $self->get_primary_key;

    FIELD:
    for my $field (@$fields) {
        next FIELD if $field eq $pkey && !$self->{$pkey};
        $save_param->{$field} = $self->{$field};
    }

    my $result;
    if ( $self->{is_recorded} ) {
	$result = $self->update($save_param);
    }
    else {
        $result = $self->insert($save_param);
    }

    return $result;
}

sub insert {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name      = $self->get_table_name;
    my @field_names     = sort keys %$param;
    my $primary_key     = $self->get_primary_key;

    my $field_names_str = join q/, /, map { q/"/ . $_ . q/"/ } @field_names;
    my $values          = join q/, /, map { '?' } @field_names;
    my @bind            = map { $param->{$_} } @field_names;

    my $pkey_val;
    if ( $self->dbh->{Driver}->{Name} eq 'Pg' ) {
	my $sql_stm = qq{
            insert into "$table_name" ($field_names_str)
            values ($values)
            returning $primary_key
        };

	$pkey_val = $self->dbh->selectrow_array(
	    quote_string($sql_stm, $self->dbh->{Driver}{Name}),
	    undef,
	    @bind
	);
    }
    else {
	my $sql_stm = qq{
	    insert into "$table_name" ($field_names_str)
	    values ($values)
        };

	my $sth = $self->dbh->prepare(
	    quote_string($sql_stm, $self->dbh->{Driver}{Name})
	);
        $sth->execute(@bind);

	if ( defined $self->{$primary_key} ) {
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

    $self->$primary_key($pkey_val);
    $self->{is_recorded} = 1;

    return $pkey_val;
}

sub update {
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

    return $self->dbh->do(
	quote_string($sql_stm, $self->dbh->{Driver}{Name}),
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
    if ( $self->dbh->do(quote_string($sql, $driver_name), undef, $self->{$pkey}) ) {
	$self->{is_recorded} = undef;
	delete $self->{$pkey};

	$res = 1;
    }

    return $res;
}

sub find {
    my ($class, @param) = @_;

    my $resultset;
    my $self = $class->new();

    if ( ref $param[0] eq 'HASH' ) {
        $resultset = $self->find_many_by_params( $param[0] );

        my @bulk_objects;
        if ( $resultset && ref $resultset eq 'ARRAY' && scalar @$resultset > 0 ) {
            for my $param (@$resultset) {
		my $obj = $class->new($param);
		$obj->{is_recorded} = 1;
                push @bulk_objects, $obj;
            }
        }
        else {
            push @bulk_objects, $self;
        }

        $self->{_objects} = \@bulk_objects;
    }
    elsif ( ref $param[0] eq 'ARRAY' ) {
	my $pkeyvals = $param[0];
	my $resultset = $self->find_many_by_primary_keys($pkeyvals);

	my @bulk_objects;
	if ( $resultset && ref $resultset eq 'ARRAY' && scalar @$resultset > 0 ) {
	    for my $paramset (@$resultset) {
		my $obj = $class->new($paramset);
		$obj->{is_recorded} = 1;
		push @bulk_objects, $obj;
	    }
	}
	else {
	    push @bulk_objects, $self;
	}

	$self->{_objects} = \@bulk_objects;
    }
    else {
        if ( scalar @param > 1 ) {
            $resultset = $self->find_many_by_condition(@param);

            my @bulk_objects;
            if ( $resultset && ref $resultset eq 'ARRAY' && scalar @$resultset > 0 ) {
                for my $param (@$resultset) {
		    my $obj = $class->new($param);
		    $obj->{is_recorded} = 1;
                    push @bulk_objects, $obj;
                }
            }
            else {
                push @bulk_objects, $self;
            }

            $self->{_objects} = \@bulk_objects;
        }
        else {
            my $pkeyval = $param[0];
            $resultset = $self->find_one_by_primary_key($pkeyval);
            $self->fill_params($resultset);
            $self->{is_recorded} = 1;
        }
    }

    return $self;
}

sub fetch {
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

sub fill_params {
    my ($self, $params) = @_;

    return unless $params;

    FIELD:
    for my $field ( sort keys %$params ) {
        $self->{$field} = $params->{$field};
    }

    return $self;
}

sub find_many_by_primary_keys {
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

    return $self->dbh->selectall_arrayref(
	quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	{ Slice => {} }
    );
}

sub find_many_by_condition {
    my ($self, @param) = @_;

    return unless $self->dbh;

    my $wherestr = shift @param;
    my $table_name = $self->get_table_name;

    my $sql_stmt = qq{
	select * from "$table_name"
        where
            $wherestr
    };

    return $self->dbh->selectall_arrayref(
	quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	{ Slice => {} },
	@param
    );
}

sub find_many_by_params {
    my ($self, $param) = @_;

    return unless $self->dbh && $param;

    my $table_name = $self->get_table_name;
    my $where_str = join q/ and /, map { q/"/ . $_ . q/"/ .' = ?' } sort keys %$param;
    my @bind = values %$param;

    my $sql_stm = qq{
        select * from "$table_name"
        where
            $where_str
    };

    return $self->dbh->selectall_arrayref(
	quote_string($sql_stm, $self->dbh->{Driver}{Name}),
	{ Slice => {} },
	@bind
    );
}

sub find_one_by_primary_key {
    my ($self, $pkeyval) = @_;

    return unless $self->dbh;

    my $table_name = $self->get_table_name;
    my $pkey = $self->get_primary_key;

    my $sql_stmt = qq{
	select * from "$table_name"
        where
            "$pkey" = ?
    };

    return $self->dbh->selectrow_hashref(
	quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	undef,
	$pkeyval
    );
}

sub is_defined {
    my ($self) = @_;

    my $pkey = $self->get_primary_key;

    return $self->{$pkey};
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

    return $self->dbh->selectrow_array(
	quote_string($sql, $self->dbh->{Driver}{Name}),
	undef,
	@bind
    );
}

# attrs:
#     table fields
sub get_all {
    my ($class, $attrs) = @_;

    my $self = $class->new();

    my $columns;
    if ( $attrs && ref $attrs eq 'ARRAY' && scalar @$attrs ) {
	$columns = join ', ', map { q/"/.$_.q/"/ } @$attrs;
    }
    else {
	$columns = '*';
    }

    my $table_name = $self->get_table_name;
    my $pkey = $self->get_primary_key;

    my $sql_stmt = qq{
	select $columns from "$table_name" order by "$pkey"
    };

    return $class->dbh->selectall_arrayref(
	quote_string($sql_stmt, $self->dbh->{Driver}{Name}),
	{ Slice => {} }
    );
}

# param:
#     only_defined_fields => 1
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

1;

__END__;

=head1 NAME

ActiveRecord::Simple

=head1 VERSION

0.21

=head1 DESCRIPTION

ActiveRecord::Simple is a simple lightweight implementation of ActiveRecord
pattern. It's fast, very simple and very ligth.

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
    my $person = MyModel::Person->find(1);

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
            class       => 'MyModel::Car',
            foreign_key => 'id_person',
            type        => 'many',
        },
        wife => {
            class       => 'MyModel::Wife',
            foreign_key => 'id_person',
            type        => 'one',
        }
    });

    # And then, you're ready to go:
    say $person->cars->fetch->id; # if the relation is one to many
    say $person->wife->name; # if the relation is one to one

=head1 METHODS

ActiveState::Simple provides a variety of techniques to make your work with
data little easier. It contains only a basic set of operations, such as
serch, create, update and delete data.

If you realy need more complicated solution, just try to expand on it with your
own methods.

=head1 Class Methods

Class methods mean that you can't do something with a separate row of the table,
but they need to manipulate of the table as a whole object. You may find a row
in the table or keep database hanlder etc.

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

Set name of the primary key. This method is reqired to use in the child
(your model) classes.

=head2 table_name

    __PACKAGE__->table_name('persons');

Set name of the table. This method is reqired to use in the child (your model)
classes.

=head2 relations

    __PACKAGE__->relations({
        cars => {
            class => 'MyModel::Car',
            foreign_key => 'id_person',
            type => 'many'
        },
    });

It's not a required method and you don't have to use it if you don't want to use
any relationships in youre tables and objects. However, if you need to,
just keep this simple schema in youre mind:

    __PACKAGE__->relations({
        [relation key] => {
            class => [class name],
            foreign_key => [column that refferers to the table],
            type => [many or one]
        },
    })

    [relation key] - this is a key that will be provide the access to instance
    of the another class (which is specified in the option "class" below),
    associated with this relationship. Allowed to use as many keys as you need:

    $package_instance->[relation key]->[any method from the related class];


=head2 find

There are several ways to find someone in your database using ActiveRecord::Simple:

    # by primary key:
    my $person = MyModel::Person->find(1);

    # by multiple primary keys
    my @persons = MyModel::Person->find([1, 2, 5])->fetch();

    # by simple condition:
    my @persons = MyModel::Person->find({ name => 'Foo' })->fetch();

    # by where-condtions:
    my @persons = MyModel::Person->find('first_name = ? and id_person > ?', 'Foo', 1);

If you want to get an instance of youre active-record class and if you know the
primary key, you can do it, just put the primary key as a parameter into the
find method:

    my $person = MyModel::Person->find(1);

In this case, you will get only one instance (because can't be more than one rows
in the table with the same values of the primary key).

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
    return unless $person->id_defined;

=head2 fetch

When you use the "find" method to get a few rows from the table, you get the
meta-object with a several objects inside. To use all of them or only a part,
use the "fetch" method:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch();

You can also specify how many objects you want to use:

    my @persons = MyModel::Person->find('id_person != ?', 1)->fetch(2);
    # fetching only 2 objects.

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

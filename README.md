ActiveRecord::Simple
====================

ActiveRecord::Simple - Simple to use lightweight implementation of
ActiveRecord pattern.

It is fast, don't have any dependencies and realy easy to use.

The basic setup of your package should be:

    package Model::Foo;

    use base 'ActiveRecord::Simple';

    __PACKAGE__->table_name('foo');
    __PACKAGE__->columns(['id', 'bar', 'baz']);
    __PACKAGE__->primary_key('id');

    1;

And then, you can use your package in a program:

    use Foo;

    my $foo = Foo->new({ bar => 'value', baz => 'value' });
    $foo->save();

    # or
    my $foo = Foo->find(1);
    say $foo->bar;

    # or
    $foo->bar('new value')->save();

    say $foo->bar;

That's it. ActiveState::Simple provides a variety of techniques to make your work with
data little easier. It contains only a basic set of operations, such as
search, create, update and delete data.

ActiveRecord::Simple doesn't handle your database connection, but you may keep
it in the special method (class attribute) "dbh":

    Foo->dbh($dbh);

    # or
    ActiveRecord::Simple->dbh($dbh);

    # or you can use a special function, like this:
    sub dbhandler {
        unless ( $dbh->ping ) {
            $dbh->connect("...");
        }

        return $dbh;
    }

    ActiveRecord::Simple->dbh( &dbhandler );

See pod documentation of the module for more information about using
ActiveRecord::Simple.

INSTALLATION
============

To install this module, run the following commands:

	$ perl Makefile.PL
	$ make
	$ make test
	$ make install

or:

        $ sudo cpan ActiveRecord::Simple

SUPPORT AND DOCUMENTATION
=========================

After installing, you can find documentation for this module with the
perldoc command.

    perldoc ActiveRecord::Simple

LICENSE AND COPYRIGHT
=====================

Copyright (C) 2013 shootnix

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

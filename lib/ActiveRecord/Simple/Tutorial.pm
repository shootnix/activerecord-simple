package ActiveRecord::Simple::Tutorial;

use strict;
use warnings;
use 5.010;

1;

__END__

=head1 NAME

ActiveRecord::Simple::Tutorial

=head1 DESCRIPTION

Using ActiveRecord::Simple as an ORMapper in your project

=head1 INTRO

Before we start, you should to know few issues about ActiveRecord::Simple

=over 8

=item -B<There is no database handler's>

ARSimple doesn't handle your database connection, just keeps a handler that you have already created.

=item -B<ARSimpe doesn't try to cover all your sql-requests by object-related code>

It's simple, so if you need to do something very sophisticated, just do it by yourself.

=item -B<ARSimple doesn't check types>

Perl doesn't check types. ARSimple is like perl.

=back

=head1 PROJECT's FILE SYSTEM

=over 8

=item -B<sql>

Directory with sql-code.

=item -B<lib>

Directory with perl-classes

=item -B<t>

Tests.

=back

=head1 DATABASE DESIGN

We going to make yet another blog engine and need a simple model: authors, articles and comments.

    CREATE TABLE authors (
        id   SERIAL PRIMARY KEY,
        name text
    );

Save this SQL-code in "sql/myschema.sql" and create the sqlite database:

    $ sqlite3 cd.db < sql/myschema.sql

=head1 CLASSES

To generate classes, run "arsimple" script:

    $ cd lib && arsimple -perl -dir ../sql -driver SQLite

We got three perl-classes: Track, Cd, Artis.








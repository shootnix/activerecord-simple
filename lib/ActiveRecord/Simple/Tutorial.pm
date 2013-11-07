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
        id   INTEGER PRIMARY KEY,
        name TEXT
    );

    CREATE TABLE articles (
        id        INTEGER PRIMARY KEY,
        title     TEXT NOT NULL,
        content   TEXT NOT NULL,
        author_id INTEGER NOT NULL REFERENCES authors(id)
    );

    CREATE TABLE comments (
        id              INTEGER PRIMARY KEY,
        create_date     TIMESTAMP NOT NULL DEFAULT NOW,
        comments_author TEXT NOT NULL,
        comment         TEXT,
        article_id      INTEGER NOT NULL REFERENCES articles(id)
    );

Save this SQL-code in "sql/myschema.sql" and create the sqlite database:

    $ sqlite3 blog.db < sql/myschema.sql

=head1 CLASSES

To generate classes, run "arsimple" script:

    $ cd lib && arsimple -perl -dir ../sql -driver SQLite

The script will read recursively directory, find the .sql files and create perl-classes from sql.
Now we have three files: Articles.pm, Authors.pm and Comments.pm. Let's do tests.

=head1 BASIC SYNTAX

In first test we should create authors. Let's go to t/ and create test-file authors.t:

    $ touch authors.t

You should create database handler and insert into Authors->dbh():

    use DBI;
    use Authors;

    Authors->dbh(DBI->connect("dbi:SQLite:sql/blog.db"));

So, we are ready to write our first bunch of tests. First, create authors John Doe and Jack Black:

    ok Authors->new({ name => 'John Doe' })->save;
    ok Authors->new({ name => 'Jack Black' })->save;

Second, check each author has been saved in database:

    ok my $john = Authors->find({ name => 'John Doe' })->fetch;
    ok $john->is_defined; is $john->name, 'John Doe'; is $john->id, 1;
    ok my $jack = Authors->find({ name => 'Jack Black' })->fetch;
    ok $jack->is_defined; is $jack->name, 'Jack Black'; is $jack->id, 2;

We have done with authors. Let's create articles.

=head1 RELATIONS

As you can see, table "articles" belongs to "authors", this is relation one-to-many: one author
can have many articles, but only one article beongs to one author. We have to reflect it in the code.
In Authors.pm (one-to-many):

    __PACKAGE__->relations({
	    articles => {
	        class => 'Articles',
	        type  => 'many',
	        key   => 'author_id'
	    }
    });

In Articles.pm (one-to-one):

    __PACKAGE__->relations({
	    author => {
	        class => 'Authors',
	        type => 'one',
	        key  => 'author_id'
	    }
    });

The foreign key is "author_id".

So we are ready to create articles. Let's do it:

    ok my $john = Authors->find({ name => 'John Doe' })->fetch;
    ok my $article = Artices->new({
        title     => 'My first article',
        content   => '...',
        author_id => $john->id
    });
    ok $article->save;

Now check the article has been saved and linked to the author:

    ok my @articles = $john->articles->fetch;
    my $first_article = shift @articles;
    is $first_article->title, 'My first article';

Also we can change an author of the article, simply set it into accessor:

    ok $first_article->author(Authors->find({ name => 'Jack Black' })->fetch)->save;
    is $first_article->author->name, 'Jack Black';

=head1 SQL-TRICKS





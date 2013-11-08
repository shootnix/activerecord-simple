package ActiveRecord::Simple::Tutorial;

use strict;
use warnings;
use 5.010;

1;

__END__

=head1 NAME

ActiveRecord::Simple::Tutorial

=head1 DESCRIPTION

Information how to use ActiveRecord::Simple as an ORMapper in your project.

=head1 INTRO

Before we start, you should to know a few issues about ActiveRecord::Simple

=over 8

=item -B<There is no database handler's>

ARSimple doesn't handle your database connection, just keeps a handler that you have already created.

=item -B<ARSimpe doesn't try to cover all your sql-requests by object-related code>

It's simple, so if you need to do something very sophisticated, just do it by yourself.

=item -B<ARSimple doesn't check types>

Perl doesn't check types. ARSimple is like perl.

=back

=head1 PROJECT's FILE SYSTEM

Filesystem of the future project looks like that.

=over 8

=item -B<sql>

Directory with sql-code.

=item -B<lib>

Directory with perl-classes

=item -B<t>

Tests.

=back

=head1 DATABASE DESIGN

We're going to make yet another blog engine and create a simple model: authors, articles and comments.

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

To generate classes, run "mars" script:

    $ cd lib && mars -perl -dir ../sql -driver SQLite

The script will read recursively directory, find the .sql files and create perl-classes from sql.
Now we have three files: Articles.pm, Authors.pm and Comments.pm. Let's start the test.

=head1 BASIC SYNTAX

In first test we have to create authors. Let's go to t/ and create test-file authors.t:

    $ touch authors.t

You have to create database handler and insert it into Authors->dbh():

    use DBI;
    use Authors;

    Authors->dbh(DBI->connect("dbi:SQLite:sql/blog.db"));

So, we are ready to write our first bunch of tests. First, let's create authors John Doe and Jack Black:

    ok Authors->new({ name => 'John Doe' })->save;
    ok Authors->new({ name => 'Jack Black' })->save;

Second, check each author has been saved in the database:

    ok my $john = Authors->find({ name => 'John Doe' })->fetch;
    ok $john->is_defined;
    is $john->name, 'John Doe';
    is $john->id, 1;

    ok my $jack = Authors->find({ name => 'Jack Black' })->fetch;
    ok $jack->is_defined;
    is $jack->name, 'Jack Black';
    is $jack->id, 2;

We have done with authors. Let's create articles.

=head1 RELATIONS

As you can see, table "articles" belongs to "authors", this is relation one-to-many: one author
can have many articles, but only one article belongs to one author. We have to reflect it in the code.
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

Also we can change article's author. Just put new object into accessor "author":

    ok $first_article->author(Authors->find({ name => 'Jack Black' })->fetch)->save;
    is $first_article->author->name, 'Jack Black';

=head1 SQL-MODIFIERS

ARSimple provides a few sql-modifiers: order_by, asc, desc, limit, offset. All this modifiers you can use before call "fetch".
Let's create test "comments" and take a look a bit closer to that functions. Of course, we need to add new relations to Articles and Comments classes to use it in our tests. I think, you already know how to do it ;-)

    my $article = Articles->get(1); ### it's the same as Articles->find(1)->fetch;
    my $comment1 = Comments->new({
        id => 1,
        comments_author => 'Batman',
        comment => 'Hello from Batman!',
        article_id => $article_id
    });
    my $comment2 = Comments->new({
        id => 2,
        comments_author => 'Superman',
        comment => 'Yahoo!',
        article_id => $article_id
    });
    ok $comment1->save;
    ok $comment2->save;

So we have two commets. Let's see what methods of sampling, we can use:

    my @comments;
    # by date (desc):
    @comments = Comments->find->order_by('create_date')->desc->fetch;
    is scalar @comments, 2;

    # by author (desc):
    @comments = Comments->find->order_by('comments_author')->asc->fetch;
    is $comments[0]->comments_author, 'Batman';

    # only one comment from database:
    @comments = Comments->find->limit(1)->fetch;
    is scalar @comments, 1;

    # only one, second comment:
    @comments = Comments->find->limit(1)->offset(1)->fetch;
    is scalar @comments, 1;

    # first comment:
    @comments = Comments->find->order_by('id')->limit(1)->fetch; # or:
    @comments = Comments->first->fetch;
    ok $comments[0]->id, 1;

    # last comment:
    @comments = Comments->find->order_by('id')->desc->limit(1)->fetch; # or:
    @comments = Comments->last->fetch;
    ok $comments[0]->id, 2;

What if we have to know only creation date of last comments? We have to use another one cool feature: method C<only>. It tells what fields we want to get:

    my $last_comment = Comments->last->only('create_date')->fetch;
    ok $last_comment->create_date;
    ok !$last_comment->comments_author;

It works everywhere before you fetch it:

    Comments->find('id > ?', 1)->only('comments_author', 'article_id')->fetch;

=head1 FETCHING

First of all, fetching is not limiting. If you'll write this:

    my @articles = Articles->find->fetch(1);

Will be fetched B<*ALL*> records from the table "articles", but you'll get only one. Why? We need it ;-) For example, to do something like that:

    my $articles_res = Articles->find;
    while (my $article = $articles_res->fetch) {
        say $article->title;
    }
    ### or even that:
    while (my @articles = $articles_res->fetch(3)) {
        say $_->title for @articles;
        say 'Next 3 Articles:';
    }

So, if you want to get only 10 records from database, use limit ;-)

    my @articles = Articles->find->limit(10)->fetch;

=head1 MANY-TO-MANY

In this tutorial we don't need to use many-to-many relations. But in real life we have to. To
read documantation how "many-to-many" relations does work, please, wisit our wiki on github: L<Relationship Tutorial|https://github.com/shootnix/activerecord-simple/wiki/Relationship-Tutorial>

=head1 HOW TO REPORT ABOUT A PROBLEM

Please, make an issue on my L<github page|https://github.com/shootnix/activerecord-simple/issues>.
Or you can write an e-mail: L<mailto:shootnix@cpan.org>




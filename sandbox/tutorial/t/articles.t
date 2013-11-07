#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Test::More;
use DBI;

use lib '../lib';
use Authors;
use Articles;

my $dbh = DBI->connect("dbi:SQLite:../sql/blog.db", "", "");
Authors->dbh($dbh);

ok my $john = Authors->find({ name => 'John Doe' })->fetch;
ok $john->is_defined;

ok my $article = Articles->new({
	id        => 1,
    title     => 'My first article',
    content   => '...',
    author_id => $john->id,
});
ok $article->save();

my @johns_articles = $john->articles->fetch;
my $first_article = shift @johns_articles;
is $first_article->title, 'My first article';
ok $first_article->author(Authors->find({ name => 'Jack Black' })->fetch)->save;
is $first_article->author->name, 'Jack Black';

done_testing();
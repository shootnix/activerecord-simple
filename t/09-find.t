#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";
use Data::Dumper;
use Test::More;

use DBI;

eval { require DBD::SQLite } or plan skip_all => 'Need DBD::SQLite for testing';


package Customer;

use parent 'ActiveRecord::Simple';


__PACKAGE__->table_name('customers');
__PACKAGE__->primary_key('id');
__PACKAGE__->columns(qw/id first_name second_name age email/);

#__PACKAGE__->has_one(info => 'CustomersInfo');

__PACKAGE__->mixins(
	mixin => sub {
		'SUM("id")'
	},
);


package main;

my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:","","")
	or die DBI->errstr;

my $_INIT_SQL = q{
	CREATE TABLE `customers` (
  		`id` int AUTO_INCREMENT,
  		`first_name` varchar(200) NULL,
  		`second_name` varchar(200) NOT NULL,
  		`age` tinyint(2) NULL,
  		`email` varchar(200) NOT NULL,
  		PRIMARY KEY (`id`)
	);
};

my $_DATA_SQL = q{
	INSERT INTO `customers` (`id`, `first_name`, `second_name`, `age`, `email`)
	VALUES
		(1,'Bob','Dylan',NULL,'bob.dylan@aol.com'),
		(2,'John','Doe',77,'john@doe.com'),
		(3,'Bill','Clinton',50,'mynameisbill@gmail.com'),
		(4,'Bob','Marley',NULL,'bob.marley@forever.com'),
		(5,'','',NULL,'foo.bar@bazz.com'),
		(6, 'Lady', 'Gaga', 666, 'gaga-o-la-la@bad.romance');
};

$dbh->do($_INIT_SQL);
$dbh->do($_DATA_SQL);

Customer->dbh($dbh);

my $finder = Customer->objects->find({ first_name => 'Bob' })->order_by('id');
isa_ok $finder, 'ActiveRecord::Simple::Find';
my @bobs = (1, 4); my $i = 0;
while (my $bob = $finder->next) {
	ok $bob->id == $bobs[$i], 'next, bob.id == ' . $bobs[$i];
	$i++;
}

$finder = Customer->objects->find;
while (my @customers_pair = $finder->next(2)) {
	is scalar @customers_pair, 2, 'next(n) works good';
}

my $f = Customer->objects->find({ first_name => 'Bob' });



ok my $Bob = Customer->objects->find({ first_name => 'Bob' })->fetch, 'find Bob';

isa_ok $Bob, 'Customer';

is $Bob->first_name, 'Bob', 'Bob has a right name';
is $Bob->second_name, 'Dylan';
ok !$Bob->age;

ok my $John = Customer->objects->get(2), 'get John';
is $John->first_name, 'John';

ok my $Bill = Customer->objects->find('second_name = ?', 'Clinton')->fetch, 'find Bill';
is $Bill->first_name, 'Bill';

ok my @customers = Customer->objects->get([1, 2, 3]), 'get customers with #1,2,3';
is scalar @customers, 3;
is $customers[0]->first_name, 'Bob';
is $customers[1]->first_name, 'John';
is $customers[2]->first_name, 'Bill';

eval { Customer->objects->get(1)->fetch };
ok $@, 'fetch after get causes die';

ok my $cnt = Customer->objects->find->count, 'count';
is $cnt, 6;

ok my $exists = Customer->objects->find({ first_name => 'Bob' })->exists, 'exists';

ok(!Customer->objects->find({ first_name => 'Not Found' })->exists);
is(Customer->objects->find({ first_name => 'Not Found' })->exists, undef);

ok my $first = Customer->objects->find->first, 'first';
is_deeply $first, $Bob;

ok my $last = Customer->objects->find->last, 'last';
is $last->id, 6;

ok my $customized = Customer->objects->find({ first_name => 'Bob' })->only('id')->fetch, 'only';
is $customized->id, 1;
ok !$customized->first_name;

ok my $customized2 = Customer->objects->find({ first_name => 'Bob' })->fields('id')->fetch, 'fields (alias to "only")';
is $customized2->id, 1;
ok !$customized2->first_name;

my $c = Customer->objects->find->only('first_name')->first;

$c = Customer->objects->find->only('id')->first;

ok $first = Customer->objects->find->only('id')->first, 'first->only';
is $first->id, 1;
ok !$first->first_name;

ok $last = Customer->objects->find->last, 'last';
is $last->id, 6;

ok my @list = Customer->objects->find->order_by('id')->desc->fetch, 'order_by, desc';
is $list[4]->id, 2;

undef @list;
ok @list = Customer->objects->find->order_by('id')->asc->fetch, 'order_by, asc';
is $list[4]->id, 5;

ok @list = Customer->objects->find->limit(2)->fetch, 'limit';
is scalar @list, 2;

ok @list = Customer->objects->find->order_by('id')->offset(2)->fetch, 'offset';
is $list[0]->id, 3;

is scalar @list, 4;

undef @list;

$Bill = Customer->objects->find({ first_name => 'Bill' });
ok $Bill->upload;

@list = Customer->objects->find->order_by('first_name')->desc->order_by('id')->asc->fetch;
is $list[0]->first_name, 'Lady', 'order_by does work';

undef @list;

@list = Customer->objects->find->group_by('first_name', 'age')->fetch;
is scalar @list, 5, 'group_by, got 4 objects';

my $count = Customer->objects->find->count;
is $count, 6, 'simple count, got 5';
undef $count;

$count = Customer->objects->find({ first_name => 'Bob' })->count;
is $count, 2, 'count, got 2 Bob\'s';
undef $count;

my @count = Customer->objects->find->group_by('first_name')->count;
is_deeply \@count, [{first_name => '', count => 1}, {first_name => 'Bill', count => 1}, {first_name => 'Bob', count => 2}, {first_name => 'John', count => 1}, {first_name => 'Lady', count => 1}];

@count = Customer->objects->find({ first_name => 'Bob' })->group_by('second_name')->count;
is_deeply \@count, [{second_name => 'Dylan', count => 1}, {second_name => 'Marley', count => 1}], 'count when find by first_name, group by second_name';

$Bill = Customer->objects->find(3)->fetch;
is_deeply $Bill->to_hash, {
	first_name => 'Bill',
	second_name => 'Clinton',
	age => 50,
	email => 'mynameisbill@gmail.com',
	id => 3,
	mixin => undef,
}, 'got undefined mixin in the hash';

$Bill = Customer->objects->find(3)->only('id', 'mixin')->fetch;
is_deeply $Bill->to_hash({ only_defined_fields => 1 }), { id => 3, mixin => 3 }, 'got defined mixin';

done_testing();
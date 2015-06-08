#!/usr/bin/perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../lib";

use DBI;


package Customer;

use parent 'ActiveRecord::Simple';


__PACKAGE__->table_name('customers');
__PACKAGE__->primary_key('id');
__PACKAGE__->columns(qw/id first_name second_name age email/);


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

	INSERT INTO `customers` (`id`, `first_name`, `second_name`, `age`, `email`)
	VALUES
		(1,'Bob','Dylan',NULL,'bob.dylan@aol.com'),
		(2,'John','Doe',77,'john@doe.com'),
		(3,'Bill','Clinton',50,'mynameisbill@gmail.com'),
		(4,'Bob','Marley',NULL,'bob.marley@forever.com'),
		(5,'','',NULL,'foo.bar@bazz.com');
};

my $_DATA_SQL = q{
	INSERT INTO `customers` (`id`, `first_name`, `second_name`, `age`, `email`)
	VALUES
		(1,'Bob','Dylan',NULL,'bob.dylan@aol.com'),
		(2,'John','Doe',77,'john@doe.com'),
		(3,'Bill','Clinton',50,'mynameisbill@gmail.com'),
		(4,'Bob','Marley',NULL,'bob.marley@forever.com'),
		(5,'','',NULL,'foo.bar@bazz.com');
};

$dbh->do($_INIT_SQL);
$dbh->do($_DATA_SQL);

use Test::More;

ok my $c = Customer->new, 'new';
isa_ok $c, 'Customer';
ok(Customer->dbh($dbh), 'set DBH');

ok my $Bob = Customer->find({ first_name => 'Bob' })->fetch, 'find Bob';
is $Bob->first_name, 'Bob', 'Bob has a right name';
is $Bob->second_name, 'Dylan';
ok !$Bob->age;

ok my $John = Customer->get(2), 'get John';
is $John->first_name, 'John';

ok my $Bill = Customer->find('second_name = ?', 'Clinton')->fetch, 'find Bill';
is $Bill->first_name, 'Bill';

ok my @customers = Customer->get([1, 2, 3]), 'get customers with #1,2,3';
is scalar @customers, 3;
is $customers[0]->first_name, 'Bob';
is $customers[1]->first_name, 'John';
is $customers[2]->first_name, 'Bill';

done_testing();

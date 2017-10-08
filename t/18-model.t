#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";


BEGIN {

	package Schema;

	use parent 'ActiveRecord::Simple';

	eval { require DBD::SQLite } or exit 0;

	__PACKAGE__->connect("dbi:SQLite:dbname=:memory:","","");



	my $_INIT_SQL_CUSTOMERS = q{

	CREATE TABLE `customer` (
  		`id` int AUTO_INCREMENT,
  		`first_name` varchar(200) NULL,
  		`second_name` varchar(200) NOT NULL,
  		`age` tinyint(2) NULL,
  		`email` varchar(200) NOT NULL,
  		PRIMARY KEY (`id`)
	);

};

	my $_DATA_SQL_CUSTOMERS = q{

	INSERT INTO `customer` (`id`, `first_name`, `second_name`, `age`, `email`)
	VALUES
		(1,'Bob','Dylan',NULL,'bob.dylan@aol.com'),
		(2,'John','Doe',77,'john@doe.com'),
		(3,'Bill','Clinton',50,'mynameisbill@gmail.com'),
		(4,'Bob','Marley',NULL,'bob.marley@forever.com'),
		(5,'','',NULL,'foo.bar@bazz.com');

	};

	Schema->dbh->do($_INIT_SQL_CUSTOMERS);
	Schema->dbh->do($_DATA_SQL_CUSTOMERS);

	my $_INIT_SQL_ORDERS = q{

	CREATE TABLE `order` (
		`id` int AUTO_INCREMENT,
		`title` varchar(200) NOT NULL,
		`amount` decimal(10,2) NOT NULL DEFAULT 0.0,
		`customer_id` int NOT NULL references `customers` (`id`),
		PRIMARY KEY (`id`)
	);

	};

	my $_DATA_SQL_ORDERS = q{

	INSERT INTO `order` (`id`, `title`, `amount`, `customer_id`)
	VALUES
		(1, 'The Order #1', 10.00, 1),
		(2, 'The Order #2', 5.66, 2),
		(3, 'The Order #3', 6.43, 3),
		(4, 'The Order #4', 2.20, 1),
		(5, 'The Order #5', 3.39, 4);

	};

	Schema->dbh->do($_INIT_SQL_ORDERS);
	Schema->dbh->do($_DATA_SQL_ORDERS);

	my $_INIT_SQL_ACHIEVEMENTS = q{

	CREATE TABLE `achievement` (
		`id` int AUTO_INCREMENT,
		`title` varchar(30) NOT NULL,
		PRIMARY KEY (`id`)
	);

	};

	my $_DATA_SQL_ACHEIVEMENTS = q{

	INSERT INTO `achievement` (`id`, `title`)
	VALUES
		(1, 'Bronze'),
		(2, 'Silver'),
		(3, 'Gold');

	};

	Schema->dbh->do($_INIT_SQL_ACHIEVEMENTS);
	Schema->dbh->do($_DATA_SQL_ACHEIVEMENTS);

	my $_INIT_SQL_CA = q{

	CREATE TABLE `customer_achievement` (
		`customer_id` int NOT NULL references customers (id),
		`achievement_id` int NOT NULL references achievements (id)
	);

	};

	my $_DATA_SQL_CA = q{

	INSERT INTO `customer_achievement` (`customer_id`, `achievement_id`)
	VALUES
		(1, 1),
		(1, 2),
		(2, 1),
		(2, 3),
		(3, 1),
		(3, 2),
		(3, 3);

	};

	Schema->dbh->do($_INIT_SQL_CA);
	Schema->dbh->do($_DATA_SQL_CA);

}



package Model;

use parent 'ActiveRecord::Simple::Model';


package Model::Customer;

our @ISA = qw/Model/;
use ActiveRecord::Simple::Field;

__PACKAGE__->setup(
	first_name  => char_field(max_length => 200),
	second_name => char_field(max_length => 200),
	age         => small_integer_field(error_messages => { null => 'Must be not null' }),
	email       => email_field(max_length => 200),
);

__PACKAGE__->has_many(achievements => 'Model::Achievement', { via => 'customer_achievement' });
__PACKAGE__->has_many(orders => 'Model::Order');


package Model::Order;
use ActiveRecord::Simple::Field;

our @ISA = qw/Model/;

#__PACKAGE__->setup();
__PACKAGE__->setup(
	title       => char_field(max_length => 200, 'db_column' => 'title'),
	amount      => decimal_field(max_digits => 10, default => '10', null => 1),
	customer_id => foreign_key(),
);

__PACKAGE__->strict_validation(1);
#__PACKAGE__->warn_validation(1);

__PACKAGE__->belongs_to(customer => 'Model::Customer');


package Model::Achievement;

our @ISA = qw/Model/;

__PACKAGE__->setup();

__PACKAGE__->has_many(customers => 'Model::Customer', { via => 'customer_achievement' });


package main;

use Test::More;
use Data::Dumper;


is(Model::Customer->_get_table_name, 'customer', 'table_name is ok');
is_deeply(Model::Customer->_get_columns, ['id', 'first_name', 'second_name', 'age', 'email'], 'columns is ok');
is_deeply(Model::Order->_get_columns, ['id', 'title', 'amount', 'customer_id']);
is(Model::Customer->_get_primary_key, 'id', 'primary_key is ok');

ok my $order = Model::Order->new(), 'new is ok';
isa_ok $order, 'Model::Order';
ok $order->amount, 'default amount value set';
is $order->amount, '10.00', 'default amount value is valid';

$order->amount(20);
is $order->amount, '20.00', 'order amount was rounded to 20.00 from 20';
$order->amount('');
is $order->amount, undef, 'order amount was converted to undef from ""';


ok my $order2 = Model::Order->get(1);
is $order2->title, 'The Order #1', 'order title ok';
is $order2->id, 1, 'order id ok';
is $order2->customer->first_name, 'Bob', 'order has a customer';

ok my $achievement = Model::Achievement->new(title => 'test'), 'setup with no params';
is $achievement->title, 'test';
is ref $achievement->_meta_->schema, 'HASH';
ok $achievement->_meta_->schema->{id};
ok $achievement->_meta_->schema->{title};
is $achievement->_meta_->primary_key_name, 'id', 'primary_key_name = id';
is $achievement->_meta_->table_name, 'achievement';

ok $order2->save, 'save';

#$order2->title(undef);
#my ($res, $errors) = $order2->title(undef)->save;
#is ref $errors->{title}, 'ARRAY';
#is $errors->{title}[0], 'NULL';

#my $customer = Model::Customer->new();
#($res, $errors) = $customer->age(undef)->save;
#is $errors->{age}[0], 'Must be not null';
#
#ok $customer->age(''), "set age to ''";
#ok ! defined $customer->age, 'age is undef';


#is $order->_meta_->table_name, 'order';
#is $order->_meta_->primary_key_name, 'id';

#ok my $a1 = Model::Achievement->new(title => 'new achievement')->save;
#my $b = Model::Achievement->find({ title => 'new achievement' })->fetch;
#ok $b, 'find saved value';

done_testing();

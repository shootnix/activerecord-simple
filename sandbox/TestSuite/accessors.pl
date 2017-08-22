#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

package AccessorTestOne;

use base 'Class::Accessor::Fast::XS';

#AccessorTestOne->follow_best_practice;
AccessorTestOne->mk_accessors(qw/id name/);



package AccessorTestTwo;

use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('table_name');
__PACKAGE__->columns(['id', 'name']);


package main;

use App::Benchmark;
use Data::Dumper;


my $one = AccessorTestOne->new({id => 1, name => 'Alex'});
my $two = AccessorTestTwo->new({id => 1, name => 'Alex'});

#say Dumper $one->name;
#say Dumper $two->name;

benchmark_diag(10_000_000, {
	class_accessor_fast_new => sub {
		AccessorTestOne->new({id => 1, name => 'Alex'});
	},
	ars_new => sub {
		AccessorTestTwo->new({id => 1, name => 'Alex'});
	},
	class_accessor_fast_get => sub {
		$one->id;
	},
	ars_get => sub {
		$two->id;
	},
	class_accessor_fast_set => sub {
		$one->id(2);
		die unless $one->id == 2;
	},
	ars_set => sub {
		$two->id(2);
		die unless $two->id == 2;
	}
});

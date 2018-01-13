#!/usr/bin/env perl

package User;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use parent 'ActiveRecord::Simple';

__PACKAGE__->table_name('user');
__PACKAGE__->columns('id', 'name');
__PACKAGE__->primary_key('id');


package main;

use 5.010;

use Test::More;
use Data::Dumper;

*{'ActiveRecord::Simple::Find::fetch'} = sub {
	return shift;
};


ok my $qm = User->objects;
isa_ok $qm->{caller}, 'User';
ok my $f = User->objects->all();

is $f->{class}, 'User';

ok $f = User->objects->get(1);
ok exists $f->{prep_select_where};
ok $f = User->objects->find({ foo => 'bar' });

ok exists $f->{prep_select_where};
is shift @{ $f->{prep_select_where} }, '"user"."foo" = ?';

#say Dumper $f;


done_testing();


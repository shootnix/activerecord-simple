#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use 5.010;

use FindBin '$Bin';
use lib "$Bin/../lib";

package t::class;

use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('t');
__PACKAGE__->columns(['foo', 'bar']);
__PACKAGE__->primary_key('foo');

1;

package t::class2;

use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('t');
__PACKAGE__->columns(['foo', 'bar']);
__PACKAGE__->primary_key('foo');

__PACKAGE__->use_smart_saving;

1;

package MockDBI;

sub selectrow_array { 1 }
sub do { 1 }
sub selectrow_hashref { { DUMMY => 'hash' } }
sub prepare { bless {}, 'MockDBI' }
sub execute { 1 }
sub last_insert_id { 1 }
sub selectall_arrayref { [{ foo => 1  }, { bar => 2 }] }

1;

*ActiveRecord::Simple::dbh = sub {
    return bless { Driver => { Name => 'mysql' } }, 'MockDBI';
};

package main;

use Test::More;
use Data::Dumper;

ok my $c = t::class->new({
    foo => 1,
    bar => 2,
});

ok $c->save(), 'save';
ok $c->foo(100);
is $c->foo, 100, 'update in memory ok';
ok $c->save(), 'update in database ok';

ok my $c2 = t::class->find(1), 'find, primary key';
isa_ok $c2, 't::class';

ok my $c3 = t::class->find({ foo => 'bar' }), 'find, params';
isa_ok $c3, 't::class';

ok my $c4 = t::class->find([1, 2, 3]), 'find, primary keys';
isa_ok $c4, 't::class';

ok my @fetched = $c4->fetch(), 'fetch';
is scalar @fetched, 2;
isa_ok $fetched[0], 't::class';
is $fetched[0]->foo, 1;


ok my $c5 = t::class->find('foo = ?', 'bar'), 'find, binded params';
isa_ok $c5, 't::class';

ok my $all = t::class->get_all(), 'get_all';
is ref $all, 'ARRAY';
is ref $all->[0], 'HASH';

is ref $c->to_hash, 'HASH', 'to_hash';
ok $c->smart_saving_used == 0, 'no use smart saving';

my $t2 = t::class2->find(1);
ok $t2->smart_saving_used == 1, 'smart_saving_used, on founded';

my $t22 = t::class2->new({ foo => 1 });
ok $t22->smart_saving_used == 1, 'smart_saving_used, on created';

ok $c->delete(), 'delete';

done_testing();
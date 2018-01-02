package Manager;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use parent 'ActiveRecord::Simple';


__PACKAGE__->table_name('manager');
__PACKAGE__->columns('id', 'name');
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => 'Artist');


1;



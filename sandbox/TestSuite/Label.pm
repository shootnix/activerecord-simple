package Label;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('label');
__PACKAGE__->columns('id', 'name');
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => 'Artist');
__PACKAGE__->has_many(cds => 'CD');

1;
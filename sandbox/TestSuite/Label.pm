package Label;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('label');
__PACKAGE__->columns(['id', 'name']);
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => 'Artist', 'label_id');
__PACKAGE__->belongs_to(cd => 'CD', 'label_id');

1;
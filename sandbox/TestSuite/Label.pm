package Label;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('label');
__PACKAGE__->columns(['id', 'name']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
    artists => {
        class => 'Artist',
        type  => 'many',
        key   => 'label_id'
    },
    cd => {
        class => 'CD',
        type  => 'one',
        key   => 'label_id',
    },
});

1;
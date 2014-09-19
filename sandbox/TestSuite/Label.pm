package Label;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('label');
#__PACKAGE__->columns(['id', 'name']);
__PACKAGE__->fields(
    id => {
        data_type => 'int',
        is_auto_increment => 1,
        is_primary_key => 1,
    },
    name => {
        data_type => 'varchar',
        size => 64
    },
);
__PACKAGE__->primary_key('id');

#__PACKAGE__->has_many(artists => 'Artist', { fk => 'label_id', pk => 'id' });
__PACKAGE__->has_many(artists => 'Artist');
#__PACKAGE__->belongs_to(cd => 'CD', 'label_id');

1;
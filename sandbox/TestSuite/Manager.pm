package Manager;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use parent 'ActiveRecord::Simple';


#__PACKAGE__->auto_load;


__PACKAGE__->table_name('managers');
__PACKAGE__->columns(
    id => {
        data_type => 'int',
        is_auto_increment => 1,
        is_primary_key => 1,
        is_nullable => 0,
    },
    name => {
        data_type => 'varchar',
        size => 63,
        is_nullable => 0,
        default_value => undef
    },
);
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => 'Artist');
__PACKAGE__->auto_save;




1;



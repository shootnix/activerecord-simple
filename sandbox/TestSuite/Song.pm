package Song;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('song');
__PACKAGE__->fields(
    id => {
        data_type => 'int',
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    title => {
        data_type => 'varchar',
        size => 64,
        is_nullable => 0,
    }
);
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(albums => {'CDSong' => 'CD'});

1;
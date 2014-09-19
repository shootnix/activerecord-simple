package CD;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cd');
__PACKAGE__->fields(
    id => {
        data_type => 'int',
        is_auto_increment => 1,
        is_primary_key => 1,
    },
    title => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 64,
    },
    release => {
        data_type => 'int',
        is_nullable => 0,
    },
    label_id => {
        data_type => 'int',
        is_foreign_key => 1,
        is_nullable => 0
    },
);
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => { 'ArtistCD' => 'Artist' });
__PACKAGE__->has_many(songs => { 'CDSong' => 'Song' });
__PACKAGE__->belongs_to(label => 'Label');

#__PACKAGE__->use_smart_saving();

1;
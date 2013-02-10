package CD;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cd');
__PACKAGE__->columns(['id', 'title', 'release', 'label_id']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
    artists => {
        class => { 'ArtistCD' => 'Artist' },
        type  => 'many',
    },
    label => {
        class => 'Label',
        type => 'one',
        key => 'label_id',
    },
    songs => {
        class => { CDSong => 'Song' },
        type  => 'many',
    }
});

1;
package Artist;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('artist');
__PACKAGE__->columns(['id', 'name', 'label_id']);
__PACKAGE__->primary_key('id');
#__PACKAGE__->columns_details({
#    id => ''
#});

__PACKAGE__->relations({
    label => {
        class => 'Label',
        type  => 'one',
        key   => 'label_id',
    },
    rating => {
        class => 'Rating',
        type => 'one',
        key => 'artist_id',
    },
    albums => {
        class => { ArtistCD => 'CD' },
        type  => 'many',
    }
});

__PACKAGE__->use_smart_saving;

1;
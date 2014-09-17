package Artist;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use parent 'ActiveRecord::Simple';

__PACKAGE__->table_name('artist');
__PACKAGE__->fields(
    id => {
        data_type => 'int',
        is_auto_increment => 1,
        is_primary_key => 1,
        is_nullable => 0,
    },
    name => {
        data_type => 'varchar',
        size => 64,
        is_nullable => 0,
    },
    label_id => {
        data_type => 'int',
        size => 100,
        is_nullable => 0,
        is_foreign_key => 1,
    }
);
__PACKAGE__->primary_key('id');
__PACKAGE__->index('index_artist_id', ['id']);


__PACKAGE__->belongs_to(label => 'Label', 'label_id');
__PACKAGE__->belongs_to(rating => 'Rating', 'artist_id');
__PACKAGE__->has_many(albums => { ArtistCD => 'CD' });
__PACKAGE__->generic(cvs => 'Cvs', { name => 'artist_name' });

__PACKAGE__->use_smart_saving;

1;
package Artist;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('artist');
__PACKAGE__->columns(['id', 'name', 'label_id']);
__PACKAGE__->primary_key('id');

__PACKAGE__->belongs_to(label => 'Label', 'label_id');
__PACKAGE__->belongs_to(rating => 'Rating', 'artist_id');
__PACKAGE__->has_many(albums => { ArtistCD => 'CD' });
__PACKAGE__->generic(cvs => 'Cvs', { name => 'artist_name' });


__PACKAGE__->use_smart_saving;

1;
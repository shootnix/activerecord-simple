package CD;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cd');
__PACKAGE__->columns(['id', 'title', 'release', 'label_id']);
__PACKAGE__->primary_key('id');

__PACKAGE__->has_many(artists => { 'ArtistCD' => 'Artist' });
__PACKAGE__->has_many(songs => { 'CDSong' => 'Song' });
__PACKAGE__->belongs_to(label => 'Label', 'label_id');

#__PACKAGE__->use_smart_saving();

1;
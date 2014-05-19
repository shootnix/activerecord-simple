package ArtistCD;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('artist_cd');
__PACKAGE__->columns(['artist_id', 'cd_id']);

__PACKAGE__->belongs_to(artist => 'Artist', 'artist_id');
__PACKAGE__->belongs_to(cd => 'CD', 'cd_id');


#__PACKAGE__->check_before_update(1);

1;
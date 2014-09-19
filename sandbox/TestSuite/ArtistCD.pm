package ArtistCD;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('artist_cd');
__PACKAGE__->fields(
    artist_id => {
        data_type   => 'int',
        is_nullable => 0,
    },
    cd_id => {
        data_type   => 'int',
        is_nullable => 0,
    },
);

__PACKAGE__->belongs_to(artist => 'Artist');
__PACKAGE__->belongs_to(cd => 'CD');


#__PACKAGE__->check_before_update(1);

1;
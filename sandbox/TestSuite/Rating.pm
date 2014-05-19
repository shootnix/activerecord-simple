package Rating;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('rating');
__PACKAGE__->columns(['range', 'artist_id']);

__PACKAGE__->belongs_to(artist => 'Artist', 'artist_id');

sub insert { __PACKAGE__->new($_[1])->save() }

1;
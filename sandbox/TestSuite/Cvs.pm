package Cvs;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cvs');
__PACKAGE__->columns(['id', 'artist_name', 'n_grammies', 'n_platinums', 'n_golds']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
    artist => {
        class => 'Artist',
        type => 'generic',
        find => {
            artist_name => 'name'
        }
    },
});

1;

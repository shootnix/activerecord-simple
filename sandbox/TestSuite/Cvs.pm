package Cvs;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cvs');
__PACKAGE__->fields(
    id => {
        data_type => 'int',
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    artist_name => {
        data_type => 'varchar',
        size => 64,
    },
    n_grammies => {
        data_type => 'int',
        is_nullable => 1,
    },
    n_platinums => {
        data_type => 'int',
        is_nullable => 1,
    },
    n_golds => {
        data_type => 'int',
        is_nullable => 1
    },
);
__PACKAGE__->primary_key('id');

__PACKAGE__->generic(artist => 'Artist', { artist_name => 'name' });


1;

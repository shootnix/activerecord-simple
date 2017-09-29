package Artist;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use parent 'ActiveRecord::Simple';


#__PACKAGE__->auto_load;

__PACKAGE__->table_name('artists');
__PACKAGE__->columns(
    id => {
        data_type => 'int',
        is_auto_increment => 1,
        is_primary_key => 1,
        is_nullable => 0,
    },
    name => {
        data_type => 'varchar',
        size => 63,
        is_nullable => 0,
        default_value => undef
    },
    label_id => {
        data_type => 'int',
        size => 100,
        is_foreign_key => 1,
    },
    manager_id => {
        data_type => 'int',
        size => 100,
        is_foreign_key => 1,
    },

);
__PACKAGE__->primary_key('id');
__PACKAGE__->index('index_artist_id', ['id']);

__PACKAGE__->belongs_to(label => 'Label');
__PACKAGE__->belongs_to(manager => 'Manager');
__PACKAGE__->has_one(rating => 'Rating');
__PACKAGE__->has_many(albums => 'CD');
__PACKAGE__->generic(cvs => 'Cvs', { name => 'artist_name' });

#__PACKAGE__->auto_save;

__PACKAGE__->mixins(
    mysum => sub {

        return 'SUM(id)';
    }
);

1;
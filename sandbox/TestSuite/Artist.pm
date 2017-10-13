package Artist;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use parent 'ActiveRecord::Simple';


#__PACKAGE__->auto_load;

__PACKAGE__->table_name('artists');
__PACKAGE__->columns('id', 'name', 'label_id', 'manager_id');
__PACKAGE__->primary_key('id');

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
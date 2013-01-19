package Person;

use lib '../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('persons');
__PACKAGE__->columns([qw/id_person first_name second_name/]);
__PACKAGE__->primary_key('id_person');

__PACKAGE__->relations({
    cars => {
        type        => 'many',
        class       => 'Car',
        foreign_key => 'id_person',
    }
});

1;
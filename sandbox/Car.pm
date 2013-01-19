package Car;

use strict;
use warnings;

use lib '../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cars');
__PACKAGE__->columns([qw/id_car model year color id id_person/]);
__PACKAGE__->primary_key('id_car');

1;
package ActiveRecord::Simple::Model;

use strict;
use warnings;
use 5.010;

use parent 'ActiveRecord::Simple';
use ActiveRecord::Simple::Model::Field;

use Data::Dumper;


our $VERSION = '0.01';

#


sub setup {
	my ($class, $fields) = @_;


}

sub field { 'ActiveRecord::Simple::Model::Field' }


1;
package ActiveRecord::Simple::Meta;

use strict;
use warnings;
use 5.010;


sub new {
	my ($class, $params) = @_;

	return bless $params, $class;
}

sub table_name { shift->{table_name} }
sub primary_key_name { shift->{primary_key_name} }
sub primary_key_value { shift->{primary_key_value} }
sub columns_list { shift->{columns_list} }
sub relations { shift->{relations} }
#sub auto_loaded { shift->{auto_loaded} }
sub schema { shift->{schema} }

1;

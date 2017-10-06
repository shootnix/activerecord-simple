package ActiveRecord::Simple::Meta;

use strict;
use warnings;
use Scalar::Util qw/blessed/;
use Carp qw/croak carp/;


sub new {
	my ($class, $params) = @_;

	return bless $params, $class;
}

sub table_name { shift->{table_name} }
sub primary_key_name { shift->{primary_key_name} }

sub columns_list { shift->{columns_list} }
sub relations { shift->{relations} }
sub schema { shift->{schema} }

sub verbose_name {
	my ($self, $verbose_name) = @_;

	if ($verbose_name) {
		$self->{verbose_name} = $verbose_name;
	}

	return $self->{verbose_name};
}

sub verbose_name_plural {
	my ($self, $verbose_name_plural) = @_;

	if ($verbose_name_plural) {
		$self->{verbose_name_plural} = $verbose_name_plural;
	}

	return $self->{verbose_name_plural} || $self->verbose_name . 's';
}

sub ordering {
	my ($self, @ordering) = @_;

	if (@ordering) {
		$self->{ordering} = \@ordering;
	}

	return $self->{ordering} || [$self->primary_key_name];
}

1;

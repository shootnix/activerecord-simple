package ActiveRecord::Simple::Validate;

use strict;
use warnings;

use 5.010;

require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('check');

our %ERROR_MESSAGES = (
    null    => 'NULL',
    blank   => 'BLANK',
    invalid => 'INVALID',
);

our @VALIDATORS = (
    'null',    \&_check_null,
    'blank',   \&_check_blank,
    'invalid', \&_check_invalid,
);


sub new {
    my ($class, %params) = @_;

    my $self = {
        error_messages => $params{error_messages} || \%ERROR_MESSAGES,
    };

    return bless $self, $class;
}

sub error_messages {
    my ($self, $messages) = @_;

    if ($messages) {
        $self->{error_messages} = $messages;
    }

    return $self->{error_messages}
}

sub validators {
    my ($self, $validators) = @_;

    push @VALIDATORS, @$validators if $validators;

    return @VALIDATORS;
}

sub check_errors {
	my ($self, $fld, $val) = @_;

    my @error_messages;
    VALIDATOR:
    for my $validator (@{ $fld->{extra}{validators} }) {
        if ($validator eq 'null') {
            if ($fld->{is_nullable} == 0 && !defined $val) {
                push @error_messages, $self->error_messages->{null};
            }
        }
        elsif ($validator eq 'blank') {
            next VALIDATOR if !defined $val;
            if ($fld->{extra}{is_blank} == 0 && $val eq q//) {
                push @error_messages, $self->error_messages->{blank};
            }
        }
        elsif ($validator eq 'invalid') {
            next VALIDATOR if !defined $val;
            if (!_check_for_data_type($val, $fld->{data_type}, $fld->{size})) {
                push @error_messages, $self->error_messages->{invalid};
            }
        }
        else {

        }
    }

    return \@error_messages;
}

sub _check_for_data_type {
    my ($val, $data_type, $size) = @_;

    return 1 unless $data_type;

    my %TYPE_CHECKS = (
        int      => \&_check_int,
        integer  => \&_check_int,
        tinyint  => \&_check_int,
        smallint => \&_check_int,
        bigint   => \&_check_int,

        double => \&_check_numeric,
       'double precision' => \&_check_numeric,

        decimal => \&_check_numeric,
        dec => \&_check_numeric,
        numeric => \&_check_numeric,

        real => \&_check_float,
        float => \&_check_float,

        bit => \&_check_bit,

        date => \&_check_DUMMY, # DUMMY
        datetime => \&_check_DUMMY, # DUMMY
        timestamp => \&_check_DUMMY, # DUMMY
        time => \&_check_DUMMY, # DUMMY

        char => \&_check_char,
        varchar => \&_check_varchar,

        binary => \&_check_DUMMY, # DUMMY
        varbinary => \&_check_DUMMY, # DUMMY
        tinyblob => \&_check_DUMMY, # DUMMY
        blob => \&_check_DUMMY, # DUMMY
        text => \&_check_DUMMY,
    );

    return (exists $TYPE_CHECKS{$data_type}) ? $TYPE_CHECKS{$data_type}->($val, $size) : 1;
}

sub _check_DUMMY { 1 }
sub _check_int {
    my ($int) = @_;
    no warnings 'numeric';
    return 0 unless ($int eq int($int));
    return 1;
}
sub _check_varchar {
    my ($val, $size) = @_;

    return length $val <= $size->[0];
}
sub _check_char {
    my ($val, $size) = @_;

    return length $val == $size->[0];
}
sub _check_float { shift =~ /^\d+\.\d+$/ }

sub _check_numeric {
    my ($val, $size) = @_;

    return 1 unless
        defined $size &&
        ref $size eq 'ARRAY' &&
        scalar @$size == 2;

    return 1 if $val =~ /^\d+$/;

    my ($first, $last) = $val =~ /^(\d+)\.(\d+)$/;

    $first && length $first <= $size->[0] or return;
    $last && length $last <= $size->[1] or return;

    return 1;
}

sub _check_bit {
    my ($val) = @_;

    return ($val == 0 || $val == 1) ? 1 : undef;
}


1;

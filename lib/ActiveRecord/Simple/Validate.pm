package ActiveRecord::Simple::Validate;

use strict;
use warnings;

use 5.010;

require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('check_errors');

our %ERROR_MESSAGES = (
    null    => 'NULL',
    blank   => 'BLANK',
    invalid => 'INVALID',
);

use List::Util qw/any/;
use Carp qw/carp croak/;
use Time::Local;


sub check_errors {
	my ($fld, $val) = @_;

    my $validators = $fld->{extra}{validators} or return;
    ref $validators eq 'ARRAY' or return;
    scalar @$validators > 0 or return;

    my $error_messages = $fld->{extra}{error_messages} || {};
    my @error_messages;

    VALIDATOR:
    for my $validator (@$validators) {
        if ($validator eq 'null') {
            if ($fld->{is_nullable} == 0 && ! defined $val) {
                push @error_messages, $error_messages->{null} || $ERROR_MESSAGES{null};
            }
        }
        elsif ($validator eq 'blank') {
            next VALIDATOR if !defined $val;
            if ($fld->{extra}{is_blank} == 0 && $val eq q//) {
                push @error_messages, $error_messages->{blank} || $ERROR_MESSAGES{blank};
            }
        }
        elsif ($validator eq 'invalid') {
            next VALIDATOR if !defined $val;
            if (!_check_for_data_type($val, $fld->{data_type}, $fld->{size})) {
                push @error_messages, $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
        elsif ($validator eq 'boolean') {
            next VALIDATOR if !defined $val;
            if (!_check_boolean($val)) {
                push @error_messages, $error_messages->{boolean} || $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
        elsif ($validator eq 'email') {
            next VALIDATOR if !defined $val;
            if (!_check_email($val)) {
                push @error_messages, $error_messages->{email} || $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
        elsif ($validator eq 'ip') {
            next VALIDATOR if !defined $val;
            if (!_check_ip($val)) {
                push @error_messages, $error_messages->{ip} || $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
        elsif ($validator eq 'ipv6') {
            next VALIDATOR if !defined $val;
            if (!_check_ipv6($val)) {
                push @error_messages, $error_messages->{ipv6} || $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
        elsif ($validator eq 'positive') {
            next VALIDATOR if !defined $val;
            if (!_check_positive($val)) {
                push @error_messages, $error_messages->{positive} || $error_messages->{invalid} || $ERROR_MESSAGES{invalid};
            }
        }
    }

    return @error_messages ? \@error_messages : undef;
}

sub _check_positive {
    my ($val) = @_;

    return $val > 0;
}

sub _check_ip {
    my ($ip) = @_;

    return $ip =~ /^\d+\.\d+\.\d+\.\d+$/;
}

sub _check_ipv6 {
    my ($ipv6) = @_;

    my $IPv4 = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))";
    my $G = "[0-9a-fA-F]{1,4}";

    my @tail = ( ":",
         "(:($G)?|$IPv4)",
             ":($IPv4|$G(:$G)?|)",
             "(:$IPv4|:$G(:$IPv4|(:$G){0,2})|:)",
         "((:$G){0,2}(:$IPv4|(:$G){1,2})|:)",
         "((:$G){0,3}(:$IPv4|(:$G){1,2})|:)",
         "((:$G){0,4}(:$IPv4|(:$G){1,2})|:)" );

    my $IPv6_re = $G;
    $IPv6_re = "$G:($IPv6_re|$_)" for @tail;
    $IPv6_re = qq/:(:$G){0,5}((:$G){1,2}|:$IPv4)|$IPv6_re/;
    $IPv6_re =~ s/\(/(?:/g;
    $IPv6_re = qr/$IPv6_re/;

    return $ipv6 =~ $IPv6_re;
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

        date => \&_check_date,
        datetime => \&_check_datetime,
        timestamp => \&_check_int, # DUMMY
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

sub _check_date {
    my ($date) = @_;

    my ($y, $m, $d) = $date =~ m/^(\d{4})-(\d\d)-(\d\d)$/;
    return unless $y && $m && $d;
    eval { timelocal(0, 0, 0, $d, $m-1, $y); } or return;

    return 1;
}

sub _check_email {
    my ($email) = @_;

    return $email =~ /.+@.+/;
}

sub _check_datetime {
    my ($date) = @_;

    my ($y, $m, $d, $h, $min, $s) = $date =~ m/^(\d{4})-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)$/;
    return unless $y && $m && $d && $h && $min && $s;
    eval { timelocal($s, $min, $h, $d, $m-1, $y) } or return;

    return 1;
}

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

    return 1 if _check_int($val);

    my ($first, $last) = $val =~ /^(\d+)\.(\d+)$/;

    return unless $first && $last;
    return unless _check_int($first);

    $first && length $first <= $size->[0] or return;
    $last && length $last <= $size->[1] or return;

    return 1;
}

sub _check_bit {
    my ($val) = @_;

    return unless _check_int($val);

    return ($val == 0 || $val == 1) ? 1 : undef;
}

sub _check_boolean { _check_bit(@_) }


1;

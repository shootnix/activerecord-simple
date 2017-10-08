package ActiveRecord::Simple::Validate;

use strict;
use warnings;

use 5.010;

require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('check_errors', 'error_messages');

our %ERROR_MESSAGES = (
    null    => 'NULL',
    blank   => 'BLANK',
    invalid => 'INVALID',
);

my $NULL = 'NULL';

use Carp qw/carp croak/;
use Time::Local;


sub check_errors {
	my ($fld, $val) = @_;

    my $error_messages = $fld->{extra}{error_messages} || {};

    if ($fld->{extra}{choices}) {
        # checks booleans and null_booleans too
        #return _error_message_for('invalid', $error_messages)
        #    if ! _exists_in_choices($val, $fld->{extra}{choices});
        return _exists_in_choices($val, $fld->{extra}{choices}) ? undef : _error_message_for('invalid', $error_messages);
    }

    # 1. is null
    return _error_message_for('null', $error_messages)
        if exists $fld->{is_nullable} && $fld->{is_nullable} == 0 && ! defined $val;
    return unless defined $val;

    # 2. blank
    if (exists $fld->{extra}{is_blank} && $fld->{extra}{is_blank} == 0) {
        return _error_message_for('blank', $error_messages)
            if $val eq q//;
    }
    return if exists $fld->{extra}{is_blank} && $fld->{extra}{is_blank} == 1 && $val eq q//;

    # 3. kind
    my $fld_kind = $fld->{extra}{kind} or return;
    if (_is_integer($fld_kind)) {
        return _error_message_for('integer', $error_messages)
            if ! _check_int($val);
    }
    elsif (_is_positive_integer($fld_kind)) {
        return _error_message_for('integer', $error_messages)
            if ! _check_int($val);

        return _error_message_for('positive', $error_messages)
            if $val < 0;
    }
    elsif ($fld_kind eq 'char') {
        return _error_message_for('char', $error_messages)
            if ! _check_varchar($val, $fld->{size});
    }
    elsif ($fld_kind eq 'date') {
        return _error_message_for('date', $error_messages)
            if ! _check_date($val);
    }
    elsif ($fld_kind eq 'date_time') {
        return _error_message_for('date_time', $error_messages)
            if ! _check_datetime($val);
    }
    elsif ($fld_kind eq 'decimal') {
        return _error_message_for('decimal', $error_messages)
            if ! _check_decimal($val, $fld->{size});
    }
    elsif ($fld_kind eq 'email') {
        return _error_message_for('char', $error_messages)
            if ! _check_varchar($val, $fld->{size});

        return _error_message_for('email', $error_messages)
            if ! _check_email($val);
    }
    elsif ($fld_kind eq 'generic_ip_address') {
        return _error_message_for('char', $error_messages)
            if ! _check_varchar($val, $fld->{size});

        return _error_message_for('generic_ip_address', $error_messages)
            if ! _check_ip($val);
    }
    elsif ($fld_kind eq 'generic_ipv6_address') {
        return _error_message_for('char', $error_messages)
            if ! _check_varchar($val, $fld->{size});

        return _error_message_for('ipv6', $error_messages)
            if ! _check_ipv6($val);
    }

    return undef;
}

sub error_messages {
    my ($error) = @_;

    return unless $error;
    return unless exists $ERROR_MESSAGES{$error};

    return $ERROR_MESSAGES{$error}
}

sub _exists_in_choices {
    my ($a, $choices) = @_;

    $a //= $NULL;

    my $matched = 0;
    for my $choice (@$choices) {
        if (ref $choice && ref $choice eq 'ARRAY') {
            my $b = $choice->[0] // $NULL;
            $matched += 1 if $a eq $b;
        }
        else {
            $choice //= $NULL;
            $matched += 1 if $a eq $choice;
        }
    }

    return $matched;
}

sub _is_integer {
    my ($kind) = @_;

    return grep { $kind eq $_ } qw/big_integer tinyint integer small_integer/;
}

sub _is_positive_integer {
    my ($kind) = @_;

    return grep { $kind eq $_ } qw/auto big_auto time foreign_key positive_small_integer boolean null_boolean positive_integer/;
}

sub _error_message_for {
    my ($kind, $error_messages) = @_;

    return $error_messages->{$kind} || $ERROR_MESSAGES{$kind} || $error_messages->{'invalid'} || $ERROR_MESSAGES{'invalid'};
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
    return unless ($int eq int($int));
    return 1;
}

sub _check_varchar {
    my ($val, $size) = @_;

    return 1 unless
        defined $size &&
        ref $size eq 'ARRAY' &&
        scalar @$size == 2;

    return unless defined $val;
    return 1 if $val eq q//;
    return 1 unless $size;

    return length $val <= $size->[0];
}

sub _check_decimal {
    my ($val, $size) = @_;

    #warn "val = $val";

    return 1 unless
        defined $size &&
        ref $size eq 'ARRAY' &&
        scalar @$size == 2;

    #warn "1 check";

    return 1 if _check_int($val);

    my ($first, $last) = $val =~ /^(\d+)\.(\d+)$/;

    return unless defined $first && defined $last;
    return unless _check_int($first);

    length($first . $last) <= $size->[0] or return;
    length $last <= $size->[1] or return;

    return 1;
}

1;

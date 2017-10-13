package ActiveRecord::Simple::Utils;

use strict;
use warnings;

require Exporter;

our @ISA = qw/Exporter/;
our @EXPORT = qw/class_to_table_name/;


sub quote_sql_stmt {
    my ($sql, $driver_name) = @_;

    return unless $sql && $driver_name;

    $driver_name //= 'Pg';
    my $quotes_map = {
        Pg => q/"/,
        mysql => q/`/,
        SQLite => q/`/,
    };
    my $quote = $quotes_map->{$driver_name};

    $sql =~ s/"/$quote/g;

    return $sql;
}

sub class_to_table_name {
    my ($class_name) = @_;

    $class_name =~ s/.*:://;
    #$class_name = lc $class_name;
    my $table_name = join('_', map {lc} grep {length} split /([A-Z]{1}[^A-Z]*)/, $class_name);

    return $table_name;
}

sub is_integer {
    my ($data_type) = @_;

    return unless $data_type;

    return grep { $data_type eq $_ } qw/integer bigint tinyint int smallint/;
}

sub is_numeric {
    my ($data_type) = @_;

    return unless $data_type;
    return 1 if is_integer($data_type);

    return grep { $data_type eq $_ } qw/numeric decimal/;
}

1;
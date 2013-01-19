#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Person;
use Car;
use DBI;

#my $dbh = DBI->connect("dbi:SQLite:test.db", "", "")
#    or die DBI->errstr;

my $dbh;

sub my_db_handler {
    unless ($dbh && $dbh->ping) {
        $dbh = DBI->connect("dbi:SQLite:test.db", "", "");
    }

    return $dbh;
}

ActiveRecord::Simple->dbh(&my_db_handler);
#Person->dbh(&my_db_handler);

my $person = Person->new({
    first_name  => 'Foo',
    second_name => 'Bar'
});
$person->save();

say $person->first_name;
say $person->second_name;

say "Person exists" if $person->is_exists_in_database;

say '---';

my $car = Car->new({
    model     => 'bmw',
    year      => 2012,
    color     => 'red',
    id        => 'P345XZD',
    id_person => $person->id_person
});
$car->save();

while ( my $persons_car = $person->cars->fetch() ) {
    say $persons_car->model;
    say $persons_car->year;
    say $persons_car->id;
    say 'Car exists' if $persons_car->is_exists_in_database;
    say '---';
}
#say $person->cars->fetch()->model;

$car->delete;
$person->delete;

say 'person doesnt exist' unless $person->is_exists_in_database;
say 'car doesnt exists' unless $car->is_exists_in_database;

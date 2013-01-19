create table persons (
    id_person    integer primary key autoincrement not null,
    first_name   varchar(64),
    second_name  varchar(64)
);

create table cars (
    id_car     integer primary key autoincrement not null,
    model      varchar(64),
    year       integer,
    color      varchar(24),
    id         varchar(12),
    id_person  integer not null references persons (id_person) on delete cascade
);
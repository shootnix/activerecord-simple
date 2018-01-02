drop table if exists artist;
drop table if exists cd;
drop table if exists song;
drop table if exists artist_cd;
drop table if exists cd_song;
drop table if exists label;
drop table if exists rating;

create table artist (
    id         integer primary key autoincrement not null,
    name       varchar(255),
    label_id   integer references id (label) on delete cascade,
    manager_id integer references id (managers) on delete cascade
);

create table cd (
    id       integer primary key autoincrement not null,
    title    varchar(255),
    release  varchar(4),
    label_id integer references id (label)
);

create table song (
    id       integer primary key autoincrement not null,
    title    varchar(255)
);

create table artist_cd (
    artist_id  integer not null references id (artist) on delete cascade,
    cd_id      integer not null references id (cd) on delete cascade
);

create table cd_song (
    song_id  integer not null references id (song) on delete cascade,
    cd_id    integer not null references id (cd) on delete cascade
);

create table label (
    id        integer primary key autoincrement not null,
    name      varchar(255)
);

create table rating (
    range      integer not null default 1,
    artist_id  integer references id (artist) on delete cascade
);

create table cv (
    id integer   primary key autoincrement not null,
    artist_name  varchar(255),
    n_grammies   integer default 0 not null,
    n_platinums  integer default 0 not null,
    n_golds      integer default 0 not null
);

create table manager (
    id integer primary key autoincrement not null,
    name varchar(255)
);

#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use DBI;
use Test::More;

use Artist;
use Label;
use Rating;
use CD;
use ArtistCD;
use CDSong;
use Song;

system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

my $dbh = DBI->connect("dbi:SQLite:test_suite.db", "", "");

Artist->dbh($dbh);

{
    ok 1, '~ Populating database ~';
    ok my $label = Label->new({ name => 'EMI' });
    ok $label->save();

    ok my $artist1 = Artist->new({ name => 'Metallica', label_id => $label->id });
    ok $artist1->save();

    ok my $artist2 = Artist->new({ name => 'U2', label_id => $label->id });
    ok $artist2->save();

    ok my $rating = Rating->new();

    ok !$rating->is_defined;

    ok $rating->insert({ range => 1, artist_id => $artist1->id });
    ok $rating->insert({ range => 2, artist_id => $artist2->id });

    ok my $album1 = CD->new({ title => 'Load', release => '1996', label_id => $label->id });
    ok $album1->save();

    ok my $album2 = CD->new({ title => 'Reload', release => '1992', label_id => $label->id });
    ok $album2->save();

    ok my $album3 = CD->new({ title => 'Boy', release => '1980', label_id => $label->id });
    ok $album3->save();

    ok my $album4 = CD->new({ title => 'Zooropa', release => '1993', label_id => $label->id });
    ok $album4->save();

    ok( ArtistCD->new({ artist_id => $artist1->id, cd_id => $album1->id })->save() );
    ok( ArtistCD->new({ artist_id => $artist1->id, cd_id => $album2->id })->save() );
    ok( ArtistCD->new({ artist_id => $artist2->id, cd_id => $album3->id })->save() );
    ok( ArtistCD->new({ artist_id => $artist2->id, cd_id => $album4->id })->save() );

    ok my $song1 = Song->new({ title => '2x4' });
    ok $song1->save();
    ok my $song2 = Song->new({ title => 'Mama Said' });
    ok $song2->save();

    ok( CDSong->new({ song_id => $song1->id, cd_id => $album1->id })->save() );
    ok( CDSong->new({ song_id => $song1->id, cd_id => $album1->id })->save() );
};

{
    ok 1, '~ cd ~';
    ok my $album = CD->find({ title => 'Zooropa' })->fetch;
    is $album->title, 'Zooropa';

    ok $album = CD->find({ title => 'Zooropa', release => '1993' })->fetch;
    is $album->title, 'Zooropa';

    ok my @discs = CD->find('id > ? order by title', 1)->fetch();
    is $discs[0]->title, 'Boy';
}

{
    ok 1, '~ artist <-> label ~';
    ok my $metallica = Artist->find({ name => 'Metallica' })->fetch;
    is $metallica->name, 'Metallica';
    is $metallica->label->name, 'EMI';

    is $metallica->label->name, 'EMI';

    ok my $u2 = Artist->find({ name => 'U2' })->fetch;
    is $u2->name, 'U2';
    is $u2->label->name, 'EMI';

    ok my $label = Label->find({ name => 'EMI' })->fetch;
    is $label->name, 'EMI';
    my @artists = $label->artists->fetch();

    is scalar @artists, 2;

    for my $artist (@artists) {
        ok $artist->name ~~ ['Metallica', 'U2'];
    }

    ### Another ways for search
    ok my $a1 = Artist->find($metallica->id)->fetch;
    is $a1->name, 'Metallica';

    ok my ($a2, $a3) = Artist->find([$metallica->id, $u2->id])->fetch;
    is $a2->name, 'Metallica';
    is $a3->name, 'U2';

    ok my $a4 = Artist->find('name = ?', 'U2')->fetch;
    is $a4->name, 'U2';
};
{
    ok 1, '~ artist <-> rating ~';
    ok my $artist = Artist->find({ name => 'Metallica' })->fetch;
    ok $artist->rating->range;

    #eval { ok my $r = Rating->find(1) };
    ok my $r = Rating->find({ range => 1 })->fetch;
    ok $r->is_defined;
    is $r->artist->name, 'Metallica';

    ok my $r2 = Rating->find({ range => 3 })->fetch;
    ok !$r2->is_defined;
}

{
    ok 1, '~ artist <- arist_cd -> cd ~';
    ok my $artist = Artist->find({ name => 'Metallica' })->fetch;

    ok my @albums = $artist->albums->fetch();
    is scalar @albums, 2;

    ok my $album = CD->find({ title => 'Boy' })->fetch;
    ok my ($u2) = $album->artists->fetch(1);
    is $u2->name, 'U2';
}

{
    ok 1, '~ song <- cd_song -> cd ~';
    ok my $album = CD->find({ title => 'Load' })->fetch;
    ok my @songs = $album->songs->fetch;
    is scalar @songs, 2;

    ok my $song = Song->find({ title => '2x4' })->fetch(1);
    ok my $cd = $song->albums->fetch(1);
    is $cd->title, 'Load';
}

{
    ok 1, '~ new fetch ~';
    ok my @cd = CD->find('id > ?', 1)->order_by('title', 'id')->fetch();
    ok @cd = CD->find('id > ?', 2)->fetch();
    ok @cd = CD->find({ title => 'Load' })->fetch();
    ok scalar @cd == 1;

    ok @cd = CD->find([1, 2, 3])->fetch();
    ok scalar @cd == 3;

    ok my $cd = CD->find(1)->fetch;
    is $cd->title, 'Load';
}

{
    ok 1, '~ use_smart_saving ~';

    ok my @a = Artist->find('id >= ?', 1)->fetch();
    my $metallica = $a[0];
    ok $metallica->save;
}

{
    ok 1, '~ ordering ~';
    my $artists = Artist->find('id != ?', 100)->order_by('name')->desc();
    ok $artists->fetch();
}

{
    pass '~ limit, offset ~';
    my @artists = Artist->find()->limit(1)->fetch;
    is scalar @artists, 1;

    my $a = Artist->find()->limit(1)->offset(1)->fetch;
    is $a->name, 'U2';
}

=c
{
    ok 1, '~ bench smart saving ~';

    use Time::HiRes qw/tv_interval gettimeofday/;

    my $t1 = [gettimeofday];

    for (1..10) {
        my $artist = Artist->find(1);
        $artist->save();
    }

    my $t2 = [gettimeofday];

    say tv_interval $t1, $t2;
}

$my $unfetched = Artist->find([1, 2]);
#$unfetched->order_by('name')->desc;
#
#while (my $artist = $unfetched->fetch()) {
#    say $artist->name;
#}
=cut

done_testing;
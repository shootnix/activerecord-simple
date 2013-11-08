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
    pass '~ Populating database ~';
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
    pass '~ cd ~';
    ok my $album = CD->find({ title => 'Zooropa' })->fetch;
    is $album->title, 'Zooropa';

    ok $album = CD->find({ title => 'Zooropa', release => '1993' })->fetch;
    is $album->title, 'Zooropa';

    my $res = CD->find('id > ? order by title', 1);
    ok my @discs = CD->find('id > ? order by title', 1)->fetch();
    is $discs[0]->title, 'Boy';

    my $id_album = $album->id;
    ok $album->title('FooBarBaz');
    is $album->title, 'FooBarBaz';
    ok $album->save();

    $album = CD->find($id_album)->fetch();
    is $album->title, 'FooBarBaz';

    $album->title('Zooropa');
    $album->save();
}

{
    pass '~ artist <-> label ~';
    ok my $metallica = Artist->find({ name => 'Metallica' })->fetch;
    is $metallica->name, 'Metallica';
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

    is $metallica->label->name, 'EMI';
    ok $metallica->label->name('Foo');
    is $metallica->label->name, 'Foo';
    ok $metallica->label->save();

    ok $u2 = Artist->find({ name => 'U2' })->fetch;
    is $u2->name, 'U2';
    is $u2->label->name, 'Foo';

    $u2->label->name('EMI');
    $u2->label->save;
};
{
    pass '~ artist <-> rating ~';
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
    pass '~ artist <- arist_cd -> cd ~';
    ok my $artist = Artist->find({ name => 'Metallica' })->fetch;

    ok my @albums = $artist->albums->fetch();
    is scalar @albums, 2;

    ok my $album = CD->find({ title => 'Boy' })->fetch;
    ok my ($u2) = $album->artists->fetch(1);
    is $u2->name, 'U2';
}

{
    pass '~ song <- cd_song -> cd ~';
    ok my $album = CD->find({ title => 'Load' })->fetch;
    ok my @songs = $album->songs->fetch;
    is scalar @songs, 2;

    ok my $song = Song->find({ title => '2x4' })->fetch(1);
    ok my $cd = $song->albums->fetch(1);
    is $cd->title, 'Load';
}

{
    pass '~ new fetch ~';
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
    pass '~ use_smart_saving ~';

    ok my @a = Artist->find('id >= ?', 1)->fetch();
    my $metallica = shift @a;
    ok $metallica->save;
    ok $metallica->_smart_saving_used;
    ok $metallica->{snapshoot};
}

{
    pass '~ ordering ~';
    my $artists_find = Artist->find('id != ?', 100)->order_by('name')->desc();
    my $artist = $artists_find->fetch(1);
    ok $artists_find->{SQL} =~ /order by/i;
    ok $artists_find->{SQL} =~ /desc$/i;
}

{
    pass '~ limit, offset ~';
    my @artists = Artist->find()->limit(1)->fetch;
    is scalar @artists, 1;

    my $a = Artist->find()->limit(1)->offset(1)->fetch;
    is $a->name, 'U2';
}

{
    pass '~ fetch ~';

    my $find = CD->find;
    while (my @cd2 = $find->fetch(2)) {
        is scalar @cd2, 2;
    }

    my $find2 = CD->find;
    my @cd = $find2->fetch(3);
    is scalar @cd, 3;
    @cd = $find2->fetch(3);
    is scalar @cd, 1;
}

{
    pass '~ new rel system ~';
    my $artist = Artist->find({ name => 'U2' })->fetch;
    is $artist->name, 'U2';

    ok $artist->label;
    is $artist->label->name, 'EMI';
    ok $artist->label(Label->new({name => 'FooBarBaz'})->save)->save;
    is $artist->label->name, 'FooBarBaz';

    my $artist_again = Artist->find({ name => 'U2' })->fetch;
    is $artist_again->label->name, 'FooBarBaz';

    my $metallica = Artist->find({ name => 'Metallica' })->fetch;
    is $metallica->label->name, 'EMI';

    ok !$artist->label(Label->new({ name => 'NewFooBarBaz' }));
}

{
    pass '~ testing "only" ~';
    my $cd = CD->find->only('title')->limit(1)->fetch;
    ok exists $cd->{title};
    ok $cd->title;
    ok !exists $cd->{release};
    ok !$cd->release;

    ok defined $cd->id;
}

{
    pass '~ read only ~';
    my $cd = CD->find(1)->fetch({ read_only => 1 });
    $cd->title('Foo');
    eval { $cd->save };
    ok $@;
    ok $@ =~ m/^Object is read-only/i;
}

{
    pass '~ count ~';
    is(CD->count(), 4);
    is(CD->count({ title => 'Boy' }), 1);
    is(CD->count('id > ?', 1), 3);
}

{
    pass '~ first && last ~';
    ok my $artist = Artist->first->fetch;
    is $artist->name, 'Metallica';
    ok $artist = Artist->last->fetch;
    is $artist->name, 'U2';
    ok defined $artist->label_id;

    ok $artist = Artist->first->only('name')->fetch;
    ok defined $artist->name;
    ok !defined $artist->label_id;
}

done_testing;
package CDSong;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cd_song');
__PACKAGE__->columns(['cd_id', 'song_id']);

__PACKAGE__->relations({
    albums => {
        class => 'CD',
        type  => 'one',
        key   => 'cd_id'
    },
    songs => {
        class => 'Song',
        type => 'one',
        key  => 'song_id',
    }
});

1;
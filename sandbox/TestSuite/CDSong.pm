package CDSong;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cd_song');
__PACKAGE__->columns(['cd_id', 'song_id']);

__PACKAGE__->belongs_to(albums => 'CD', 'cd_id');
__PACKAGE__->belongs_to(songs => 'Song', 'song_id');


1;
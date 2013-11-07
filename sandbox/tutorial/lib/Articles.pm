package Articles;

use strict;
use warnings;
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('articles');
__PACKAGE__->columns(['id', 'title', 'content', 'author_id']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
    author => {
    	class => 'Authors',
    	type  => 'one',
    	key   => 'author_id'
    },
});

1;

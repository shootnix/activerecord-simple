package Comments;

use strict;
use warnings;
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('comments');
__PACKAGE__->columns(['id', 'create_date', 'comments_author', 'comment', 'article_id']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
	article => {
		class => 'Articles',
		type  => 'one',
        key   => 'article_id'
	}
});

1;

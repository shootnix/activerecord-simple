package Authors;

use strict;
use warnings;
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('authors');
__PACKAGE__->columns(['id', 'name']);
__PACKAGE__->primary_key('id');

__PACKAGE__->relations({
    articles => {
        class => 'Articles',
        type  => 'many',
        key   => 'author_id'
    },
});

1;

package Comments;

use strict
use warnings
use base 'ActiveRecord::Simple';

_PACKAGE_->table_name('comments');
_PACKAGE_->columns(['id', 'create_date', 'comments_author', 'comment', 'article_id']);
_PACKAGE_->primary_key('id');

1;

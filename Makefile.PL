use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ActiveRecord::Simple',
    AUTHOR              => q{shootnix <shootnix@cpan.org>},
    VERSION_FROM        => 'lib/ActiveRecord/Simple.pm',
    ABSTRACT_FROM       => 'lib/ActiveRecord/Simple.pm',
    LICENSE             => 'perl',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'ActiveRecord::Simple-*' },
);

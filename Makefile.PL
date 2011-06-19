use 5.006;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME            => 'Labyrinth::Plugin::Core',
    VERSION_FROM    => 'lib/Labyrinth/Plugin/Core.pm',
    PREREQ_PM       => {
        'Labyrinth'         => '5.07',

        'Clone'             => 0,
        'Time::Local'       => 0,
        'Image::Size'       => 0,
        'File::Copy'        => 0,
        'File::Basename'    => 0,
        'Digest::MD5'       => 0,
        'URI::Escape'       => 0,
        'Config::IniFiles'  => 0,
    },
    NO_META     => 1,
    ABSTRACT    => 'Core Labyrinth codebase - Core Plugins',
    AUTHOR      => 'Barbie <barbie@cpan.org>',
);

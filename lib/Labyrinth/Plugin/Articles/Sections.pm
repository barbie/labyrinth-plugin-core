package Labyrinth::Plugin::Articles::Sections;

use warnings;
use strict;

use vars qw($VERSION $ALLSQL $SECTIONID);
$VERSION = '5.01';

=head1 NAME

Labyrinth::Plugin::Articles::Sections - Sections handler plugin for Labyrinth

=head1 DESCRIPTION

Contains all the section handling functionality

=cut

# -------------------------------------
# Library Modules

use base qw(Labyrinth::Plugin::Articles);

use Clone qw(clone);

use Labyrinth::Audit;
use Labyrinth::DBUtils;
use Labyrinth::DTUtils;
use Labyrinth::MLUtils;
use Labyrinth::Session;
use Labyrinth::Support;
use Labyrinth::Variables;

# -------------------------------------
# Variables

# type: 0 = optional, 1 = mandatory
# html: 0 = none, 1 = text, 2 = textarea

my %fields = (
    articleid   => { type => 0, html => 0 },
    quickname   => { type => 1, html => 0 },
    title       => { type => 1, html => 1 },
);

my (@mandatory,@allfields);
for(keys %fields) {
    push @mandatory, $_     if($fields{$_}->{type});
    push @allfields, $_;
}

$ALLSQL     = 'AllArticles';
$SECTIONID  = 2;

# -------------------------------------
# The Subs

=head1 PUBLIC INTERFACE METHODS

=over 4

=item GetSection

=back

=cut

sub GetSection {
    my $name = $cgiparams{name};
    my $request = $cgiparams{act} || 'home-public';
    ($cgiparams{name}) = split("-",$request);
    shift->SUPER::Item();
    $tvars{page}->{section} = $tvars{articles}->{$cgiparams{name}}  if($tvars{articles}->{$cgiparams{name}});
    $cgiparams{name} = $name;   # revert back to what it should be!
}

=head1 ADMIN INTERFACE METHODS

Standard actions to administer the section content.

=over 4

=item Access

=item Admin

=item Add

=item Edit

=item Save

=item Delete

=back

=cut

sub Access  { Authorised(GOD) }

sub Admin {
    return  unless AccessUser(GOD);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Admin();
}

sub Add {
    return  unless AccessUser(GOD);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Add();
}

sub Edit {
    return  unless AccessUser(GOD);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Edit();
}

sub Save {
    return  unless AccessUser(GOD);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Save();
}

sub Delete {
    return  unless AccessUser(GOD);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Delete();
}

1;

__END__

=head1 SEE ALSO

  Labyrinth

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2011 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

package Labyrinth::Plugin::Articles::Site;

use warnings;
use strict;

my $VERSION = '5.04';

=head1 NAME

Labyrinth::Plugin::Articles::Site - Site Pages handler plugin for Labyrinth

=head1 DESCRIPTION

Contains all the site pages handling functionality

=cut

# -------------------------------------
# Library Modules

use base qw(Labyrinth::Plugin::Articles);

use Clone qw(clone);
use Time::Local;
use Data::Dumper;

use Labyrinth::Audit;
use Labyrinth::DBUtils;
use Labyrinth::DTUtils;
use Labyrinth::Globals;
use Labyrinth::MLUtils;
use Labyrinth::Session;
use Labyrinth::Support;
use Labyrinth::Variables;
use Labyrinth::Writer;
use Labyrinth::Metadata;

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

my $SECTIONID = 3;

# -------------------------------------
# The Subs

=head1 PUBLIC INTERFACE METHODS

=over 4

=item Archive

=item List

=item Meta

=item Cloud

=item Search

=item Item

=back

=cut

sub Archive {
    $cgiparams{sectionid} = $SECTIONID;
    $cgiparams{section} = 'site';

    shift->SUPER::Archive();
    $tvars{articles} = undef;
}

sub List {
    $cgiparams{sectionid} = $SECTIONID;
    $settings{limit} = 1;

    shift->SUPER::List();
}

sub Meta {
    return  unless($cgiparams{data});

    $cgiparams{sectionid} = $SECTIONID;
    $settings{limit} = 10;

    shift->SUPER::Meta();
}

sub Cloud {
    $cgiparams{sectionid} = $SECTIONID;
    $cgiparams{actcode} = 'site-meta';
    shift->SUPER::Cloud();
}

sub Search {
    return  unless($cgiparams{data});

    $cgiparams{sectionid} = $SECTIONID;
    $settings{limit} = 10;

    shift->SUPER::Search();
}

sub Item {
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Item();
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

sub Access  { Authorised(MASTER) }

sub Admin {
    return  unless AccessUser(MASTER);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Admin();
}

sub Add {
    return  unless AccessUser(MASTER);
    $cgiparams{sectionid} = $SECTIONID;
    my $self = shift;
    $self->SUPER::Add();
    $self->SUPER::Tags();
}

sub Edit {
    return  unless AccessUser(MASTER);
    $cgiparams{sectionid} = $SECTIONID;
    my $self = shift;
    $self->SUPER::Edit();
    $self->SUPER::Tags();
}

sub Save {
    return  unless AccessUser(MASTER);
    $cgiparams{sectionid} = $SECTIONID;
    $cgiparams{quickname} ||= formatDate(0);
    shift->SUPER::Save();
}

sub Delete {
    return  unless AccessUser(MASTER);
    $cgiparams{sectionid} = $SECTIONID;
    shift->SUPER::Delete();
}

1;

__END__

=head1 SEE ALSO

L<Labyrinth>

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2011 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

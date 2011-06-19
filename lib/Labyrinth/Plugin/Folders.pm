package Labyrinth::Plugin::Folders;

use warnings;
use strict;

my $VERSION = '5.08';

=head1 NAME

Labyrinth::Plugin::Folders - handler for Labyrinth folders

=head1 DESCRIPTION

Contains all the folder handling functionality for the Labyrinth
framework.

=cut

# -------------------------------------
# Library Modules

use base qw(Labyrinth::Plugin::Base);

use Labyrinth::DBUtils;
use Labyrinth::MLUtils;
use Labyrinth::Support;
use Labyrinth::Variables;

# -------------------------------------
# Variables

# type: 0 = optional, 1 = mandatory
# html: 0 = none, 1 = text, 2 = textarea

my %fields = (
    foldername  => { type => 1, html => 1 },
    parent      => { type => 1, html => 0 },
    folderid    => { type => 1, html => 0 },
    ref         => { type => 1, html => 0 },
);

my (@mandatory,@allfields);
for(keys %fields) {
    push @mandatory, $_     if($fields{$_}->{type});
    push @allfields, $_;
}

my $LEVEL       = ADMIN;

# -------------------------------------
# The Subs

=head1 ADMIN INTERFACE METHODS

=over 4

=item Admin

=item Add

=item AddLinkRealm

=item Edit

=item Save

=item Delete

=item DeleteLinkRealm

=back

=cut

sub Admin {
    return  unless AccessUser(ADMIN);

    my @where = ();
    push @where, "foldername LIKE '%$cgiparams{'searchname'}%'" if($cgiparams{'searchname'});
    my $where = @where ? 'WHERE '.join(' AND ',@where) : '';

    my @rows = $dbi->GetQuery('hash','AllFolders',{where=>$where});
    $tvars{data} = \@rows   if(@rows);
}

sub Add {
    return  unless AccessUser(ADMIN);
}

sub AddLinkRealm {
    return  unless AccessUser(ADMIN);
    return  unless $cgiparams{'folderid'};
    return  unless $cgiparams{'realmid'};

    $dbi->DoQuery('AddLinkRealm',$cgiparams{'realmid'},$cgiparams{'folderid'});

    if($cgiparams{'tree'}) {
        my @rows = $dbi->GetQuery('hash','GetFolder',$cgiparams{'folderid'});
        @rows = $dbi->GetQuery('hash','GetFoldersByRefs',{xref => $rows[0]->{'ref'}});

        foreach (@rows) {
            $dbi->DoQuery('AddLinkRealm',$cgiparams{'realmid'},$_->{folderid});
        }
    }
}

sub Edit {
    return  unless AccessUser($LEVEL);
    return  unless $cgiparams{'folderid'};

    my @rows = $dbi->GetQuery('hash','GetFolder',$cgiparams{'folderid'});
    return  unless(@rows);

    $tvars{data} = $rows[0];

    my @grows = $dbi->GetQuery('hash','LinkGroups',$cgiparams{'groupid'});

    for(keys %fields) {
        if($fields{$_}->{html} == 1)    { $tvars{data}->{$_} = CleanHTML($tvars{data}->{$_}) }
        elsif($fields{$_}->{html} == 2) { $tvars{data}->{$_} = SafeHTML($tvars{data}->{$_}) }
    }
}

sub Save {
    return  unless AccessUser($LEVEL);
    return  unless AuthorCheck('GetFolder','folderid');
    for(keys %fields) {
           if($fields{$_}->{html} == 1) { $cgiparams{$_} = CleanHTML($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 2) { $cgiparams{$_} = CleanTags($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 3) { $cgiparams{$_} = CleanLink($cgiparams{$_}) }
    }

    return  if FieldCheck(\@allfields,\@mandatory);

    $dbi->DoQuery('SaveFolder', $tvars{data}->{'foldername'},
                                $tvars{data}->{'parent'},
                                $tvars{data}->{'ref'},
                                $tvars{data}->{'folderid'});
}

sub Delete {
    return  unless AccessUser($LEVEL);
    return  unless $cgiparams{'folderid'};

    $dbi->DoQuery('DeleteFolderIndex',$cgiparams{'folderid'});
    $dbi->DoQuery('DeleteFolder',$cgiparams{'folderid'});
}

sub DeleteLinkRealm {
    return  unless AccessUser($LEVEL);
    my @rows = $dbi->GetQuery('hash','GetFolder',$cgiparams{'folderid'});
    @rows = $dbi->GetQuery('hash','GetFoldersByRefs',{xref => $rows[0]->{'ref'}});
    my $ids = join(",",map {$_->{folderid}} @rows);
    $ids = ($ids ? ",$cgiparams{'folderid'}" : $cgiparams{'folderid'});

    $dbi->DoQuery('DeleteLinkRealm',$cgiparams{'realmid'},{ids => $ids});
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
  modify it under the Artistic License 2.0.

=cut

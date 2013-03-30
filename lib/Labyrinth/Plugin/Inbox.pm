package Labyrinth::Plugin::Inbox;

use warnings;
use strict;

my $VERSION = '5.11';

=head1 NAME

Labyrinth::Plugin::Inbox - Inbox plugin handler for Labyrinth

=head1 DESCRIPTION

Contains all the inbox/message handling functionality for the Labyrinth
framework.

=cut

# -------------------------------------
# Library Modules

use base qw(Labyrinth::Plugin::Base);

use Labyrinth::DBUtils;
use Labyrinth::Inbox;
use Labyrinth::Variables;

# -------------------------------------
# The Subs

=head1 PUBLIC INTERFACE METHODS

=over 4

=item InboxCheck

=item InboxView

=item MessageView

=item MessageApprove

=item MessageDecline

=back

=cut

sub InboxCheck {
    return  if($tvars{user}->{name} eq 'guest');
    my $folders = AccessAllFolders($tvars{loginid},PUBLISHER);
    my $areas = AccessAllAreas();
    my @rows = $dbi->GetQuery('array','CountInbox',
                    {areas=>$areas,folders=>$folders});
    $tvars{inbox} = $rows[0]->[0] || 0;
}

sub InboxView {
    return  if($tvars{user}->{name} eq 'guest');
    my $folders = AccessAllFolders($tvars{loginid},PUBLISHER);
    my $areas = AccessAllAreas();
    my @rows = $dbi->GetQuery('array','ReadInbox',
                    {areas=>$areas,folders=>$folders});
    $tvars{inbox} = scalar(@rows);
    $tvars{data}  = \@rows  if(@rows);
}

sub MessageView {
    return  if($tvars{user}->{name} eq 'guest');
    my @rows = $dbi->GetQuery('hash','ReadMessage', $cgiparams{message});
    $tvars{data}  = \@rows  if(@rows);
}

sub MessageApprove {
    return  if($tvars{user}->{name} eq 'guest');
    MessageApproval(1,$tvars{loginid},$cgiparams{message});
}

sub MessageDecline {
    return  if($tvars{user}->{name} eq 'guest');
    MessageApproval(0,$tvars{loginid},$cgiparams{message});
}

1;

__END__

=head1 SEE ALSO

L<Labyrinth>

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2013 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the Artistic License 2.0.

=cut

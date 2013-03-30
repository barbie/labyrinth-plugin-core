package Labyrinth::Plugin::Users;

use warnings;
use strict;

my $VERSION = '5.11';

=head1 NAME

Labyrinth::Plugin::Users - Plugin Users handler for Labyrinth

=head1 DESCRIPTION

Contains all the default user handling functionality for the Labyrinth
framework.

=cut

# -------------------------------------
# Library Modules

use base qw(Labyrinth::Plugin::Base);

use Labyrinth::Audit;
use Labyrinth::DBUtils;
use Labyrinth::Media;
use Labyrinth::MLUtils;
use Labyrinth::Session;
use Labyrinth::Writer;
use Labyrinth::Support;
use Labyrinth::Users;
use Labyrinth::Variables;

use Clone   qw/clone/;
use Digest::MD5 qw(md5_hex);
use URI::Escape qw(uri_escape);

# -------------------------------------
# Constants

use constant    MaxUserWidth    => 300;
use constant    MaxUserHeight   => 400;

# -------------------------------------
# Variables

# type: 0 = optional, 1 = mandatory
# html: 0 = none, 1 = text, 2 = textarea

my %fields = (
    email       => { type => 1, html => 1 },
    effect      => { type => 0, html => 1 },
    userid      => { type => 0, html => 0 },
    nickname    => { type => 0, html => 1 },
    realname    => { type => 1, html => 1 },
    aboutme     => { type => 0, html => 2 },
    search      => { type => 0, html => 0 },
    image       => { type => 0, html => 0 },
    accessid    => { type => 0, html => 0 },
    realmid     => { type => 0, html => 0 },
);

my (@mandatory,@allfields);
for(keys %fields) {
    push @mandatory, $_     if($fields{$_}->{type});
    push @allfields, $_;
}

my $LEVEL = ADMIN;

# -------------------------------------
# The Subs

=head1 PUBLIC INTERFACE METHODS

=over 4

=item UserLists

=item Gravatar

=item Item

=item Name

=item Password

=item Register

=item Registered

=back

=cut

sub UserLists {
    my (%search,$search,$key);
    my @fields = ();
    $search{where} = '';
    $search{order} = 'realname,nickname';
    $search{search} = 1;
    $search{access} = MASTER + 1;

    if(Authorised(ADMIN)) {
        $search{order} = 'u.realname'   if($cgiparams{ordered});
        $search{search} = 0;
        $search{access} = PUBLISHER     if($tvars{loginid} > 1);
    }

    if($cgiparams{'all'}) {
        $key = 'SearchUsers';
        @fields = ('%','%');

    } elsif($cgiparams{'letter'}) {
        $search = ($cgiparams{'letter'} || '') . '%';
        @fields = ($search,$search);
        $key = 'SearchUserNames';

    } elsif($cgiparams{'searchname'}) {
        $search = '%' . $cgiparams{'searchname'} . '%';
        @fields = ($search,$search);
        $key = 'SearchUserNames';

    } elsif($cgiparams{'searched'}) {
        @fields = ($cgiparams{'searched'},$cgiparams{'searched'});
        $key = 'SearchUsers';

    } else {
        $key = 'SearchUsers';
        @fields = ('%','%');
    }

    my @rows = $dbi->GetQuery('hash',$key,\%search,@fields);
    LogDebug("UserList: key=[$key], rows found=[".scalar(@rows)."]");

    for(@rows) {
        ($_->{width},$_->{height}) = GetImageSize($_->{link},$_->{dimensions},$_->{width},$_->{height},MaxUserWidth,MaxUserHeight);
        $_->{gravatar} = GetGravatar($_->{userid},$_->{email});

        if($_->{url} && $_->{url} !~ /^https?:/) {
            $_->{url} = 'http://' . $_->{url};
        }
        if($_->{aboutme}) {
            $_->{aboutme} = '<p>' . $_->{aboutme}   unless($_->{aboutme} =~ /^\s*<p>/si);
            $_->{aboutme} .= '</p>'                 unless($_->{aboutme} =~ m!</p>\s*$!si);
        }
        my @grps = $dbi->GetQuery('hash','LinkedUsers',$_->{userid});
        if(@grps) {
            $_->{member} = $grps[0]->{member};
        }
        if(Authorised(ADMIN)) {
            $_->{name}  = $_->{realname};
            $_->{name} .= " ($_->{nickname})" if($_->{nickname});
        } else {
            $_->{name} = $_->{nickname} || $_->{realname};
        }
    }

    $tvars{users}    = \@rows       if(@rows);
    $tvars{searched} = $fields[0]   if(@fields);
}

sub Gravatar {
    my $nophoto = uri_escape($settings{nophoto});
    $tvars{data}{gravatar} = $nophoto;

    return  unless $cgiparams{'userid'};
    my @rows = $dbi->GetQuery('hash','GetUserByID',$cgiparams{'userid'});
    return  unless @rows;

    $tvars{data}{gravatar} =
        'http://www.gravatar.com/avatar.php?'
        .'gravatar_id='.md5_hex($rows[0]->{email})
        .'&amp;default='.$nophoto
        .'&amp;size=80';
}

sub Item {
    return  unless $cgiparams{'userid'};

    my @rows = $dbi->GetQuery('hash','GetUserByID',$cgiparams{'userid'});
    return  unless(@rows);

    $rows[0]->{tag}  = ''   if($rows[0]->{link} =~ /blank.png/);
    $rows[0]->{link} = ''   if($rows[0]->{link} =~ /blank.png/);

    ($rows[0]->{width},$rows[0]->{height}) = GetImageSize($rows[0]->{link},$rows[0]->{dimensions},$rows[0]->{width},$rows[0]->{height},MaxUserWidth,MaxUserHeight);
    $rows[0]->{gravatar} = GetGravatar($rows[0]->{userid},$rows[0]->{email});

    $tvars{data} = $rows[0];
}

sub Name {
    return unless($cgiparams{'userid'});
    return UserName($cgiparams{'userid'})
}

sub Password {
    return  unless $tvars{'loggedin'};

    $cgiparams{'userid'} = $tvars{'loginid'}    unless(Authorised(ADMIN) && $cgiparams{'userid'});
    $tvars{data}->{name} = UserName($cgiparams{userid});

    my @mandatory = qw(userid effect1 effect2 effect3);
    if(FieldCheck(\@mandatory,\@mandatory)) {
        $tvars{errmess} = 'All fields must be complete, please try again.';
        $tvars{errcode} = 'ERROR';
        return;
    }

    my $who = $cgiparams{'userid'};
    $who = $tvars{'loginid'} if(Authorised(ADMIN));

    my @rows = $dbi->GetQuery('hash','ValidUser',$who,$cgiparams{'effect1'});
    unless(@rows) {
        $tvars{errmess} = 'Current password is invalid, please try again.';
        $tvars{errcode} = 'ERROR';
        return;
    }

    if($cgiparams{effect2} ne $cgiparams{effect3}) {
        $tvars{errmess} = 'New &amp; verify passwords don\'t match, please try again.';
        $tvars{errcode} = 'ERROR';
        return;
    }

    my %passerrors = (
        1 => "Password too short, length should be $settings{minpasslen}-$settings{maxpasslen} characters.",
        2 => "Password too long, length should be $settings{minpasslen}-$settings{maxpasslen} characters.",
        3 => 'Password not cyptic enough, please enter as per password rules.',
        4 => 'Password contains spaces or tabs.',
        5 => 'Password should contain 3 or more unique characters.',
    );

    my $invalid = PasswordCheck($cgiparams{effect2});
    if($invalid) {
        $tvars{errmess} = $passerrors{$invalid};
        $tvars{errcode} = 'ERROR';
        return;
    }

    $dbi->DoQuery('ChangePassword',$cgiparams{effect2},$cgiparams{'userid'});
    $tvars{thanks} = 'Password Changed.';

    if($cgiparams{mailuser}) {
        my @rows = $dbi->GetQuery('hash','GetUserByID',$cgiparams{'userid'});
        MailSend(   template    => 'mailer/reset.eml',
                    name        => $rows[0]->{realname},
                    password    => $cgiparams{effect2},
                    email       => $rows[0]->{email}
        );
    }
}

sub Register {
    my %data = (
        'link'          => 'images/blank.png',
        'tag'           => '[No Image]',
        'admin'         => Authorised(ADMIN),
    );

    $tvars{data}{$_} = $data{$_}  for(keys %data);
    $tvars{userid} = 0;
    $tvars{newuser} = 1;
    $tvars{htmltags} = LegalTags();
}

sub Registered {
    $cgiparams{cause} = $cgiparams{email};
}

=head1 ADMIN INTERFACE METHODS

=over 4

=item Login

=item Logout

=item Store

=item Retrieve

=item LoggedIn

=item ImageCheck

=item Admin

=item Add

=item Edit

=item Save

=item AdminSave

=item Delete

=item Ban

=item AdminPass

=item AdminChng

=cut

sub Login    { Labyrinth::Session::Login()    }
sub Logout   { Labyrinth::Session::Logout()   }
sub Store    { Labyrinth::Session::Store()    }
sub Retrieve { Labyrinth::Session::Retrieve() }

sub LoggedIn {
    $tvars{errcode} = 'ERROR'   if(!$tvars{loggedin});
}

sub ImageCheck  {
    my @rows = $dbi->GetQuery('array','UsersImageCheck',$_[0]);
    @rows ? 1 : 0;
}

sub Admin {
    return  unless AccessUser($LEVEL);

    # note: cannot alter the guest & master users
    if(my $ids = join(",",grep {$_ > 2} CGIArray('LISTED'))) {
        $dbi->DoQuery('SetUserSearch',{ids=>$ids},1)    if($cgiparams{doaction} eq 'Show');
        $dbi->DoQuery('SetUserSearch',{ids=>$ids},0)    if($cgiparams{doaction} eq 'Hide');
        Ban($ids)                                       if($cgiparams{doaction} eq 'Ban');
        Delete($ids)                                    if($cgiparams{doaction} eq 'Delete');
    }

    UserLists();
}

sub Add {
    return  unless AccessUser($LEVEL);

    my %data = (
        'link'      => 'images/blank.png',
        'tag'       => '[No Image]',
        ddrealms    => RealmSelect(0),
        ddaccess    => AccessSelect(0),
        ddgroups    => 'no groups assigned',
        member      => 'no group assigned',
    );

    $tvars{users}{data} = \%data;
    $tvars{userid} = 0;
}

sub Edit {
    $cgiparams{userid} ||= $tvars{'loginid'};
    return  unless MasterCheck();
    return  unless AuthorCheck('GetUserByID','userid',$LEVEL);

    $tvars{data}{tag}      = '[No Image]' if(!$tvars{data}{link} || $tvars{data}{link} =~ /blank.png/);
    $tvars{data}{name}     = UserName($tvars{data}{userid});
    $tvars{data}{admin}    = Authorised(ADMIN);
    $tvars{data}{ddrealms} = RealmSelect(RealmID($tvars{data}{realm}));
    $tvars{data}{ddaccess} = AccessSelect($tvars{data}{accessid});

    my @grps = $dbi->GetQuery('hash','LinkedUsers',$cgiparams{'userid'});
    if(@grps) {
        $tvars{data}{ddgroups} = join(', ',map {$_->{groupname}} @grps);
        $tvars{data}{member} = $grps[0]->{member};
    } else {
        $tvars{data}{ddgroups} = 'no groups assigned';
        $tvars{data}{member} = 'no group assigned';
    }

    $tvars{htmltags} = LegalTags();
    $tvars{users}{data}    = clone($tvars{data});  # data fields need to be editable
    $tvars{users}{preview} = clone($tvars{data});  # data fields need to be editable

    for(keys %fields) {
           if($fields{$_}->{html} == 1) { $tvars{users}{data}{$_}    = CleanHTML($tvars{users}{data}{$_});
                                          $tvars{users}{preview}{$_} = CleanHTML($tvars{users}{preview}{$_}); }
        elsif($fields{$_}->{html} == 2) { $tvars{users}{data}{$_}    = SafeHTML($tvars{users}{data}{$_});     }
    }

    $tvars{users}{preview}{gravatar} = GetGravatar($tvars{users}{preview}{userid},$tvars{users}{preview}{email});

    $tvars{users}{preview}{link} = undef
        if($tvars{users}{data}{link} && $tvars{users}{data}{link} =~ /blank.png/);
}

sub Save {
    my $newuser = $cgiparams{'userid'} ? 0 : 1;
    unless($newuser) {
        return  unless MasterCheck();
        if($cgiparams{userid} != $tvars{'loginid'} && !Authorised($LEVEL)) {
            $tvars{errcode} = 'BADACCESS';
            return;
        }
    }

    return  unless AuthorCheck('GetUserByID','userid',$LEVEL);

    $tvars{newuser} = $newuser;
    for(keys %fields) {
           if($fields{$_}->{html} == 1) { $cgiparams{$_} = CleanHTML($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 2) { $cgiparams{$_} = CleanTags($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 3) { $cgiparams{$_} = CleanLink($cgiparams{$_}) }
    }

    return  if FieldCheck(\@allfields,\@mandatory);

    ## before continuing we should ensure the IP address has not
    ## submitted repeated registrations. Though we should be aware
    ## of Proxy Servers too.
    my $imageid = $cgiparams{imageid} || 1;
    ($imageid) = SaveImageFile(
            param => 'image',
            stock => 'Users'
        )   if($cgiparams{image});

    my @fields = (  $tvars{data}{'nickname'}, $tvars{data}{'realname'},
                    $tvars{data}{'email'},    $imageid
    );

    if($newuser) {
        $tvars{data}{'accessid'} = $tvars{data}{'accessid'} ? 1 : 0;
        $tvars{data}{'search'}   = $tvars{data}{'search'}   ? 1 : 0;
        $tvars{data}{'realm'}    = 'public';
        $cgiparams{'userid'} = $dbi->IDQuery('NewUser', $tvars{data}{'effect'},
                                                        $tvars{data}{'accessid'},
                                                        $tvars{data}{'search'},
                                                        $tvars{data}{'realm'},
                                                        @fields);
    } else {
        $dbi->DoQuery('SaveUser',@fields,$cgiparams{'userid'});
    }

    $tvars{data}{userid} = $cgiparams{'userid'};
    $tvars{newuser} = 0;
}

sub AdminSave {
    return  unless AccessUser(ADMIN);
    return  unless MasterCheck();

    my $newuser = $cgiparams{'userid'} ? 0 : 1;
    return  unless AuthorCheck('GetUserByID','userid',$LEVEL);

    $tvars{newuser} = $newuser;

    for(keys %fields) {
           if($fields{$_}->{html} == 1) { $cgiparams{$_} = CleanHTML($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 2) { $cgiparams{$_} = CleanTags($cgiparams{$_}) }
        elsif($fields{$_}->{html} == 3) { $cgiparams{$_} = CleanLink($cgiparams{$_}) }
    }

    my $realm = $tvars{data}->{realm} || 'public';
    return  if FieldCheck(\@allfields,\@mandatory);

    ## before continuing we should ensure the IP address has not
    ## submitted repeated registrations. Though we should be aware
    ## of Proxy Servers too.
    my $imageid = $cgiparams{imageid} || 1;
    ($imageid) = SaveImageFile(
            param => 'image',
            stock => 'Users'
        )   if($cgiparams{image});

    # in case of a new user
    $tvars{data}->{'accessid'} = $tvars{data}->{'accessid'} || 1;
    $tvars{data}->{'search'}   = $tvars{data}->{'search'} ? 1 : 0;
    $tvars{data}->{'realm'}    = Authorised(ADMIN) && $tvars{data}->{'realmid'} ? RealmName($tvars{data}->{realmid}) : $realm;

    my @fields = (  $tvars{data}{'accessid'}, $tvars{data}{'search'},
                    $tvars{data}{'realm'},    
                    $tvars{data}{'nickname'}, $tvars{data}{'realname'},
                    $tvars{data}{'email'},    $imageid
    );

    if($newuser) {
        $cgiparams{'userid'} = $dbi->IDQuery('NewUser',$tvars{data}->{'effect'},@fields);
    } else {
        $dbi->DoQuery('AdminSaveUser',@fields,$cgiparams{'userid'});
    }

    $tvars{data}->{userid} = $cgiparams{'userid'};
    $tvars{newuser} = 0;
}

sub Delete {
    my $ids = shift;
    return  unless AccessUser($LEVEL);
    $dbi->DoQuery('DeleteUsers',{ids => $ids});
    $tvars{thanks} = 'Users Deleted.';
}

sub Ban {
    my $ids = shift;
    return  unless AccessUser($LEVEL);
    $dbi->DoQuery('BanUsers',{ids => $ids},'-banned-');
    $tvars{thanks} = 'Users Banned.';
}

sub AdminPass {
    return  unless($cgiparams{'userid'});
    return  unless MasterCheck();
    return  unless AccessUser($LEVEL);
    return  unless AuthorCheck('GetUserByID','userid',$LEVEL);
    $tvars{data}{name}     = UserName($cgiparams{'userid'});
}

sub AdminChng {
    return  unless($cgiparams{'userid'});
    return  unless MasterCheck();
    return  unless AccessUser($LEVEL);

    my @mandatory = qw(userid effect2 effect3);
    if(FieldCheck(\@mandatory,\@mandatory)) {
        $tvars{errmess} = 'All fields must be complete, please try again.';
        $tvars{errcode} = 'ERROR';
        return;
    }

    $tvars{data}{name}     = UserName($cgiparams{'userid'});

    if($cgiparams{effect2} ne $cgiparams{effect3}) {
        $tvars{errmess} = 'New &amp; verify passwords don\'t match, please try again.';
        $tvars{errcode} = 'ERROR';
        return;
    }

    my %passerrors = (
        1 => "Password too short, length should be $settings{minpasslen}-$settings{maxpasslen} characters.",
        2 => "Password too long, length should be $settings{minpasslen}-$settings{maxpasslen} characters.",
        3 => 'Password not cyptic enough, please enter as per password rules.',
        4 => 'Password contains spaces or tabs.',
        5 => 'Password should contain 3 or more unique characters.',
    );

    my $invalid = PasswordCheck($cgiparams{effect2});
    if($invalid) {
        $tvars{errmess} = $passerrors{$invalid};
        $tvars{errcode} = 'ERROR';
        return;
    }

    $dbi->DoQuery('ChangePassword',$cgiparams{effect2},$cgiparams{'userid'});
    $tvars{thanks} = 'Password Changed.';

    if($cgiparams{mailuser}) {
        my @rows = $dbi->GetQuery('hash','GetUserByID',$cgiparams{'userid'});
        MailSend(   template    => 'mailer/reset.eml',
                    name        => $rows[0]->{realname},
                    password    => $cgiparams{effect2},
                    email       => $rows[0]->{email}
        );
    }
}

=item ACL

=item ACLSave

=item ACLDelete

=cut

sub ACL {
    return  unless AccessUser($LEVEL);
    return  unless $cgiparams{'userid'};

    my @rows = $dbi->GetQuery('hash','GetUserByID',$cgiparams{'userid'});
    $tvars{data}->{$_} = $rows[0]->{$_}  for(qw(userid realname));

    @rows = $dbi->GetQuery('hash','UserACLs',$cgiparams{'userid'});
    for my $row (@rows) {
        push @{$tvars{data}->{access}}, $row;
    }

    $tvars{ddfolder} = FolderSelect();
    $tvars{ddaccess} = AccessSelect();
}

sub ACLSave {
    return  unless AccessUser($LEVEL);

    my @manfields = qw(userid accessid folderid);;
    return  if FieldCheck(\@manfields,\@manfields);

    my @rows = $dbi->GetQuery('hash','UserACLCheck',
            $cgiparams{'userid'},
            $cgiparams{'accessid'},
            $cgiparams{'folderid'});
    return  if(@rows);

    $dbi->DoQuery('UserACLSave',
            $cgiparams{'userid'},
            $cgiparams{'accessid'},
            $cgiparams{'folderid'});

    $tvars{thanks} = 'User access saved successfully.';
}

sub ACLDelete {
    return  unless AccessUser($LEVEL);

    my @manfields = qw(userid accessid folderid);;
    return  if FieldCheck(\@manfields,\@manfields);

    $dbi->DoQuery('UserACLDelete',
            $cgiparams{'userid'},
            $cgiparams{'accessid'},
            $cgiparams{'folderid'});

    $tvars{thanks} = 'User access removed successfully.';
}

1;

__END__

=back

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

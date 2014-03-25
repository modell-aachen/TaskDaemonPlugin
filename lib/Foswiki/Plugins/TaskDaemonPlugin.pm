# See bottom of file for default license and copyright information

package Foswiki::Plugins::TaskDaemonPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Plugins::SolrPlugin::Index ();
use Event;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IO::Socket       ();
use JSON;

our $VERSION = '1.0';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION = 'Simple example on how to get around IWatch.';

our $NO_PREFS_IN_TOPIC = 1;

use constant DEBUG => 0;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler( 'index', \&_restIndex, authenticate => 1, 'http_allow' => 'POST' );

    # Plugin correctly initialized
    return 1;
}

sub grind {
    my $session = shift;
    my $type = $main::mattworker_data{type};
    my $data = $main::mattworker_data{data};

    my $indexer = Foswiki::Plugins::SolrPlugin::getIndexer($session);
    my $caches = $main::mattworker_data{caches};
    $indexer->groupsCache($caches->{groups_members}) if $caches->{groups_members};
    $indexer->webACLsCache($caches->{web_acls}) if $caches->{web_acls};

    if ($type eq 'update_topic') {
        $indexer->updateTopic(undef, $data);
        $indexer->commit(1);
    }
    elsif ($type eq 'update_web') {
        $indexer->update($data);
        $indexer->commit(1);
    }

    $main::mattworker_data{caches} = {
        groups_members => $indexer->groupsCache(),
        web_acls => $indexer->webACLsCache(),
    };

}

sub _send {
    my ($message, $type) = @_;

    $type ||= 'update_topic';

    my $socket = new IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => 8090,
        Proto => 'tcp',
        Timeout => 3
    );

    Foswiki::Func::writeWarning("sending '$type': '$message'") if DEBUG;
    if ($socket) {
        my $host = $Foswiki::cfg{DefaultUrlHost};
        $host =~ s#^https?://##;
        $socket->send(encode_json({
            type => $type,
            data => $message,
            host => $host,
        }));
    } else {
        Foswiki::Func::writeWarning( "Realtime-indexing is offline!" );
    };
}


my @flushCmd;

sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    return unless $topic eq $Foswiki::cfg{WebPrefsTopicName};

    my ($oldMeta) = Foswiki::Func::readTopic($web, $topic);
    if ($oldMeta->getPreference('ALLOWWEBVIEW') ne $meta->getPreference('ALLOWWEBVIEW') ||
            $oldMeta->getPreference('DENYWEBVIEW') ne $meta->getPreference('DENYWEBVIEW')) {
        @flushCmd = ([$web, 'flush_acls'], [$web, 'update_web']);
    }
}

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    foreach my $cmd (@flushCmd) {
        _send(@$cmd);
    }
    if (!@flushCmd) {
        _send("$web.$topic");
    }
    undef @flushCmd;
}

sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $oldAttachment,
         $newWeb, $newTopic, $newAttachment ) = @_;

     if(not $oldTopic) {
         _send("$newWeb", 'update_web'); # old web will be deleted automatically
     } else {
         if ("$oldWeb.$oldTopic" eq "$newWeb.$newTopic") {
             # --> probably attachent
             _send("$oldWeb.$oldTopic");
         } else {
             # newWeb.newTopic will cause a afterSaveHandler anyway _send("$oldWeb.$oldTopic\n$newWeb.$newTopic");
             _send("$newWeb.$newTopic");
         }
     }
}

sub completePageHandler {
    my( $html, $httpHeaders ) = @_;

    my $session = $Foswiki::Plugins::SESSION;
    my $req = $session->{request};
    if ($req->action eq 'manage' && $req->param('action') =~ /^(?:add|remove)User(?:To|From)Group$/ ||
        $req->param('refreshldap'))
    {
        _send('', 'flush_groups');
        _send("$Foswiki::cfg{UsersWebName}.". $req->param('groupname')) if $req->param('groupname');
    }
}

# Disabled -> let afterSave handle it
sub afterUploadHandlerDisabled {
    my( $attrHashRef, $meta ) = @_;

    my $web = $meta->web();
    my $topic = $meta->topic();

    _send("$web.$topic");
}

sub _restIndex {
    my ( $session, $subject, $verb, $response ) = @_;

    my $params = $session->{request}->{param};
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName( $params->{w}[0], $params->{t}[0] );

    $web = '' if ( !$params->{w}[0] );
    $topic = '' if ( !$params->{t}[0] );

    if ( !$web || !Foswiki::Func::webExists( $web ) ) {
        $response->status( 400 );
        return;
    }

    if ( $topic ) {
        _send( "$web.$topic" );
    } else {
        _send( $web, "update_web" );
    }

    $response->status( 200 );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: MAOst

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

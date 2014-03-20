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

    # Plugin correctly initialized
    return 1;
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
        $socket->send(encode_json({
            type => $type,
            data => $message,
        }));
    } else {
        Foswiki::Func::writeWarning( "Realtime-indexing is offline!" );
    };
}

sub launchWorker {
    my $session = shift;
    my $exitWorker = AnyEvent->condvar;
    AE::signal INT => sub { $exitWorker->send; };

    my @read; @read = (json => sub {
        my ($hdl, $json) = @_;

        my $oldHost = $Foswiki::cfg{DefaultUrlHost};
        $Foswiki::cfg{DefaultUrlHost} = $json->{host} if $json->{host};

        if ($json->{type} eq 'update_topic') {
            my $indexer = Foswiki::Plugins::SolrPlugin::getIndexer($session);

            my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $json->{data});
            eval { $indexer->updateTopic($web, $topic); $indexer->commit(1); };
            if ($@) {
                Foswiki::Func::writeWarning( "Worker: update_topic exception: $@" );
            }
        } elsif ($json->{type} eq 'update_web') {
            my $indexer = Foswiki::Plugins::SolrPlugin::getIndexer($session);

            my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($json->{data});
            eval { $indexer->update($web); $indexer->commit(1); };
            if ($@) {
                Foswiki::Func::writeWarning( "Worker: update_web exception: $@" );
            }
        } elsif ($json->{type} eq 'flush_acls') {
            Foswiki::Func::wrtieWarning("flushing acls") if DEBUG;
            my $indexer = Foswiki::Plugins::SolrPlugin::getIndexer($session);
            $indexer->finish();
        } elsif ($json->{type} eq 'exit_worker') {
            $exitWorker->send;
            return;
        }

        $Foswiki::cfg{DefaultUrlHost} = $oldHost;

        $hdl->push_write(json => {type => 'worker_idle'});
        $hdl->push_read(@read);
    });
    my $hdl = new AnyEvent::Handle(
        connect => ['127.0.0.1', 8090],
        on_connect => sub {
            my $hdl = shift;
            $hdl->push_write(json => {type => 'worker_idle'});
            $hdl->push_read(@read);
        },
        on_connect_error => sub {
            Foswiki::Func::writeWarning( "Worker: failed to connect to MATT daemon: $!" );
            exit();
        },
        on_error => sub {
            my ($hdl, $fatal, $message) = @_;
            Foswiki::Func::writeWarning( "Worker: error in connection to MATT daemon: $message" );
            $hdl->destroy unless $fatal;
        },
    );
    $exitWorker->recv;
}

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    if($topic eq $Foswiki::cfg{WebPrefsTopicName}) {
        _send($web, 'flush_acls'); # XXX check if ACLs/workflow changed
        _send($web, 'update_web');
    } else {
        _send("$web.$topic");
    }
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

# Disabled -> let afterSave handle it
sub afterUploadHandlerDisabled {
    my( $attrHashRef, $meta ) = @_;

    my $web = $meta->web();
    my $topic = $meta->topic();

    _send("$web.$topic");
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

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
our $SHORTDESCRIPTION = 'Modell Aachen Task and Topic Daemon.';

our $NO_PREFS_IN_TOPIC = 1;

use constant DEBUG => 0;

use constant RETURN_RESPONSE => 1;
use constant RETURN_SOCKET => 2;

our $socket;
our $flushSocket;

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

sub finishPlugin {
    if($flushSocket && $socket) {
        $socket->flush();
        undef $flushSocket;
    }
    undef $socket unless $socket; # If we had an error, try again next request
}

sub grind {
    my $session = shift;
    my $type = $main::mattworker_data{type};
    my $data = $main::mattworker_data{data};
    my $caches = $main::mattworker_data{caches};

    $main::mattworker_data{handlers}{engine_part}->($session, $type, $data, $caches);
}

# send message to TaskDaemon
sub send {
    my ($message, $type, $department, $wait, $isRetry) = @_;

    unless ( defined $socket && $socket->connected() ) {
        $socket = new IO::Socket::INET->new(
            PeerAddr => $Foswiki::cfg{TaskDaemonPlugin}{Address} || 127.0.0.1,
            PeerPort => $Foswiki::cfg{TaskDaemonPlugin}{Port} || 8090,
            Proto => 'tcp',
            Timeout => 3
        );
        Foswiki::Func::writeWarning("Created new socket", $socket || '(failed)') if DEBUG;
        unless ( $socket ) {
            Foswiki::Func::writeWarning( "Can not bind to TaskDaemon: $@" );
            $socket = 0; # do not try again for this request
        }
    }
    if ( $socket ) {
        $flushSocket = 1;
        Foswiki::Func::writeWarning("Sending '$type': '$message' to TaskDaemon") if DEBUG;
        my $host = $Foswiki::cfg{DefaultUrlHost};
        $host =~ s#^https?://##;
        my $core = $Foswiki::cfg{ScriptDir};
        $core =~ s#/bin/?$##;
        my $sent = $socket->send(encode_json({
            type => $type,
            data => $message,
            host => $host,
            department => $department,
            _wait => $wait || 0,
            core => $core,
        }));
        unless($sent && $socket->connected()) {
            if($isRetry) {
                Foswiki::Func::writeWarning("Failed to send command to daemon") if DEBUG;
                return;
            } else {
                # Maybe the socket closed (which we apparently can not detect), so retry once.
                # This happens, when the daemon restarts.
                Foswiki::Func::writeWarning("Socket no longer valid, re-attempting") if DEBUG;
                return Foswiki::Plugins::TaskDaemonPlugin::send($message, $type, $department, $wait, 1);
            }
        }
        if ($wait) {
            return $socket if $wait eq RETURN_SOCKET;
            my $response;
            $socket->recv($response, 1234);
            return decode_json($response);
        }
    }
}


1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Stephan Osthold, Jan Krüger, Sven Meyer, Maik Glatki

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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

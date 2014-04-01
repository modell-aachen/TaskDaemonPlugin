#!/usr/bin/perl -w
#
# Copyright (C) 2014 Modell Aachen GmbH
#
# For licensing info read LICENSE file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

use strict;
use warnings;

use Event;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IO::Socket       ();
use JSON;

# Set library paths in @INC, at compile time
BEGIN {
  if (-e './setlib.cfg') {
    unshift @INC, '.';
  } elsif (-e '../bin/setlib.cfg') {
    unshift @INC, '../bin';
  }
  $Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
  $ENV{FOSWIKI_ACTION} = 'mattworker';
  require 'setlib.cfg';
}

use Foswiki ();
use Foswiki::UI ();
launchWorker();

our %mattworker_data;

sub _idle {
    shift->push_write(json => {type => 'worker_idle', cache_fields => ['groups_members', 'web_acls'] });
}

sub launchWorker {
    my $exitWorker = AnyEvent->condvar;
    AE::signal INT => sub { $exitWorker->send; };

    my @read; @read = (json => sub {
        my ($hdl, $json) = @_;

        my $t = $json->{type};
        my $host = $json->{host};
        local $ENV{HTTP_HOST} = $host if defined $host;
        $mattworker_data{type} = $t;
        $mattworker_data{data} = $json->{data};

        my $doit;
        if ($ENV{VIRTUALHOSTS}) {
            $doit = sub {
                use Foswiki::Contrib::VirtualHostingContrib::VirtualHost ();
                Foswiki::Contrib::VirtualHostingContrib::VirtualHost->run_on($host, sub { $Foswiki::engine->run(); } );
            };
        } else {
            $doit = sub {
                $Foswiki::engine->run(),
            };
        }

        if ($t =~ m'update_topic|update_web') {
            $mattworker_data{caches} = $json->{cache};
            eval { $doit->(); };
            if ($@) {
                print "Worker: $t exception: $@\n";
            } else {
                for my $c ('groups_members', 'web_acls') {
                    $hdl->push_write(json => {
                        type => 'set_cache',
                        host => $host,
                        data => {key => $c, value => $mattworker_data{caches}{$c}},
                    });
                }
            }
        } elsif ($t eq 'flush_acls') {
            print "Flush web ACL cache\n";
            $hdl->push_write(json => {type => 'clear_cache', host => $host});
        } elsif ($t eq 'flush_groups') {
            print "Flush group membership cache\n";
            $hdl->push_write(json => {type => 'clear_cache', host => $host});
        } elsif ($t eq 'exit_worker') {
            $exitWorker->send;
            return;
        }

        _idle($hdl);
        $hdl->push_read(@read);
    });
    my $hdl = new AnyEvent::Handle(
        connect => ['127.0.0.1', 8090],
        on_connect => sub {
            my $hdl = shift;
            _idle($hdl);
            $hdl->push_read(@read);
        },
        on_connect_error => sub {
            print "Worker: failed to connect to MATT daemon: $!\n";
            exit();
        },
        on_eof => sub {
            print "Worker: MATT daemon closed the connection, exiting\n";
            exit();
        },
        on_error => sub {
            my ($hdl, $fatal, $message) = @_;
            print "Worker: error in connection to MATT daemon: $message\n";
            exit();
        },
    );
    $exitWorker->recv;
    $hdl->destroy;
}
1;


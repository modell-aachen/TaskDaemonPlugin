require 5.004;
use strict;
use warnings;

package MATTDaemon;
use AnyEvent::Handle;
use AnyEvent::Socket;

use constant DEBUG => 1;

my @todos = ();
my $hosts = {};

sub run {
    my $dir = $ENV{FOSWIKI_DIR};
    unless($dir) {
        print "Please set FOSWIKI_DIR to your Foswiki installation\n";
        return;
    }
    unless(chdir("$dir/bin")) {
       print "Could not change into $dir/bin\n";
       return;
    }
    my $quitMatt = AnyEvent->condvar;
    my %clients;
    my @queue;
    my %waiting_workers;

    tcp_server('127.0.0.1', 8090, sub {
            my ($fh, $host, $port) = @_;
            my $cid = "$host:$port";
            print "client connected from $cid\n";
            my $buffer;
            my $disconnect = sub {
                print "client at $cid disconnected\n";
                delete $clients{$cid};
                delete $waiting_workers{$cid};
            };
            my $hdl = new AnyEvent::Handle(fh => $fh);
            $hdl->on_read(sub {
                $hdl->push_read(json => sub {
                        my ($hdl, $json) = @_;
                        my $type = $json->{type};
                        my $host = $json->{host} || 'default';

                        unless ($type) {
                            $hdl->push_write(json => {
                                    status => 'error',
                                    msg => 'message was missing type arg'
                            });
                            return;
                        }
                        if ($type eq 'worker_idle') {
                            if (@queue) {
                                $hdl->push_write(json => shift @queue);
                            } else {
                                $waiting_workers{$cid} = $hdl;
                            }
                        } elsif ($type eq 'getCache') {
                            $hdl->push_write(json => $hosts->{$host}{$json->{data}});
                        } elsif ($type eq 'setCache') {
                            $hosts->{$host} ||= {};
                            $hosts->{$host}{$json->{data}{key}} = $json->{data}{value};
                        } elsif ($type eq 'clearCache') {
                            undef $hosts->{$host};
                        } elsif ($type eq 'harakiri') {
                            foreach (keys %waiting_workers) {
                                $waiting_workers{$_}->push_write(json => {type => 'exit_worker'});
                                $disconnect->($_);
                            }
                        } else {
                            print "$json->{type}: $json->{data}\n" if DEBUG;
                            if (keys %waiting_workers) {
                                my ($worker) = keys %waiting_workers;
                                my $whdl = delete $waiting_workers{$worker};
                                $whdl->push_write(json => $json);
                            } else {
                                push @queue, $json;
                            }
                            $hdl->push_write(json => {status => 'ok', msg => 'queued'});
                        }
                });
            });
            $clients{$cid} = $hdl;
            $hdl->on_eof($disconnect);
            $hdl->on_error($disconnect);
        });
    $quitMatt->recv;
}

run();

1;

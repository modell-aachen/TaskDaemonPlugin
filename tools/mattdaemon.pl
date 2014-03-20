require 5.004;
use strict;
use warnings;

package MATTDaemon;
use AnyEvent::Handle;
use AnyEvent::Socket;

my $dir = '/srv/www/1.1.8/open';

use constant DEBUG => 1;
my @todos = ();

sub run {
    chdir("$dir/bin") or die "Could not change into $dir/bin";
    my $quitMatt = AnyEvent->condvar;
    my %clients;
    my @queue;
    my %waiting_workers;

    tcp_server('127.0.0.1', 8090, sub {
            my ($fh, $host, $port) = @_;
            my $cid = "$host:$port";
            print "client connected from $host:$port\n";
            my $buffer;
            my $disconnect = sub {
                my $id = shift || $cid;
                delete $clients{$id};
                delete $waiting_workers{$id};
            };
            my $hdl = new AnyEvent::Handle(fh => $fh);
            $hdl->on_read(sub {
                $hdl->push_read(json => sub {
                        my ($hdl, $json) = @_;

                        unless ($json->{type}) {
                            $hdl->push_write(json => {
                                    status => 'error',
                                    msg => 'message was missing type arg'
                            });
                            return;
                        }
                        if ($json->{type} eq 'update_topic' || $json->{type} eq 'update_web') {
                            print "$json->{type}: $json->{data}\n" if DEBUG;
                            if (keys %waiting_workers) {
                                my ($worker) = keys %waiting_workers;
                                my $whdl = delete $waiting_workers{$worker};
                                $whdl->push_write(json => $json);
                            } else {
                                push @queue, $json;
                            }
                            $hdl->push_write(json => {status => 'ok', msg => 'queued'});
                        } elsif ($json->{type} eq 'worker_idle') {
                            if (@queue) {
                                $hdl->push_write(json => shift @queue);
                            } else {
                                $waiting_workers{$cid} = $hdl;
                            }
                        } elsif ($json->{type} eq 'harakiri') {
                            foreach (keys %waiting_workers) {
                                $waiting_workers{$_}->push_write(json => {type => 'exit_worker'});
                                $disconnect->($_);
                            }
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

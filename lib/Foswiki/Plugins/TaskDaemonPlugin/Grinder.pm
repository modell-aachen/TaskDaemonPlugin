use strict;
use warnings;

{
    handle_message => sub {
        my ($host, $t, $hdl, $run_engine, $json) = @_;
        if ($t =~ m'create_event') {
            # getContainer
            #
            # XXX Konzeptuluieren
            # Container
            #  * webtopic
            #  * status
            #  * uid
            #  * squashedinfo
            #
            # Event
            #  * Container
            #  * Payload
        } elsif ($t eq 'update_event') {
        }
    },
};

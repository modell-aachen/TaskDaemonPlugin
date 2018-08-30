use strict;
use warnings;

use JSON;
use Encode qw(encode);

{
    handle_message => sub {
        my ($host, $type, $hdl, $run_engine, $json) = @_;

        eval {
            my $data = from_json($json->{data});
            push (@ARGV, encode('UTF-8', "/" . $data->{webtopic})); # XXX
            $Foswiki::engine->{user} = $data->{user};
            $run_engine->();
            pop @ARGV;
        };
        if($@) {
            print STDERR $@;
        }

        return {};
    },
    engine_part => sub {
        my ($session, $type, $data, $caches) = @_;

        my $json = from_json($data);
        if($json->{callback}){
            eval {
                "$json->{callback}"->grinder($session, $type, $data, $caches);
            };
            if($@) {
                print STDERR $@;
                Foswiki::Func::writeWarning("Grinder called, but the callback-Plugin has no grinder-method ($@)");
            }
        } else {
            Foswiki::Func::writeWarning("Grinder called, but no callback was found");
        }
    },
};

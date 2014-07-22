#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('TaskDaemonPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

=begin TML

You can do a lot more with the build system if you want; for example, to add
a new target, you could do this:

<verbatim>
{
    package MyModuleBuild;
    our @ISA = qw( Foswiki::Contrib::Build );

    sub new {
        my $class = shift;
        return bless( $class->SUPER::new( "MyModule" ), $class );
    }

    sub target_mytarget {
        my $this = shift;
        # Do other build stuff here
    }
}

# Create the build object
my $build = new MyModuleBuild();
</verbatim>

You can also specify a different default target server for uploads.
This can be any web on any accessible Foswiki installation.
These defaults will be used when expanding tokens in .txt
files, but be warned, they can be overridden at upload time!

<verbatim>
# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://foswiki.org/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';
</verbatim>

=cut


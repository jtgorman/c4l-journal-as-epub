#!/usr/bin/env perl

use strict ;
use warnings ;

use Test::More ;
use create_epub ;

my $input    = 't/test_dom_cleanup/input.html' ;
my $output   = 't/test_dom_cleanup/output.html' ;
my $expected = 't/test_dom_cleanup/expected.html' ;

use Digest::MD5 qw( md5 ) ;
use File::Slurp ;

use Mojo ;


# should probably make the tests more fine grained by testing each
# function in turn...

my $input_lines = read_file( $input ) ;
my $dom = Mojo::DOM->new( $input_lines ) ;

create_epub::clean_up_internal_links( $dom ) ;
create_epub::remove_sidebar( $dom ) ;
create_epub::remove_login( $dom ) ;
create_epub::remove_comments( $dom ) ;

# apparently write_file does not utf8 encode on way out...
# and we need to?
open(my $FH, ">:encoding(UTF-8)", $output)
      or die "Failed to open file - $!";

write_file $FH, "$dom" ;

#ok, need to normalize if we're going to do this
is( md5( $output ),
    md5( $expected) ) ;

done_testing ;

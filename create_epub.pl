#!/usr/env perl

use strict ;
use warnings ;

# Original process, experimenting with things
# Right now treating perl as a superduper shell script,
# but in long run could replace almost all these steps with
# perl modules

my $url = $ARGV[0] ;
my $issue_id = 0;

# this was a hack that gets the articles and the associated
# content, or at least some of it.

#wget http://journal.code4lib.org/issues/issue1/feed/doaj
#mv doaj toc.xml
#xsltproc get_links.xslt toc.xml | xargs -n 1 -i{} wget -r -l 1 --no-parent  -k {}
#xsltproc get_links.xslt toc.xml | xargs -n 1 -i{} wget -r -l 1 -A jpg,jpeg,png,gif -k {}

use LWP ;
use File::Path qw( make_path ) ;


print "processing $url \n" ;
# TODO: Add in Log4perl

if ( $url =~ /^\s*https?:\/\/(.*)/ ) {
    # we don't want the prefix, mostly for 
    $url = $1 ;
    print "Chopped url to $url\n" ;
}

if( $url =~ /(issue[^\/s]+)\// ) {
    $issue_id = $1;
    print "Issue id will be $issue_id \n";
}


make_path( $issue_id . '/' . $url ) ;

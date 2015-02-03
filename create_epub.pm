#!/usr/env perl

package create_epub ;

use strict ;
use warnings ;

use LWP::UserAgent ;

use XML::LibXML ;

use File::Copy ;
use File::Slurp ;
use File::Find ;

use Mojo ;

use EBook::EPUB ;

__PACKAGE__->run() unless caller;

sub run {

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
    
    # may need to use ile::path make_path if need
    # to create recusive structure, but looking
    # at manual attempt, not going to follow url
    # structure anyhow
    mkdir( $issue_id ) ;
    
    my $ua = LWP::UserAgent->new ;
    $ua->agent("Code4Lib Epub Maker Scraper") ;
    
    my $request = HTTP::Request->new(POST => 'http://' . $url ) ;
    
    my $result = $ua->request( $request ) ;
    
    if( ! ($result->is_success ) ) {
        die( 'Failure! ' . $result->status_line ) ;
    }
    
    
    my $toc_xml = $result->content()  ;
    
    open my $toc_xml_fh, '>', $issue_id . '/toc.xml' or die "Can't save table of contents source xml file" ;
    print $toc_xml_fh $toc_xml ;
    close $toc_xml_fh ;
    
    

    # so we want to do two things with this table of contents:
    # 1) use the table of contents to loop over the
    #    various documents and download them into
    #    the issue directory we just created
    # 2) build up an index type page
    
    download_articles( $issue_id, $toc_xml ) ;
    
    clean_up( $issue_id ) ;
    
    create_index_page( $issue_id, $toc_xml ) ;
    
    # once that's all done I think we can just zip up the content
    # to create an epub
    
    package_epub( $issue_id ) ;
}

sub package_epub {

    my $issue_id = shift ;
    my $epub = EBook::EPUB->new ;

    $epub->add_title("Code4Lib $issue_id") ;
    $epub->add_language('en') ;


    # could create epub object
    find( sub{ process_epub_file( $epub, $_, $File::Find::name ) ; },
          $issue_id ) ;

    $epub->pack_zip("$issue_id.epub") ;
}

sub process_epub_file {

    my $epub = shift ;
    my $file = shift ;
    my $full_path = shift ;
    
    if( -f $file && $file =~ /\.x?html?$/) {
        $epub->copy_xhtml( $file, $full_path ) ;
    }
    elsif( -f $file && $file =~ /\.css$/) {
        $epub->copy_stylesheet( $file, $full_path ) ;
    }
    elsif( -f $file && $file =~ /.xml/) {
        #ignore now 
    }
    elsif( -f $file && $file =~ /(\.png|\.jpg)/) {
        
        $epub->copy_file( $file, $full_path, "image/$1" ) ;
    }

}

sub download_articles {

    my $issue_id = shift ;
    my $toc_xml  = shift ;

    my $parser = XML::LibXML->new() ;
    my $dom = $parser->load_xml( string => $toc_xml ) ;

    my $url_nodes = $dom->findnodes( '//fullTextUrl' ) ;
    foreach my $url_node ($url_nodes->get_nodelist() ) {
        my $text_nodes = $url_node->findnodes( 'text()' ) ;
        my $article_url ;
        foreach my $text_node ($text_nodes->get_nodelist()) {
            $article_url .= $text_node->data ;
        }
        print $article_url . "\n" ;
        print "Processing $article_url \n " ;
        download_article( $issue_id, $article_url ) ;
        
    }
    # be nice! waiting a wee bit
    sleep(2) ;

 
}

sub download_article {
    my $issue_id = shift;
    my $article_url = shift ;

    #TODO: look at LWP and stuff
    chdir( $issue_id ) ;

    print `wget -r -l 1 --no-parent --convert-links $article_url` ;
    print `wget -r -l 1 -A jpg,jpeg,png,gif --convert-links $article_url` ;

    
    if( $article_url =~ /\/(\d+)\/?$/) {
        fix_article_index_page( $1 ) ;
    }    
    chdir( '..' ) ;
}

sub fix_article_index_page {

   # I'm not quite sure why, but with the structure of
    # wordpress & using wget this way  it creates a directory and also
    # a html file (ie 39/ and 39.1)
    #
    # For now trying just to move any of those files into
    # the corresponding file as index.html

    
    
    my $article_id = shift;
    move( "journal.code4lib.org/articles/${article_id}.1",
          "journal.code4lib.org/articles/${article_id}/index.html" ) ;
    
}

sub create_index_page {

    my $issue_id = shift ;
    my $toc_xml  = shift ;

    # crappy hack, but works for now
    print `xsltproc create_index.xsl $issue_id/toc.xml > $issue_id/index.html`;

}

# if I could fix wget or use a different spider
# this probably wouldn't be an issue
sub clean_up {

    my $issue_id = shift ;

    # clean up links
    find(\&wanted, $issue_id) ;

    find(\&celan_up
}


sub wanted {
    
    if( -f $_ && $_ =~ /\.html?$/ ) {
        print "Cleaning up links on $File::Find::name  \n" ;

        my $lines = read_file( $_ ) ;
        my $dom = Mojo::DOM->new( $lines ) ;
        
        for my $link ($dom->find('a[href]')->each) {
            #$link->attr(rel => 'nofollow')
            #    if $link->attr('href') !~ m(\Ahttps?://www[.]myforum[.]com(?:/|\z));
            my $prev_link_value = $link->attr('href') ;
            print $prev_link_value . "\n" ;
            if( $prev_link_value =~ m{https?://journal.code4lib.org/(articles|media|wp-content)} ) {
                my $new_link_value = $prev_link_value ; 
                $new_link_value =~ s{https?://}{} ;
                print "Changing to $new_link_value \n" ;
                $link->attr( href => $new_link_value ) ;
            }
        }
        
        write_file "${_}~", "$dom";
        rename "${_}~" => $_ ;
    }
}

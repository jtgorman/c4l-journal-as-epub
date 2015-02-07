#!/usr/env perl

package create_epub ;

use strict ;
use warnings ;

use LWP::UserAgent ;

use XML::LibXML ;

use File::Copy ;
use File::Slurp ;
use File::Find ;

# for correcting some stuff in the DOM
use Mojo ;

#for transforming html -> xhtml strict
# html tidy seems a wrapper around a fork of the tidy
# libraries. For now just going to call out to
# the tidy cli
#use HTML::Tidy ;


use EBook::EPUB ;

use List::MoreUtils qw(natatime);

use Cwd ;
use File::chdir;

my $skip_download = 0 ;
__PACKAGE__->run() unless caller;

sub run {


    use Getopt::Long ;
    GetOptions( 'skip-download' => \$skip_download ) ;


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
    
    my @article_ids = download_articles( $issue_id, $toc_xml ) ;

    fix_index_locations( $issue_id, @article_ids ) ;
    
    
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

    # hmmm, now we need to add nav points
    # add_navpoint(%opts)
    #  class
    #  content
    #  id 
    #  play_order
    #  label 

    $epub->add_navpoint( {content => "$issue_id/index.html",
                          label   => 'Table of Contents',
                          play_order => 1,
                          id => 'pub-toc'} ) ;


    add_article_nav( $epub,
                     $issue_id ) ;
                     
    $epub->pack_zip("$issue_id.epub") ;
}

sub fix_index_locations {

    my $issue_id = shift ;
    my @article_ids = @_ ;

    use Data::Dumper ;
    
    print Dumper( \@article_ids ) ;
    
    local $CWD = $issue_id ;

    
    # seem to be some issues w/ timing, so 
    # doing this next step after all the downloads...
    sleep(1) ;

    foreach my $article_id (@article_ids) {

        print "fixing $article_id index pages\n" ;
        print "Currently at " . getcwd() . "\n";
        
        fix_article_index_page('journal.code4lib.org/articles',
                               $article_id ) ;
    }    
}

sub add_article_nav {


    my $epub = shift ;
    my $issue_id = shift ;
    
    my $lines = read_file( $issue_id . '/toc.xml' ) ;
    my $dom = Mojo::DOM->new( $lines ) ;

    # want thetitle & fullTextUrl of each record
    # ideally as hash
    my $records_filtered = natatime 2, $dom->find('title, fullTextUrl')->map('text')->each ;
    my $order = 2 ;
    while( my @field = $records_filtered->() ) {
        my $title = $field[0] ;
        my $url = $field[1] ; 
        
        my $uri = $url ;
        $uri =~ s{\s*https?://}{} ;

        print "Adding  $title (${uri}) to nav points\n" ;
        $epub->add_navpoint( { content => "${issue_id}/${uri}/index.html",
                               label   => $title,
                               play_order => $order,
                               id => 'article' . ($order - 1 ),
                           } ) ;
        $order++ ; 
    }
}
sub process_epub_file {

    my $epub = shift ;
    my $file = shift ;
    my $full_path = shift ;

    print "Procesing $file at $full_path \n" ;
    
    if( -f $file && $file =~ /\.x?html?$/) {
        print "html spotted, processing \n" ;
        $epub->copy_xhtml( $file, $full_path ) ;
    }
    elsif( -f $file && $file =~ /\.css$/) {
            print "css spotted, processing \n" ;
        $epub->copy_stylesheet( $file, $full_path ) ;
    }
    elsif( -f $file && $file =~ /.xml/) {
        #ignore now 
    }
    elsif( -f $file && $file =~ /(\.png|\.jpg)/) {
        print "image spotted, copying\n" ;
        $epub->copy_file( $file, $full_path, "image/$1" ) ;
    }

}

sub download_articles {
    
    my $issue_id = shift ;
    my $toc_xml  = shift ;
    
    my @article_ids = ();
    
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
        print "Processing _${article_url}_ \n " ;
        download_article( $issue_id, $article_url ) ;

        if( $article_url =~ m{/(\d+)/?\s*$}x ) {
            push( @article_ids, $1 ) ;
        }
    }

    return @article_ids ;
 
}



sub download_article {
    my $issue_id = shift;
    my $article_url = shift ;

    print "downloading article -> $article_url\n" ;
    #TODO: look at LWP and stuff
    local $CWD =  $issue_id  ;

    if( ! $skip_download ) {
        my $results = `wget -nc -p -k --no-parent  $article_url` ;
        #        $results .= `wget -r -l 1 -A jpg,jpeg,png,gif --convert-links $article_url` ;
    }
    # be nice! waiting a wee bit
    sleep(2) ;

}

#might want to change so using file paths
sub fix_article_index_page {

    my $article_path = shift ;
    my $article_id = shift ;

    local $CWD  = $article_path ;
    # I'm not quite sure why, but with the structure of
    # wordpress & using wget this way  it creates a directory and also
    # a html file (ie 39/ and 39.1)
    #
    # For now trying just to move any of those files into
    # the corresponding file as index.html

    # occasionally there's just a file that's the article id
    print "Looking for $article_id, current at $CWD \n " ;
    
    if( -d $article_id && -f ($article_id . '.1') ) {
        print "found directory & file \n" ;
        move( "${article_id}.1",
              "${article_id}/index.html" ) ;
    }
    elsif( -e $article_id && -f $article_id) {
        print "just found file \n" ;
        move( $article_id,
              "${article_id}~" ) ;

        mkdir( $article_id ) ;

        move( "${article_id}~",
              $article_id . '/index.html' ) ;
    }
    print "finished fixing article index path for $article_id at $article_path  \n" ;
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

    # not the most efficient way to do this..
    # TODO: refactor so just one recursive patha nd clean up all html in one go
    #       Either pass around the dom object or just have a pass
    #       of functions 
    

    find(\&clean_up_html, $issue_id ) ;
}

sub clean_up_html {
    
    if( -f $_ && $_ =~ /\.html?$/ ) {

        my $lines = read_file( $_ ) ;
        my $dom = Mojo::DOM->new( $lines ) ;
        
        print "Cleaning up $File::Find::name  \n" ;
        
        clean_up_internal_links( $dom ) ;
        remove_sidebar( $dom ) ;
        remove_login( $dom ) ;
        remove_comments( $dom ) ;

        # apparently write_file does not utf8 encode on way out...
        # and we need to? ugh.
        open(my $FH, ">:encoding(UTF-8)", "${_}~")
            or die "Failed to open file - $!";

        write_file $FH, "$dom";
        rename "${_}~" => $_ ;

        # Unfortuantly the "xhtml transitional" of
        # the ournal pages..isn't actually valid xhtml
        # which leads to wanrings, going to see if can't avoid that

        #my $tidy = HTML::Tidy->new( { output_xhtml => 1, tidy_mark = 0  } ) ;
        my $msg = `tidy -utf8 -asxhtml -m  $_` ;



    }

    
}

sub remove_login {
    
    my $dom = shift ;
    $dom->find( q{div[id="login"]} )->each( sub {$_->remove()} ) ;
    $dom->find( q{p[id="login"]} )->each( sub {$_->remove()} ) ;
}

sub remove_sidebar {

    my $dom = shift ;
    $dom->find( q{div[id="meta"]})->each( sub { $_-> remove() } ) ;
    
}

sub remove_comments {
    my $dom = shift ;
    $dom->find( q{div[class="comments"]} )->each( sub { $_ -> remove() } ) ;
}

sub clean_up_internal_links {

    my $dom = shift ;
    for my $link ($dom->find('a[href],link[href]')->each) {
        my $prev_link_value = $link->attr('href') ;
        
        if( $prev_link_value =~ m{https?://journal.code4lib.org/(articles|media|wp-content)} ) {
            my $new_link_value = $prev_link_value ; 
            $new_link_value =~ s{https?://}{} ;
            #           print "Changing to $new_link_value \n" ;
            $link->attr( href => $new_link_value ) ;
        }
        elsif( $prev_link_value =~ m{^../(articles|media|wp-content)} ) {
            # ok, since we moved this down a level, need to bump up
            # the ../
            # could also just replace w/ paths, probably should do for css
            my $new_link_value = '../' .$prev_link_value ; 
            $link->attr( href => $new_link_value ) ;
            
        }
        
    }
    
    for my $link ($dom->find('img[src]')->each) {
        my $prev_link_value = $link->attr('src') ;
        if( $prev_link_value =~ m{^../(articles|media|wp-content)} ) {
            # ok, since we moved this down a level, need to bump up
            # the ../
            # could also just replace w/ paths, probably should do for css
            my $new_link_value = '../' .$prev_link_value ; 
            $link->attr( src => $new_link_value ) ;
            
        }
    }
}

__END__

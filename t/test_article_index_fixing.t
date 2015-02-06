#!/usr/bin/env perl

use strict ;
use warnings ;

use Test::More ;

use File::Path qw(remove_tree make_path);

use File::Find ;

use create_epub ;

my $article_url = 'http://journal.code4lib.org/articles/10'; 
$article_url =~ m{(\d+)/?\s*$} ;
my $article_id =  $1 ;
is( $article_id, 10 ) ;

my $issue_id = 'fake_issue' ;

set_up_dir_and_file_1( $issue_id,
                       $article_id ) ;

my $test_article_dir_1 = 't/test_dir_and_file_1/'
           . $issue_id
           . '/journal.code4lib.org/articles/' ;

ok(-e $test_article_dir_1 . $article_id . '.1' ) ;


create_epub::fix_article_index_page( $test_article_dir_1, 10 ) ;

ok( -e $test_article_dir_1 . $article_id . "/index.html" ) ;

ok( !( -e $test_article_dir_1 . $article_id . '.1' ) ) ;

tear_down_dir_and_file( 1 ) ;


set_up_dir_and_file_2(  $issue_id,
                        $article_id ) ;


my $test_dir_2 = 't/test_dir_and_file_2/'
        . $issue_id . '/' 
        . '/journal.code4lib.org/articles/' ;
       
ok( -e  $test_dir_2 . $article_id );

ok( ! -e   $test_dir_2
         .  $article_id
         . '/index.html' );

create_epub::fix_article_index_page( $test_dir_2, 10  ) ;

ok( ! -f $test_dir_2 . $article_id );

ok( -e $test_dir_2 . $article_id . '/index.html' );

tear_down_dir_and_file( 2 ) ;
    
#http://journal.code4lib.org/articles/10375
#http://journal.code4lib.org/articles/10279
#http://journal.code4lib.org/articles/10328
#http://journal.code4lib.org/articles/10311
#http://journal.code4lib.org/articles/10269
#http://journal.code4lib.org/articles/10350
#http://journal.code4lib.org/articles/10293

    
done_testing() ;

sub set_up_dir_and_file_1 {

    my $test_case_no = 1; 
    my $issue_id   = shift ;
    my $article_id = shift ;

    my $test_dir = 't/test_dir_and_file_'
                 . $test_case_no . '/'
                 . $issue_id . '/' 
                 . '/journal.code4lib.org/articles/' ;


    make_path(  $test_dir . '/' . $article_id )  ;
    open my $test_fh, '>', $test_dir . '/' . $article_id . '.1' ;
    print $test_fh "<html><head><title>Test $article_id</title></head><body><h1>$article_id</body></html>" ;
    close $test_fh ;

    
    #maybe make actual html file?

    
    
}

sub set_up_dir_and_file_2 {

    my $test_case_no = 2; 
    my $issue_id   = shift ;
    my $article_id = shift ;

    my $test_dir = 't/test_dir_and_file_2/'
                  . $issue_id . '/' 
                 . '/journal.code4lib.org/articles/' ;


    make_path(  $test_dir  )  ;
    open my $test_fh_2, '>', $test_dir . '/' . $article_id ;

    print $test_fh_2 "<html><head><title>Test $article_id</title></head><body><h1>$article_id</body></html>" ;

    close $test_fh_2 ;

    
    #maybe make actual html file?

    
    
}

sub tear_down_dir_and_file {

    my $test_case_no = shift ;
    my $test_dir = 't/test_dir_and_file_' . $test_case_no ;

    remove_tree( $test_dir ) ;

}

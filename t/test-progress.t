#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use YAML::Any qw/DumpFile/;
use File::Spec;

my $dir;
## Create config settings required by plugin
BEGIN {
    $dir = File::Temp->newdir(CLEANUP => 0);
    my $file = File::Spec->catfile($dir, 'config.yml');
    DumpFile($file, { plugins => { ProgressStatus => { dir => "$dir" }}});

    $ENV{DANCER_CONFDIR} = "$dir/";
};

use Dancer2;
use Dancer2::Test;

use_ok('Dancer2::Plugin::ProgressStatus');


get '/test_progress_status_simple_with_no_args' => sub {
    start_progress_status('test');

    update_progress_status( 'test', 10 );

    update_progress_status( 'test', 20 );

    return 'ok';
};

get '/test_progress_status_with_args' => sub {
    start_progress_status({
        name     => 'test2',
        total    => 200,
        count    => 0,
        override => 1,
    });

    update_progress_status( 'test2', 10, 'Message1' );

    update_progress_status( 'test2', 110, 'Message2' );

    return 'ok';
};

get '/test_progress_status_good_concurrency' => sub {
    start_progress_status({
        name    => 'test3',
        total   => 200,
        overide => 1,
    });
    start_progress_status('test3'); # This should override the first

    return 'ok';
};

## This test is skipped below
get '/test_progress_status_bad_concurrency' => sub {
    if ( fork() == 0 ) {
        start_progress_status({
            name     => 'test4',
            total    => 200,
            override => 1
        });
        exit;
    }
    else {
        wait;

        start_progress_status('test4'); # This should die
    }

    return 'ok';
};

my $response = dancer_response( GET => '/test_progress_status_simple_with_no_args' );
is( $response->status, 200, '200 response when setting and updating progress' );
$response = dancer_response( GET => '/_progressstatus/test' );
my $data = from_json($response->content);
is($response->status, 200, 'Get good response from progressstatus');
is($data->{total}, 100, 'Total is 100');
is($data->{count}, $data->{total}, 'Count matches total');

$response = dancer_response( GET => '/test_progress_status_with_args' );
is( $response->status, 200, '200 response for less simple progress' );
$response = dancer_response( GET => '/_progressstatus/test2' );
$data = from_json($response->content);
is($data->{total}, 200, 'Total is 200');
is($data->{count}, $data->{total}, 'Count matches total');


$response = dancer_response( GET => '/test_progress_status_good_concurrency' );
is($response->status, 200, 'Two progress meters with the same name and same pid pass');
$response = dancer_response( GET => '/_progressstatus/test3' );
$data = from_json($response->content);
is($data->{total}, 100, 'Total is overriden');

SKIP: {
    skip 'This test requires manual clean up', 1;
    $response = dancer_response( GET => '/test_progress_status_bad_concurrency' );
    is($response->status, 500, 'Two progress meters with different pid fail');
}

done_testing(11);

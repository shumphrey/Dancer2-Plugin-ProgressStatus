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
    my $prog = start_progress_status('test');
    $prog++;
    $prog++; # count should be 2

    return 'ok';
};

get '/test_progress_status_with_args' => sub {
    my $prog = start_progress_status({
        name     => 'test2',
        total    => 200,
        count    => 0,
    });

    $prog++;
    $prog++;
    $prog++;
    $prog->add_message('Message1');
    $prog->add_message('Message2');
    # count should be 3 and messages should be size 2

    return 'ok';
};

get '/test_progress_status_good_concurrency' => sub {
    my $prog1 = start_progress_status({
        name    => 'test3',
        total   => 200,
    });
    my $prog2 = eval { start_progress_status('test3') }; # This should die

    if ( $@ ) {
        return $@;
    }

    return 'ok';
};

# Test progress status with an extra identifier
get '/test_progress_with_progress_id' => sub {
    my $prog = start_progress_status();

    return 'ok';
};

my $response = dancer_response( GET => '/test_progress_status_simple_with_no_args' );
is( $response->status, 200, '200 response when setting and updating progress' );
$response = dancer_response( GET => '/_progress_status/test' );
my $data = from_json($response->content);
is($response->status, 200, 'Get good response from progressstatus');
is($data->{total}, 100, 'Total is 100');
is($data->{count}, 2, 'Count matches total');
ok(!$data->{in_progress}, 'No longer in progress');

$response = dancer_response( GET => '/test_progress_status_with_args' );
is( $response->status, 200, '200 response for less simple progress' );
$response = dancer_response( GET => '/_progress_status/test2' );
$data = from_json($response->content);
is($data->{total}, 200, 'Total is 200');
is($data->{count}, 3, 'Count matches total');
is(scalar(@{$data->{messages}}), 2, 'Has two messages');
ok(!$data->{in_progress}, 'No longer in progress');


$response = dancer_response( GET => '/test_progress_status_good_concurrency' );
is($response->status, 200, 'Two progress meters with the same name and same pid pass');
like($response->content, qr/^Progress status test3 already exists/, 'two unfinished progress meters with the same name dies');
$response = dancer_response( GET => '/_progress_status/test3' );
$data = from_json($response->content);
is($data->{total}, 200, 'Total is overriden');

## Test progress status with automatic ID
$response = dancer_response( GET => '/test_progress_with_progress_id', {
    params => {
        progress_id => 1000
    }   
});
is($response->status, 200, '200 response for progress with progress id');

$response = dancer_response( GET => '/_progress_status/1000' );
is($response->status, 200, 'Get good response from progressstatus');
my $data = from_json($response->content);
is($data->{total}, 100, 'Get a sensible response');


done_testing(14);

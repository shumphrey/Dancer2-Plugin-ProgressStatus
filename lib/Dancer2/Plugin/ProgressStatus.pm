# ABSTRACT: Keeps track of progress status
=head1 NAME

Dancer2::Plugin::ProgressStatus

=head1 DESCRIPTION

Records and fetches progress entries.

This module allows your route to start a progress status meter and update it
whilst your long running task is in progress.
How you break up the running task is up to you.

Whilst the long running task is in progress, an AJAX GET request can be made to
C</_progress_status/:name> to fetch JSON serialized data representing the
progress status that matches :name

This progress module does not depend on an event loop based webserver such as
L<Twiggy> as the long running request and the query to fetch the progress
can be issued entirely separately.

It does currently depend on the webserver being hosted on one machine and uses
local file storage for the progress data and as such is probably not suitable
for a production environment at this time.

=head1 SYNOPSIS

  get '/route' => sub {
    my $progress = start_progress_status({ name => 'progress1', total => 100 });
    while($some_condition) {
        # .. do some slow running stuff
        $progress++; # add's one to the progress
        $progress->add_message('an update message');
    }

    // $progress goes out of scope here and automatically ends the progress meter
  };

Then with some javascript on the front end, something like this:

  function checkProgress() {
      $.getJSON('/_progress_status/progress1', function(data) {
         if ( !data.in_progress ) {
            console.log("Finished progress1");
            return;
         }
         setTimeout(function() {
            checkProgress,
            3000
         });
      })
  }

=head1 CONFIG

  plugins:
    ProgressStatus:
      dir: "/tmp/dancer_progress"

The only plugin setting currently understood is where to store the progress
data. This is required.

=head1 SEE ALSO

L<Dancer2>

=head1 METHODS

=over

=cut

package Dancer2::Plugin::ProgressStatus;

use strict;
use warnings;

use Digest::MD5 qw/md5_hex/;
use Path::Tiny;
use Carp;
use JSON qw//;

use Dancer2::Plugin;
use Dancer2::Plugin::ProgressStatus::Object;

sub _progress_status_file {
    my ( $dsl, $name ) = @_;

    my $dir = $dsl->config->{'plugins'}->{ProgressStatus}->{dir}
                or croak 'No ProgressStatus plugin settings in config';

    return Path::Tiny::path($dir, md5_hex($name));
}


on_plugin_import {
    my $dsl = shift;

    # determine if there is a prefix?

    # Register the route for fetching messages
    $dsl->app->add_route(
        method  => 'get',
        regexp  => '/_progress_status/:name',
        code    => sub {
            my $context = shift;
            my $data = _get_progress_status_data($dsl, $context->request->params->{'name'});
            $context->response->content_type('application/json');

            return JSON->new->encode($data);
        },
    );
};

sub _get_progress_status_data {
    my ($dsl, $name) = @_;

    my $file = $dsl->_progress_status_file($name);
    if ( !$file->is_file ) {
        return {
            error  => "No such progress status $name",
            status => 'error',
        };
    }
    my $data = JSON->new->decode($file->slurp_utf8());
    delete $data->{pid};

    return $data;
}


=item start_progress_status

  my $prog = set_progress_status({ name => "MyProgressStatus" });

Registers a new progress status for this session and automatically creates
a route for returning data about the progress status.

Returns a progress object that you can use to set the progress.
e.g.

  $prog++;
  $prog->add_message();
  $prog->increment(10);

If an existing progress status with this name already exists and is currently
in progress this call will die without affecting the original status.
Either wrap this in an eval, use
L<Dancer2::Plugin::ProgressStatus/is_progress_running> or ensure by some other
means that two progress meters don't start at the same time.

The route for querying the progress status is defined as:

  GET /_progress_status/:name

It returns a JSON serialized structure something like:

  {
    total: 100,
    count: 20,
    messages: [ "array of messages" ],
    in_progress: true
    status: 'some status message'
  }

When the progress object goes out of scope in_progress is automatically
set to false.

set_progress_status takes a C<name> (required), a C<total> (defaults to 100)
a C<count> (defaults to 0), and C<messages> an optional arrayref of message
strings.

=cut
register start_progress_status => sub {
    my ($dsl, $args) = @_;

    if ( !ref($args) ) {
        $args = { name => $args };
    }

    my $name = delete($args->{name}) or croak 'Must supply progress name';

    my $file = $dsl->_progress_status_file($name);
    if ( $file->is_file ) {
        my $d = JSON->new->decode($file->slurp_utf8());
        my $in_progress = $d->{in_progress};

        if ( $in_progress && $d->{pid} != $$ ) {
            if ( kill(0, $d->{pid}) ) {
                die "Progress status $name already exists for a running process, cannot create a new one\n";
            }
        }
        elsif ( $in_progress ) {
            die "Progress status $name already exists\n";
        }
    }

    my %objargs = (
        _on_save => sub {
            my ($obj, $is_finished) = @_;
            my $data = JSON->new->encode({
                total       => $obj->total,
                count       => $obj->count,
                messages    => $obj->messages,
                in_progress => $is_finished ? JSON::false : JSON::true,
                status      => $obj->status,
                pid         => $$,
            });

            $file->spew_utf8($data);
        },
    );

    foreach my $key (qw/total count status messages/) {
        if ( $args->{$key} ) {
            $objargs{$key} = $args->{$key};
        }
    }

    my $obj = Dancer2::Plugin::ProgressStatus::Object->new(%objargs);
    $obj->save();
    return $obj;
};

=item is_progress_running

  my $bool = is_progress_running($name);

Returns true if there is a running progress by this name.
L<Dancer2::Plugin::ProgressStatus/start_progess_status> dies if two
progress meters with the same name start at the same time so this can be used
to confirm without catching the start call in an eval.

=cut
register is_progress_running => sub {
    my ( $dsl, $name ) = @_;
    my $file = $dsl->_progress_status_file($name);

    if ( $file->exists ) {
        my $d = JSON->new->decode($file->slurp_utf8());
        my $in_progress = $d->{in_progress};

        if ( $in_progress && $d->{pid} != $$ && kill(0, $d->{pid}) ) {
            return 1;
        }
    }
    return 0;
};


register_plugin;

=back

=cut

1;


# ABSTRACT: Keeps track of progress status
=head1 NAME

Dancer2::Plugin::ProgressStatus

=head1 DESCRIPTION

Records and fetches progress entries.

This module allows your route to start a progress status meter and update it
whilst your long running task is in progress.
How you break up the running task is up to you.

Whilst the long running task is in progress, an AJAX GET request can be made to
C</_progressstatus/:name> to fetch JSON serialized data representing the
progress status that matches :name

This progress module does not depend on an event loop based webserver such as
L<Twiggy> as the long running request and the query to fetch the progress
can be issued entirely separately.

It does currently depend on the webserver being hosted on one machine and uses
local file storage for the progress data and as such is probably not suitable
for a production environment at this time.

=head1 SYNOPSIS

  get '/route' => sub {
    start_progress_status({ name => 'progress1', total => 100 });
    while($some_condition) {
        # .. do some slow running stuff
        update_progress_status('progress1', 'an update message');
    }
  };

Then with some javascript on the front end, something like this:

  function checkProgress() {
      $.getJSON('/_progressstatus/progress1', function(data) {
         if ( data.finished == true ) {
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
data.
Will use a temporary directory if no config settings are supplied.

=head1 SEE ALSO

L<Dancer2>

=head1 METHODS

=over

=cut

package Dancer2::Plugin::ProgressStatus;

use v5.14;
use strict;
use warnings;

use Dancer2::Plugin;

use Digest::MD5 qw/md5_hex/;
use Path::Tiny;
use Carp;
use JSON qw//;

has '_progressstatus_base_dir' => (
    is      => 'ro',
    default => sub {
        my ( $dsl ) = @_;

        my $settings = plugin_setting;
        my $dir = $settings->{dir} or croak 'No ProgressStatus plugin settings in config';
        return $dir;
    },
);
sub _progressstatus_file {
    my ( $dsl, $name ) = @_;

    return path($dsl->_progressstatus_base_dir, md5_hex($name));
}


on_plugin_import {
    my $dsl = shift;

    # determine if there is a prefix?

    # Register the route for fetching messages
    $dsl->app->add_route(
        method  => 'get',
        regexp  => '/_progressstatus/:name',
        code    => sub {
            my $context = shift;
            my $data = _get_progressstatus_data($dsl, $context->request->params->{'name'});
            $context->response->content_type('application/json');

            return JSON->new->encode($data);
        },
    );
};

sub _get_progressstatus_data {
    my ($dsl, $name) = @_;

    my $file = $dsl->_progressstatus_file($name);
    if ( !$file->is_file ) {
        die "No such progress status $name";
    }
    my $data = JSON->new->decode($file->slurp_utf8());
    delete $data->{pid};

    return $data;
}

sub _set_progressstatus_data {
    my ($dsl, $name, $args) = @_;

    my $total    = $args->{total}    || 100;
    my $count    = $args->{count}    || 0;
    my $messages = $args->{messages} || [];
    my $update   = $args->{update}   || 0;
    my $override = $args->{override} || 0;

    my $json = JSON->new;
    my $file = $dsl->_progressstatus_file($name);

    my $data = {};
    if ( $file->is_file ) {
        my $d = $json->decode($file->slurp_utf8());
        my $in_progress = $d->{in_progress};

        if ( $in_progress && !$override && $d->{pid} != $$ ) {
            if ( kill 0, $d->{pid} ) {
                die "Progress status already exists for a running process, and override is not specified\n";
            }
        }
        
        if ( $update ) {
            $data = $d;
        }
    }

    $data->{total}     ||= $total;
    $data->{count}       = $count;
    $data->{messages}  ||= [];
    $data->{pid}         = $$;
    $data->{in_progress} = JSON::true;

    if ( $args->{finished} ) {
        $data->{in_progress} = JSON::false;
        $data->{count} = $data->{total};
    }

    push @{$data->{messages}}, @$messages;
    $file->spew_utf8($json->encode($data));
}

sub _delete_progressstatus_data {
    my ($dsl, $name) = @_;
    my $file = $dsl->_progressstatus_file($name);
    if ( $file->is_file ) {
        $file->remove or die "Failed to unlink $file";
    }
}


=item start_progress_status

  set_progress_status({
    name => "MyProgressStatus",
  });

Registers a new progress status for this session and automatically creates
a route for returning data about the progress status.

If an existing progress status with this name already exists and is currently
in progress for a different pid then this call will die, if the pid is the same
the second one will override the first.
It is up to the app code to prevent multiple progress statuses with
the same name from running at the same time.

The route for querying the progress status is defined as:

  GET /_progressstatus/:name

It returns a JSON serialized structure something like:

  {
    total: 100,
    count: 20,
    messages: [ "array of messages" ],
    in_progress: 1
  }

Additionally, an after hook is defined to automatically set in_progress to
false and count to total when the route finishes.

set_progress_status takes a C<name> (required), a C<total> (defaults to 100)
a C<count> (defaults to 0), and C<messages> an optional arrayref of message
strings.

=cut
register start_progress_status => sub {
    my ($dsl, $args) = @_;

    if ( !ref($args) ) {
        $args = { name => $args };
    }

    my $name             = delete($args->{name}) or croak 'Must supply progress name';
    my $delete_on_finish = delete($args->{delete_on_finish}) || 0;
    my $end_message      = delete($args->{end_message}) || "Finished $name";
    my $path             = $dsl->request->path;

    $dsl->_set_progressstatus_data($name, $args);

    # Register the hook that will update the progress status
    # When the route finishes
    my $hook = Dancer2::Core::Hook->new(
        name => 'after',
        code => sub {
            my $response = shift;

            if ( $dsl->request->path eq $path ) {
                $dsl->_set_progressstatus_data($name, {
                    update   => 1,
                    finished => 1,
                    messages => [$end_message],
                });
                
                if ( $delete_on_finish ) {
                    $dsl->_delete_progressstatus_data($name);
                }
            }
        }
    );
    $dsl->app->add_hook($hook);
};

=item update_progress_status

Updates an existing progress status with new data

=cut
register update_progress_status => sub {
    my ( $dsl, $name, $count, @messages ) = @_;

    $dsl->_set_progressstatus_data($name, {
        count    => $count,
        messages => \@messages,
        update   => 1,
    });
};


register_plugin;

=back

=cut

1;


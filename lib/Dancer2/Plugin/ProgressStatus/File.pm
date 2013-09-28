=head1 NAME

Dancer2::Plugin::ProgressStatus::File

=head1 DESCRIPTION

An object that represents a progress status.

=head1 SYNOPSIS

  $progress++;
  $progress->add_message('everything is going swimmingly');

=head1 AUTHOR

Steven Humphrey

=head1 METHODS

=over

=cut

package Dancer2::Plugin::ProgressStatus::File;

use strict;
use warnings;

use Moo;
use Scalar::Util qw/looks_like_number/;
use JSON;

use overload
    '++' => \&increment,
    '--' => \&decrement,
    '+'  => \&increment,
    '-'  => \&decrement;

has total => (
    is      => 'ro',
    isa     => sub { die 'total must be a number' unless looks_like_number($_[0]) },
    default => sub { 100 }
);
has count => (
    is      => 'rw',
    isa     => sub { die 'count must be a number' unless looks_like_number($_[0]) },
    default => sub { 0 }
);
has messages => (
    is      => 'ro',
    default => sub { [] },
);
has status => (
    is      => 'rw',
    default => sub { 'in progress' },
);

has _file => (
    is      => 'ro',
    isa     => sub {
        die '_file needs a Path::Tiny object' unless ref($_[0]) eq 'Path::Tiny';
    }
);

has _file_pid => (
    is => 'ro',
);


after [qw/status count/] => sub {
    if ( $_[1] ) {
        $_[0]->save();
    }
};

sub finish {
    my ( $self ) = @_;

    $self->save(1);
}

=item save

You shouldn't need to call this.
Any use of increment, decrement, ++, --, add_message, status, count, etc
will automatically call save.

=cut
sub save {
    my ( $self, $is_finished ) = @_;

    my $data = JSON->new->encode({
        total       => $self->total,
        count       => $self->count,
        messages    => $self->messages,
        in_progress => $is_finished ? JSON::false : JSON::true,
        status      => $self->status,
        pid         => $$,
    });

    $self->_file->spew_utf8($data);
}

=item increment

Adds a specified amount to the count (defaults to 1)

  $prog->increment(10);

Can also add messages at the same time

  $prog->increment(10, 'updating count by 10');

=cut
sub increment {
    my ( $self, $increment, @messages ) = @_;

    $increment ||= 1;
    $self->count($self->count + $increment);
    if ( @messages ) {
        push @{$self->messages}, @messages;
    }
    $self->save();
}

=item decrement

Decrement a specified amount from the count (defaults to 1)

  $prog->decrement(10);

Can also add messages at the same time

  $prog->decrement(10, 'reducing count by 10');

=cut
sub decrement {
    my ( $self, $increment, @messages ) = @_;
    $increment ||= 1;
    $self->count($self->count - $increment);
    if ( @messages ) {
        push @{$self->messages}, @messages;
    }
    $self->save();
}

=item add_message

Adds one or more string messages to the status data.

  $prog->add_message('a simple message');

=cut
sub add_message {
    my ( $self, @messages ) = @_;

    push @{$self->messages}, @messages;
    $self->save();
}

=item delete

Peranently removes the status file.

  $prog->delete();

This will remove the status file and any query on this progress will return a
hash with status set to 'error'.

=cut
sub delete {
    $_[0]->_file->remove or die "Failed to unlink $_[0]->_file";
}


sub DESTROY {
    $_[0]->finish();
}

no Moo;

=back

=cut

1;


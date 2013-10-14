=head1 NAME

Dancer2::Plugin::ProgressStatus::Object

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

package Dancer2::Plugin::ProgressStatus::Object;

use strict;
use warnings;

use Moo;
use Scalar::Util qw/looks_like_number/;

use overload
    '++' => sub { my ($self, $i) = @_; $self->increment($i) },
    '--' => sub { my ($self, $i) = @_; $self->decrement($i) },
    '='  => sub { $_[0] }; # should never clone this object

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

has _on_save => (
    is       => 'ro',
    required => 1,
    isa      => sub { die 'needs _on_save coderef' unless ref($_[0]) eq 'CODE' },
);

has start_time => (
    is   => 'rw',
    default => sub { time(); }
);

has current_time => (
    is   => 'rw',
    default => sub { time(); }
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
    $self->current_time(time());
    $self->_on_save->($self, $is_finished);
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

sub DESTROY {
    $_[0]->finish();
}

no Moo;

=back

=cut

1;


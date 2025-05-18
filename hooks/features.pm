#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Minio v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('2.7.10');
  return $obj;
}

sub perform {
  my ($self) = @_;

  foreach my $feature (@{$self->{features}}) {
    if ($feature =~ /^(self-signed-cert|provided-cert|distributed)$/) {
      $self->add_feature($feature);
    } else {
      bail(
        "Feature [$feature] not supported in this context.".
        " Supported features are: self-signed-cert, provided-cert, and distributed."
      );
    }
  }

  # Validate required features
  if (!$self->has_feature('self-signed-cert') && !$self->has_feature('provided-cert')) {
    bail(
      "You must select either 'self-signed-cert' feature, or 'provided-cert'."
    );
  }

  # Validate distributed configuration
  if ($self->has_feature('distributed')) {
    my $num_nodes = $self->env->lookup('params.num_minio_nodes');
    if (!defined($num_nodes)) {
      bail(
        "Your manifest is missing num_minio_nodes. Please edit your manifest\n".
        "and try again. For more help, please see MANUAL.md"
      );
    }
    if ($num_nodes < 4 || $num_nodes > 32 || $num_nodes % 2 != 0) {
      bail(
        "Invalid number of Minio nodes for HA. It must be greater than 4, less\n".
        "than 32, and evenly divisible by 2."
      );
    }
  }

  return $self->done();
}

1;

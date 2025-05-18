#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::Minio v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/info/;
use parent qw(Genesis::Hook::PostDeploy);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('2.7.10');
  return $self;
}

sub perform {
  my ($self) = @_;

  if ($self->deploy_successful) {
    info("\n\n".
         "#M{$ENV{GENESIS_ENVIRONMENT}} Minio deployed!\n".
         "\n".
         "For details about the deployment, run\n".
         "\n".
         "  #G{$ENV{GENESIS_CALL_ENV} info}\n".
         "\n".
         "To visit the Minio page:\n".
         "\n".
         "  #G{$ENV{GENESIS_CALL_ENV} do -- visit}\n".
         "\n".
         "To download s3, a CLI tool used to interact with Minio's S3 APIs:\n".
         "\n".
         "  #G{$ENV{GENESIS_CALL_ENV} do -- download-s3}\n".
         "\n".
         "To exec s3 commands with the appropriate envvars set:\n".
         "\n".
         "  #G{$ENV{GENESIS_CALL_ENV} do -- s3 <command>}\n".
         "\n");
  }

  # Call parent class methods if needed
  $self->SUPER::perform() if $self->can('SUPER::perform');

  # Mark the hook as completed successfully
  return $self->done(1);
}

1;

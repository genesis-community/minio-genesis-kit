#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::Minio v1.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('2.7.10');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};

  # Get credentials
  my $accesskey = $self->vault->get("$vault_prefix/access_token:accesskey");
  my $secretkey = $self->vault->get("$vault_prefix/access_token:secretkey");

  # Display information
  info("#B{Minio Information}\n".
       "\nMinio endpoint\n".
       "\t#C{%s}\n".
       "\nMinio credentials\n".
       "\tusername: #M{%s}\n".
       "\tpassword: #G{%s}",
       $env->exodus_lookup('url'),
       $accesskey,
       $secretkey);

  return $self->done();
}

1;

#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Minio::S3 v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('2.7.10');
  return $obj;
}

sub cmd_details {
  return "Execute 's3' commands with the appropriate environment variables set.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if s3 command exists
  my $local = 0;
  my ($out, $rc) = run('command -v ./s3 > /dev/null');
  if ($rc == 0) {
    $local = 1;
  } else {
    ($out, $rc) = run('command -v s3 > /dev/null');
    if ($rc != 0) {
      bail("#R{[ERROR]} Cannot find '#C{s3}' command -- use download-s3 addon to download it to somewhere in your path");
    }
  }

  # Get access credentials
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};
  my $user = $self->vault->get("$vault_prefix/access_token:accesskey");
  my $pass = $self->vault->get("$vault_prefix/access_token:secretkey");
  my $minio_url = $env->exodus_lookup('url');

  # Set environment variables and run s3 command
  my %env_vars = (
    S3_AKI => $user,
    S3_KEY => $pass,
    S3_URL => $minio_url,
    S3_USE_PATH => 'yes',
  );

  # Add S3_INSECURE if using self-signed certificate
  if ($env->exodus_lookup('self-signed')) {
    $env_vars{S3_INSECURE} = '1';
  }

  # Build environment variable string for run
  my $env_string = join(' ', map { "$_='$env_vars{$_}'" } keys %env_vars);

  # Run s3 command with environment variables
  ($out, $rc) = run({ interactive => 1 }, "$env_string s3 " . join(' ', @{$self->{args}}));
  if ($rc != 0) {
    bail("Failed to run s3 command: %s", $out);
  }

  return $self->done(1);
}

1;

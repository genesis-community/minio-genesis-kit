#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Minio::Open v1.0.0;

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
  return "Open the Minio web console in a browser (macOS only).\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if open command exists (macOS)
  my ($out, $rc) = run('command -v open >/dev/null 2>&1');
  if ($rc != 0) {
    $env->notify("The 'open' addon script only works on macOS, currently.");
    return $self->done(0);
  }

  # Get access credentials
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};
  my $user = $self->vault->get("$vault_prefix/access_token:accesskey");
  my $pass = $self->vault->get("$vault_prefix/access_token:secretkey");
  my $minio_url = $env->exodus_lookup('url');

  # Display credentials
  info("You will need to enter the following credentials once the page opens: \n".
       "\n".
       "  \033[1m\033[1;36m accesskey: \033[0m %s\n".
       "  \033[1m\033[1;36m secretkey: \033[0m %s\n",
       $user, $pass);

  # Prompt to open
  run('read -n 1 -s -r -p "Press any key to open the web console..."');

  # Open the URL
  ($out, $rc) = run('open "$1"', $minio_url);
  if ($rc != 0) {
    bail("Failed to open browser: %s", $out);
  }

  return $self->done(1);
}

1;

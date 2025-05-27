#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::Minio v1.0.0;

use strict;
use warnings;
use v5.20;

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis;
use Genesis::UI qw(prompt_for_boolean);

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{features} = [];
  $obj->check_minimum_genesis_version('2.7.10');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Handle SSL certificate configuration
  my $ssl_cert_feature = $self->_configure_ssl();
  push @{$self->{features}}, $ssl_cert_feature;

  # Handle external domain
  my $external_domain = $self->_get_external_domain();

  # Handle distributed configuration
  my $num_minio_nodes = $self->_configure_distribution();

  # Create environment file
  $self->_create_environment_file($external_domain, $num_minio_nodes);

  # Offer environment editor
  $self->_offer_environment_editor();

  return $self->done();
}

sub _configure_ssl {
  my ($self) = @_;

  info("\nMinio will be running on HTTPS, and as such, needs an SSL cert/key.");

  my $ssl_cert_feature;
  prompt_for('ssl_cert_feature', 'select',
    "Do you have an SSL certificate for Minio, or do you need a self-signed cert?",
    '-o "[provided-cert]I have my own certificate for Minio"',
    '-o "[self-signed-cert]Please have Genesis create a self-signed certificate for Minio"',
    \$ssl_cert_feature);

  if ($ssl_cert_feature eq "provided-cert") {
    my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};

    my $certificate;
    prompt_for("$vault_prefix/ssl/server:certificate", 'secret-block',
      "What is the SSL certificate for Minio?", \$certificate);

    my $key;
    prompt_for("$vault_prefix/ssl/server:key", 'secret-block',
      "What is the SSL key for Minio?", \$key);
  }

  return $ssl_cert_feature;
}

sub _get_external_domain {
  my ($self) = @_;

  info("\nThe external domain for Minio is the DNS entry users will use to access".
       "\nMinio. You can specify the IP address if you don't have a DNS entry. Do".
       "\nnot include 'https://' in this value.");

  my $external_domain;
  prompt_for('external_domain', 'line', "External Domain or IP:", '-i', \$external_domain);

  return $external_domain;
}

sub _configure_distribution {
  my ($self) = @_;

  info("\nWould you like to setup a distributed Minio install? This is a RAID-like".
       "\ninstallation that requires at least 4 Minio instances that replicate data for".
       "\nhigh-availibility and protection against data rot.");

  my $distribute;
  prompt_for('distribute', 'boolean', "", \$distribute);

  my $num_minio_nodes = 1;
  if ($distribute eq "true") {
    info("\nHow many instances of Minio would you like to deploy? It must be at least 4,".
         "\nat most 32, and evenly divisable by 2. (e.g. {4,6,8,...,32})");

    $num_minio_nodes = $self->_ask_for_num_of_nodes();
    push @{$self->{features}}, "distributed";
  }

  return $num_minio_nodes;
}

sub _ask_for_num_of_nodes {
  my ($self) = @_;

  my $num_minio_nodes;
  prompt_for('num_minio_nodes', 'line',
    "How many Minio VMs would you like - between 4 and 12?",
    '-V "4-32"',
    '--default "4"',
    \$num_minio_nodes);

  if ($num_minio_nodes < 4 || $num_minio_nodes % 2 != 0 || $num_minio_nodes > 32) {
    return $self->_ask_for_num_of_nodes();
  }

  return $num_minio_nodes;
}

sub _create_environment_file {
  my ($self, $external_domain, $num_minio_nodes) = @_;

  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">>", $env_file or die "Cannot open $env_file for writing: $!";

  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features:\n";

  foreach my $feature (@{$self->{features}}) {
    print $fh "    - $feature\n";
  }

  # Generate and add the genesis_config_block
  my ($out, $rc) = run('genesis_config_block');
  bail("Failed to generate genesis_config_block") if $rc;
  print $fh $out;

  print $fh "params:\n";
  print $fh "  external_domain: $external_domain\n";
  print $fh "  num_minio_nodes: $num_minio_nodes\n";
  print $fh "  network:         minio\n";

  close $fh;
}

sub _offer_environment_editor {
  my ($self) = @_;
  my ($out, $rc) = run({ interactive => 1 }, 'offer_environment_editor');
  bail("Failed to offer environment editor") if $rc;
}

1;

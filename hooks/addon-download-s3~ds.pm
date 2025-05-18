#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Minio::DownloadS3 v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run error/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('2.7.10');
  return $obj;
}

sub cmd_details {
  return "Download 's3', a CLI tool for interacting with S3 APIs.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'p=s',   # Platform
    'sync',  # Sync with existing s3
  ]);

  # Default path to current directory
  my $path = ".";

  # Process non-option arguments (path)
  if (@{$self->{args}}) {
    $path = $self->{args}[0];
  }

  # Handle sync option
  if ($options{sync}) {
    if ($path ne ".") {
      bail("#R{[ERROR]} Can't specify a path and use --sync option");
    }

    my ($out, $rc) = run('command -v s3 2>/dev/null');
    if ($rc != 0 || !$out) {
      bail("#R{[ERROR]} No s3 found in path -- cannot use --sync option");
    }

    $path = $out;
    chomp($path);

    # Check write permission
    my ($perm_out, $perm_rc) = run('test -w "$1"', $path);
    if ($perm_rc != 0) {
      bail("#R{[ERROR]} No write permission to $path -- cannot use --sync option");
    }
  }

  # Determine platform
  my $platform = $options{p} || $ENV{OSTYPE} || "";

  if ($platform =~ /darwin|mac/i) {
    $platform = 'darwin';
  } elsif ($platform =~ /linux/i) {
    $platform = 'linux';
  } elsif ($platform =~ /cygwin|win/i) {
    $platform = 'windows';
  } else {
    if ($options{p}) {
      bail("#R{[ERROR]} Unknown platform type '$platform': expecting one of darwin or linux");
    } else {
      bail("#R{[ERROR]} Cannot determine platform type: please specify one of darwin or linux using the -p option");
    }
  }

  # If path is a directory, append /s3
  if (-d $path) {
    $path = "$path/s3";
  }

  # Get the latest release URL
  my ($url_out, $url_rc) = run('curl -s "https://api.github.com/repos/jhunt/s3/releases/latest" | grep browser_download_url | grep $1 | cut -d \'"\'f 4', $platform);
  if ($url_rc != 0 || !$url_out) {
    bail("Failed to determine download URL for platform $platform");
  }
  chomp($url_out);
  my $url = $url_out;

  # Download the file
  info("\nDownloading #C{%s/amd64} version of s3 from #C{%s}...\n", $platform, $url);

  my ($dl_out, $dl_rc) = run('curl -o "$1" -w "%{http_code}" -Lk "$2"', $path, $url);
  if ($dl_rc != 0 || $dl_out ne '200') {
    bail("#R{[ERROR]} Failed to download s3 (Status: $dl_out)");
  }

  # Make executable
  my ($chmod_out, $chmod_rc) = run('chmod a+x "$1"', $path);
  if ($chmod_rc != 0) {
    bail("Failed to make s3 executable: $chmod_out");
  }

  # Get access credentials
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};
  my $user = $self->vault->get("$vault_prefix/access_token:accesskey");
  my $pass = $self->vault->get("$vault_prefix/access_token:secretkey");
  my $minio_url = $env->exodus_lookup('url');

  # Display success message
  info("\n#G{Download successful - written to} #C{%s}\n".
       "\nTo target this Minio instance with 's3', you'll need these envvars:\n".
       "\nexport S3_AKI=%s\n".
       "export S3_KEY=%s\n".
       "export S3_URL=%s\n".
       "\nYou should source this binary in your PATH.\n",
       $path, $user, $pass, $minio_url);

  return $self->done(1);
}

1;

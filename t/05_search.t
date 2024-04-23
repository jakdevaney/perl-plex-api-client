#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Test::More; 
plan tests => 1;

use PlexTV;
use Data::Dumper;

my @SEARCH_SUBS = qw(
  search
  search_hub
  voice_search
  get_search_results
  
);

can_ok('PlexTV', @SEARCH_SUBS);

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

my $hub_search = $plex->search_hub();

exit;
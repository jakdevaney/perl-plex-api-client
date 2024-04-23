#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Test::More; 
plan tests => 8;

use PlexTV;
use Data::Dumper;

my @UTIL_SUBS = qw(
  get_search_type_id
  get_search_type_name
  get_tag_type_id
  get_tag_type_name
  replace_secrets
  _build_parameters
);

can_ok('PlexTV', @UTIL_SUBS);


my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);


my $search_type_id = $plex->get_search_type_id('movie');
is($search_type_id, 1, 'Check get search type ID');


my $search_type_name = $plex->get_search_type_name(2);
is($search_type_name, 'show', 'Check get search type name');


my $tag_type_id = $plex->get_tag_type_id('role');
is($tag_type_id, 6, 'Check get tag type ID');


my $tag_type_name = $plex->get_tag_type_name(318);
is($tag_type_name, 'studio', 'Check get tag type name');


my $secret_string = $plex->{url} . '?' . $plex->{token_parameter};
$secret_string = $plex->replace_secrets($secret_string);
like($secret_string, qr/X-Plex-Token=\*{5}/, 'Check secrets have been hidden');


my $parameters = { studio => 'marvel', actor => 'Tom', magic => undef };
my $parameter_string = $plex->_build_parameters($parameters);
is($parameter_string, 'actor=Tom&studio=marvel', 'Check parameter building');


my $filters = [ 'year<=2002', 'studio=marvel,sony' ];
my $filter_string = $plex->_build_parameters($parameters, $filters);
is($parameter_string, 'actor=Tom&studio=marvel&year<=2002&studio=marvel,sony', 'Check parameter with filters building');


exit;
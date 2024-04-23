#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Data::Dumper;
use Test::More; 
plan tests => 14;

require_ok('PlexTV');
require_ok('PlexTV::MyPlex');

use PlexTV;
use PlexTV::MyPlex;

my $plex = new_ok('PlexTV', undef, 'plex');
is($plex->{mode}, 'perl', 'Check default output mode');


# TODO rethink output mode, per call? or maybe good as is?
$plex->set_mode('min');
is($plex->{mode}, 'min', 'Check set output mode');


$plex->set_mode('error');
is($plex->{mode}, 'perl', 'Check set output mode with bad mode');

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $server_metadata = $plex->connect($host, $port, $token);

isa_ok($plex->{client}, 'REST::Client');
is($plex->{host}, $host, 'Check host is set');
is($plex->{port}, $port, 'Check port is set');
is($plex->{url}, "https://$host:$port/", 'Check url is set');
is($plex->{token}, $token, 'Check token is set');
is($plex->{token_parameter}, "X-Plex-Token=$token", 'Check token parameter is set');
is($plex->{uri_base}, 'server://31559f5533f49bdb5eaefdb4c86cfcf7ce3fff95/com.plexapp.plugins.library/', 'Check uri base is set');
is($server_metadata->{MediaContainer}[0]->{claimed}, 1, 'Check server is claimed');

exit;
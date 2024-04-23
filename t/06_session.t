#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Test::More; 
plan tests => 1;

use PlexTV;
use Data::Dumper;

my @SESSION_SUBS = qw(
  get_active_sessions
  get_session_history
  get_transcode_sessions
  stop_transcode_session
  start_universal_transcode
  get_media_timeline
);

can_ok('PlexTV', @SESSION_SUBS);

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

my $sessions = $plex->get_active_sessions();
$sessions = $sessions->{MediaContainer}->[0];
say Dumper $sessions;
is($sessions->{size}, 0, 'Check active sessions');

my $session_history = $plex->get_session_history();
is($sessions->{size}, 0, 'Check session history');

my $transcode_sessions = $plex->get_transcode_sessions();
is($sessions->{size}, 0, 'Check transcode sessions');

my $status_code = $plex->stop_transcode_session(3);
say Dumper $status_code;

my $media_timeline = $plex->get_media_timeline();
say Dumper $media_timeline;

exit;
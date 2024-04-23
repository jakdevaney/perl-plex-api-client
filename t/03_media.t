#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Test::More;
plan tests => 8;

use PlexTV;

my @MEDIA_SUBS = qw(
  mark_media_played
  mark_media_unplayed
  update_media_progress
  get_global_hubs
  get_library_hubs
);

can_ok('PlexTV', @MEDIA_SUBS);

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

my $episode_key = '880';
my $status_code = $plex->mark_media_played($episode_key);
like($status_code, qr/2\d\d/, 'Check mark played status code');


$status_code = $plex->mark_media_unplayed($episode_key);
like($status_code, qr/2\d\d/, 'Check mark unplayed status code');


my $time = 60000 * 3; # 3 Minutes
eval { $status_code = $plex->update_media_progress($episode_key, $time, 'playuing') };
like($@, qr/^ERROR/, 'Check only valid playback status are accepted');


$status_code = $plex->update_media_progress($episode_key, $time, 'playing');
like($status_code, qr/2\d\d/, 'Check update media progress status code');


my $global_hubs = $plex->get_global_hubs();
$global_hubs = $global_hubs->{MediaContainer}->[0]->{Hub};
my @HUB_NAMES = qw(home.continue home.movies.recent home.television.recent home.music.recent home.photos.recent home.videos.recent home.playlists);
my @hub_names = map { $_->{hubIdentifier} } @{ $global_hubs };
is(@hub_names, @HUB_NAMES, 'Check global hubs');


my $hub_count = scalar @{ $global_hubs };
is($hub_count, 7, 'Check global hub count');


# TODO this shouldnt be needed, if the library is properly cleaned
my $libraries = $plex->get_all_libraries();
my $library = $libraries->{MediaContainer}->[0]->{Directory}->[0];
my $library_key = $library->{key};

my $library_hubs = $plex->get_library_hubs($library_key);
$library_hubs = $library_hubs->{MediaContainer}->[0]->{Hub};
$hub_count = scalar @{ $library_hubs };
is($hub_count, 7, 'Check library hub count');


exit;
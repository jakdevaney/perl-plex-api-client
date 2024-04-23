#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use File::Basename;
use Test::More;
use Data::Dumper;
plan tests => 8;

use PlexTV;
use Data::Dumper;

my @PLAYLIST_SUBS = qw(
  get_all_playlists
  get_playlist
  create_playlist
  delete_playlist
  delete_all_playlists
  update_playlist
  get_playlist_items
  add_item_to_playlist
  clear_playlist
  upload_playlist
);

can_ok('PlexTV', @PLAYLIST_SUBS);


my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);


my $fails = $plex->delete_all_playlists();
is($fails, 0, 'Check delete all playlists');


my $playlists = $plex->get_all_playlists();
my $playlist_count = $playlists->{MediaContainer}->[0]->{size};
is($playlist_count, 0, 'Check get all playlists');


my $SMART = 1;
my $DUMB = 0;

my $playlist = $plex->create_playlist('90s Movies', 'video', $DUMB, $plex->{uri_base} . '1');
$playlist = $playlist->{MediaContainer}->[0]->{Playlist}->[0];
is($playlist->{title}, '90s Movies', 'Check create a playlist');


my $playlist_key = $playlist->{ratingKey};


# TODO this shouldnt be needed, if the library is properly cleaned
my $libraries = $plex->get_all_libraries();
my $library = $libraries->{MediaContainer}->[0]->{Directory}->[0];
my $library_key = $library->{key};
my $items = $plex->get_library_items($library_key);
my $item_key = $items->{MediaContainer}->[0]->{Video}->[0]->{ratingKey};

my $playlist_item = $plex->add_item_to_playlist($playlist_key, $item_key);
my $item_count = $playlist_item->{MediaContainer}->[0]->{Playlist}->[0]->{leafCount};
is($item_count, 1, 'Check add item to playlist');


my $playlist_items = $plex->get_playlist_items($playlist_key, 'video');
$playlist_items = $playlist_items->{MediaContainer}->[0]->{Video}->[0];
is($playlist_items->{ratingKey}, $item_key, 'Check correct item added to playlist');


$item_count = $playlist_item->{MediaContainer}->[0]->{size};
is($item_count, 1, 'Check playlist item count');


$playlist = $plex->clear_playlist($playlist_key);
$item_count = $playlist->{MediaContainer}->[0]->{Playlist}->[0]->{leafCount};
is($item_count, 0, 'Check playlist cleared');


# TODO
#$playlist = $plex->update_playlist($playlist_filepath);
#say Dumper $playlist;

#my $status_code = $plex->delete_playlist($playlist_key);
#like($status_code, qr/2\d\d/, 'Check delete playlist status code');


# FIXME this should be a path to an m3u on the SERVER!
my $this_dir = dirname(__FILE__);
my $playlist_filepath = "$this_dir/data/test_playlist.m3u";
$playlist = $plex->upload_playlist($playlist_filepath);

exit;
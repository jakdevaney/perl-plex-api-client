#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Test::More; 
use Data::Dumper;
plan tests => 20;

use PlexTV;

my @LIBRARY_SUBS = qw(
  get_on_deck
  get_recently_added
  get_all_libraries
  get_library_details
  get_library_by_title
  add_library
  delete_library
  refresh_library
  refresh_all_libraries
  get_library_items
  get_latest_library_items
  get_common_library_items
  get_items_metadata
  get_items_children
  get_hash_value
);

can_ok('PlexTV', @LIBRARY_SUBS);

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

my $all_libraries = $plex->get_all_libraries();
$all_libraries = $all_libraries->{MediaContainer}->[0]->{Directory};
my $library_count = scalar @{ $all_libraries };
is($library_count, 4, 'Check number of libraries');


my $library_key = $all_libraries->[0]->{key};
my $library = $plex->get_library_details($library_key);
$library = $library->{MediaContainer}->[0];
is($library->{title1}, 'Movies', 'Check library title');


my $library_by_title = $plex->get_library_by_title('Movies');
is($library->{librarySectionID}, $library_by_title->{key}, 'Compare library got by title');


my $status_code = $plex->delete_library($library_key);
like($status_code, qr/2\d\d/, 'Check delete library status code');
$all_libraries = $plex->get_all_libraries()->{MediaContainer}->[0]->{Directory};
my $new_library_count = scalar @{ $all_libraries };
is($new_library_count, $library_count - 1, 'Check delete library');


$status_code = $plex->add_library('Movies', 'movie', '/data/Movies', 'tv.plex.agents.movie', 'Plex Movie', 'en-US');
like($status_code, qr/2\d\d/, 'Check add library status code');
$all_libraries = $plex->get_all_libraries()->{MediaContainer}->[0]->{Directory};
$new_library_count = scalar @{ $all_libraries };
is($new_library_count, $library_count, 'Check add library');


$library_key = $all_libraries->[1]->{key};
my $is_refreshing = $library_by_title->{refreshing};
$status_code = $plex->refresh_library($library_key);
like($status_code, qr/2\d\d/, 'Check refresh status code');
$library_by_title = $plex->get_library_by_title('Movies');
is($library_by_title->{refreshing}, 1, 'Check library is refreshing');


my $refresh_all_fails = $plex->refresh_all_libraries();
is($refresh_all_fails, 0, 'Check refresh all success');


my $library_items = $plex->get_library_items($library_key);
my $items = $library_items->{MediaContainer}->[0]->{Directory};
my $item_count = scalar @{ $items };
is($item_count, 2, 'Check all library items returned');


$library_items = $plex->get_library_items($library_key, undef, [ 'year<=2005' ]);
$items = $library_items->{MediaContainer}->[0]->{Directory};
$item_count = scalar @{ $items };
is($item_count, 1, 'Check filtered library items returned');


# TODO get some items to be returned
$library_items = $plex->get_latest_library_items($library_key);
$library = $library_items->{MediaContainer}->[0];
is($library->{title1}, 'TV', 'Check latest library items');


$library_items = $plex->get_common_library_items($library_key, 1, [ 'year>=2000' ]);
$library = $library_items->{MediaContainer}->[0];
is($library->{title1}, 'TV', 'Check common library items');


my $items_metadata = $plex->get_items_metadata('868');
my $metadata = $items_metadata->{MediaContainer}->[0]->{Directory}->[0];
is($metadata->{title}, 'Season 4', 'Check item metadata');


my $items_children = $plex->get_items_children('758');
my $children = $items_children->{MediaContainer}->[0]->{Directory};
my $child_count = scalar @{ $children };
is($child_count, 5, 'Check item children count');


sleep 3; # Wait for refreshes to finish

my $recently_added = $plex->get_recently_added();
is($recently_added->{MediaContainer}->[0]->{size}, 12, 'Check recently added count');


# TODO maybe use media subs to start, and add something to the ondeck
my $on_deck = $plex->get_on_deck();
is($on_deck->{MediaContainer}->[0]->{size}, 0, 'Check on deck');


my $hash_value = $plex->get_hash_value('file:///data/Photos/Food/bacon.jpg');
$hash_value = $hash_value->{MediaContainer}->[0];
is($hash_value->{size}, 0, 'Check hash value');
say Dumper $hash_value;

exit;
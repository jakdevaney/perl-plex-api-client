#! /usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use Data::Dumper;
use File::Basename;
use PlexTV;
use PlexTV::MyPlex;

my $container_name = "perl-plex-client-test";
my $timezone = 'Etc/UTC';
my $claim_token = _get_claim_token();
my $host_ip_address = $ENV{PLEX_CLIENT_HOST};
my $hostname = 'PerlPlexClientTest';
my $data_path = $ENV{PLEX_CLIENT_DATA_PATH}; 
my $stub_video = 'video_stub.mp4';
my $stub_audio = 'audio_stub.mp3';
my $stub_image = 'cute_cat.jpg';
my $this_dir = dirname(__FILE__);

sub _get_claim_token {
    my $my_plex = PlexTV::MyPlex->new();
    $my_plex->sign_in($ENV{PLEX_CLIENT_USERNAME}, $ENV{PLEX_CLIENT_PASSWORD});
    return $my_plex->get_claim_token();
}

sub start_docker_container {
    say 'Starting docker';
    #`docker start`;
    # TODO is docker installed? did it start correctly?

    # TODO download plex docker image

    my @docker_run_parameters = (
        '-d',
        "--name $container_name",
        '-p 32400:32400/tcp',
        '-p 3005:3005/tcp',
        '-p 8324:8324/tcp',
        '-p 32469:32469/tcp',
        '-p 1900:1900/udp',
        '-p 32410:32410/udp',
        '-p 32412:32412/udp',
        '-p 32413:32413/udp',
        '-p 32414:32414/udp',
        "-e TZ=\"$timezone\"",
        "-e PLEX_CLAIM=\"$claim_token\"",
        "-e ADVERTISE_IP=\"http://$host_ip_address:32400/\"",
        "-h \"$hostname\"",
        "-v \"$data_path/config:/config\"",
        "-v \"$data_path/transcode:/transcode\"",
        "-v \"$data_path/media:/data\"",
        "plexinc/pms-docker:latest"
    );

    my $docker_run_command = 'docker run ' . join ' ', @docker_run_parameters;
    say 'Running docker container';
    `$docker_run_command`;

    # Wait for container to start up
    sleep 12;
}

start_docker_container();

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

setup_movies($plex);
setup_shows($plex);
setup_music($plex);
setup_photos($plex);

say Dumper $plex->get_all_libraries();

sub setup_movies {
    my ($plex) = @_;
    say 'Setting up Movies library';

    my $library = $plex->get_library_by_title('Movies');
    if( not $library ) {
        say 'Adding Movies library';
        $plex->add_library('Movies', 'movie', '/data/Movies', 'tv.plex.agents.movie', 'Plex Movie', 'en-US');
    } else {
        say 'Movies library already exists';
    }

    my $movies_path = "$data_path/media/Movies";
    if( -e $movies_path ) {
        say "Movies library already exists at '$movies_path'";
    } else {
        `mkdir -v "$movies_path"`;
    }

    # TODO look at legality of using these films
    my %movies = (
        'The Matrix' => '1999',
        'The Terminator' => '1984',
        'Total Recall' => '1990',
        'Space Jam' => '1996'
    );

    for my $movie_name ( keys %movies ) {
        my $movie_year = $movies{$movie_name};

        my $movie_dir = "$this_dir/../data/media/Movies/$movie_name ($movie_year)";
        if( -e $movie_dir ) {
            say "Movie directory already exists at '$movie_dir'";
        } else {
            `mkdir -v "$movie_dir"`;
        }
        
        my $movie_path = "$movie_dir/$movie_name.mkv";
        if( -e $movie_path ) {
            say "Movie already exists at '$movie_path'";
        } else {
            `cp -v $this_dir/../data/media/$stub_video "$movie_path"`;
        }
    }

    return;
}

sub setup_shows {
    my ($plex) = @_;
    say 'Setting up TV library';

    my $library = $plex->get_library_by_title('TV');
    if( not $library ) {
        say 'Adding TV library';
        $plex->add_library('TV', 'show', '/data/TV', 'tv.plex.agents.series', 'Plex TV Series', 'en-US');
    } else {
        say 'TV library already exists';
    }

    my $tv_path = "$data_path/media/TV";
    if( -e $tv_path ) {
        say "TV library aready exists at '$tv_path'";
    } else {
        `mkdir -v "$tv_path"`;
    }

    my %shows = (
        'Lost' => [ 25,24,23 ],
        'Mr. Robot' => [ 10,12,10,13 ]
    );

    for my $show_name ( keys %shows ) {

        my $show_path = "$this_dir/../data/media/TV/$show_name";
        if( -e $show_path ) {
            say "Show directory already exists at '$show_path'";
        } else {
            `mkdir -v "$show_path"`;
        }

        my $season_episodes = $shows{$show_name};
        my $season_count = scalar @{ $season_episodes };
        for my $season ( 1 .. $season_count ) {

            my $season_path = "$this_dir/../data/media/TV/$show_name/Season $season";
            if( -e $season_path ) {
                say "Season directory already exists at '$season_path'";
            } else {
                `mkdir -v "$season_path"`;
            }

            my $episode_count = $season_episodes->[$season-1];
            for my $episode ( 1 .. $episode_count ) {
                my $episode_name = "S$season" . "E$episode.mkv";
                
                my $episode_path = "$this_dir/../data/media/TV/$show_name/Season $season/$episode_name";
                if( -e $episode_path ) {
                    say "Episode already exists at '$episode_path'";
                } else {
                    `cp -v "$this_dir/../data/media/$stub_video" "$episode_path"`;
                }
            }
        }
    }
    return;
}

sub setup_music {
    my ($plex) = @_;
    say 'Setting up Music library';

    my $library = $plex->get_library_by_title('Music');
    if( not $library ) {
        say 'Adding Music library';
        $plex->add_library('Music', 'artist', '/data/Music', 'tv.plex.agents.music', 'Plex Music', 'en-US');
    } else {
        say 'Music library already exists';
    }

    my $music_path = "$data_path/media/Music";
    if( -e $music_path ) {
        say "Music library already exists at '$music_path'";
    } else {
        `mkdir -v "$music_path"`;
    }

    my %music = (
        'Broke For Free' => {
            'Layers' => [
                '1 - As Colorful As Ever',
                '2 - Knock Knock'
    ] } );

    for my $artist_name ( keys %music ) {

        my $artist_path = "$this_dir/../data/media/Music/$artist_name";
        if( -e $artist_path ) {
            say "Artist directory already exists at '$artist_path'";
        } else {
            `mkdir "$artist_path"`;
        }

        my ($album) = keys %{ $music{$artist_name} };
        my $album_path = "$this_dir/../data/media/Music/$artist_name/$album";
        if( -e $album_path ) {
            say "Album directory already exists at '$album_path'";
        } else {
            `mkdir -v "$album_path"`;
        }

        for my $song ( @{ $music{$artist_name}->{$album} } ) {
            my $song_path = "$this_dir/../data/media/Music/$artist_name/$album/$song.mp3";
            if( -e $song_path ) {
                say "Song already exists at '$song_path'";
            } else {
                `cp -v "$this_dir/../data/media/$stub_audio" "$song_path"`;
            }
        }
    }
    return;
}

sub setup_photos {
    my ($plex) = @_;
    say 'Setting up Photos library';

    my $library = $plex->get_library_by_title('Photos');
    if( not $library ) {
        say 'Adding Photos library';
        $plex->add_library('Photos', 'photo', '/data/Photos', 'com.plexapp.agents.none', 'Plex Photo Scanner', 'xn');
    } else {
        say 'Photos library already exists';
    }

    my $photos_path = "$data_path/media/Photos";
    if( -e $photos_path ) {
        say "Photos directory already exists at '$photos_path'";
    } else {
        `mkdir -v '$photos_path'`;
    }

    my @photos = qw(cheese lettuce tomato bacon turkey);  

    for my $photo ( @photos ) {
        my $photo_path = "$this_dir/../data/media/Photos/Food/$photo.jpg";
        if( -e $photo_path ) {
            say "Photo already exists at '$photo_path'";
        } else {
            `cp -v "$this_dir/../data/media/$stub_image" "$photo_path"`;
        }
    }
    return;
}

exit 0;
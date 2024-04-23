package PlexTV;

use strict;
use warnings;
use feature 'say';
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
use REST::Client;
use Scalar::Util qw(looks_like_number);
use URL::Encode qw(url_encode_utf8);
use XML::LibXML;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

our $VERSION = '0.0.1';

my $LIBXML_DOCUMENT_MODE = 'libxml';
my $MIN_PERL_OBJECT_MODE = 'min';
my $PERL_OBJECT_MODE     = 'perl';
my $RAW_XML_MODE         = 'raw';
my @MODES = ($LIBXML_DOCUMENT_MODE, $MIN_PERL_OBJECT_MODE, $PERL_OBJECT_MODE, $RAW_XML_MODE);

my %SEARCH_TYPES = (
    movie => 1,
    show => 2,
    season => 3,
    episode => 4,
    trailer => 5,
    comic => 6,
    person => 7,
    artist => 8,
    album => 9,
    track => 10,
    picture => 11,
    clip => 12,
    photo => 13,
    photoalbum => 14,
    playlist => 15,
    playlistFolder => 16,
    collection => 18,
    optimizedVersion => 42,
    userPlaylistItem => 1001
);
my %REVERSE_SEARCH_TYPES = reverse %SEARCH_TYPES;

sub get_search_type_id {
    my ($self, $name) = @_;
    return %SEARCH_TYPES{$name};
}

sub get_search_type_name {
    my ($self, $id) = @_;
    return %REVERSE_SEARCH_TYPES{$id};
}

my %TAG_TYPES = (
    tag => 0,
    genre => 1,
    collection => 2,
    director => 4,
    writer => 5,
    role => 6,
    producer => 7,
    country => 8,
    chapter => 9,
    review => 10,
    label => 11,
    marker => 12,
    mediaProcessingTarget => 42,
    make => 200,
    model => 201,
    aperture => 202,
    exposure => 203,
    iso => 204,
    lens => 205,
    device => 206,
    autotag => 207,
    mood => 300,
    style => 301,
    format => 302,
    similar => 305,
    concert => 306,
    banner => 311,
    poster => 312,
    art => 313,
    guid => 314,
    ratingImage => 316,
    theme => 317,
    studio => 318,
    network => 319,
    place => 400
);
my %REVERSE_TAG_TYPES = reverse %TAG_TYPES;

sub get_tag_type_id {
    my ($self, $name) = @_;
    return %TAG_TYPES{$name};
}

sub get_tag_type_name {
    my ($self, $id) = @_;
    return %REVERSE_TAG_TYPES{$id};
}

# TODO is OO needed?
# why not just mixin via 'use PlexTV qw(get_libraries get_other_things)
sub new {
    my ($class, $args) = @_;
    my $self = {};
    bless $self, $class;

    my $mode;
    if( $args ) {
        $mode = $args->{mode};
    }
    $self->set_mode($mode);
    
    return $self;
}

sub set_mode {
    my ($self, $mode_arg) = @_;
    my $mode;
    if( $mode_arg ) {
        ($mode) = grep { $_ eq $mode_arg } @MODES;
        say "WARN: Unknown output mode arg: $mode_arg" unless $mode;
    }
    $mode //= $PERL_OBJECT_MODE;
    $self->{mode} = $mode;
    say "INFO: Output mode set to: $mode";
    return;
}

sub connect {
    my ($self, $host, $port, $token) = @_;
    $self->{client} = REST::Client->new();
    $self->{host} = $host;
    $self->{port} = $port;
    $self->{token} = $token;
    $self->{url} = "https://$host:$port/";
    $self->{token_parameter} = "X-Plex-Token=$token";

    my $server_metadata = $self->get_server_metadata();
    if( not $server_metadata ) {
        say "ERROR: Could not connect to server at '$self->{url}'";
        return;
    }

    my $machine_identifier = $server_metadata->{MediaContainer}->[0]->{machineIdentifier};
    $self->{uri_base} = "server://$machine_identifier/com.plexapp.plugins.library/";
    return $server_metadata;
}

sub replace_secrets {
    my ($self, $string) = @_;
    my $secret_string = '*' x 5;
    $string =~ s/$self->{token}/$secret_string/g;
    return $string;
}

sub get {
    my ($self, $query, $method, $parameters) = @_;
    $self->query($query, $method, $parameters);
    my $xml = $self->{client}->responseContent();
    return $xml if $self->{mode} eq $RAW_XML_MODE;
    my $dom = $self->parse_xml_to_dom($xml);
    if( not $dom ) {
        say "ERROR: Could not parse xml:\n$xml";
        return;
    }
    return $dom if $self->{mode} eq $LIBXML_DOCUMENT_MODE;
    return dom_to_object($dom);
}

sub get_status_code {
    my ($self, $query, $method, $parameters) = @_;
    $self->query($query, $method, $parameters);
    return $self->{client}->responseCode();
}

sub query {
    my ($self, $path, $method, $parameters) = @_;
    $method //= 'GET';
    my $url = $self->{url} . "$path?" . $self->{token_parameter};
    $url .= "&$parameters" if $parameters;
	say "$method : $url";
	$self->{client}->$method($url);
    return;
}

sub parse_xml_to_dom {
    my($self, $xml) = @_;
    return if not $xml;
    my $dom;
    eval { $dom = XML::LibXML->load_xml(string => $xml) };
    warn $@ if $@;
    return $dom;
}

sub dom_to_object {
    my ($dom) = @_;
    my $object;
    my @elements = $dom->findnodes('./*');
    for my $element ( @elements ) {
        my %attributes = %{ $element };
        my $sub_attrs = dom_to_object($element);
        %attributes = ( %attributes, %{ $sub_attrs } ) if $sub_attrs;
        push @{ $object->{$element->nodeName} }, \%attributes;
    }
    return $object;
}

 # Uses XML::LibXML::Element's overloaded hash deref to create hashes from attributes
sub _get_attributes_from_elements {
    my ($elements) = @_;
    my @attributes = map { { %{ $_ } } } @{ $elements };
    return \@attributes;
}

# Could use URI library's query_form but it will not be sorted
sub _build_parameters {
    my ($self, $parameters, $filters) = @_;
    delete $parameters->@{ grep { not defined $parameters->{$_} } keys %{ $parameters } };
    # TODO handle array refs, create multiple
    my @parameters = map { join '=', $_ => $parameters->{$_} } sort keys %{ $parameters };
    my $parameter_string = join '&', @parameters;
    $parameter_string .= '&' if @parameters and $filters;
    $parameter_string .= join '&', @{ $filters } if $filters;
    return $parameter_string;
}

sub _build_filters {
    my ($filters) = @_;
    my $filter_string = join '&', @{ $filters } if $filters;
    return $filter_string;
}

sub get_server_metadata {
    my ($self) = @_;
    return $self->get('identity');
}

sub get_server_activities {
    my ($self) = @_;
    my $activities = $self->get('activities');
    if( $self->{mode} eq $MIN_PERL_OBJECT_MODE ) {
        my @activity_elements = $activities->findnodes('/MediaContainer/Activity');
        $activities = _get_attributes_from_elements(\@activity_elements);
    }
    return $activities;
}

sub cancel_activity {
    my ($self, $activity) = @_;
    return $self->get_status("activities/$activity", 'DELETE');
}

sub get_butler_tasks {
    my ($self) = @_;
    my $tasks = $self->get('butler');
    if( $self->{mode} eq $MIN_PERL_OBJECT_MODE ) {
        my @tasks = map { $_->textContent } $tasks->findnodes('/ButlerTasks/ButlerTask/@name');
        $tasks = \@tasks;
    }
    return $tasks;
}

sub start_all_butler_tasks {
    my ($self) = @_;
    return $self->get_status_code('butler', 'POST');
}

sub stop_all_butler_tasks {
    my ($self) = @_;
    return $self->get_status_code('butler', 'DELETE');
}

sub start_butler_task {
    my ($self, $task) = @_;
    if( $self->_is_valid_butler_task($task) ) {
        return $self->get_status_code("butler/$task", 'POST');
    }
    return;
}

sub stop_butler_task {
    my ($self, $task) = @_;
    if( $self->_is_valid_butler_task($task) ) {
        return $self->get_status_code("butler/$task", 'DELETE');
    }
    return;
}

sub _is_valid_butler_task {
    my ($self, $task) = @_;
    my $tasks = $self->get('butler');
    $tasks = $tasks->{ButlerTasks}->[0]->{ButlerTask};
    my $tasks_regex = join '|', map { $_->{name} } @{ $tasks };
    if( $task =~ /^($tasks_regex)$/ ) {
        return 1;
    }
    #my ($match) = grep { $task } map { $_->{name} } @{ $tasks };
    #if( $match ) {
    #    return 1;
    #}
    say "ERROR: Task '$task' is not a valid butler task.";
    { local $" = "\n\t"; say "Valid tasks are:\n\t@{ $tasks }"; }
    return;
}

sub check_for_update {
    my ($self, $download) = @_;
    my $parameters = $self->_build_parameters({download => $download});
    return $self->get_status_code('updater/check', 'PUT', $parameters);
}

sub apply_update {
    my ($self, $tonight) = @_;
    my $parameters = $self->_build_parameters({tonight => $tonight});
    return $self->get_status_code('updater/apply', 'PUT', $parameters);
}

sub skip_update {
    my ($self) = @_;
    return $self->get_status_code('updater/apply', 'PUT', 'skip=1');
}

sub get_update_status {
    my ($self) = @_;
    my $updates = $self->get('updater/status');
    if( $self->{mode} eq $MIN_PERL_OBJECT_MODE ) {
        my @update_elements = $updates->findnodes('/MediaContainer/Release');
        $updates = _get_attributes_from_elements(\@update_elements);
    }
    return $updates;
}

sub log {
    my ($self, $level, $message, $source) = @_;
    if( not _check_log_level($level) ) {
        return;
    }
    my $parameters = $self->_build_parameters({level=>$level, message=>$message, source=>$source});
    return $self->get_status_code('log', 'GET', $parameters);
}

#?
sub log_multiline {
    my ($self, $level, $message, $source) = @_;
    if( not _check_log_level($level) ) {
        return;
    }
    my $parameters = $self->_build_parameters({level=>$level, message=>$message, source=>$source});
    return $self->get_status_code('log', 'POST', $parameters);
}

sub download_logs {
    my ($self, $download_path) = @_;
    my $data = $self->get('diagnostics/logs');
    open my $OUT, '>', $download_path;
    print $OUT $data;
    close $OUT;
    return $self->{client}->responseCode();
}

sub download_databases {
    my ($self, $download_path) = @_;
    my $data = $self->get('diagnostics/databases');
    open my $OUT, '>', $download_path;
    print $OUT $data;
    close $OUT;
    return $self->{client}->responseCode();
}

sub _check_log_level {
    my ($level) = @_;
    if( looks_like_number($level) and $level >= 0 and $level <= 4 ) {
        return 1;
    }
    say "ERROR: Level '$level' is not a valid level.";
    say "\tLevel should be a number between 0 and 4 inclusive.";
    return;
}

# TODO return http status code instead of dom
sub enable_papertrail {
    my ($self) = @_;
    return $self->get_status_code('log/networked');
}

sub get_transient_token {
    my ($self) = @_;
    my $token = $self->get('security/token', 'GET', 'type=delegation&scope=all');
    if( $self->{mode} eq $MIN_PERL_OBJECT_MODE ) {
        ($token) = $token->findnodes('/MediaContainer/@token');
        $token = $token->value();
    }
    return $token;
}

# What is this? What is a valid source?
# Only available PMS >= 1.15.4
sub get_source_connection_info {
    my ($self, $source) = @_;
    return $self->get('security/resources', 'GET', "source=$source");
}

# What is this? What is a valid type?
# Types are 1 = video, 2 = audio, ...
sub get_hash_value {
    my ($self, $url, $type) = @_;
    if( $url !~ /^file:\/\// ) {
        say "ERROR: url must start with 'file://'";
        return;
    }
    my $parameters = $self->_build_parameters({url => $url, type => $type});
    return $self->get('library/hashes', 'GET', $parameters);
}

# TODO: more than just video (photos/music)
sub get_recently_added {
    my ($self) = @_;
    my $dom = $self->get('library/recentlyAdded');
    return $dom if $self->{mode} ne $MIN_PERL_OBJECT_MODE;

    my @elements = $dom->findnodes('//Directory|//Video');
    my $attributes = _get_attributes_from_elements(\@elements);
    my @recently_added;
    for my $element ( @{ $attributes } ) {
        my $item = "$element->{type}:$element->{ratingKey}:";
        if( $element->{type} eq 'season' ) {
            $item .= "$element->{parentTitle}:";
        }
        $item .= $element->{title};
        push @recently_added, $item;
    }
    return \@recently_added;
}

sub get_all_libraries {
    my ($self) = @_;
    return $self->get('library/sections');
}

sub get_library_details {
    my ($self, $section_id) = @_;
    return $self->get("library/sections/$section_id");
}

sub get_library_by_title {
    my ($self, $title) = @_;
    my $libraries = $self->get_all_libraries();
    $libraries = $libraries->{MediaContainer}->[0]->{Directory};
    my ($library) = grep { $_->{title} eq $title } @{ $libraries };
    return $library;
}

sub add_library {
    my ($self, $name, $type, $location, $agent, $scanner, $language) = @_;
    my $parameters = $self->_build_parameters({
        name => $name,
        type => $type,
        agent => $agent,
        scanner => $scanner,
        language => $language,
        location => url_encode_utf8($location)
    });
    return $self->get_status_code('library/sections', 'POST', $parameters);
}

sub delete_library {
    my ($self, $section_id) = @_;
    return $self->get_status_code("library/sections/$section_id", 'DELETE');
}

sub refresh_library {
    my ($self, $section_id) = @_;
    return $self->get_status_code("library/sections/$section_id/refresh");
}

sub refresh_all_libraries {
    my ($self) = @_;
    my $libraries = $self->get_all_libraries();
    $libraries = $libraries->{MediaContainer}->[0]->{Directory};
    my $fails = 0;
    for my $library_key ( map { $_->{key} } @{ $libraries } ) {
        my $status_code = $self->refresh_library($library_key);
        $fails++ if $status_code !~ /2\d\d/;
    }
    return $fails;
}

sub get_library_items {
    my ($self, $section_id, $type, $filters) = @_;
    my $parameters = $self->_build_parameters({ type => $type }, $filters );
    return $self->get("library/sections/$section_id/all", 'GET', $parameters);
}

sub get_latest_library_items {
    my ($self, $section_id, $type, $filters) = @_;
    my $parameters = $self->_build_parameters({ type => $type }, $filters);
    return $self->get("library/sections/$section_id/latest", 'GET', $parameters);
}

sub get_common_library_items {
    my ($self, $section_id, $type, $filters) = @_;
    my $parameters = $self->_build_parameters({ type => $type }, $filters);
    return $self->get("library/sections/$section_id/common", 'GET', $parameters);
}

sub get_items_metadata {
    my ($self, $rating_key) = @_;
    return $self->get("library/metadata/$rating_key");
}

sub get_items_children {
    my ($self, $rating_key) = @_;
    return $self->get("library/metadata/$rating_key/children");
}

sub get_on_deck {
    my ($self) = @_;
    return $self->get('library/onDeck');
}

sub mark_media_played {
    my ($self, $key) = @_;
    return $self->get_status_code(':/scrobble', 'GET', "key=$key&identifier=com.plexapp.plugins.library");
}

sub mark_media_unplayed {
    my ($self, $key) = @_;
    return $self->get_status_code(':/unscrobble', 'GET', "key=$key&identifier=com.plexapp.plugins.library");
}

my @VALID_PLAYBACK_STATES = qw(playing played stopped);
sub _is_valid_playback_state {
    my $state = shift;
    return grep /$state/, @VALID_PLAYBACK_STATES;
}

sub update_media_progress {
    my ($self, $key, $time, $state) = @_;
    $state //= 'stopped';
    if( not _is_valid_playback_state($state) ) {
        die "ERROR: State '$state' is not a valid playback state.";
        { local $" = "\n\t"; say "Valid playblack states are:\n\t@VALID_PLAYBACK_STATES"; }
        return;
    }
    my $parameters = "key=$key&time=$time&state=$state&identifier=com.plexapp.plugins.library";
    return $self->get_status_code(':/progress', 'GET', $parameters);
}

sub get_global_hubs {
    my ($self, $count, $only_transient) = @_;
    my $parameters = $self->_build_parameters({count => $count, onlyTransient => $only_transient});
    return $self->get('hubs', 'GET', $parameters);
}

sub get_library_hubs {
    my ($self, $section_id, $count, $only_transient) = @_;
    my $parameters = $self->_build_parameters({count => $count, onlyTransient => $only_transient});
    return $self->get("hubs/sections/$section_id", 'GET', $parameters);
}

sub create_playlist {
    my ($self, $title, $type, $smart, $uri, $playlist_id) = @_;
    my $parameters = $self->_build_parameters({
        title => $title,
        type => $type,
        smart => $smart,
        uri => $uri,
        playQueueId => $playlist_id
    });
    return $self->get('playlists', 'POST', $parameters);
}

sub get_all_playlists {
    my ($self, $playlist_type, $smart) = @_;
    my $parameters = $self->_build_parameters({playlistType => $playlist_type, smart => $smart});
    return $self->get('playlists/all', 'GET', $parameters);
}

sub get_playlist {
    my ($self, $playlist_id) = @_;
    return $self->get("playlists/$playlist_id");
}

sub delete_playlist {
    my ($self, $playlist_id) = @_;
    return $self->get_status_code("playlists/$playlist_id", 'DELETE');
}

# Can update playlist metadata with this from PMS 1.9.1
sub update_playlist {
    my ($self, $playlist_id) = @_;
    return $self->get("playlists/$playlist_id", 'PUT');
}

sub delete_all_playlists {
    my ($self) = @_;
    my $playlists = $self->get_all_playlists();
    $playlists = $playlists->{MediaContainer}->[0]->{Playlist};
    my $fails = 0;
    for my $playlist_key ( map { $_->{ratingKey} } @{ $playlists } ) {
        my $status_code = $self->delete_playlist($playlist_key);
        $fails++ if $status_code !~ /2\d\d/;
    }
    return $fails;
}

sub get_playlist_items {
    my ($self, $playlist_id, $type) = @_;
    my $parameters = $self->_build_parameters({type => $type});
    return $self->get("playlists/$playlist_id/items", 'GET', $parameters);
}

# Only works with dumb playlists
sub clear_playlist {
    my ($self, $playlist_id) = @_;
    return $self->get("playlists/$playlist_id/items", 'DELETE');
}

sub add_item_to_playlist {
    my ($self, $playlist_id, $item_key) = @_;
    my $uri = $self->{uri_base} . "library/metadata/$item_key";
    return $self->get("playlists/$playlist_id/items", 'PUT', "uri=$uri");
}

sub add_playlist_to_playlist {
    my ($self, $to, $from) = @_;
    my $parameters = $self->_build_parameters({playQueueID => $from});
    return $self->get("playlists/$to/items", 'PUT', $parameters);
}

sub upload_playlist {
    my ($self, $path, $force) = @_;
    return $self->get('playlists/upload', 'POST', "path=$path&force=$force");
}

sub search {
    # TODO
}

sub search_hub {
    my ($self, $query, $section_id, $limit) = @_;
    my $parameters = $self->_build_parameters({query => $query, sectionId => $section_id, limit => $limit});
    return $self->get('hubs/search', 'GET', $parameters);
}

# THOT "alexa plex play the film with tom hanks I've seen the least on living room tv"
sub voice_search {
    my ($self, $query, $section_id, $limit) = @_;
    my $parameters = $self->_build_parameters({query => $query, sectionId => $section_id, limit => $limit});
    return $self->get('hubs/search/voice', 'GET', $parameters);
}

sub get_search_results {
    my ($self, $query) = @_;
    return $self->get('search', 'GET', "query=$query");
}

sub get_active_sessions {
    my ($self) = @_;
    return $self->get('status/sessions');
}

sub get_session_history {
    my ($self) = @_;
    return $self->get('status/sessions/history/all');
}

sub get_transcode_sessions {
    my ($self) = @_;
    return $self->get('transcode/sessions');
}

sub stop_transcode_session {
    my ($self, $session_key) = @_;
    return $self->get_status_code("transcode/sessions/$session_key", 'DELETE');
}

sub start_universal_transcode {
    my ($self, $has_mde, $path, $media_index, $part_index, $protocol, $fast_seek, $direct_play, $direct_stream, $subtitle_style, $subtitles, $audio_boost, $location, $media_buffer_size, $session, $add_debug_overlay, $auto_adjust_quality) = @_;
    my $parameters = "hasMde=$has_mde&path=$path&mediaIndex=$media_index&partIndex=$part_index&protocol=$protocol";
    my $optional_parameters = build_parameters(['fastSeek', 'directPlay', 'directStream', 'subtitleSize', 'subtitles', 'audioBoost', 'location', 'mediaBufferSize', 'session', 'addDebugOverlay', 'autoAdjustQuality'], [$fast_seek, $direct_play, $direct_stream, $subtitle_style, $subtitles, $audio_boost, $location, $media_buffer_size, $session, $add_debug_overlay, $auto_adjust_quality]);
    $parameters .= "&$optional_parameters" if $optional_parameters;
    return $self->get('video/:/transcode/universal/start.mpd', 'GET', $parameters);
}

sub get_media_timeline {
    my ($self, $rating_key, $key, $state, $has_mde, $time, $duration, $context, $playlist_id, $play_back_time, $row) = @_;
    my $parameters = $self->_build_parameters({
        ratingKey => $rating_key,
        key => $key,
        state => $state,
        hasMDE => $has_mde,
        time => $time,
        duration => $duration,
        context => $context,
        playQueueItemID => $playlist_id,
        playBackTime => $play_back_time,
        row => $row
    });
    return $self->get(':/timeline', 'GET', $parameters);
}

1;

__END__
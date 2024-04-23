package PlexTV::MyPlex;

use strict;
use warnings;
use feature 'say';
use Data::Dumper;
use Data::UUID; # issues about security
$Data::Dumper::Sortkeys = 1;
use JSON;
use MIME::Base64;
use REST::Client;

my $PLEX_TV_URL = 'https://plex.tv';

sub new {
    my ($class, @args) = @_;
    my $default_headers = _create_default_headers();
    my $self = {
        default_headers => $default_headers
    };
    $self->{client} = REST::Client->new();
    bless $self, $class;
    return $self;
}

sub query {
    my ($self, $path, $method, $parameters, $custom_headers) = @_;
    $method //= 'GET';
    my $url = "$PLEX_TV_URL/$path";
    my $headers = { %{ $self->{default_headers} } };
    if( $custom_headers ) {
        $headers = { %{ $headers }, %{ $custom_headers } };
    }
	#say "$method : $url";
    #say 'headers : ' . Dumper $headers;
	$self->{client}->request($method, $url, undef, $headers);
	my $response = $self->{client}->responseContent();
    chomp $response;
	#say $response;
    return $response;
}

sub _create_default_headers {
    my $default_headers = {
        'X-Plex-Product' => 'Perl Plex API Client',
        'X-Plex-Version' => '0.0.1',
        'X-Plex-Client-Identifier' => _get_or_create_client_id()
    };
    return $default_headers;
}

sub _get_or_create_client_id {
    # TODO load from a file? or create with create_uuid()
    return 'd75f5202-433e-4b7d-9322-73910fcdb65e';
}

sub create_uuid {
    my $uuid_generator = Data::UUID->new();
    my $uuid = $uuid_generator->create_str();
    say $uuid;
    return $uuid;
}

sub sign_in {
    my ($self, $username, $password) = @_;
    say 'Sigining in to plex.tv';
    my $auth_header = _create_auth_header($username, $password);
    my $response = $self->query('users/sign_in.json', 'POST', undef, $auth_header);
    my $json = decode_json($response);
    my $token = $json->{user}->{authToken};
    $self->{default_headers}->{'X-Plex-Token'} = $token;
    say 'Successfully signed into plex.tv';
}

sub _create_auth_header {
    my ($username, $password) = @_;
    my $credentials = encode_base64("$username:$password");
    chomp $credentials;
    return { Authorization => "Basic $credentials" };
}

sub get_claim_token {
    my ($self) = @_;
    say 'Getting claim token from plex.tv';
    my $response = $self->query('api/claim/token.json');
    my $json = decode_json($response);
    my $claim_token = $json->{token};
    say 'Got claim token from plex.tv';
    return $claim_token;
}

1;

__END__
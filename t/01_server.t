#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use Data::Dumper;
use Test::More; 
plan tests => 19;

use PlexTV;

my @SERVER_SUBS = qw(
  get_server_metadata
  get_server_activities
  cancel_activity
  get_butler_tasks
  start_all_butler_tasks
  stop_all_butler_tasks
  start_butler_task
  stop_butler_task
  check_for_update
  apply_update
  skip_update
  get_update_status
  log
  log_multiline
  enable_papertrail
  download_logs
  download_databases
  get_transient_token
  get_source_connection_info
);

can_ok('PlexTV', @SERVER_SUBS);

my $host = 'localhost';
my $port = '32400';
my $token = $ENV{PLEX_CLIENT_TOKEN};
my $plex = PlexTV->new();
$plex->connect($host, $port, $token);

my $server_metadata = $plex->get_server_metadata();
$server_metadata = $server_metadata->{MediaContainer}->[0];
is($server_metadata->{machineIdentifier}, '31559f5533f49bdb5eaefdb4c86cfcf7ce3fff95', 'Check server id');
is($server_metadata->{version}, '1.32.6.7557-1cf77d501', 'Check server version');


my $server_activities = $plex->get_server_activities();
is($server_activities->{MediaContainer}->[0]->{size}, 0, 'Check server activites');


my $butler_tasks = $plex->get_butler_tasks();
$butler_tasks = $butler_tasks->{ButlerTasks}->[0]->{ButlerTask};
is($butler_tasks->[0]->{name}, 'AutomaticUpdates', 'Check list of available butler tasks');


my $status_code = $plex->start_butler_task('BackupDatabase');
like($status_code, qr/2\d\d/, 'Check start butler task status code');


$server_activities = $plex->get_server_activities();
is($server_activities->{MediaContainer}->[0]->{size}, 2, 'Check butler task started');


$status_code = $plex->stop_butler_task('BackupDatabase');
like($status_code, qr/2\d\d/, 'Check stop butler task status code');


$status_code = $plex->start_all_butler_tasks();
like($status_code, qr/2\d\d/, 'Check start all butler tasks status code');


$status_code = $plex->stop_all_butler_tasks();
like($status_code, qr/2\d\d/, 'Check stop all butler tasks status code');


$status_code = $plex->check_for_update(1);
like($status_code, qr/2\d\d/, 'Check update check status code');


# TODO get a version that can be auto installed
#$status_code = $plex->apply_update(1);
#like($status_code, qr/2\d\d/, 'Check stop all butler tasks status code');


#$status_code = $plex->skip_update();
#like($status_code, qr/2\d\d/, 'Check stop all butler tasks status code');


my $update_status = $plex->get_update_status();
$update_status = $update_status->{MediaContainer}->[0];
like($update_status->{downloadURL}, qr/^https:\/\/plex\.tv\/downloads/, 'Check update status');


$status_code = $plex->log('1', 'testing', 'perl-api-client test');
like($status_code, qr/2\d\d/, 'Check log status code');


$status_code = $plex->log_multiline('1', 'testing multiline', 'perl-api-client test');
like($status_code, qr/2\d\d/, 'Check multiline log status code');


$status_code = $plex->enable_papertrail();
like($status_code, qr/2\d\d/, 'Check enable papertrail status code');


my $transient_token = $plex->get_transient_token();
$transient_token = $transient_token->{MediaContainer}->[0]->{token};
like($transient_token, qr/^transient-[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}$/, 'Check get transient token');


my $source_connection = $plex->get_source_connection_info();
$source_connection = $source_connection->{MediaContainer}->[0];
is($source_connection->{size}, 0, 'Check get source connection info');


# TODO should these subs store old mode and then set raw, then revert?
$plex->{mode} = 'raw';
my $logs_zip = 'logs.zip';
$status_code = $plex->download_logs($logs_zip);
like($status_code, qr/2\d\d/, 'Check download logs status code');
`rm $logs_zip`;

my $dbs_zip = 'dbs.zip';
$status_code = $plex->download_databases($dbs_zip);
like($status_code, qr/2\d\d/, 'Check download databases status code');
`rm $dbs_zip`;

exit;
#! /usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use File::Basename;

my $this_dir = dirname(__FILE__);

my @tests = glob "$this_dir/../*.t";

for my $test ( @tests ) {
    say `perl -I $this_dir/../../lib -MDevel::Cover $test`;
}

say `cover -report html_basic`;

exit;
#!/usr/bin/perl

use strict;
use Audio::Wav;

my $res = getWavlength($ARGV[0]);
print $res;

sub getWavlength
{
    	my $file = shift;
	my $wav = new Audio::Wav;
	my $read = $wav -> read($file);
	my $length = $read -> length_seconds();
	return $length;
}

1;


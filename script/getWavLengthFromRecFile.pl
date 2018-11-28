#!/usr/bin/perl

use strict;
use Audio::Wav;

open(IN,$ARGV[0])||die("The file can't find!\n");
while(my $row = <IN>)
{
	chomp($row);
	#print $row."\n";
	my @arr = split(/\|/,$row,2);
	#my $res = getWavlength($arr[0]);
	my $res = qx(perl script/getWavLength.pl $arr[0]);
	print $arr[0]."|".$res."\n";
}

sub getWavlength
{
    	my $file = shift;
	my $wav = new Audio::Wav;
	my $read = $wav -> read($file);
	my $length = $read -> length_seconds();
	return $length;
}

1;


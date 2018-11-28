#!/usr/bin/perl

package OuterServer;
use Config::Tiny;

sub getInnerEnglishAsrText
{
	my $res;
	my $config = Config::Tiny->new;
	$config = Config::Tiny->read('config/config.ini', 'utf8');
	my $filename = $config->{align_text_config}->{inner_asr_text_file};
	open(IN,$filename)||die("Please config the filename.");
	while (my $row_in = <IN>) 
	{
		chomp($row_in);
		my @arr = split(/\|/,$row_in,2);
		my $filename = $arr[0];
		my $usertext = $arr[1];

		$filename =~ s/^\s+|\s+$//g;
		$usertext =~ s/^\s+|\s+$//g;

		$res->{$filename} = $usertext;
	}
	return $res;
}

sub getNuanceEnglishAsrText
{

}

sub getBaiduEnglishAsrText
{

}

sub getUnsEnglishOralScore
{

}

sub getiFlyEnglishAsrText
{

}

1;


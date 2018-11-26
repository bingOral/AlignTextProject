#!/usr/bin/perl

use strict;
use JSON;
use DBI;
use POSIX;
use threads;
use Try::Tiny;
use Audio::Wav;
use Word2vec::Word2vec;
use Search::Elasticsearch;
use script::yankt;

if(scalar(@ARGV) != 3)
{
	print "Usage : perl FindBestTextFromSRTWithASR.pl input threadnum index\n";		
	exit;
}

open(IN,$ARGV[0])||die("The file can't find!\n");

&Main();

sub Main
{
	my $threadnum = $ARGV[1];
	my @tasks = <IN>;
	my $group = div(\@tasks,$threadnum);
	my $w2v = Word2vec::Word2vec->new();
	$w2v->ReadTrainedVectorDataFromFile("data/text8.bin");
	my $es = Search::Elasticsearch->new(nodes=>['localhost:9200'], cxn_pool => 'Sniff');

	my @threads;
	foreach my $key (keys %$group)
	{
		my $thread = threads->create(\&dowork,$group->{$key},$w2v,$es);
		push @threads,$thread;
	}
		
	foreach(@threads)
	{
		$_->join();
	}
}

sub div
{
	my $ref = shift;
	my $threadnum = shift;

	my $res;
    	for(my $i = 0; $i < scalar(@$ref); $i++)
	{
   		my $flag = $i%$threadnum;
   		push @{$res->{$flag}},$ref->[$i];
    	}
	
	 return $res;
}

sub dowork
{
	my $ref = shift;
	my $w2v = shift;
	my $es  = shift;

	foreach my $row (@$ref)
	{
		chomp($row);
		my $jsonparser = new JSON;
		my $json = $jsonparser->decode($row);
		my $info = $json->{info};
		my $wavs = $json->{subwav};
		my $url = $json->{url};
		my $filename = $json->{filename};
		
		foreach my $wav (@$wavs)
		{
			my $final;

			#call inner english asr engine
			my $inner_asr_res = getAsrText('inner',$wav);
			$inner_asr_res =~ s/^\s+|\s+$//g;

			if($inner_asr_res ne 'null' && $inner_asr_res ne 'NULL')
			{
				my $inner_result = getSimilarity($inner_asr_res,$info,$w2v);
				my $wavlength  = qx(perl script/getWavLength.pl $wav);

				$final->{wav} = $wav;
				$final->{url} = $url;
				$final->{length} = $wavlength;

				$final->{inner_asr_text} = $inner_asr_res;
				$final->{inner_ref_text} = $inner_result->{ref};
				$final->{inner_ref_similarity} = $inner_result->{similarity};

				#print
				print "Process audio file : ".$wav."\n"."$wav 's inner-asr text : ".$inner_asr_res."\n"."$wav 's inner-ref text : ".$inner_result->{ref}."\n";
				print $jsonparser->encode($final)."\n\n";

				#insert Elastic
				yankt::insertandupdate($wav,$filename,$url,$info,$wavlength,-1,
								$final->{inner_asr_text},$final->{inner_ref_text},$final->{inner_ref_similarity}, #inner asr server
								"","",0, #second
								"","",0, #third
								"","",0, #forth 
								0,"","", #reserved
								'voa-special');  
			}

			#call nuance english asr engine
		}
	}
}

sub getSimilarity
{
	my $asr_res = shift;
	my $info = shift;
	my $w2v = shift;

	my $result;
	my $res = preProcessInfo($info);
	my $res_nums = split(/\s+/,$res);

	$asr_res =~ s/^\s+|\s+$//g;
	my $asr_res_nums = split(/\s+/,$asr_res);
	my $max = int($asr_res_nums * 1.12);
	my $min = int($asr_res_nums * 0.88);

	if($min < 1)
	{
		$min = 1;
	}

	my $final_ref_res = getSubString($res,0,$min);
	my $final_similarity = $w2v->ComputeAvgOfWordsCosineSimilarity($asr_res,$final_ref_res);
	for(my $k = 0; $k <= ($res_nums - $max); $k++)
	{
		for(my $i = $min; $i <= $max; $i++)
		{
			my $ref_res = getSubString($res,$k,$i);
			my $similarity = $w2v->ComputeAvgOfWordsCosineSimilarity($asr_res,$ref_res);
			if($final_similarity < $similarity)
			{
				$final_ref_res = $ref_res;
				$final_similarity = $similarity;
			}
		}
	}

	$result->{ref} = $final_ref_res;
	$result->{similarity} = $final_similarity;
	return $result;
}

sub getAsrText
{
	my $asr_engine = shift;
	my $wav = shift;

	if($asr_engine eq 'baidu')
	{
		$asr_engine = "./script/TestBaiduASR.py";
	}
	elsif($asr_engine eq 'inner')
	{
		$asr_engine = "./script/TestCallServASR.py";
	}
	my $call_asr = qx(python $asr_engine $wav);
	return preProcessInfo($call_asr);
}

sub getSubString
{
	my $info = shift;
	my $start = shift;
	my $step = shift;
	my $end = $start + $step;

	my @arr = split(/\s+/,$info);
	if($start + $step > scalar(@arr))
	{
		$end = scalar(@arr);
	}

	my $res;
	for(my $i = $start; $i <= $end; $i++)
	{
		$res .= $arr[$i]." ";
	}

	return $res;
}

sub preProcessInfo
{
	my $info = shift;
	my $res = $info;

	$res =~ s/’/'/g;
	$res =~ s/\'s/@/g;
	$res =~ s/\'m/%/g;
	$res =~ s/\'t/#/g;
	$res =~ s/\'ll/&&/g;
	$res =~ s/([0-9]+)\,([0-9]+)/$&##$2/g;
	$res =~ s/([a-z]+)\-([a-z]+)/$1&$2/g;
	$res =~ s/([0-9]+)\.([0-9]+)/$&~$2/g;

	$res =~ s/[^a-z0-9A-Z@%&#~]/ /g;
	$res =~ s/[,"!'?-]/ /g;
	$res =~ s/\(|\)\[\]\_/ /g;
	$res =~ s/\(.*\)/ /g;
	$res =~ s/[\r\n]/ /g;
	$res =~ s/\s+/ /g;

	$res =~ s/&&/\'ll/g;
	$res =~ s/##/,/g;
	$res =~ s/@/\'s/g;
	$res =~ s/%/\'m/g;
	$res =~ s/#/\'t/g;
	$res =~ s/&/-/g;
	$res =~ s/~/./g;

	$res = lc($res);
	return $res;
}

1;

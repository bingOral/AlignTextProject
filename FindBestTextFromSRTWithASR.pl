#!/usr/bin/perl

use strict;
use JSON;
use threads;
use Try::Tiny;
use Config::Tiny;
use List::Util qw/min max/;
use Word2vec::Word2vec;
use Search::Elasticsearch;
use script::Elastic;

if(scalar(@ARGV) != 2)
{
	print "Usage : perl $0 input threadnum\n";		
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
	my $es = Search::Elasticsearch->new(nodes=>['192.168.1.20:9200'], cxn_pool => 'Sniff');
	my $env = init();

	my @threads;
	foreach my $key (keys %$group)
	{
		my $thread = threads->create(\&dowork,$group->{$key},$w2v,$es,$env);
		push @threads,$thread;
	}
		
	foreach(@threads)
	{
		$_->join();
	}
}

sub init
{
	my $config = Config::Tiny->new;
	$config = Config::Tiny->read('config/config.ini', 'utf8');
	
	my $res;

	$res->{dest_align_index} = $config->{align_text_config}->{dest_align_index};
	$res->{nuance_asr_text_index} = $config->{align_text_config}->{nuance_asr_text_index};
	$res->{uns_asr_text_index} = $config->{align_text_config}->{uns_asr_text_index};
	$res->{baidu_asr_text_index} = $config->{align_text_config}->{baidu_asr_text_index};
	$res->{iFly_asr_text_index} = $config->{align_text_config}->{iFly_asr_text_index};
	$res->{uns_oral_score_index} = $config->{align_text_config}->{uns_oral_score_index};
	$res->{elastic_insert_flag} = $config->{align_text_config}->{elastic_insert_flag};
	$res->{flag} = $config->{align_text_config}->{flag};

	return $res;
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
	my $env = shift;

	my $index = $env->{dest_align_index};
	my $status = $env->{elastic_insert_flag};

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
			$wav =~ s/%//g;
			my $final;
			my $asr_res;
			my $wavlength;

			try
			{
				my $nuance_asr_text_index = $env->{nuance_asr_text_index};
				my $doc = $es->get(index => $nuance_asr_text_index, type => 'data', id => $wav);
				$asr_res = preProcessInfo($doc->{_source}->{text});
				$wavlength = $doc->{_source}->{length};
			}
			catch
			{
				$asr_res = "NULL";
				$wavlength = 0;
			};

			my $flag;
			if($status eq 'true')
			{
				$flag = 0;	
			}
			else
			{
				$flag = getWavExiststsStatus($es,$index,$wav,'second_text_similarity');
			}

			if($flag == 0)
			{
				my $result;
				if($asr_res eq 'NULL')
				{
					$result->{ref} = $asr_res;
					$result->{similarity} = 0;
				}
				elsif(index($info,$asr_res) >= 0)
				{
					$result->{ref} = $asr_res;
					$result->{similarity} = 1;
				}
				else
				{
					$result = getSimilarity($asr_res,$info,$w2v);
				}

				$final->{wav} = $wav;
				$final->{url} = $url;
				$final->{length} = $wavlength;
				$final->{asr_text} = $asr_res;
				$final->{ref_text} = $result->{ref};
				$final->{text_similarity} = $result->{similarity};
				
				#print
				print "Process audio file : ".$wav."\n"."$wav 's asr text : ".$asr_res."\n"."$wav 's ref text : ".$result->{ref}."\n";
				print $jsonparser->encode($final)."\n\n";

				my $data;
				$data->{es} = $es;
				$data->{index} = $index;
				$data->{wavname} = $wav;
				$data->{filename} = $filename;
				$data->{url} = $url;
				$data->{info} = $info;
				$data->{length} = $wavlength;
				$data->{oral_score} = -1;

				$data->{second_asr_text} = $final->{asr_text};
				$data->{second_align_text} = $final->{ref_text};
				$data->{second_text_similarity} = $final->{text_similarity};
				$data->{flag} = $env->{flag};

				elastic::insertDB($data);
			}
			else
			{
				print "The file ".$wav." has been processed !\n\n";
			}
		}
	}
}

sub getWavNotExiststsStatus
{
	my $es = shift;
	my $index = shift;
	my $wav = shift;

	my $results = $es->search(index => $index, body => {query => {match => {_id => $wav}}});
	my $flag = $results->{hits}->{total};
	return $flag;
}

sub getWavExiststsStatus
{
	my $es = shift;
	my $index = shift;
	my $wav = shift;
	my $field = shift;
	
	my $flag = getWavNotExiststsStatus($es,$index,$wav);
	if($flag > 0)
	{
		my $doc = $es->get(index => $index, type => 'data', id => $wav);
		my $text = $doc->{_source}->{$field};
		if($text)
		{
			return 1;
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return 0;
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
	my $max = int($asr_res_nums * 1.1);
	my $min = int($asr_res_nums * 0.9);

	if($min < 1)
	{
		$min = 1;
	}

	my $final_ref_res = getSubString($res,0,$min);
	$final_ref_res =~ s/^\s+|\s+$//g;
	my $final_similarity = $w2v->ComputeAvgOfWordsCosineSimilarity($asr_res,$final_ref_res);
	if($final_similarity == 1 and $final_ref_res eq $asr_res)
	{
		$result->{ref} = $final_ref_res;
		$result->{similarity} = $final_similarity;
		return $result;
	}

	for(my $k = 0; $k <= ($res_nums - $max); $k++)
	{
		for(my $i = $min; $i <= $max; $i++)
		{
			my $ref_res = getSubString($res,$k,$i);
			$ref_res =~ s/^\s+|\s+$//g;
			my $similarity = $w2v->ComputeAvgOfWordsCosineSimilarity($asr_res,$ref_res);

			if($similarity == 1 and $ref_res ne $asr_res)
			{
				my $max = max(length($ref_res), length($asr_res));
				my $min = min(length($ref_res), length($asr_res));
				$similarity = sprintf "%0.3f",($min/$max);
			}

			if($final_similarity < $similarity)
			{
				$final_ref_res = $ref_res;
				$final_similarity = $similarity;
			}

			if($final_similarity == 1)
			{
				$result->{ref} = $final_ref_res;
				$result->{similarity} = $final_similarity;
				return $result;
			}
		}
	}

	$final_similarity = 0 unless $final_similarity;
	$result->{ref} = $final_ref_res;
	$result->{similarity} = $final_similarity;
	return $result;
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
	$res =~ s/^\s+|\s+$//g;

	$res = lc($res);
	return $res;
}

1;

#!/usr/bin/perl

package AlignString;

sub calStringSimilarity
{
	my $str = shift;
	my $info = shift;
	my $res;
	my $rtn;

	my $flag = index($info,$str);
	if($flag >= 0)
	{
		$res->{ref} = $str;
		$res->{similarity} = 1;
		return $res;
	}
	else
	{
		$rtn = fuzzySearch($str,$info);
	}

	$res = $rtn;
	return $res;
}

sub fuzzySearch
{
	my $str = shift;
	my $info = shift;

	my $str_nums = split(/\s+/,$str);
	my $info_nums = split(/\s+/,$info);

	my $first_substr_pos = $str_nums - 1;
	my $newstr = getSubStringByWord($str,$first_substr_pos);
	my $flag = index($info,$newstr);

	print $info.":".$newstr.":".$flag."\n";

	my $start_index;
	my $end_index;
	if($flag >= 0)
	{
		$start_index = $flag - length($str);
		$end_index = $flag + length($str);

		print "Before index info :".$start_index.":".$end_index.":".$info."\n";

		my $char_start_index = substr($info,$start_index,1);
		my $char_end_index = substr($info,$end_index,1);
		
		if($char_start_index ne ' ')
		{
			my $j = 10;
			while ($j--)
			{
				my $m = $start_index - $j;
				$char_start_index = substr($info,$m,1);
				if($char_start_index eq ' ')
				{
					$start_index = $m;
					last;
				}
				if($m < 0)
				{
					$start_index = 0;
					last;
				}
			}
		}

		if($char_end_index ne ' ')
		{
			my $j = 1;
			while($j <= 10)
			{
				my $m = $end_index + $j;
				$char_end_index = substr($info,$m,1);
				if($char_end_index eq ' ')
				{
					$end_index = $m;
					last;
				}
				if($m > length($info))
				{
					$end_index = length($info);
					last;
				}
			}
		}

		my $len = $end_index - $start_index;
		my $newinfo = substr($info,$start_index,$len);
		print " After index info :".$start_index.":".$end_index.":".$newinfo."\n";
		return;
	}
	else
	{
		my $newstr_nums = split(/\s+/,$newstr);
		my $next_substr_pos = $newstr - 1;
		my $str_next = getSubStringByWord($newstr,$next_substr_pos);
		fuzzySearch($str_next,$info);
	}
}

sub getSubStringByWord
{
	my $str = shift;
	my $length = shift;

	my @arr = split(/\s+/,$str);
	return if(scalar(@arr) == 0);
	$length = scalar(@arr) if($length > scalar(@arr));
	$length = 0 if($length < 0);
	
	my $newstr;
	for(my $i = 0; $i < $length; $i++)
	{
		$newstr .= $arr[$i]." ";
	}
	$newstr =~ s/^\s+|\s+$//g;
	return $newstr;
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

	$result->{ref} = $final_ref_res;
	$result->{similarity} = $final_similarity;
	return $result;
}

1;

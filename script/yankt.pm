#!/usr/bin/perl

package yankt;

use strict;
use POSIX;
use Search::Elasticsearch;

sub insertandupdate
{
	my $es = shift;
	my $index = shift;
	my $wavname = shift;
	my $origin_audio = shift;
	my $url = shift;
	my $info = shift;
	my $length = shift;
	my $oral_score = shift;
	my $first_asr_text = shift;
	my $first_align_text = shift;
	my $first_text_similarity = shift;
	my $second_asr_text = shift;
	my $second_align_text = shift;
	my $second_text_similarity = shift;
	my $third_asr_text = shift;
	my $third_align_text = shift;
	my $third_text_similarity = shift;
	my $forth_asr_text = shift;
	my $forth_align_text = shift;
	my $forth_text_similarity = shift;
	my $first_reserved = shift;
	my $second_reserved = shift;
	my $third_reserved = shift;
	my $flag = shift;
	my $time = strftime("%Y-%m-%d %H:%M:%S",localtime());
		
	my $results = $es->search(index => 'callserv_data_english', body => {query => {match => {wavname => $wavname}}});
	my $flag = $results->{hits}->{total};

	if($flag > 0)
	{	
		my $doc = $es->get(
			index   => $index,
			type    => 'data',
			id      => $wavname
		);

		$origin_audio = $doc->{_source}->{origin_audio} if $origin_audio eq '';
		$url = $doc->{_source}->{url} if $url eq '';
		$info = $doc->{_source}->{info} if $info eq '';
		$length = $doc->{_source}->{length} if $length == 0;
		$oral_score = $doc->{_source}->{oral_score} if $oral_score == 0;
		$first_asr_text = $doc->{_source}->{first_asr_text} if $first_asr_text eq '';
		$first_align_text = $doc->{_source}->{first_align_text} if $first_align_text eq '';
		$first_text_similarity = $doc->{_source}->{first_text_similarity} if $first_text_similarity == 0;
		$second_asr_text = $doc->{_source}->{second_asr_text} if $second_asr_text eq '';
		$second_align_text = $doc->{_source}->{second_align_text} if $second_align_text eq '';
		$second_text_similarity = $doc->{_source}->{second_text_similarity} if $second_text_similarity == 0;
		$third_asr_text = $doc->{_source}->{third_asr_text} if $third_asr_text eq '';
		$third_align_text = $doc->{_source}->{third_align_text} if $third_align_text eq '';
		$third_text_similarity = $doc->{_source}->{third_text_similarity} if $third_text_similarity == 0;
		$forth_asr_text = $doc->{_source}->{forth_asr_text} if $forth_asr_text eq '';
		$forth_align_text = $doc->{_source}->{forth_align_text} if $forth_align_text eq '';
		$forth_text_similarity = $doc->{_source}->{forth_text_similarity} if $forth_text_similarity == 0;
		$first_reserved = $doc->{_source}->{first_reserved} if $first_reserved == 0;
		$second_reserved = $doc->{_source}->{second_reserved} if $second_reserved eq '';
		$third_reserved = $doc->{_source}->{third_reserved} if $third_reserved eq '';
		$flag = $doc->{_source}->{flag} if $flag eq '';

		insert($es,$wavname,$origin_audio,$url,$info,$length,$oral_score,
				$first_asr_text,$first_align_text,$first_text_similarity,
				$second_asr_text,$second_align_text,$second_text_similarity,
				$third_asr_text,$third_align_text,$third_text_similarity,
				$forth_asr_text,$forth_align_text,$forth_text_similarity,
				$first_reserved,$second_reserved,$third_reserved,$flag,$time);
	}
	else
	{
		insert($es,$wavname,$origin_audio,$url,$info,$length,$oral_score,
				$first_asr_text,$first_align_text,$first_text_similarity,
				$second_asr_text,$second_align_text,$second_text_similarity,
				$third_asr_text,$third_align_text,$third_text_similarity,
				$forth_asr_text,$forth_align_text,$forth_text_similarity,
				$first_reserved,$second_reserved,$third_reserved,$flag,$time);	
	}
}

sub insert
{
	my $es = shift;

	my $wavname = shift;
	my $origin_audio = shift;
	my $url = shift;
	my $info = shift;
	my $length = shift;
	my $oral_score = shift;
	my $first_asr_text = shift;
	my $first_align_text = shift;
	my $first_text_similarity = shift;
	my $second_asr_text = shift;
	my $second_align_text = shift;
	my $second_text_similarity = shift;
	my $third_asr_text = shift;
	my $third_align_text = shift;
	my $third_text_similarity = shift;
	my $forth_asr_text = shift;
	my $forth_align_text = shift;
	my $forth_text_similarity = shift;
	my $first_reserved = shift;
	my $second_reserved = shift;
	my $third_reserved = shift;
	my $flag = shift;
	my $time = shift;

	$es->index(
		index   => $index,
		type    => 'data',
		id      => $wavname,
		body    => {
			wavname => $wavname,
			origin_audio => $origin_audio,
			url => $url,
			info => $info,
			length => $length,
			oral_score => $oral_score,
			first_asr_text => $first_asr_text,
			first_align_text => $first_align_text,
			first_text_similarity => $first_text_similarity,
			second_asr_text => $second_asr_text,
			second_align_text => $second_align_text,
			second_text_similarity => $second_text_similarity,
			third_asr_text => $third_asr_text,
			third_align_text => $third_align_text,
			third_text_similarity => $third_text_similarity,
			forth_asr_text => $forth_asr_text,
			forth_align_text => $forth_align_text,
			forth_text_similarity => $forth_text_similarity,
			first_reserved => $first_reserved,
			second_reserved => $second_reserved,
			third_reserved => $third_reserved,
			flag => $flag,
			time => $time
		}
	);
}

1;


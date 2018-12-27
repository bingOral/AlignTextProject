#!/usr/bin/perl

package elastic;

use strict;
use POSIX;
use Search::Elasticsearch;

sub insertDB
{
	my $data = shift;

	my $es = $data->{es};
	my $index = $data->{index};
	my $wavname = $data->{wavname};
	my $origin_audio = $data->{filename};
	my $url = $data->{url};
	my $info = $data->{info};
	my $length = $data->{length};
	my $oral_score = $data->{oral_score};
	my $first_asr_text = $data->{first_asr_text};
	my $first_align_text = $data->{first_align_text};
	my $first_text_similarity = $data->{first_text_similarity};
	my $second_asr_text = $data->{second_asr_text};
	my $second_align_text = $data->{second_align_text};
	my $second_text_similarity = $data->{second_text_similarity};
	my $third_asr_text = $data->{third_asr_text};
	my $third_align_text = $data->{third_align_text};
	my $third_text_similarity = $data->{third_text_similarity};
	my $forth_asr_text = $data->{forth_asr_text};
	my $forth_align_text = $data->{forth_align_text};
	my $forth_text_similarity = $data->{forth_text_similarity};
	my $first_reserved = $data->{first_reserved};
	my $second_reserved = $data->{second_reserved};
	my $third_reserved = $data->{third_reserved};
	my $flag = $data->{flag};
	my $time = strftime("%Y-%m-%d %H:%M:%S",localtime());
		
	my $results = $es->search(index => $index, body => {query => {match => {_id => $wavname}}});
	my $flags = $results->{hits}->{total};

	if($flags > 0)
	{	
		my $doc = $es->get(
			index   => $index,
			type    => 'data',
			id      => $wavname
		);

		$origin_audio = $doc->{_source}->{origin_audio} unless $origin_audio;
		$url = $doc->{_source}->{url} unless $url;
		$info = $doc->{_source}->{info} unless $info;
		$length = $doc->{_source}->{length} unless $length;
		$oral_score = $doc->{_source}->{oral_score} unless $oral_score;
		$first_asr_text = $doc->{_source}->{first_asr_text} unless $first_asr_text;
		$first_align_text = $doc->{_source}->{first_align_text} unless $first_align_text;
		$first_text_similarity = $doc->{_source}->{first_text_similarity} unless $first_text_similarity;
		$second_asr_text = $doc->{_source}->{second_asr_text} unless $second_asr_text;
		$second_align_text = $doc->{_source}->{second_align_text} unless $second_align_text;
		$second_text_similarity = $doc->{_source}->{second_text_similarity} unless $second_text_similarity;
		$third_asr_text = $doc->{_source}->{third_asr_text} unless $third_asr_text;
		$third_align_text = $doc->{_source}->{third_align_text} unless $third_align_text;
		$third_text_similarity = $doc->{_source}->{third_text_similarity} unless $third_text_similarity;
		$forth_asr_text = $doc->{_source}->{forth_asr_text} unless $forth_asr_text;
		$forth_align_text = $doc->{_source}->{forth_align_text} unless $forth_align_text;
		$forth_text_similarity = $doc->{_source}->{forth_text_similarity} unless $forth_text_similarity;
		$first_reserved = $doc->{_source}->{first_reserved} unless $first_reserved;
		$second_reserved = $doc->{_source}->{second_reserved} unless $second_reserved;
		$third_reserved = $doc->{_source}->{third_reserved} unless $third_reserved;
		$flag = $doc->{_source}->{flag} unless $flag;

		insert($es,$index,$wavname,$origin_audio,$url,$info,$length,$oral_score,
				$first_asr_text,$first_align_text,$first_text_similarity,
				$second_asr_text,$second_align_text,$second_text_similarity,
				$third_asr_text,$third_align_text,$third_text_similarity,
				$forth_asr_text,$forth_align_text,$forth_text_similarity,
				$first_reserved,$second_reserved,$third_reserved,$flag,$time);
	}
	else
	{
		insert($es,$index,$wavname,$origin_audio,$url,$info,$length,$oral_score,
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


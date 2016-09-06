#!/usr/bin/perl
use strict;
use warnings;

open my $file,"<$ARGV[0]" or die;
my ($buff,$res,$start,$log_head,$ms_head)=("","",0,12,4);

while(1){
	$res=myread(\$file,\$buff,12,$start);
	last if $res == -1;
	my ($offset,$size)=get_head($buff);
	$start += $log_head + $ms_head;

	$res=myread(\$file,\$buff,1,$start);
	last if $res < 1;
	my $kfk_version=get_byte($buff);
	#print "Kafka Version: $kfk_version\n";
	my $v_ms_head = $kfk_version == 1 ? 10 : 2;
	$start += $v_ms_head;

	$res=myread(\$file,\$buff,4,$start);
	last if $res < 4;
	my $key=get_int($buff);
	my $ms_key_len=4 + ($key > 0 ? $key : 0);
	$start += $ms_key_len;
	
	$res=myread(\$file,\$buff,4,$start);
	last if $res == -1;
	my $ms_size=get_int($buff);
	$start += 4;
	my $ms_len=$size - $ms_key_len - $ms_head - $v_ms_head - 4;
	#print $ms_len,"\n";

	$res=myread(\$file,\$buff,$ms_len,$start);
	last if $res == -1;
	print "Offset: $offset\tMessage: $buff\n";
	$start += $ms_len;
}


close $file;

sub myread{
	return if @_ != 4;
	my ($file,$buff,$len,$offset)=@_;

	seek($$file,$offset,0) || return -1;
	my $res=read($$file,$$buff,$len);
	return $res;
}

sub get_int{
	my $buff=shift || 0;
	return unpack("i>",$buff);
}

sub get_head{
	my $buff=shift || return ();
	return unpack("q>i>",$buff);
}

sub get_byte{
	my $buff=shift || -1;
	return unpack("C",$buff);
}

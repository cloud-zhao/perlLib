package Avro::IO;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw();
use Avro::Base;

sub new{
	my $class=shift;
	my $self={};
	$self->{buf}=shift;
	$self->{type}=ref $self->{buf};
	$self->{index}=0;

	return bless $self,$class;
}

my $check_index=sub{
	my $self=shift;
	my $len=$self->len;
	$self->{index}=$self->{index} > $len ? $len : $self->{index};
};

sub read{
	my $self=shift;
	my $len=shift || -1;
	my $buf;

	if($self->{type} eq "GLOB"){
		$len == -1 ? read($self->{buf},$buf,-s $self->{buf}) : read($self->{buf},$buf,$len);
		return $buf;
	}

	return $self->{buf} if $len == -1;
	$self->$check_index();
	return if $self->{index} == $self->len;
	$buf=substr($self->{buf},$self->{index},$len);
	$self->{index}+=$len;
	return $buf;
}

sub write{
	my $self=shift;
	my $buf=shift || '';

	if($self->{type} eq "GLOB"){
		print { $self->{buf} } $buf;
		return;
	}
	
	$self->$check_index();
	if($self->eof){
		$self->{buf}.=$buf;
	}else{
		my $head=substr($self->{buf},0,$self->{index});
		my $tail=substr($self->{buf},$self->{index},$self->len);
		$self->{buf}=$head.$buf.$tail;
	}
	$self->{index}+=length($buf);
}

sub eof{$_[0]->{index}>=$_[0]->len}
sub len{length($_[0]->{buf})||0}

sub seek{
	my $self=shift;
	my $seek=shift || 0;
	my $flag=defined(shift) ? 1 : 0;

	return seek($self->{buf},$seek,$flag) if $self->{type} eq 'GLOB';

	$seek= $seek < length($self->{buf}) ? $seek : length($self->{buf});
	$self->{index}=$flag == 0 ? $seek : $self->{index} + $seek;
}

sub tell{$_[0]->{type} eq "GLOB" ? tell($_[0]->{buf}) : $_[0]->{index}}


1;

__END__

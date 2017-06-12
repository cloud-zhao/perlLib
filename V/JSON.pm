package V::JSON;
$VERSION=0.0.1;

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK=qw(json_encode);

my $type={
	'"'	=>	1,
	"'"	=>	1,
	','	=>	2,
	'['	=>	3,
	']'	=>	-3,
	'{'	=>	4,
	'}'	=>	-4,
	'n'	=>	5,
	'f'	=>	6,
	't'	=>	6,
	':'	=>	7
};
sub is_type{$type->{+shift}||$type->{int}}
sub get_byte{substr($_[0],$_[1]++,1)}

sub get_value{
	my $t=get_byte $_[0],$_[1];
	my $i=$type->{$t};
	if($i){
		return '' if $_[2]==1 && $i==1;
		return '' if $_[2]==2 && ($i==2 || $i==-3 || $i==-4);
		$t.=get_value(@_);
	}else{
		$t.=get_value(@_);
		return $t;
	}
}

sub get_string{get_value @_,1}
sub get_number{
	$_[1]--;
	my $r=get_value $_[0],$_[1],2;
	$_[1]--;
	die "type error" if $r!~/^\d+$/;
	return $r;
}
sub get_boolean{
	$_[1]--;
	my $r=get_value $_[0],$_[1],2;
	$_[1]--;
	die "type error" if $r ne 'true' && $r ne 'false';

	my $c=sub{bless \(my $c=shift),'V::JSON::Boolean'};

	return $r eq 'true'?$c->(1):$c->(0);
}
sub get_null{
	$_[1]--;
	my $r=get_value $_[0],$_[1],2;
	$_[1]--;
	die "type error" if $r ne 'null';
	return undef;
}
sub get_object{
	my $t=shift;
	my $v;

	if($type->{$t} && $type->{$t} == 1){
		$v=get_string @_;
	}elsif($type->{$t} && $type->{$t} == 3){
		$v=get_array(@_);
	}elsif($type->{$t} && $type->{$t} == 4){
		$v=get_hash(@_);
	}elsif($type->{$t} && $type->{$t} == 5){
		$v=get_null @_;
	}elsif($type->{$t} && $type->{$t} == 6){
		$v=get_boolean @_;
	}elsif($t =~ /\d/){
		$v=get_number @_;
	}else{
		die "value type error";
	}

	return $v;
}

sub get_array{
	my $t=get_byte $_[0],$_[1];
	my ($r,$v)=([],undef);

	$v=get_object $t,@_;
	push @$r,$v;
	$t=get_byte $_[0],$_[1];
	if($type->{$t} && $type->{$t} == 2){
		$v=get_array(@_);
		push @$r,@$v;
		return $r;
	}elsif($type->{$t} && $type->{$t} == -3){
		return $r;
	}else{
		die "object type error";
	}
}

sub get_hash{
	my $t=get_byte $_[0],$_[1];
	my ($r,$k,$v)=({},undef,undef);
	#mlog(3,$t,$_[1]);
	if($type->{$t} && $type->{$t} == 1){
		$k=get_string @_;
	#	mlog(3,$k,$_[1]);
		$t=get_byte @_;
	#	mlog(3,$k,$t,$_[1]);
		if($type->{$t} && $type->{$t} == 7){
			$t=get_byte @_;
			$v=get_object $t,@_;
		}else{
			die "kev:value type error";
		}
		$r->{$k}=$v;
		$t=get_byte @_;
		if($type->{$t} && $type->{$t} == 2){
			$v=get_hash(@_);
			$r->{$_}=$v->{$_} for keys %$v;
			return $r;
		}elsif($type->{$t} && $type->{$t} == -4){
			return $r;
		}else{
			die "object type error";
		}
	}else{
		die "key type error";
	}
}

my $all={};
sub mlog{
	my $c=(caller)[2];
	$all->{$c}++;
	exit if $all->{$c} == shift;
	print "[LOG] $c ",join "\t",@_,"\n";
}

sub validate_str{
	my $str=shift;
	my $s=substr($str,0,1);
	my $e=substr($str,len($str),1);
	die "json str error" if $type->{$s} && $type->{$e} && $type->{$s}==4 && $type->{$e}==-4;
}

sub json_encode{
	my $str=shift || return {};
	my $index=0;
	my $t=get_byte $str,$index;
	if($type->{$t} && $type->{$t} == 4){
		return get_hash $str,$index;
	}else{
		die "type error";
	}
}

1;

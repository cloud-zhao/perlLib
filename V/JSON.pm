package V::JSON;
$VERSION=0.0.1;

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK=qw(json_encode json_decode);

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
my ($get_value,$get_array,$get_hash,$builder_hash,$builder_array);
my $get_byte=sub {substr($_[0],$_[1]++,1)};
$get_value=sub{
	my $t=$get_byte->($_[0],$_[1]);
	my $i=$type->{$t};
	if($i){
		my $e=$get_byte->($_[0],$_[1]-=2);
		$_[1]++;
		return '' if $_[2]==1 && $i==1 && $e ne '\\';
		return '' if $_[2]==2 && ($i==2 || $i==-3 || $i==-4);
		$t.=$get_value->(@_);
	}else{
		$t.=$get_value->(@_);
		return $t;
	}
};
my $get_string=sub{$get_value->(@_,1)};
my $get_number=sub{
	$_[1]--;
	my $r=$get_value->($_[0],$_[1],2);
	$_[1]--;
	die "type error" if $r!~/^\d+$/;
	return $r;
};
my $get_boolean=sub{
	$_[1]--;
	my $r=$get_value->($_[0],$_[1],2);
	$_[1]--;
	die "type error" if $r ne 'true' && $r ne 'false';

	my $c=sub{bless \(my $c=shift),'V::JSON::Boolean'};

	return $r eq 'true'?$c->(1):$c->(0);
};
my $get_null=sub{
	$_[1]--;
	my $r=$get_value->($_[0],$_[1],2);
	$_[1]--;
	die "type error" if $r ne 'null';
	return undef;
};
my $get_object=sub{
	my $t=shift;
	my $v;

	if($type->{$t} && $type->{$t} == 1){
		$v=$get_string->(@_);
	}elsif($type->{$t} && $type->{$t} == 3){
		$v=$get_array->(@_);
	}elsif($type->{$t} && $type->{$t} == 4){
		$v=$get_hash->(@_);
	}elsif($type->{$t} && $type->{$t} == 5){
		$v=$get_null->(@_);
	}elsif($type->{$t} && $type->{$t} == 6){
		$v=$get_boolean->(@_);
	}elsif($t =~ /\d/){
		$v=$get_number->(@_);
	}else{
		die "value type error";
	}

	return $v;
};

$get_array=sub{
	my $t=$get_byte->($_[0],$_[1]);
	my ($r,$v)=([],undef);

	$v=$get_object->($t,@_);
	push @$r,$v;
	$t=$get_byte->($_[0],$_[1]);
	if($type->{$t} && $type->{$t} == 2){
		$v=$get_array->(@_);
		push @$r,@$v;
		return $r;
	}elsif($type->{$t} && $type->{$t} == -3){
		return $r;
	}else{
		die "object type error";
	}
};

$get_hash=sub{
	my $t=$get_byte->($_[0],$_[1]);
	my ($r,$k,$v)=({},undef,undef);
	if($type->{$t} && $type->{$t} == 1){
		$k=$get_string->(@_);
		$t=$get_byte->(@_);
		if($type->{$t} && $type->{$t} == 7){
			$t=$get_byte->(@_);
			$v=$get_object->($t,@_);
		}else{
			die "kev:value type error";
		}
		$r->{$k}=$v;
		$t=$get_byte->(@_);
		if($type->{$t} && $type->{$t} == 2){
			$v=$get_hash->(@_);
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
};

sub json_encode{
	my $str=shift || return {};
	my $index=0;
	my $t=$get_byte->($str,$index);
	return $get_object->($t,$str,$index);
}

my $builder_scalar=sub{
	my $s=shift;
	no warnings 'numeric';
	return length(""&$s)==1 && $s*0==0 && $s+0==$s ? $s : qq/"$s"/;
};
my $builder_undef=sub{'null'};
my $builder_boolean=sub{$_[0]?'true':'false'};
my $builder_object=sub{
	return unless @_;
	my $d=shift;

	if(defined $d){
		my $r=ref $d||'SCALAR';
		if($r eq 'SCALAR'){
			return $builder_scalar->($d);
		}elsif($r eq 'V::JSON::Boolean'){
			return $builder_boolean->($$d);
		}elsif($r eq 'ARRAY'){
			return $builder_array->($d);
		}elsif($r eq 'HASH'){
			return $builder_hash->($d);
		}else{
			die "type error $r";
		}
	}else{
		return $builder_undef->();
	}
};
$builder_hash=sub{
	my $d=shift;
	my $s=[];

	push @$s,qq("$_").":".$builder_object->($d->{$_}) for keys %$d;
	return '{'.join(',',@$s).'}';
};
$builder_array=sub{
	my $d=shift;
	my $s=[];

	push @$s,$builder_object->($_) for @$d;
	return '['.join(',',@$s).']';
};

sub json_decode{$builder_object->(shift)}

1;

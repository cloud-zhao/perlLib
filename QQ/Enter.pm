package QQ::Enter;
$VERSION="0.0.1";

use strict;
use warnings;
use Digest::HMAC_SHA1;
use URI::Escape;
use Mojo::UserAgent;
use JSON;

use base qw(Exporter);
our @EXPORT=qw();


sub new{
	my $class=shift;
	my ($id,$key,%para)=@_;
	my $pub_para={url=>"",region=>"sh"};
	my $self={};

	$pub_para->{$_}=exists $pub_para->{$_} ? $para{$_} : _para_check(1) for keys %para;
	$self->{id}	=$id 	 || die "ID Can not be empty!!!\n";
	$self->{key}	=$key	 || die "key Can not be empty!!!\n";
	$self->{JSON}   =JSON->new();
	$self->{region} =$pub_para->{region};
	$self->{url}	=$pub_para->{url}=~m#(?:^http://)?([^/]+(?:/[^/]+)*)(?!/)$# ? $1 : "";

	return bless $self,$class;
}

my $localdate=sub{
	my %time;
	$time{$_}=length($_)==1 ? "0$_" : $_ for 0..59;
	my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=localtime(time()-8*3600);
	$year+=1900;
	$mon+=1;
	return "$year-$time{$mon}-$time{$day}T$time{$hour}:$time{$min}:$time{$sec}Z";
};

my $strkey=sub {
	my ($key,$data)=@_;
	my $hmac=Digest::HMAC_SHA1->new($key);
	$hmac->add($data);
	return $hmac->b64digest."=";
};

my $signature=sub {
	my ($url,$pub_para,$key)=@_;
	my $req_str=join '&',map{my $pk=$_;s/_/./g;$_."=".$pub_para->{$pk}} sort{$a cmp $b} keys %$pub_para;
	my $mth=length("https://$url?$req_str") < 2000 ? 'GET' : 'POST';
	return $strkey->($key,"$mth$url?$req_str");
};

sub entrance{
	my $self=shift;
	my $ac_para=shift;
	die "Parameter error.\ntype HASH\n" unless ref $ac_para eq 'HASH';
	my $ua=Mojo::UserAgent->new();
	my $public_para={Action		=>	undef,
			 Region		=>	$self->{region},
		 	 Nonce		=>	srand,
			 Timestamp	=>	time,
			 SecretId	=>	$self->{id},
	 };

	$self->_set_url unless $self->{url};
	$public_para->{$_}=$ac_para->{$_} for keys %$ac_para;
	$public_para->{Signature}=$signature->($self->{url},$public_para,$self->{key});
	my $req_str=join '&',map{$_."=".uri_escape_utf8($public_para->{$_})} keys %$public_para;
	my $abs_url="https://$self->{url}";
	my $request="$abs_url?$req_str";
	my $header={"Content-Type"=>"application/x-www-form-urlencoded"};

	my $tx=length($request) < 2000 ? 
	$ua->build_tx('GET'=>$request) :
	$ua->build_tx('POST'=>$abs_url=>$header=>$req_str);
	
	$tx=$ua->start($tx);
	my $res;
	unless($res=$tx->success){
		my $err=$tx->error;
		return $err->{code} ? $tx->res->body : '{"code":9999,"message:"'.$err->{message}.'"}';
	}
	return $res->body;
}

sub _para_check{$_[1] ? $_[1] : die "Parameter error.\n"}
sub _res_check{
	my $self=shift;
	my $res=$self->_para_check(shift);
	my $info=$self->{JSON}->decode($res);

	return $info->{code}==0 ? $info : 0;
}

sub _set_url{
	my $self=shift;
	my $URL={Cvm => "cvm.api.qcloud.com/v2/index.php",
		 Cdn => "cdn.api.qcloud.com/v2/index.php",
	 	 Lb  => "lb.api.qcloud.com/v2/index.php",
		 Dfw => "dfw.api.qcloud.com/v2/index.php"};
	for(keys %$URL){
		$self->{url}=$URL->{$_} if $self->isa("QQ::".$_);
	}
}

1;

__END__

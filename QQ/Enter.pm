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
	my ($id,$key,$url,$region)=@_;
	my $self={};
	$self->{url}	=$url ?	"$url/v2/index.php" : "cvm.api.qcloud.com/v2/index.php";
	$self->{id}	=$id 	 || die "ID Can not be empty!!!\n";
	$self->{key}	=$key	 || die "key Can not be empty!!!\n";
	$self->{JSON}   =JSON->new();
	$self->{region} = $region || "sh";

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
	return $strkey->($key,"GET$url?$req_str");
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

	$public_para->{$_}=$ac_para->{$_} for keys %$ac_para;
	$public_para->{Signature}=$signature->($self->{url},$public_para,$self->{key});
	my $req_str=join '&',map{$_."=".uri_escape_utf8($public_para->{$_})} keys %$public_para;
	$req_str="https://$self->{url}?$req_str";

	my $tx=$ua->get($req_str);
	my $res;
	unless($res=$tx->success){
		print $tx->res->body,"\n";
		exit;
	}
	return $res->body;
}

1;

__END__

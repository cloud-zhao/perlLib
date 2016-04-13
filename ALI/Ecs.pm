package ALI::Ecs;
$VERSION="0.0.1";

use strict;
use warnings;
use UUID ':all';
use Digest::HMAC_SHA1;
use URI::Escape;
use Mojo::UserAgent;
use JSON;

use base qw(Exporter);
our @EXPORT=qw();


sub new{
	my $class=shift;
	my ($id,$key,$url,$format)=@_;
	my $self={};
	$self->{url}	=$url 	 || "ecs.aliyuncs.com";
	$self->{id}	=$id 	 || die "ID Can not be empty!!!\n";
	$self->{key}	=$key	 || die "key Can not be empty!!!\n";
	$self->{format}	=$format || "JSON";
	$self->{JSON}   =JSON->new();

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
	my ($pub_para,$key)=@_;
	my $req_str=join '&',map{$_."=".$pub_para->{$_}} sort{$a cmp $b} keys %$pub_para;
	$req_str="GET&".uri_escape_utf8("/")."&".uri_escape_utf8($req_str);
	return uri_escape_utf8($strkey->("$key&",$req_str));
};

sub entrance{
	my $self=shift;
	my (%ac_para)=@_;
	my $req_str;
	my $ua=Mojo::UserAgent->new();
	my $public_para={Format			=>	$self->{format},
			 Version		=>	"2014-05-26",
		 	 SignatureMethod	=>	"HMAC-SHA1",
			 SignatureVersion	=>	"1.0",
			 SignatureNonce		=>	uuid(),
			 Timestamp		=>	&$localdate,
			 AccessKeyId		=>	$self->{id},
	 };

	$public_para->{$_}=$ac_para{$_} for keys %ac_para;
	%$public_para=map{uri_escape_utf8($_)=>uri_escape_utf8($public_para->{$_})} keys %$public_para;
	$public_para->{Signature}=$signature->($public_para,$self->{key});
	$req_str=join '&',map{$_."=".$public_para->{$_}} keys %$public_para;
	$req_str="https://$self->{url}/?$req_str";

	my $tx=$ua->get($req_str);
	my $res;
	unless($res=$tx->success){
		my $err=$tx->error;
		$err->{code} ? print "Failed: $err->{code}\tresponse: $err->{message}\n" :
		print "Connection error: $err->{message}\n";
		exit;
	}
	return $res->body;
};

sub get_allinstance{
	my $self=shift;
	my $region=shift || die "Region can not be empty.\n";
	my $para={Action	=>"DescribeInstances",
		  RegionId	=>$region,
		  Status	=>"Running",
		  PageSize	=>1,
		  PageNumber	=>1};
	my $maxsize=100;
	my $maxnum=1;
	my $instances=[];
	
	my $totalcount=$self->{JSON}->decode($self->entrance(%$para))->{TotalCount};

	return $instances unless $totalcount;

	if($totalcount <= $maxsize){
		$maxnum=1;
	}else{
		my $flag=$totalcount % $maxsize;
		$maxnum= ($flag == 0) ? int($totalcount/$maxsize) : int($totalcount/$maxsize)+1;
	}

	$para->{PageSize}=$maxsize;
	for(1..$maxnum){
		$para->{PageNumber}=$_;
		my $ins=$self->{JSON}->decode($self->entrance(%$para))->{Instances}{Instance};
		push @$instances,@$ins;
	}

	return $instances;
}

sub instanced{
	my $self=shift;
	my ($insid,$action)=@_;
	my $ac={stop	=>"StopInstance",
		start	=>"StartInstance",
		reboot	=>"RebootInstance"};
	my $para={Action	=>$ac->{$action} || die "Parameter error.\n",
		  InstanceId	=>$insid || die "Parameter error.\n"};
	my $cb=sub {
		$para->{ForceStop}="true";
		$self->entrance(%$para);
	};
	my $fun={stop	=>$cb,
		 start	=>sub{$self->entrance(%$para)},
		 reboot	=>$cb};

	return &$fun->{$action};
}

sub modify_instance{
	my $self=shift;
	my ($insid,%para)=@_;
	die "Parameter error.\n" if @_%2 == 0;
	$para{Action}="ModifyInstanceAttribute";
	$para{InstanceId}=$insid || die "InstanceId can not be empty.\n";
	$self->entrance(%para);
}

1;

__END__

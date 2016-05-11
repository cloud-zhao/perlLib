package QQ::Cvm;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "cvm.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] eq URL ? $_[0] : URL};
my $para_check=sub{$_[0] ? $_[0] : die "Parameter error.\n"};


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
	my ($action,@insids)=@_;
	my $ac={stop	=>"StopInstances",
		start	=>"StartInstances",
		reboot	=>"RebootInstances",
		del	=>"ReturnInstance"};
	my $para={Action	=>$para_check->($ac->{$action})};

	my $cb1=sub {
		$para->{ForceStop}="true";
		$self->entrance($para);
	};
	my $cb2=sub{$self->entrance($para)};

	if(@insids && ($action ne 'del')){
		for(my $i;$i<@insids;$i++){
			$para->{"instanceIds.".$i}=$insids[$i];
		}
	}elsif(@insids){
		$cb2=sub{
			for(@insids){
				$para->{instanceId}=$_;
				$self->entrance($para);
			}
		};
	}

	my $fun={stop	=>$cb1,
		 start	=>$cb2,
		 reboot	=>$cb2,
	 	 del	=>$cb2};

	return &{$fun->{$action}};
}

sub modify_instance{
	my $self=shift;
	my $insid=$para_check->(shift);
	my $name=$para_check->(shift);
	
	my $para={Action	=>	"ModifyInstanceAttributes",
		  instanceId	=>	$insid,
	  	  instanceName	=>	$name};
	$self->entrance($para);
}


1;

__END__

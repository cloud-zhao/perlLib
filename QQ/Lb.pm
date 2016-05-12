package QQ::Lb;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "lb.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};

sub add_lb_hosts{
	my $self=shift;
	my $lbid=_para_check(shift);
	my $insids=shift;

	my $para={Action => "RegisterInstancesWithLoadBalancer"};
	my $w_check=sub{$_[0]>0 && $_[0]<100 ? $_[0] : 10 };

	$self->{url}=$url_check->($self->{url});
	if(ref $insids eq 'ARRAY'){
		for(my $i=0;$i<@$insids;$i++){
			$para->{"backends.$i.instanceId"}=$insids->[$i];
			$para->{"backends.$i.weight"}=10;
		}
	}elsif(ref $insids eq 'HASH'){
		my @keys=keys %$insids;
		for(my $i=0;$i<@keys;$i++){
			$para->{"backends.$i.instanceId"}=$key[$i];
			$para->{"backends.$i.weight"}=$w_check->($insids->{$key[$i]});
		}
	}else{
		die "Parameter type error.not HASH or ARRAY.\n";
	}

	$self->entrance($para);
}

sub get_lb_hosts{
	my $self=shift;
	my $lbid=_para_check(shift);

	my $para={Action 	=> "DescribeLoadBalancerBackends",
		  loadBalancerId=> $lbid,
		  offset	=> 0,
	  	  limit		=> 100};

	$self->{url}=$url_check->($self->{url});
	my $res=$self->entrance($para);
	my $info=$self->_res_check($res) || return $res;
	my $hosts={};
	$hosts->{$_->{lanIp}}=$_ for @{$info->{backendSet}};

	return {get_host	=>sub{$hosts->{+shift}},
		to_string	=>sub{
					for(keys %$hosts){
						print "$hosts->{$_}{unInstanceId}\t";
						print "$hosts->{$_}{instanceName}\t";
						print "$hosts->{$_}{lanIp}\t";
						print "$hosts->{$_}{weight}\t";
						print "$hosts->{$_}{wanIpSet}[0]\n";
					}
				}
	       };
}

1;

__END__

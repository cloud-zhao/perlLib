package QQ::Lb;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "lb.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};

sub get_lbs{
	my $self=shift;
	my (%user)=@_;

	my $all_para={loadBalancerIds	=> 1,
		      loadBalancerType	=> 0,
		      loadBalancerName	=> 0,
		      domain		=> 0,
		      loadBalancerVips	=> 1,
		      backendWanIps	=> 1,
		      orderBy		=> 0,
		      orderType		=> 0,
		      searchKey		=> 0,
		      offset		=> 0,
		      projectId		=> 0};

	my $para={Action	=> "DescribeLoadBalancers",
		  limit		=> 100,
		  projectId	=> 0,
	  	  offset	=> 0};

	$self->{url}=$url_check->($self->{url});
	for(keys %user){
		if(exists $all_para->{$_}){
			if($all_para->{$_}==0){
				$para->{$_}=$user{$_};
			}elsif(ref $user{$_} eq 'ARRAY'){
				for(my $i=0;$i<@{$user{$_}};$i++){
					$para->{"$_.$i"}=$user{$_}[$i];
				}
			}elsif(!ref($user{$_})){
				$para->{"$_.0"}=$user{$_};
			}
		}
	}
	my ($res,$total_count,@lbs);

	my $exec=sub{
		my $ex=shift;
		$res=$self->entrance($para);
		my $json=$self->_res_check($res);
		if($json){
			$total_count=$json->{totalCount};
			push @lbs,@{$json->{loadBalancerSet}};
			if($total_count>@lbs){
				$para->{offset}+=$para->{limit};
				$ex->($ex);
			}
		}
	};

	$exec->($exec);

	if(@lbs){
		if($total_count!=@lbs){
			print STDERR $res,"\n";
		}
		return {get_lb		=>sub{for(@lbs){return $_ if $_->{loadBalancerName} eq "$_[0]"}},
			get_all 	=>sub{@lbs},
			to_string	=>sub{for(@lbs){
						print "$_->{unLoadBalancerId}\t";
						print "$_->{loadBalancerName}\t";	
						print "$_->{domain}\t";	
						print "$_->{loadBalancerVips}[0]\n";	
					      }}
			};
	}
	
	return $res;
}

sub add_lb_hosts{
	my $self=shift;
	my $lbid=$self->_para_check(shift);
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
			$para->{"backends.$i.instanceId"}=$keys[$i];
			$para->{"backends.$i.weight"}=$w_check->($insids->{$keys[$i]});
		}
	}else{
		die "Parameter type error.not HASH or ARRAY.\n";
	}

	$self->entrance($para);
}

sub get_lb_hosts{
	my $self=shift;
	my $lbid=$self->_para_check(shift);

	my $para={Action 	=> "DescribeLoadBalancerBackends",
		  loadBalancerId=> $lbid,
		  offset	=> 0,
	  	  limit		=> 100};

	$self->{url}=$url_check->($self->{url});
	my ($res,$total_count,@hosts);

	my $exec=sub{
		my $ex=shift;
		$res=$self->entrance($para);
		my $json=$self->_res_check($res);
		if($json){
			$total_count=$json->{totalCount};
			push @hosts,@{$json->{backendSet}};
			if($total_count>@hosts){
				$para->{offset}+=$para->{limit};
				$ex->($ex);
			}
		}
	};

	$exec->($exec);

	if(@hosts){
		return {get_all		=>sub{@hosts},
			to_string	=>sub{
					for(@hosts){
						print "$_->{unInstanceId}\t";
						print "$_->{instanceName}\t";
						print "$_->{lanIp}\t";
						print "$_->{weight}\t";
						print "$_->{wanIpSet}[0]\n";
					}
				}
	       };
       }

       return $res;
}


1;

__END__

package QQ::Dfw;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "dfw.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};

sub get_sgs{
	my $self=shift;
	my (%user)=@_;
	my $all_para={projectId		=> 0,
		      instanceId	=> 0,
	      	      sgId		=> 0,
	      	      sgName		=> 0};

	my $para={Action	=> "DescribeSecurityGroups"};
	for(keys %user){
		$para->{$_}=$user{$_} if exists $all_para->{$_};
	}

	$self->{url}=$url_check->($self->{url});
	my $res=$self->entrance($para);
	my $sgs=$self->_res_check($res) || return $res;

	$sgs=$sgs->{data};
	
	return {get_sg		=>sub{for(@$sgs){return $_ if $_->{sgName} eq "$_[0]"}},
		to_string	=>sub{for(@$sgs){print "$_->{sgId}\t$_->{sgName}\t$_->{projectId}\n"}}};

}

sub get_sg_policy{
	my $self=shift;
	my $sgid=$self->_para_check(shift);

	my $para={Action	=> "DescribeSecurityGroupPolicy",
		  sgId		=> $sgid};

	$self->{url}=$url_check->($self->{url});
	my $res=$self->entrance($para);
	my $policy=$self->_res_check($res) || return $res;
	my $policy_in=$policy->{data}{ingress};
	my $policy_out=$policy->{data}{egress};

	my $policy_print=sub{
			my $direction=shift;
			my (@policy_)=@_;
			print uc($direction)." POLICY\n";
			for(my $i=0;$i<@policy_;$i++){
				print "\t$i\t".($policy_[$i]->{ipProtocol} || "All traffic");
				print ",".($policy_[$i]->{portRange} || "ALL");
				print ",".($policy_[$i]->{cidrIp} || "ANY");
				print ",$policy_[$i]->{action}\n";
			}
		};

	my $policy_list=sub{
			my (@policy_)=@_;
			my $array={};
			for(my $i=0;$i<@policy_;$i++){
				my $i_list=[];
				push @$i_list,$policy_[$i]->{ipProtocol} || 0;
				push @$i_list,$policy_[$i]->{portRange} || 0;
				push @$i_list,$policy_[$i]->{cidrIp} || 0;
				push @$i_list,$policy_[$i]->{action} eq "ACCEPT" ? 1 : 0;
				$array->{$i}=$i_list;
			}

			return $array;
		};

	return {to_string =>sub{$policy_print->("ingress",@$policy_in);
				$policy_print->("egress",@$policy_out);
			    },
		get_list  =>sub{
				my $all={};
				$all->{ingress}=$policy_list->(@$policy_in);
				$all->{egress}=$policy_list->(@$policy_out);
				return $all;
			    },
	       };
}

sub modify_sg_policy{
	my $self=shift;
	my $sgid=$self->_para_check(shift);
	my (%policys)=@_;
	my @dire=qw(ingress egress);
	my @action=qw(DROP ACCEPT);

	return 0 unless exists $policys{$dire[0]} || exists $policys{$dire[1]};

	my @params=qw(ipProtocol
		      portRange
		      cidrIp
		      action
		      desc);
	my $para={Action	=> "ModifySecurityGroupPolicy",
		  sgId		=> $sgid};

	#%policys=(ingress=>{0=>[0,0,0,1]});

	$self->{url}=$url_check->($self->{url});

	for my $gress (keys %policys){
		for my $num (keys %{$policys{$gress}}){
			my $policy=$policys{$gress}->{$num};
			$para->{"$gress.$num.$params[0]"}=$policy->[0] if $policy->[0];
			$para->{"$gress.$num.$params[1]"}=$policy->[1] if $policy->[1];
			$para->{"$gress.$num.$params[2]"}=$policy->[2] if $policy->[2];
			$para->{"$gress.$num.$params[3]"}=$policy->[3] ? $action[1] : $action[0];
			$para->{"$gress.$num.$params[4]"}=$policy->[4] if @$policy == 5;
		}
	}

	$self->entrance($para);
}

sub add_sg_policy{
	my $self=shift;
	my $sgid=$self->_para_check(shift);
	my (@policy)=@_;
	
	return 0 unless @policy;

	my $res=$self->get_sg_policy($sgid);
	my $policys=ref $res eq "HASH" ? $res->{get_list}() : return $res;

	my $num=keys %{$policys->{ingress}};
	$policys->{ingress}{$num}=\@policy;

	$self->modify_sg_policy($sgid,ingress=>$policys->{ingress},egress=>$policys->{egress});
}

1;

__END__

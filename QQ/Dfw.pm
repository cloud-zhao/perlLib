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

	return {to_string =>sub{$policy_print->("ingress",@$policy_in);
				$policy_print->("egress",@$policy_out)}};
}


1;

__END__

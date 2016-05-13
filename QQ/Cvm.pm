package QQ::Cvm;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "cvm.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};

sub get_instances{
	my $self=shift;
	my (%user)=@_;

	my $all_para={searchWord	=> 0,
		      offset		=> 0,
		      projectId		=> 0,
		      status		=> 0,
		      instanceIds	=> 1,
	              lanIps		=> 1};
	my $para={Action	=> "DescribeInstances",
		  status	=> 2,
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
	my ($res,$total_count,@instances);

	my $exec=sub{
		my $ex=shift;
		$res=$self->entrance($para);
		my $json=$self->_res_check($res);
		if($json){
			$total_count=$json->{totalCount};
			push @instances,@{$json->{instanceSet}};
			if($total_count>@instances){
				$para->{offset}+=$para->{limit};
				$ex->($ex);
			}
		}
	};

	$exec->($exec);

	if(@instances){
		if($total_count!=@instances){
			print STDERR $res,"\n";
		}
		return {get_ids		=>sub{my @ids;
					      push @ids,$_->{unInstanceId} for @instances;
					      return @ids;},
			get_all 	=>sub{@instances},
			to_string	=>sub{for(@instances){
						print "$_->{unInstanceId}\t";
						print "$_->{instanceName}\t";	
						print "$_->{lanIp}\t";	
						print "$_->{wanIpSet}[0]\n";	
					      }}
			};
	}
	
	return $res;
}

sub instanced{
	my $self=shift;
	my ($action,@insids)=@_;
	my $ac={stop	=>"StopInstances",
		start	=>"StartInstances",
		reboot	=>"RebootInstances",
		del	=>"ReturnInstance"};
	my $para={Action	=>$self->_para_check($ac->{$action})};

	my $cb1=sub {
		$para->{ForceStop}="true";
		$self->entrance($para);
	};
	my $cb2=sub{$self->entrance($para)};

	$self->{url}=$url_check->($self->{url});
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
	my $insid=$self->_para_check(shift);
	my $name=$self->_para_check(shift);
	
	my $para={Action	=>	"ModifyInstanceAttributes",
		  instanceId	=>	$insid,
	  	  instanceName	=>	$name};

	$self->{url}=$url_check->($self->{url});
	$self->entrance($para);
}


1;

__END__

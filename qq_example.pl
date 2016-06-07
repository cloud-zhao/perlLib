#!/bin/perl
use strict;
use warnings;
use QQ::Cvm;
use QQ::Cdn;
use QQ::Lb;
use QQ::Dfw;

my $id="self id";
my $key="self key";
my $res;

#my $cdn=QQ::Cdn->new($id,$key);
#print $cdn->get_hosts->{get_id}("q.cdn.mtq.tvm.cn"),"\n";
#print $cdn->get_cdn_log("q.cdn.mtq.tvm.cn")->{get_log}("20160508"),"\n";

#my $cvm=QQ::Cvm->new($id,$key);
#my $res=$cvm->get_instances;
#print_res($res,"to_string");

my $lb=QQ::Lb->new($id,$key);
#$res=$lb->get_lbs;
#print_res($res,"get_lb","cdn");
$res=$lb->get_lb_hosts("lb-elna4yg3");
print_res($res,"to_string");

my $sg=QQ::Dfw->new($id,$key);
#$res=$sg->get_sgs;
#$res=$sg->get_sg_policy("sg-9117yfdy");
#print_res($res,"to_string");


#parameter:
#     sgid,
#     ingress=>{policy_number=>[protocol,port,source_ip,aciton,desc]},
#     egress=>{policy_number=>[protocol,port,target_ip,action,desc]}
#parameter "desc" optional
#print $sg->modify_sg_policy("sg-88lxjane",ingress=>{4=>[qw(tcp 22),0,1]});
##print "\n";
#parameter:sgid,ip_protocol,port,source_ip,action,desc;
#print $sg->add_sg_policy("sg-88lxjane","tcp",9999,0,1),"\n";



sub print_res{
	my $res=shift;
	my $fun=shift;

	my $action={HASH	=>sub{print  "$_ :\t$_[0]->{$_}\n" for keys %{$_[0]}},
		    ARRAY	=>sub{print "$_\n" for @{$_[0]}},
	    	    SCALAR	=>sub{$_[0]}};
	
	if(ref $res eq "HASH"){
		my $info=$res->{$fun}(@_);
		my $type=ref $info;
		$action->{$type ? $type : "SCALAR" }($info);
	}else{
		print "$res\n";
	}
}

package QQ::Lb;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "lb.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] eq URL ? $_[0] : URL};
my $para_check=sub{$_[0] ? $_[0] : die "Parameter error.\n"};

sub add_lb_host{
	my $self=shift;
	my $lbid=$para_check->(shift);
	my $insids=$para_check->(shift);

	my $para={Action => "RegisterInstancesWithLoadBalancer"};
	my $w_check=sub{$_[0]>0 && $_[0]<100 ? $_[0] : 10 };
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

1;

__END__

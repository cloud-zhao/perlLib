package QQ::Cdn;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "cdn.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};

sub get_hosts{
	my $self=shift;
	my $para={Action => "DescribeCdnHosts"};

	$self->{url}=$url_check->($self->{url});
	my $res=$self->entrance($para);
	my $hosts=$self->_res_check($res) || return $res;
	my $info={};
	$info->{$_->{host}}=$_ for @{$hosts->{data}{hosts}};

	return {get_host	=>sub{$info->{$_[0]} || ""},
		get_id		=>sub{$_[0] ? exists $info->{$_[0]} ? $info->{$_[0]}{id} : "" : ""},
		get_projectid	=>sub{$_[0] ? $info->{$_[0]}->{project_id} : ""},
		to_string	=>sub{print "$_\t$info->{$_}{id}\t$info->{$_}{project_id}\n" for keys %$info}};
}

sub get_cdn_log{
	my $self=shift;
	my $host=shift || die "Host can not be empty.\n";
	my $para={Action => "GenerateLogList",
		  hostId => $self->get_hosts->{get_id}($host) || 0};

	$self->{url}=$url_check->($self->{url});
	my $res=$self->entrance($para);
	my $list=$self->_res_check($res) || return $res;
	my $info=[];
	push @$info,$_->{link} for @{$list->{data}{list}};

	return {get_log 	=>sub{$_[0] ? grep{/$_[0]/} @$info : $info},
		to_string	=>sub{print $_,"\n" for @$info}};
}

sub flush_cdn{
	my $self=shift;
	my (@url)=@_;
	my $para={Action => "RefreshCdnUrl"};
	my (@urls,@dirs,@result);

	$self->{url}=$url_check->($self->{url});
	m#^http://.+$# ? rindex($_,'/')==(length()-1) ? push @dirs,$_ : push @urls,$_ : print "Warning:$_ format error\n" for @url;

	my $exec=sub{
		my ($flag,@link)=@_;
		$para->{Action}= $flag eq "dir" ? "RefreshCdnDir" : "RefreshCdnUrl";
		if(@link){
			for(my $i=0;$i<@link;$i++){
				$para->{$flag."s.".$i}=$link[$i];
			}
			push @result,$self->entrance($para);
		}
	};
	
	$exec->("dir",@dirs);
	$exec->("url",@urls);

	return @result;
}


1;

__END__

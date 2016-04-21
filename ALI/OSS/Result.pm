package ALI::OSS::Result;
use strict;
use warnings;
use Mojo::DOM;

use base qw(Exporter);
our @EXPORT=qw();


sub new{
	my $class=shift;
	my $self={};
	$self->{body}=shift || "";
	$self->{dom}=Mojo::DOM->new($self->{body})->xml(1) || die "$!\n";
	return bless $self,$class;
}

sub get_buckets{
	my $self=shift;
	my $body=shift || $self->{body};
	my @label=qw(CreationDate Name Location ExtranetEndpoint IntranetEndpoint);
	my $bucket={};
	my $buckets=[];

	for my $dom ($self->{dom}->parse($body)->find('Bucket')->each){
		$bucket->{$_}=$dom->at($_)->text for @label;
		push @$buckets,$bucket;
	}

	my $get_name=sub{
		my @names;
		push @names,$_->{Name} for @$buckets;
		return @names;
	};
	my $get_bucket=sub{
		my $name=shift || return $buckets;
		for(@$buckets){
			return $_ if $_->{Name} eq $name;
		}
	};
	my $to_string=sub{
		print "Name\tCreate Date\tLocation\n";
		print "$_->{Name}\t$_->{CreationDate}\t$_->{Location}\n" for @$buckets;
	};

	return {get_name	=>$get_name,
		get_bucket	=>$get_bucket,
		to_string	=>$to_string};
}









1;

__END__

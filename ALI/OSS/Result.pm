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
	$slef->{dom}=Mojo::DOM->new($self->{body}) || die "$!\n";
	return bless $self,$class;
}

sub get_buckets{
	my $self=shift;
}









1;

__END__

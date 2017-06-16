package Avro::Schema::Named;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(Avro::Schema);
use Avro::Base;

sub new{
	my $class=shift;
	my $type=shift;
	my $name=shift // return;
	my ($namespace,$other_props)=@_;
	my $self=Avro::Schema->new($type,$other_props || {});
	my $self->{name}=$name;
	my $self->{namespace}=$namespace;
	bless $self,$class;
}

1;

__END__

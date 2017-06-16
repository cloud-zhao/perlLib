package Avro::Schema::Primitive;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(Avro::Schema);
use Avro::Base;

sub new{
	my $class=shift;
	my $type=shift;
	return if ! primitive_types->{$type};
	my $self=Avro::Schema->new($type,shift || {});

	bless $self,$class;
}

1;

__END__

package Avro::IO::Ts;

use strict;
use warnings;
use base qw(Avro::IO);
use Avro::Base;

sub get_struct{
	_first \@_;
	my $first=shift;
	return {ref	=>$first,
		package	=>__PACKAGE__,
		data	=>shift
	};
}

package Avro::IO::Tts;

my $ff=200;
sub t{
	print "tts: $ff\n";
	print "abn: ",(keys %{+Avro::Base::named_types})[1],"\n";
}

1;

__END__

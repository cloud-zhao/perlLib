package Avro::IO::BinaryDecoder;

use strict;
use warnings;
use base qw(Avro::IO);
use Avro::Base;


sub read_null{''}
sub read_boolean{!!$_[0]->read(1)}
sub read_int{$_[0]->read_long}

sub read_long{
	my $self=shift;
	my $b=ord($self->read(1));
	my $n=$b&0x7f;
	my $s=7;
	
	while(($b & 0x80) != 0){
		$b=ord($self->read(1));
		$n |= ($b&0x7f)<<$s;
		$s+=7;
	}
	my $data=sprintf("%d",($n>>1)^-($n&1));

	return $data;
}

sub read_float{
	my $self=shift;

	my $bits = ((ord(self->read(1)) & 0xff) |
      		   ((ord(self->read(1)) & 0xff) <<  8) |
      		   ((ord(self->read(1)) & 0xff) << 16) |
      		   ((ord(self->read(1)) & 0xff) << 24));
	my $data=unpack(struct_float,pack(struct_int,$bits));

	return $data;
}

sub read_double{
	my $self=shift;

	my $bits = ((ord(self->read(1)) & 0xff) | 
		  ((ord(self->read(1)) & 0xff) << 8)  |
		  ((ord(self->read(1)) & 0xff) << 16) |
		  ((ord(self->read(1)) & 0xff) << 24) |
		  ((ord(self->read(1)) & 0xff) << 32) |
		  ((ord(self->read(1)) & 0xff) << 40) |
		  ((ord(self->read(1)) & 0xff) << 48) |
		  ((ord(self->read(1)) & 0xff) << 56));
	my $data=unpack(struct_double,pack(struct_long,$bits));

	return $data;
}

sub read_bytes{$_[0]->read($_[0]->read_long)}
sub read_string{decode "utf8",$_[0]->read_bytes}


sub check_crc32{
	my $self=shift;
	my $bytes=shift;

	
}



1;

__END__

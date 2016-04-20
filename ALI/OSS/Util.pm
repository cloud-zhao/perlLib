package ALI::OSS::Util;
use strict;
use warnings;
use Digest::HMAC_SHA1;
use Digest::MD5 qw(md5_base64);

use base qw(Exporter);
our @EXPORT=qw(gtime get_md5 get_sign validate_bucket validate_object);

sub gtime{
	my $time=shift || time;
	my %dnum;
	my @weekday=qw(Sun Mon Tue Wed Thu Fri Sat);
	my @month=qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	$dnum{$_}=length($_)==1 ? "0$_" : $_ for 0..59;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime $time;
	return "$weekday[$wday], $dnum{$mday} $month[$mon] ".
		($year+1900).
		" $dnum{$hour}:$dnum{$min}:$dnum{$sec} GMT";
}

sub get_md5{md5_base64(shift)."==";}

sub get_sign{
	my $id=shift;
	my $key=shift;
	my ($method,$content_md5,$content_type,$date,$osshead,$resource)=@_;
	my $sigstr="$method\n$content_md5\n$content_type\n$date\n$osshead$resource";
	my $sig=Digest::HMAC_SHA1->new($key);
	$sig->add($sigstr);
	return "OSS $id:".$sig->b64digest()."=";
}

sub validate_bucket{
	my $bucket_name=shift;
	my $format=qr/^[a-z0-9][a-z0-9-]{2,62}$/;
	die "Bucket name format error.\n" if $bucket_name !~ $format;
	return "$bucket_name";
}

sub validate_object{
	my $object=shift || die "Object can not be empty.\n";
	my $format=qr/^.{1,1023}$/;
	if(index($object,'/')==0 || $object!~$format){
		die "Object name format error.\n";
	}else{
		return "$object";
	}
}

1;

__END__

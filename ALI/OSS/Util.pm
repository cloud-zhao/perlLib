package ALI::OSS::Util;
use strict;
use warnings;
use Digest::HMAC_SHA1;
use Digest::MD5 qw(md5_base64);

use base qw(Exporter);
our @EXPORT=qw(	gtime get_file_md5 
		get_sign validate_bucket 
		validate_object validate_filename 
		get_resource get_str_md5);

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

sub validate_filename{
	my $file_name=shift;
	return $file_name=~m/^[^\n\t]{1,255}$/ ? 1 : 0;
}

sub get_file_md5{
	my $file=shift || die "Content can not be empty.\n";
	if(validate_filename($file) && -f $file){
		my $content;
		open my $fh,"<$file" or die "can't open file $file\t$!\n";
		my $len=(stat $file)[7] || 16384;
		die "Sysread file failed.\n" unless sysread($fh,$content,$len) > 0;
		close $fh;
		md5_base64($content)."==";
	}else{
		die "$file not found!!!\n";
	}
}

sub get_str_md5{
	my $content=shift || die "Content can not be empty.\n";
	md5_base64($content)."==";
}

sub get_resource{
	my $bucket=shift || "";
	my $object=shift || "";
	if($bucket && $object){
		$bucket=validate_bucket($bucket);
		$object=validate_object($object);
		return "/".$bucket."/".$object;
	}elsif($bucket){
		$bucket=validate_bucket($bucket);
		return "/".$bucket."/";
	}else{
		return "/";
	}
}

sub get_sign{
	my $id=shift;
	my $key=shift;
	my ($method,$header,$resource)=@_;
	my $content_md5=$header->{"Content-MD5"} || "";
	my $content_type=$header->{"Content-Type"};
	my $date=$header->{Date};
	my $osshead=join "\n",map{$_.":".$header->{$_}} sort{$a cmp $b } grep /^x-oss.*/,keys %$header;
	$osshead=$osshead ? $osshead."\n" : "";
	my $sigstr="$method\n$content_md5\n$content_type\n$date\n$osshead$resource";
	my $sig=Digest::HMAC_SHA1->new($key);
	$sig->add($sigstr);
	return "OSS $id:".$sig->b64digest()."=";
}

sub validate_bucket{
	my $bucket_name=shift;
	my $format=qr/^[a-z0-9][a-z0-9-]{2,62}$/;
	die "Bucket name format error.\n" if $bucket_name !~ $format;
	return $bucket_name;
}

sub validate_object{
	my $object=shift || die "Object can not be empty.\n";
	my $format=qr/^.{1,1023}$/;
	if(index($object,'/')==0 || $object!~$format){
		die "Object name format error.\n";
	}else{
		return $object;
	}
}

1;

__END__

package ALI::OSS::Client;
use strict;
use warnings;
use ALI::OSS::Http;
use ALI::OSS::MimeType;
use ALI::OSS::Util;
use ALI::OSS::Result;

use base qw(Exporter);
our @EXPORT=qw();

use constant {
	#CLINET http field
	H_HEAD		=>	"headers",
	H_BODY		=>	"body",
	H_MTH		=>	"method",
	H_URL		=>	"url",
	H_R_TIMEOUT	=>	"timeout",
	#HTTP method
	GET		=>	"GET",
	PUT		=>	"PUT",
	HEAD		=>	"HEAD",
	POST		=>	"POST",
	DEL		=>	"DELETE",
	OPTIONS		=>	"OPTIONS",
	PATCH		=>	"PATCH",
	#HTTP headers
	CO_TYPE		=>	"Content-Type",
	CO_LENGTH	=>	"Content-Length",
	CO_MD5		=>	"Content-MD5",
	CO_RANGE	=>	"Content-Range",
	CO_DISPOSITION	=>	"Content-Disposition",
	CO_ENCODING	=>	"Content-Encoding",
	CO_CODING	=>	"Content-Coding",
	DATE		=>	"Date",
	EXPIRES		=>	"Expires",
	CA_CONTROL	=>	"Cache-control",
	IF_MODIFIED	=>	"If-Modified-Since",
	IF_UNMODIFIED	=>	"If-Unmodified-Since",
	IF_MATCH	=>	"If-Match",
	IF_NONE_MATCH	=>	"If-None-Match",
	AUTH		=>	"Authorization",
	#ALI oss headers
	OSS_ACL		=>	"x-oss-acl",
	OSS_O_ACL	=>	"x-oss-object-acl",
	OSS_O_GROUP	=>	"x-oss-file-group",
	OSS_O_C_SOURCE	=>	"x-oss-copy-source",
	OSS_O_C_S_RANGE	=>	"x-oss-copy-source-range",
	#ALI OSS acl
	OSS_ACL_TYPE_P	=>	"private",
	OSS_ACL_TYPE_PR	=>	"public-read",
	OSS_ACL_TYPE_PW	=>	"public-read-write",
};

sub new{
	my $class=shift;
	my ($id,$key,$url,$timeout)=@_;
	my $self={};
	$self->{ID}=$id || die "ID can not be empty.\n";
	$self->{KEY}=$key || die "KEY can not be empty.\n";
	$self->{URL}=$url || "https://oss-cn-hangzhou.aliyuncs.com";
	$self->{TIMEOUT}=$timeout || 300;
	$self->{UA}=ALI::OSS::Http->new($self->{URL}) || die "Create http object failed.\n";
	$self->{DOM}=ALI::OSS::Result->new;

	return bless $self,$class;
}

sub get_buckets{
	my $self=shift;
	my $header={
		DATE()		=>	gtime(),
		CO_TYPE()	=>	"",
		AUTH()		=>	""};
	my $object="/";
	my $resource="$object";
	$header->{+CO_TYPE}=get_mimetype;
	$header->{+AUTH}=get_sign($self->{ID},$self->{KEY},GET,"",
				$header->{+CO_TYPE},$header->{+DATE},"",$resource);
	$self->{UA}->set_req(H_HEAD()=>$header,H_MTH()=>GET());
	$self->{DOM}->get_buckets($self->{UA}->send_req->res_body)->{to_string}();
}

sub put_object{
	my $self=shift;
	my ($bucket,$object,$content)=@_;
	my $header={CA_CONTROL()	=>	"no-cache",
		    CO_MD5()		=>	"",
	    	    CO_LENGTH()		=>	"",
	    	    DATE()		=>	gtime(),
	    	    CO_TYPE()		=>	"",
	    	    EXPIRES()		=>	gtime(time+10*60),
	    	    CO_ENCODING()	=>	"utf-8",
	    	    AUTH()		=>	""
	    };
	$bucket=validate_bucket $bucket;
	$object=validate_object	$object;
	my $resource="/$bucket/$object";

	$header->{+CO_MD5}=get_md5 $content;
	$header->{+CO_LENGTH}=length $content || die "Content can not be empty.\n";
	$header->{+CO_TYPE}=get_mimetype $object;
	$header->{+AUTH}=get_sign($self->{ID},$self->{KEY},PUT,$header->{+CO_MD5},
				$header->{+CO_TYPE},$header->{+DATE},"",$resource);
	my $url=$self->{URL}.$resource;

	#print "$_\t$header->{$_}\n" for keys  %$header;

	my $ua=$self->{UA}->set_req(H_HEAD()=>$header,H_BODY()=>$content,H_MTH()=>PUT());
	$ua->send_req->res_tostring;

}

1;

__END__

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
	H_BTYPE		=>	"bodytype",
	H_MTH		=>	"method",
	H_URL		=>	"url",
	H_RES		=>	"resource",
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
	my ($id,$key,$url,$ctimeout,$rtimeout)=@_;
	my $self={};
	$self->{ID}=$id || die "ID can not be empty.\n";
	$self->{KEY}=$key || die "KEY can not be empty.\n";
	$self->{URL}=$url || "https://oss-cn-hangzhou.aliyuncs.com";
	$self->{C_TIMEOUT}=$ctimeout || "";
	$self->{R_TIMEOUT}=$rtimeout || "";
	$self->{DOM}=ALI::OSS::Result->new;

	return bless $self,$class;
}

my $check_para=sub{shift || die "Can not be empty.\n"};

sub get_buckets{
	my $self=shift;
	my $header={
		DATE()		=>	gtime(),
		CO_TYPE()	=>	get_mimetype,
		AUTH()		=>	""};

	my $req={H_MTH()	=>	GET,
		 H_RES()	=>	get_resource,
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL}};

	my $res=$self->_send_req($req);
	$res->get_buckets->{to_string}();
}

sub put_bucket{
	my $self=shift;
	my $bucket=$check_para->(shift);
	my $acl=shift || OSS_ACL_TYPE_PR;
	my $object="?acl";
	my $header={
		DATE()		=>	gtime(),
		CO_TYPE()	=>	get_mimetype,
		AUTH()		=>	"",
		OSS_ACL()	=>	$acl};

	my $req={H_MTH()	=>	PUT,
		 H_RES()	=>	get_resource($bucket,$object),
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL}};
	

	$self->_send_req($req)->res_tostring;
}

sub get_objects{
	my $self=shift;
	my $bucket=$check_para->(shift);
	my $opt=shift;

	my $header={
		DATE()		=>	gtime,
		CO_TYPE()	=>	get_mimetype,
		AUTH()		=>	""};
	if(ref $opt eq 'HASH'){
		$header->{$_}=$opt->{$_} for keys %$opt;
	}

	my $req={H_MTH()	=>	GET,
		 H_RES()	=>	get_resource($bucket),
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL}};

	$self->_send_req($req)->get_objects->{to_string}();
}

sub upload_file{
	my $self=shift;
	my $bucket=$check_para->(shift);
	my $object=$check_para->(shift);
	my $file=$check_para->(shift);
	my $header={CA_CONTROL()	=>	"no-cache",
		    CO_MD5()		=>	"",
	    	    CO_LENGTH()		=>	"",
	    	    DATE()		=>	gtime(),
	    	    CO_TYPE()		=>	"",
	    	    EXPIRES()		=>	gtime(time+10*60),
	    	    CO_ENCODING()	=>	"utf-8",
	    	    AUTH()		=>	""
	    };

	die "$file not found.\n" unless validate_filename($file) && -f $file;
	$header->{+CO_MD5}=get_file_md5 $file;
	$header->{+CO_LENGTH}=(stat $file)[7];
	$header->{+CO_TYPE}=get_mimetype $object;

	my $req={H_MTH()	=>	PUT,
		 H_RES()	=>	get_resource($bucket,$object),
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL},
	 	 H_BODY()	=>	$file,
	 	 H_BTYPE()	=>	"file"};

	$self->_send_req($req)->res_tostring;
}

sub put_object{
	my $self=shift;
	my $bucket=$check_para->(shift);
	my $object=$check_para->(shift);
	my $content=$check_para->(shift);
	my $header={CA_CONTROL()	=>	"no-cache",
		    CO_MD5()		=>	"",
	    	    CO_LENGTH()		=>	"",
	    	    DATE()		=>	gtime(),
	    	    CO_TYPE()		=>	"",
	    	    EXPIRES()		=>	gtime(time+10*60),
	    	    CO_ENCODING()	=>	"utf-8",
	    	    AUTH()		=>	""
	    };
	$header->{+CO_MD5}=get_str_md5 $content;
	$header->{+CO_LENGTH}=length $content;
	$header->{+CO_TYPE}=get_mimetype $object;

	my $req={H_MTH()	=>	PUT,
		 H_RES()	=>	get_resource($bucket,$object),
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL},
	 	 H_BODY()	=>	$content,
	 	 H_BTYPE()	=>	"object"};

	$self->_send_req($req)->res_tostring;
}

sub _get_sign{
	my $self=shift;
	return get_sign($self->{ID},$self->{KEY},@_);
}

sub _send_req{
	my $self=shift;
	my $req=$check_para->(shift);
	my $ua=ALI::OSS::Http->new($self->{C_TIMEOUT},$self->{R_TIMEOUT});
	my ($header,$method,$resource,$url)=($req->{+H_HEAD},$req->{+H_MTH},
						$req->{+H_RES},$req->{+H_URL});
	$header->{+DATE}=gtime;
	if(exists $header->{+EXPIRES}){
		$header->{+EXPIRES}=gtime(time+10*60);
	}
	$header->{+AUTH}=$self->_get_sign($method,$header,$resource);
	$url=$url.$resource;
	
	exists $req->{+H_BTYPE} ?
	$ua->set_req(H_HEAD()=>$header,H_BODY()=>$req->{+H_BODY},H_BTYPE()=>$req->{+H_BTYPE},H_MTH()=>$method,H_URL()=>$url) :
	$ua->set_req(H_HEAD()=>$header,H_MTH()=>$method,H_URL()=>$url) ;
	my $res=$self->{DOM}->res_parse($ua->send_req);
	if($res->res_code==500){
		print STDERR 
		"CODE: $res->res_code\n
		BODY: $res->res_body\n
		MESSAGE: $res->res_message\n";
		$self->_send_req($req);
	}

	return $res;
}

1;

__END__

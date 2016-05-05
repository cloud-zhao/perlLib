package ALI::OSS::Client;
use strict;
use warnings;
use ALI::OSS::Http;
use ALI::OSS::MimeType;
use ALI::OSS::Util;
use ALI::OSS::Result;

use base qw(Exporter);
our @EXPORT=qw( OSS_ACL_TYPE_P
		OSS_ACL_TYPE_PR
		OSS_ACL_TYPE_PW
		);

use constant {
	#Http body type
	HBT_F		=>	"file",
	HBT_O		=>	"object",
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
	OSS_F_GROUP	=>	"x-oss-file-group",
	OSS_C_SOURCE	=>	"x-oss-copy-source",
	OSS_C_S_RANGE	=>	"x-oss-copy-source-range",
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

sub _put_buckets{
	my $self=shift;
	my $bucket=$check_para->(shift);
	my $object=$check_para->(shift);
	my $opts= @_ ? ref $_[0] eq 'HASH' ? $_[0] : die "Parameter format not HASH.\n" : {};
	my $header={
		DATE()		=>	gtime(),
		CO_TYPE()	=>	"",
		AUTH()		=>	""};

	my $req={H_MTH()	=>	PUT,
		 H_RES()	=>	get_resource($bucket,"?".$object),
	 	 H_HEAD()	=>	$header,
	 	 H_URL()	=>	$self->{URL}};
	
	
	my $xml_head='<?xml version="1.0" encoding="UTF-8"?>';
	my $pub_head={CO_TYPE()=>get_mimetype("a.xml"),CO_LENGTH()=>""};
	my $get_info={	acl		=>	sub{return {H_HEAD()=>{OSS_ACL()=>$opts->{acl},
							        CO_TYPE()=>get_mimetype}
						}},
		  	website		=>	sub{return {H_HEAD()=>$pub_head,
						     H_BODY()=>$xml_head."<WebsiteConfiguration>
						     <IndexDocument><Suffix>$opts->{Suffix}</Suffix></IndexDocument>
						     <ErrorDocument><Key>$opts->{Key}</Key></ErrorDocument>
						     </WebsiteConfiguration>"
						}},
		  	logging		=>	sub{return {H_HEAD()=>$pub_head,
						     H_BODY()=>$xml_head."<BucketLoggingStatus><LoggingEnabled>
						     <TargetBucket>".$opts->{TargetBucket}."</TargetBucket>
						     <TargetPrefix>".$opts->{TargetPrefix}."</TargetPrefix>
						     </LoggingEnabled></BucketLoggingStatus>"
						}},
			referer		=>	sub{return {H_HEAD()=>$pub_head,
						     H_BODY()=>$xml_head."<RefererConfiguration>
						     <AllowEmptyReferer>true</AllowEmptyReferer>
						     <RefererList>".
						     join '',map{"<Referer>$_</Referer>"} @{$opts->{Referers}}
						     ."</RefererList>
						     </RefererConfiguration>"
						}},
			lifecycle	=>	sub{return {H_HEAD()=>$pub_head,
						     H_BODY()=>$xml_head."<LifecycleConfiguration>".
						     join '',map{"<Rule><ID>$_->{ID}</ID>
						     <Prefix>$_->{Prefix}</Prefix>
						     <Status>$_->{Status}</Status>
						     <Expiration><Days>$_->{ExDays}</Days></Expiration>
						     <AbortMultipartUpload><Days>$_->{AbDays}</Days></AbortMultipartUpload>
						     </Rule>"} @{$opts->{Rules}}
						     ."</LifecycleConfiguration>"
						}}
	};


	my $info= exists $get_info->{$object} ? $get_info->{$object}() : die "Object error.!\n" ;

	$header->{$_}=$info->{+H_HEAD}{$_} for keys %{$info->{+H_HEAD}};
	if(exists $info->{+H_BODY}){
		$header->{+CO_LENGTH}=length $info->{+H_BODY};
		$req->{+H_BODY}=$info->{+H_BODY};
		$req->{+H_BTYPE}=HBT_O;
	}
		
	$self->_send_req($req)->res_tostring;

}

sub put_bucket{shift->_put_buckets(shift,"acl",{acl=>shift || OSS_ACL_TYPE_PR})};
sub put_bucket_acl{shift->_put_buckets(shift,"acl",{acl=>shift || OSS_ACL_TYPE_PR})};
sub put_bucket_logging{shift->_put_buckets(shift,"logging",{TargetBucket=>shift,TargetPrefix=>shift})};
sub put_bucket_website{shift->_put_buckets(shift,"website",{Suffix=>shift,Key=>shift})};
sub put_bucket_referer{shift->_put_buckets(shift,"referer",{Referers=>[@_]})};

sub put_bucket_lifecycle{
	my $self=shift;
	my $bucket=shift;
	my $object="lifecycle";
	my $opts={Rules=>[]};
	my @list=@_ ? @_%5==0 ? @_ : die "Parameter error.\n" : exit;

	for(my $i=0;$i<@list;$i++){
		my %rules;
		$rules{ID}=$list[$i++];
		$rules{Prefix}=$list[$i++];
		$rules{Status}=$list[$i++];
		$rules{ExDays}=$list[$i++];
		$rules{AbDays}=$list[$i];
		push @{$opts->{Rules}},\%rules;
	}

	$self->_put_buckets($bucket,$object,$opts);
}

my $create_sub=sub{
	my ($class,%subs)=@_;
	my $set_sub=eval{require Sub::Util;Sub::Util->can('set_subname')} || die;
	no strict 'refs';
	no warnings 'redefine';
	*{"${class}::$_"}=$set_sub->("${class}::$_",$subs{$_}) for keys %subs;
};

my $create_pucket_sub=sub{
	my ($mth,$sub_name,$object_name)=@_;
	$create_sub->(__PACKAGE__,$sub_name,sub{
		my $self=shift;
		my $bucket=$check_para->(shift);
		my $object=$object_name ? "?".$object_name : "";
		my $header={
			DATE()		=>	gtime(),
			CO_TYPE()	=>	get_mimetype,
			AUTH()		=>	""};

		my $req={H_MTH()	=>	$mth,
			 H_RES()	=>	get_resource($bucket,$object),
		 	 H_HEAD()	=>	$header,
		 	 H_URL()	=>	$self->{URL}};

		 #return $self->_send_req($req);
		$self->_send_req($req)->res_tostring;
	});
};

$create_pucket_sub->(GET,"get_bucket_".$_,$_) for qw(acl location logging website referer lifecycle);
$create_pucket_sub->(GET,"get_bucket_info","bucketInfo");
$create_pucket_sub->(DEL,"del_bucket_".$_,$_) for qw(logging website lifecycle);
$create_pucket_sub->(DEL,"del_bucket","");

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
	 	 H_BTYPE()	=>	HBT_F};

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
	 	 H_BTYPE()	=>	HBT_O};

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

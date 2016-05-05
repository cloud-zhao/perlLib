package ALI::OSS::Http;
use strict;
use warnings;
use ALI::OSS::UserAgent;
use ALI::OSS::Util;


sub new{
	my $class=shift;
	my $self={};
	$self->{connect}{timeout}=shift || 30;
	$self->{req}{timeout}=shift || 5184000;
	@{$self->{method}}{qw(put delete get head post options patch)}=qw(PUT DELETE GET HEAD POST OPTIONS PATCH);
	return bless $self,$class;
}

sub set_http{
	my $self=shift;
	my $key =shift || die "Key can not be empty.\n";
	my $value =shift || die "Value can not be empty.\n";
	if(ref $value eq 'HASH'){
		$self->{$key}{$_}=$value->{$_} for keys %$value;
	}else{
		die "Value type error.\n";
	}
	return $self;
}

sub set_connect{
	my $self=shift;
	my %con=@_;
	$self=$self->set_http(connect=>\%con);
	return $self;
}

sub set_req{
	my $self=shift;
	my %req=@_;
	$self=$self->set_http(req=>\%req);
	return $self;
}

my $get_url=sub{shift->{req}{url} || die "Url can not be empty.\n"};
my $get_headers=sub{ref $_[0]->{req}{headers} eq 'HASH' ? $_[0]->{req}{headers} : {}};
my $get_method=sub{
	my $self=shift;
	my $me=$self->{method}{lc($self->{req}{method})} || die "Unknown http method.\n";
	return $me;
};
my $get_body=sub{exists $_[0]->{req}{body} ? $_[0]->{req}{body} : undef};
my $get_bodytype=sub{exists $_[0]->{req}{bodytype} ? uc $_[0]->{req}{bodytype} eq 'FILE' ? 1 : 0 : 0};


sub send_req{
	my $self=shift;
	my $ua=ALI::OSS::UserAgent->new();
	my $method=$self->$get_method;
	my $url=$self->$get_url;
	my $header=$self->$get_headers;
	my $body=$self->$get_body;
	#print "$method $url $body\n";
	#print "$_\t$header->{$_}\n" for keys %$header;
	$ua=$ua->request_timeout($self->{req}{timeout})->connect_timeout($self->{connect}{timeout});
	my $tx=$ua->build_tx($method=>$url=>$header);
	$self->$get_bodytype ? $tx->req->content->asset(Mojo::Asset::File->new(path=>$body)) :
	$tx->req->body($body) if defined $body;
	$tx=$ua->start($tx);
	my $res;
	unless($res=$tx->success){
		my $err=$tx->error;
		$self->{res}{code}=$err->{code};
		$self->{res}{body}=$tx->res->body if $err->{code};
		$self->{res}{message}=$err->{message};
		$self->{res}{headers}=$tx->res->headers->to_hash if $err->{code};
	}else{
		$self->{res}{code}=$res->code;
		$self->{res}{body}=$res->body;
		$self->{res}{message}=$res->message;
		$self->{res}{headers}=$res->headers->to_hash;
	}
	
	return $self->{res};
}


1;

__END__

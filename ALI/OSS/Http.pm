package ALI::OSS::Http;
use strict;
use warnings;
use ALI::OSS::UserAgent;


sub new{
	my $class=shift;
	my $self={};
	$self->{connect}{timeout}=30;
	$self->{req}{timeout}=5184000;
	@{$self->{method}}{qw(put del get head post opt patch)}=qw(PUT DELETE GET HEAD POST OPTIONS PATCH);
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

sub res_tostring{
	my $self=shift;
	my $res=$self->{res};
	print "CODE: $res->{code}\n";
	print "BODY: $res->{body}\n";
	print "MESSAGE: $res->{message}\n";
	print "HEADER:\t$_ : $res->{headers}{$_}\n" for keys %{$res->{headers}};
}

my $get_url=sub{shift->{req}{url} || die "Url can not be empty.\n"};
my $get_headers=sub{
	my $header=shift->{req}{headers};
	return ref $header eq 'HASH' ? $header : {};
};

sub send_req{
	my $self=shift;
	my $t=ALI::OSS::UserAgent->new();
	my $method=$self->get_method;
	my $url=$self->$get_url;
	my $header=$self->$get_headers;
	my $body=$self->{req}{body};
	$t=$t->request_timeout($self->{req}{timeout})->connect_timeout($self->{connect}{timeout});
	my $tx=$t->send_request($method,$url,$header,$body);
	my $res;
	unless($res=$tx->success){
		my $err=$tx->error;
		if($err->{code}){
			$self->{res}{code}=$err->{code};
			$self->{res}{body}=$tx->res->body;
			$self->{res}{message}=$err->{message};
			$self->{res}{headers}=$tx->res->headers->to_hash;
		}
		$self->{connect}{message}=$err->{message};
	}else{
		$self->{res}{code}=$res->code;
		$self->{res}{body}=$res->body;
		$self->{res}{message}=$res->message;
		$self->{res}{headers}=$res->headers->to_hash;
	}
	return $self;
}

sub get_method{
	my $self=shift;
	my $me=$self->{method}{lc($self->{req}{method})} || die "Unknown http method.\n";
	return $me;
}

1;

__END__

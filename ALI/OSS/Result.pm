package ALI::OSS::Result;
use strict;
use warnings;
use Mojo::DOM;

use base qw(Exporter);
our @EXPORT=qw();


sub new{
	my $class=shift;
	my $self={};
	$self->{res}=shift;
	$self->{dom}=Mojo::DOM->new->xml(1) || die "$!\n";
	return bless $self,$class;
}

sub get_buckets{
	my $self=shift;
	my $body=shift || $self->res_body;
	my @label=qw(CreationDate Name Location ExtranetEndpoint IntranetEndpoint);
	my $buckets=[];

	for my $dom ($self->{dom}->parse($body)->find('Bucket')->each){
		my $bucket={};
		$bucket->{$_}=$dom->at($_)->text for @label;
		push @$buckets,$bucket;
	}

	my $get_name=sub{
		my @names;
		push @names,$_->{Name} for @$buckets;
		return @names;
	};
	my $get_bucket=sub{
		my $name=shift || return $buckets;
		for(@$buckets){
			return $_ if $_->{Name} eq $name;
		}
	};
	my $to_string=sub{
		print "$_\t" for @label;
		print "\n";
		for my $o (@$buckets){
			print "$o->{$_}\t" for @label;
			print "\n";
		}
	};

	return {get_name	=>$get_name,
		get_bucket	=>$get_bucket,
		to_string	=>$to_string};
}

sub get_objects{
	my $self=shift;
	my $body=shift || $self->res_body;
	my @label=qw(Key Size LastModified Type);
	my $objects=[];

	for my $dom ($self->{dom}->parse($body)->find('Contents')->each){
		my $object={};
		$object->{$_}=$dom->at($_)->text for @label;
		push @$objects,$object;
	}

	my $get_name=sub{
		my @names;
		push @names,$_->{Key} for @$objects;
		return @names;
	};
	my $get_object=sub{
		my $name=shift || return $objects;
		for(@$objects){
			return $_ if $_->{Key} eq $name;
		}
	};
	my $to_string=sub{
		print "$_\t" for @label;
		print "\n";
		for my $o (@$objects){
			print "$o->{$_}\t" for @label;
			print "\n";
		}
	};

	return {get_name	=>$get_name,
		get_object	=>$get_object,
		to_string	=>$to_string};
}

sub res_parse{
	my $self=shift;
	$self->{res}=shift || die "Res can not be empty.\n";
	my $format=shift || 'HASH';
	if(ref $self->{res} eq $format){
		return $self;
	}else{
		die "Parameter format error.\n";
	}
}

sub res_body{ shift->{res}{body} || "" }
sub res_code{ shift->{res}{code} || 404 }
sub res_headers{ shift->{res}{headers} || {} }
sub res_message{ shift->{res}{message} || "FAIL" }

sub res_tostring{
	my $self=shift;
	my $res=$self->{res};
	print "CODE: $res->{code}\n";
	print "BODY: $res->{body}\n";
	print "MESSAGE: $res->{message}\n";
	print "HEADER:\t$_ : $res->{headers}{$_}\n" for keys %{$res->{headers}};
}





1;

__END__

package Avro::Schema;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw();
use Avro::Base;

sub new{
	my $class=shift;
	my $self=ref $_[0] eq "HASH" ? shift : die "param error\n";

	validate_avsc_object($self);

	bless $self,$class;
}


sub parse{
	_first \@_;
	my $json=shift;
	my $json_hash;
	eval {$json_hash=decode_json($json)};
	die "$json not a json" if $@;

	Avro::Schema->new($json_hash);

}

sub get_other_props{
	_first \@_;
	my ($f,$e)=@_;
	return if ref $f ne 'HASH' or ref $e ne 'HASH';
	my $d={};
	!$e->{$_}?$d->{$_}=$f->{$_}:undef for keys %$f;
	return $d;
}

sub validate_avsc_object{
	_first \@_;
	my $json=shift;
	return unless ref $json eq 'HASH';
	my $type=$json->{type} // die "type error";
	my $other_props=get_other_props $json,schema_reserved;

	if(! ref $type){
		if(primitive_types->{$type}){
			validate_primitive($json->{name});
		}elsif(named_types->{$type}){
			if($type eq 'fixed'){
				validate_fixed($json->{name},$json->{fixed});
			}elsif($type eq 'enum'){
				validate_enum($json->{name},$json->{symbols});
			}elsif($type eq 'record' || $type eq 'error'){
				validate_record($json->{name},$json->{namespace},$json->{fields});
			}
		}else{
			die "$type is an undefined type.";
		}
	}elsif(ref $type eq 'ARRAY'){
		!primitive_types->{$_}? die "union $_ not primitive type\n" : undef for @$type;
	}elsif(ref $type eq 'HASH'){
		validate_avsc_object($type);
	}
}

sub validate_name{_first \@_;$_[0] // die "name field can't undef"}
sub validate_named{_first \@_;validate_name $_[0];$_[1]=$_[1] || $_[0]}
sub validate_fields{_first \@_;die "fields type error" unless ref $_[0] eq 'ARRAY' && ref $_[0]->[0] eq 'HASH';}

sub validate_primitive{validate_name @_}
sub validate_fixed{
	_first \@_;
	validate_name $_[0];
	die "size not set" unless $_[1] && $_[1]>0;
}
sub validate_enum{
	_first \@_;
	validate_name $_[0];
	die "symbols not set" unless ref $_[1] eq 'ARRAY' && @$_[1]>0;
}
sub validate_record{
	_first \@_;
	validate_named $_[0],$_[1];
	validate_fields $_[2];
	my $fields=$_[2];
	validate_avsc_object $_ for @$fields;
}



1;

__END__

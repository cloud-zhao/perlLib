package Avro::Base;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(Exporter);
use Encode qw(encode decode);
use Mojo::JSON qw(encode_json decode_json);

our @EXPORT=qw(
	_first
	encode decode
	encode_json decode_json	
);

my $PRIMITIVE_TYPES={
	null		=>	1,
	boolean		=>	1,
	string		=>	1,
	bytes		=>	1,
	int		=>	1,
	long		=>	1,
	float		=>	1,
	double		=>	1
};
my $NAMED_TYPES={
	fixed		=>	1,
	enum		=>	1,
	record		=>	1,
	error		=>	1
};
my $VALID_TYPES={
	%$NAMED_TYPES	=>	%$PRIMITIVE_TYPES,
	array		=>	1,
	map		=>	1,
	union		=>	1,
	request		=>	1,
	error_union	=>	1
};
my $SCHEMA_RESERVED_PROPS={
	type		=>	1,
  	name		=>	1,
  	namespace	=>	1,
  	fields		=>	1,
  	items		=>	1,
  	size		=>	1,
  	symbols		=>	1,
  	values		=>	1,
  	doc		=>	1
};
my $FIELD_RESERVED_PROPS={
	default		=>	1,
  	name		=>	1,
  	doc		=>	1,
  	order		=>	1,
  	type		=>	1
};
my $VALID_FIELD_SORT_ORDERS={
  ascending		=>	1,
  descending		=>	1,
  ignore		=>	1
};

my $SUB_HEADER = {
	#pack flag
	STRUCT_INT	=>	'I>',
	STRUCT_FLOAT	=>	'f>',
	STRUCT_LONG	=>	'Q>',
	STRUCT_DOUBLE	=>	'd>',
	STRUCT_CRC32	=>	'I>',

	#max and min int long
	INT_MIN_VALUE	=>	-(1<<31),
	INT_MAX_VALUE	=>	(1<<31)-1,
	LONG_MIN_VALUE	=>	-(1<<63),
	LONG_MAX_VALUE	=>	(1<<63)-1,

	#type
	PRIMITIVE_TYPES	=>	$PRIMITIVE_TYPES,
	NAMED_TYPES	=>	$NAMED_TYPES,
	VALID_TYPES	=>	$VALID_TYPES,
	SCHEMA_RESERVED	=>	$SCHEMA_RESERVED_PROPS,
	FIELD_RESERVED	=>	$FIELD_RESERVED_PROPS,
	VALID_FIELD_SORT=>	$VALID_FIELD_SORT_ORDERS
};

sub _first{shift @{$_[0]} if (ref $_[0]->[0]||$_[0]->[0]) eq (caller)[0]}

sub _create_sub{
	my $set_name=eval{ require Sub::Util; Sub::Util->can('set_subname') } || sub { $_[1] };
	my ($class, %patch) = @_;
	no strict 'refs';
	no warnings 'redefine';
	*{"${class}::$_"} = $set_name->("${class}::$_", $patch{$_}) for keys %patch;
}

for my $key (keys %$SUB_HEADER){
	_create_sub __PACKAGE__,lc $key,sub{$SUB_HEADER->{$key}};
	push @EXPORT,lc $key;
}


1;

__END__

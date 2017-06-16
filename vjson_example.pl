#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use V::JSON qw(json_encode json_decode);

my $s='{"name":"t","type":"record","fields":[{"name":"t1","type":"string"},{"name":"t2","type":"int"}],"default":null,"test":false,"len":"20"}';
print "$s\n";
my $g=json_encode($s);

my $f=json_decode($g);

print Dumper $g;
print "\n$f\n";

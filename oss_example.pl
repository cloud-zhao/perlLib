#!/usr/bin/perl
use strict;
use warnings;

use ALI::OSS::Client;

my $file="../ppg.jpg";

my $id="id";
my $key="key";
my $bucket="test";
my $my_b="testcloud";
my $object="cloudtest/nuu.jpg";
my $url="https://oss-cn-hangzhou.aliyuncs.com";
my $body="content";


my $oss=ALI::OSS::Client->new($id,$key,$url);
#$oss->put_object($bucket,$object,$body);
#$oss->upload_file($bucket,$object,$file);
#$oss->put_bucket($my_b,OSS_ACL_TYPE_P);
#$oss->get_buckets;
#$oss->get_objects($bucket,{delimiter=>'/',"max-keys"=>30,prefix=>"cloudtest/"});
#$oss->put_bucket_logging($my_b,$my_b,"access.log");
#$oss->put_bucket_acl($my_b,OSS_ACL_TYPE_PR);
#$oss->del_bucket_logging($my_b);
$oss->get_bucket_info($my_b);

print OSS_ACL_TYPE_PW,"\n";



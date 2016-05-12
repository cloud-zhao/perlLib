package QQ::Dfw;
$VERSION="0.0.1";

use strict;
use warnings;
use base qw(QQ::Enter);
use constant URL => "dfw.api.qcloud.com/v2/index.php";

my $url_check=sub{$_[0] || URL};




1;

__END__

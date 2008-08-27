#!/usr/bin/perl
use strict;
use warnings;

package QuestionServerHandler;

use Cwd;
BEGIN {
my $root_path = $0;
$root_path =~ s|[^/]*$||;
$root_path = Cwd::abs_path($root_path);
$root_path = $root_path . '/../../';
$root_path = Cwd::abs_path($root_path);

$QuestionServer::RootPath = $root_path;
eval "use lib '$root_path/lib'"; die $@ if $@;
}


use QuestionServer;

use IO::Handle;
use XMLRPC::Transport::HTTP;
use Data::Dumper;

my $server = XMLRPC::Transport::HTTP::CGI
   -> dispatch_to('QuestionServer')
   -> handle
;














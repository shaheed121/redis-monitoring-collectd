#!/usr/bin/perl
use strict;
use warnings;

my $password = `/bin/grep "requirepass" /etc/ops-redis/redis.conf | awk '{print \$NF}'`;
$password =~ s/\W+//g;
if (!$password) { $password = '';}

my $alive = `redis-cli -a '$password' info`;
if ($alive eq '') {
	print "Redis is Dead!!!";
	exit 2;
}


my $tmp_file = "/usr/lib/nagios/redis-mon/rejectcount";
my $current = `redis-cli -a '$password' info | grep "rejected_connections" |  cut -d":" -f2`;
$current =~ s/[^0-9]//g;

if ( -z "$tmp_file" ) {
        open ( my $fh1, ">", "$tmp_file" ) or die $! ;
        print "Probably this is the first run or $tmp_file is missing";
        print $fh1 $current;
        exit 2;
}

open ( my $fh, "<" , "$tmp_file" );
my $firstline = <$fh>;
close $fh;

open ( my $fh2, ">" , "$tmp_file" );
print $fh2 $current;
close $fh2;

my $output = $current - $firstline;

if ( $output > 5 ) {
        print "Attention!!! $output rejected_connections in last 5 minutes. \n";
        exit 2;
} else {
        print "Everything looks good at the moment. Rejected connection in last 5 minutes is $output. \n";
        exit 0;
}

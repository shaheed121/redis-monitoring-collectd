#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Sys::Hostname::Long;
use Getopt::Long;

my $interval = 10; #default
GetOptions (
	"interval=i" => \$interval
);

my %stats;
my $host=hostname_long;
my $password = `/bin/grep "requirepass" /etc/ops-redis/redis.conf | awk '{print \$NF}'`;
chomp $password;
if ($password eq ""){ $password="dummy";}
my @redis_stat=`/usr/bin/redis-cli -a $password info`;


#infinite while loop to putval the data at regular intervals
do{
sleep($interval);
foreach my $var1 (@redis_stat){
        if ($var1 !~ '^#.*'){
                $var1 =~ s/\r//g;
		$var1 =~ s/^$//g;
                my @arr = split(/:/, $var1);
                $stats{$arr[0]} = $arr[1];
                }
        }
my @todelete = qw/redis_version process_id slave_read_only tcp_port pubsub_channels master_host gcc_version redis_git_sha1 aof_enabled loading used_memory_peak_human used_memory_human arch_bits/;
foreach my $del (@todelete){
	delete $stats{$del};
	}

my $key;
my $value;
MAINLOOP:
while ( ($key, $value) = each %stats ){
	 if (! defined $value){
		next MAINLOOP;
		}
chomp $value;
	if ($value =~ /^\d/){
		print "PUTVAL $host/redis/gauge-$key N:$value\n";
		}
	elsif ($value =~ /(.*)lag(.*)/){
	my @lag = split (/=/, $value);
	print "PUTVAL $host/redis/gauge-lag N:$lag[5]\n";
		}

	}
}while(1);

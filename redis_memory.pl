#!/usr/bin/perl
use strict;
use warnings;
use Sys::Hostname;

my $host=hostname;
my $password = `/bin/grep "requirepass" /etc/ops-redis/redis.conf | awk '{print \$NF}'`;
$password =~ s/\W+//g;
if (!$password) { $password = '';}
my $config = `/bin/grep "rename-command CONFIG" /etc/ops-redis/redis.conf | awk '{print \$NF}'`;
$config =~ s/\W+//g;
if (!$config) { $config = "CONFIG";}
my $maxmemory = `redis-cli -a '$password' $config GET maxmemory | awk 'NR==2'`;
my $alive = `redis-cli -a '$password' info`;
if ($alive eq '') {
        print "Redis is Dead!!!";
        exit 2;
}
my $maxmemorypolicy = `redis-cli -a '$password' $config GET maxmemory-policy | awk 'NR==2'`;

my $sysmemory = `free -g | awk '{print \$2}' | awk 'NR==2'`;
my $usedmem = `redis-cli -a '$password' info | grep used_memory: | cut -d":" -f2`; 
chomp ($maxmemory,$maxmemorypolicy);
$usedmem =~ s/[^0-9]//g;
my $maxGB = $maxmemory / 1024 / 1024 / 1024;
$maxGB = sprintf("%.9f", $maxGB);
my $used = $usedmem / 1024 / 1024 / 1024;
$used = sprintf("%.9f", $used);


if ( $maxmemory == 0 ) {
	if ($maxmemorypolicy eq "noeviction") {
		my $critical = 0.8 * $sysmemory; 
		my $warning  = 0.75 * $sysmemory;
		if ( $used >= $critical ) {
			print "Memory breached 80% of system memory. Current used = $used GB";
			exit 2;
		}
		if ( $used >= $warning ) {
                        print "Memory breached 75% of system memory. Current used = $used GB";
                        exit 1;
                } 
		print "Max memory set is 0, but everything looks fine. Cheers! \n";
                exit 0;
	}
	print "Eviction is set. Not monitoring, but current used = $used GB  \n";
	exit 0;
}
else {
	if ($maxmemorypolicy eq "noeviction") {
                my $critical = 0.8 * $maxmemory;
                my $warning  = 0.75 * $maxmemory;
                if ( $used >= $critical ) {
                        print "Memory breached 80% of set memory. Current used = $used GB";
                        exit 2;
                }
                if ( $used >= $warning ) {
                        print "Memory breached 75% of set memory. Current used = $used GB";
                        exit 1;
                }
		print "Everything looks fine. Cheers! \n";
		exit 0;
        }
        print "Eviction is set. Not monitoring, but current used = $used GB \n";
        exit 0;
}

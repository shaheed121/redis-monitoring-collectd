#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Sys::Hostname;

my %stats;
my $message = undef;
my $host=hostname;
my $password = `/bin/grep "requirepass" /etc/ops-redis/redis.conf | awk '{print \$NF}'`;
$password =~ s/\W+//g;
if (!$password) { $password = '';}
my @redis_stat = `redis-cli -a $password info`;
my %lag;
my $used_memory;
my $lag_limit = '6';
my $mem_threshold = '80';

my ($stringvar, $red_max_memory) = split ( /\ /, `egrep -i '^maxmemory\ ' /etc/ops-redis/redis.conf`);
if ($red_max_memory =~ /.*(gb)/){
	$red_max_memory =~ s/(.*)(gb)/$1/g;
	$red_max_memory = $red_max_memory * 1073741824;
	}
elsif ($red_max_memory =~ /.*(mb)/){
	$red_max_memory =~ s/(.*)(mb)/$1/g;
	$red_max_memory = $red_max_memory * 1048576;
	}

my @sys_memory = split ( /\ /, `free -bt | grep Mem` );
if (! defined $red_max_memory){
	$used_memory = ($mem_threshold / 100) * $sys_memory[4];
	$used_memory = sprintf ("%.0f", $used_memory);
	}
else {
	$used_memory = ($mem_threshold / 100) * $red_max_memory; 
	$used_memory = sprintf ("%.0f", $used_memory);
	}

foreach my $var1 (@redis_stat){
	$var1 =~ s/(\r|\n)//g;
	next if ($var1 =~ /^$/);
	if ($var1 !~ '^#.*'){
		my @arr = split(/:/, $var1);
		$stats{$arr[0]} = $arr[1];
		}
	}

if ($stats{rdb_last_bgsave_status} !~ 'ok'){
	chomp $stats{rdb_last_bgsave_status};
	$message = $message . "Crit: bgsave notOK, ";
	}

if ($stats{used_memory} > "$used_memory" ){
	chomp $stats{used_memory};
	$message = $message . "Crit Mem using $stats{used_memory}, ";
	}

if ($stats{role} =~ 'master'){
	%lag = map { map { (split /=/)[-1] } (split /,/,$stats{$_})[-1,0] } grep {/^slave/} keys %stats;
	foreach (keys %lag){
        	$message = $message .  "Crit: Lag slave $lag{$_}  $_ sec, " if ($_ > $lag_limit);
        	}
	}

if ($stats{aof_last_bgrewrite_status} !~ 'ok'){
	chomp $stats{aof_last_bgrewrite_status};
	$message = $message . "Crit aof last bgrewrite not OK";
	}


if (! defined $message) {
	print "Redis stats OK";
        exit 0;
	}

else {
	print "$message";
	exit 2;
}

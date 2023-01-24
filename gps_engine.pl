#!/usr/bin/perl
use strict;
use warnings;

# Runs as a service deamon ->  sudo vi /lib/systemd/system/gps.service	
# Polled by the webpage using data coming from gps_engine.pl which is being run either locally or remptely.

use JSON;
use Socket;    
use IO::Socket;

use lib '.';# Load local libary
use GPS;

$|++;# Flush after every write

my $GPS=GPS->new(GPS_PORT => "/dev/ttyACM0");
my $socket = new IO::Socket::INET(
	LocalHost => 'localhost', # or your external IP address if gps-engine.pl is not ran on the same server
	#LocalHost => '192.168.0.2', 
	LocalPort => '1111',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);

if(! $socket){die "Unable to start GPS engine!"}

print "SERVER started OK!\n";

while (1){
	my $API_CALL = $socket->accept;
	print $API_CALL->peerhost;

	&update;

	print $API_CALL "HTTP/1.0 200 OK\n\rAccess-Control-Allow-Origin: *\n\rContent-Type: application/json;charset=utf-8\n\r\n\r";

	my $json=encode_json({
		utc_time   => $GPS->{RMC}{UTC},
		utc_date   => $GPS->{RMC}{date},
		sats_avail => $GPS->{GGA}{sats} || 0,
		sats_total => $GPS->{GSV}{sats} || 0,
		lock_gll   => $GPS->{GLL}{status} || '',
		lock_rmc   => $GPS->{RMC}{status} || '',
		GSV        => $GPS->{GSV},
	});

	#print $json;
	print $API_CALL $json;
	close $API_CALL;

	print "OK!\n";
}


sub update{
	$GPS->update;

	if($GPS->{log_entries}){
		for(qw(error warn info)){
			if($GPS->{$_}){
				print "\n$_: ".join "\n",@{$GPS->{$_}};
			}
		}

		$GPS->clear_logs;
	}
}



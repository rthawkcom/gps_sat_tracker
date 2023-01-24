#!/user/bin/perl
package GPS;

use strict;
use warnings;

sub new{
	my $this = shift;
	my $class = ref($this) || $this;
	my $self={@_};

	bless $self, $class;


	$self->{GPS_PORT}||='/dev/ttyACM0';


	if(! -e $self->{GPS_PORT}){die "\n######################\n!!! Plug the GPS unit in first!!!\n######################\n\n"}

	@{$self->{PRN_TO_SAT}}=qw(
		USA-xxx
	232
	180
	258
	289
	206
	251
	201
	262
	256
	265
	145
	192
	132
	309
	196
	166
	183
	293
	177
	150
	168
	175
	304
	239
	213
	260
	242
	151
	199
	248
	190
	266
);

	@{$self->{PRN_TO_SAT_TYPE}}=qw(
		USA-xxx
	2F
	2R
	2F
	3
	2RM
	2F
	2RM
	2F
	2F
	2F
	2R
	2RM
	2R
	3
	2RM
	2R
	2RM
	3
	2R
	2R
	2R
	2R
	3
	2F
	2F
	2F
	2F
	2R
	2RM
	2F
	2RM
	2F
);
	$self->{_DISPATCH}={
		GPGSA => \&GPGSA,
		GPGLL => \&GPGLL,
		GPRMC => \&GPRMC,
		GPVTG => \&GPVTG,
		GPGSV => \&GPGSV,
		GPGGA => \&GPGGA,
		GPTXT => \&GPTXT,
	};

	open $self->{GPS_INPUT}, '<'.$self->{GPS_PORT} or die "\nGPS unit is not responding! Are you running as sudo?\n";

	$self->clear_logs;

	return $self;
}

sub log{
	my $self=shift;

	my $level=shift;
	my $msg  =shift;

	push @{ $self->{$level} },sprintf "%s: %s", time, $msg;

	$self->{log_entries}++;
}

sub clear_logs{
	my $self=shift;

	for(qw(error warn info)){
		undef $self->{$_};
	}

	$self->{log_entries}=0;
}

sub update{
	my $self=shift;

	my $IN=$self->{GPS_INPUT}||do{ $self->log('error',"Unable to read GPS port!");return};

	my $sentence;
	while($sentence=<$IN>){

		if($self->{DIAG}){print "$sentence\n"}
		$sentence =~ s/\r|\n//g;	
		if($sentence !~ /\$GP/){
			$self->log('error', "BAD READ! System read delay? Got: [$sentence]");
			return;
		}

		$sentence =~ s/^\$//;
		my($sub,$msg)=split ',',$sentence,2;
		#print "$sub -> $msg\n";
		my $decode=$self->{_DISPATCH}{$sub}||do{ $self->log('error',"Received unknown GPS Sentance of [$sub] from GPS unit!");return};

		no strict 'refs';
		$self->$decode($msg);

		$self->{LOCKED}=0;
		$self->{STATUS}='searching';


		$self->{GLL}{status}||return;
		$self->{RMC}{status}||return;
		if($self->{GLL}{status} eq 'A' and $self->{RMC}{status} eq 'A'){
			$self->{STATUS}="tracking";
			$self->{LOCKED}=1;
		}

		$self->{TIME}=$self->utc_to_texas($self->{RMC}{date},$self->{RMC}{UTC});
		$self->{LOCATION}  = $self->ddmm_to_decimal_degrees({
				lat=>{
					ddmm=>$self->{GLL}{lat},
					NS=>$self->{GLL}{NS},
				},
				lon=>{
					ddmm=>$self->{GLL}{lon},
					EW=>$self->{GLL}{EW},
				}
			});
	}
}


# GPGSA 	GPS receiver operating mode, satellites used in the position solution, and DOP values.
sub GPGSA{ #This log contains GNSS receiver operating mode, satellites used for navigation and DOP values. 
	my $self=shift;
		(
		$self->{GSA}{mode}, # (A)utonomos, (D)GPS, E=DR
		$self->{GSA}{sats},
		$self->{GSA}{sat}{1}, # PRN of satellite used in fix
		$self->{GSA}{sat}{2},
		$self->{GSA}{sat}{3},
		$self->{GSA}{sat}{4},
		$self->{GSA}{sat}{5},
		$self->{GSA}{sat}{6},
		$self->{GSA}{sat}{7},
		$self->{GSA}{sat}{8},
		$self->{GSA}{sat}{9},
		$self->{GSA}{sat}{10},
		$self->{GSA}{sat}{11},
		$self->{GSA}{sat}{12},
		$self->{GSA}{PDOP},
		$self->{GSA}{HDOP},
		$self->{GSA}{VDOP},
		$self->{GSV}{GNSSID}, #his field is only output if the NMEAVERSION is 4.11 
		$self->{GSA}{checksum},
	)=split ',', shift||return;
}

# GPGLL - Geographic position, latitude, longitude
sub GPGLL{
	my $self=shift;
		(
		$self->{GLL}{lat}, # ddmm.mmmm
		$self->{GLL}{NS},
		$self->{GLL}{lon},
		$self->{GLL}{EW},
		$self->{GLL}{UTC},
		$self->{GLL}{status}, # (A)ctive or in(V)alid
		$self->{GLL}{mode}, # (A)utonomos, (D)GPS, E=DR
		$self->{GLL}{checksum},
	)=split ',', shift||return;
}

# GPRMC 	Time, date, position, course and speed data
sub GPRMC{
	my $self=shift;
	(
		$self->{RMC}{UTC},
		$self->{RMC}{status}, # (A)ctive or in(V)alid
		$self->{RMC}{lat}, # ddmm.mmmm
		$self->{RMC}{NS},
		$self->{RMC}{lon},
		$self->{RMC}{EW},
		$self->{RMC}{speed}, #knots
		$self->{RMC}{dir},
		$self->{RMC}{date}, # ddmmyy
		$self->{RMC}{mag},
		$self->{RMC}{mode}, # (A)utonomos, (D)GPS, E=DR
		$self->{RMC}{checksum},
	)=split ',', shift||return;
}

#GPVTG 	Course and speed information relative to thized to PPS).
sub GPVTG{
	my $self=shift;
	(
		$self->{VTG}{true_dir},
		$self->{VTG}{true},
		$self->{VTG}{mag_dir},
		$self->{VTG}{mag},
		$self->{VTG}{knot_speed},
		$self->{VTG}{knot},
		$self->{VTG}{km_speed},
		$self->{VTG}{km},
		$self->{VTG}{mode}, # (A)utonomos, (D)GPS, E=DR
		$self->{VTG}{checksum},
	)=split ',', shift||return;;
}

#GPGSV 	The number of GPS satellites in view satellite ID number
#$GPGSV,4,1,14, 01,18,040,15,02,09,210,23,03,15,085,12,06,46,193,17*78
#$GPGSV,4,2,14, 07,03,158,28,13,12,244,  ,14,57,080,  ,15,00,275,*70
#$GPGSV,4,3,14, 17,65,341,25,19,58,291,12,22,11,062,17,24,15,316,30*74
#$GPGSV,4,4,14, 28,63,058,  ,30,30,170,15*7C
#          sats prn el az snr prn el az snr

sub GPGSV{
	my $self=shift;
	my ($sentence,$checksum)=split '\*', shift||return, 2;
	my ($msgs,$msg,$sats,$data)=split ',', $sentence, 4;
	my @data=split ',',$data;

	$self->{GSV}{sats}=$sats;

	while(@data){
		my $prn=shift @data;
		$self->{GSV}{$prn}{elevation}=shift @data;
		$self->{GSV}{$prn}{azimuth  }=shift @data;
		$self->{GSV}{$prn}{SNR      }=shift @data;# 00-99dB null when not tracked
		$self->{GSV}{$prn}{sat      }=${$self->{PRN_TO_SAT     }}[$prn];
		$self->{GSV}{$prn}{type     }=${$self->{PRN_TO_SAT_TYPE}}[$prn];
	}
		#$GPS->{GSV}{GNSSID}=shift; #his field is only output if the NMEAVERSION is 4.11 
		$self->{GSV}{checksum}=$checksum;
}

#GPGGA 	Global positioning system fix data (time, position, fix type data)
sub GPGGA{
	my $self=shift||return;
	(
		$self->{GGA}{UTC}, #hhmmss.sss 
		$self->{GGA}{lat}, #ddmm.mmmm
		$self->{GGA}{NS},
		$self->{GGA}{lon},
		$self->{GGA}{EW},
		$self->{GGA}{fix}, # 0 = No fix, 1=SPS mode, 2= Differential GPS SPS mode, 3-5 invalid, 6= dead reckoning mode
		$self->{GGA}{sats}, # 0-12
		$self->{GGA}{HDOP},#Horizontal Dilution of Precision 
		$self->{GGA}{alt},	#MSL Altitude
		$self->{GGA}{units1},
		$self->{GGA}{geoid},	#Geoid Separation
		$self->{GGA}{units2},
		$self->{GGA}{age},	# Age of Differential Correction in Seconds
		$self->{GGA}{checksum},
	)=split ',', shift||return;

	$self->{GGA}{sats}=~ s/^0(\d)/$1/;
}

sub GPTXT{
	my $self=shift;
	my $TXT = shift or return;
	my ($sentence,$checksum)=split '\*', $TXT, 2;
	my ($msgs,$msg,$level,$text)=split ',', $sentence, 4;
	my @LEVEL = qw( error Warn info );

	$self->log($LEVEL[$level],$text);
}

sub ddmm_to_decimal_degrees{
	my $self=shift;
	my $DDMM = shift or return {lat=>0,lon=>0};
	if(!$DDMM->{lat}{ddmm}){return {lat=>0,lon=>0}}

	# Set
	$DDMM->{lat}{ddmm} =~ s/^0//;
	$DDMM->{lat}{ddmm} =~ /(^\d\d)(.*)/;
	$DDMM->{lat}{deg} = $1;
	$DDMM->{lat}{min} = $2;

	$DDMM->{lon}{ddmm} =~ s/^0//;
	$DDMM->{lon}{ddmm} =~ /(^\d\d)(.*)/;
	$DDMM->{lon}{deg} = $1;
	$DDMM->{lon}{min} = $2;

	# Convert
	my $lat= sprintf "%3.7f",$DDMM->{lat}{deg} + $DDMM->{lat}{min}/60; # $DDMM{$lat}{deg}{sec} + Seconds/3600
	my $lon= sprintf "%3.7f",$DDMM->{lon}{deg} + $DDMM->{lon}{min}/60;
	if($DDMM->{lat}{NS} =~ /S/i){$lat*=-1}
	if($DDMM->{lon}{EW} =~ /W/i){$lon*=-1}

	return {lat=>$lat,lon=>$lon}
}

sub utc_to_texas{
	my $self=shift;
	my $date=shift or return {date=>"0-0-0",time=>"00:00:00"};
	my $time=shift or return {date=>"0-0-0",time=>"00:00:00"};

	$date =~ /(^\d\d)(\d\d)(\d\d)/;
	my ($d,$mn,$y)=($1, $2, $3); #-6:00 CST
	$y+=2000;

	$time =~ /(^\d\d)(\d\d)(\d\d)/;
	my ($h,$m,$s)=(($1 + 18), $2, $3); #-6:00 CST

	if($h > 6){$d--}

	return {date=>"$mn-$d-$y",time=>"$h:$m:$s"};
}


1;



########################   DOCUMENTATION   ####################################

=SERIAL
my $port = Device::SerialPort->new(GPS_PORT) or die "GPS unit is not responding! Are you running as sudo?";
$port->baudrate(115200); # Configure this to match your device
$port->databits(8);
$port->parity("none");
$port->stopbits(1);

my $sentence = $port->lookfor();

xxxxxxxxxxxx

$port->lookclear; # needed to prevent blocking

=cut



=INFO

GPS Sentences | NMEA Sentences | GPGGA GPGLL GPVTG GPRMC

This page describes GPS Sentences or NMEA Sentences with example patterns. These GPS Sentences (i.e. NMEA Sentences) covers GPGGA, GPGLL, GPVTG, GPRMC etc.

Introduction:
• A GPS receiver module requires only DC power supply for its operation. It will start outputting data as soon as it has identified GPS satellites within its range.
• GPS module uses plain ASCII protocol known as NMEA developed by National Marine Electronics Association. Hence they are also known as NMEA sentences.
• Each block of data is referred as "sentence". Each of these sentences are parsed independently.
• The default transmission rate of these gps sentences is 4800 bps. Certain GPS modules use serial rate of 9600 bps also. It uses 8 bits for ASCII character, no parity and 1 stop bit.
• Sentence begins with two letters to represent GPS device. For example, "GP" represent GPS device and so on.
• Remainder of sentence consists of letters/numerals in plain ASCII. A sentence can not have more than 80 characters.
• A sentence carry latitude, longitude, altitude and time of readings obtained from satellites.
• Some sentence data structures are proprietary developed by device manufacturers which begins with letter "P".

Following is the generic table which mentions functional description of NMEA output messages.
GPS Sentences or NMEA Sentences
NMEA Sentence 	Meaning
GPGGA 	Global positioning system fix data (time, position, fix type data)
GPGLL 	Geographic position, latitude, longitude
GPVTG 	Course and speed information relative to the ground
GPRMC 	Time, date, position, course and speed data
GPGSA 	GPS receiver operating mode, satellites used in the position solution, and DOP values.
GPGSV 	The number of GPS satellites in view satellite ID numbers, elevation, azimuth and SNR values.
GPMSS 	Signal to noise ratio, signal strength, frequency, and bit rate from a radio beacon receiver.
GPTRF 	Transit fix data
GPSTN 	Multiple data ID
GPXTE 	cross track error, measured
GPZDA 	Date and time (PPS timing message, synchronized to PPS).
150 	OK to send message.

GPS sentence | GPGGA

Following table mentions GPGGA sentence description with example.
➤Example of GPGGA GPS sentence:-
$GPGGA, 161229.487, 3723.2475, N, 12158.3416, W, 1, 07, 1.0, 9.0, M, , , , 0000*18
Name or Field 	Example 	Description
Message ID 	$GPGGA 	GGA protocol header
UTC time 	161229.487 	hhmmss.sss
Latitude 	3723.2475 (37 degrees, 23.2475 minutes) 	ddmm.mmmm
N/S Indicator 	N 	N = North, S = South
Longitude 	12158.3416 (121 degrees, 58.3416 minutes) 	dddmm.mmmm
E/W indicator 	W 	E = East or W = West
Position Fix Indicator 	1 	GPS Sentences Position Fix Indicator
Satellites used 	07 	Range is 0 to 12
HDOP 	1.0 	Horizontal Dilution of Precision
MSL Altitude 	9.0 	Meters
Units 	M 	Meters
Geoid Separation 		Meters
Units 	M 	Meters
Age of diff. corr. 		Second
Diff. ref. station ID 	0000 	
Checksum 	*18 	
<CR><LF> 		End of message termination

GPS sentence | GPGLL

Following table mentions GPGLL sentence description with example.
➤Example of GPGLL GPS sentence:-
$GPGLL, 3723.2475, N, 12158.3416, W, 161229.487, A, A*41
Name or Field 	Example 	Description
Message ID 	$GPGLL 	GLL protocol header
Latitude 	3723.2475 	ddmm.mmmm
N/S indicator 	N 	N =North or S = south
Longitude 	12158.3416 	dddmm.mmmm
E/W indicator 	W 	E =East or W = West
UTC time 	161229.487 	hhmmss.sss
Status 	A 	A = data valid or V = data not valid
Mode 	A 	A =Autonomous , D =DGPS, E =DR (This field is only present in NMEA version 3.0)
Checksum 	*41 	
<CR><LF> 		End of message termination

GPS sentence | GPVTG

Following table mentions GPVTG sentence description with example.
➤Example of GPVTG GPS sentence:-
$GPVTG, 309.62, T, ,M, 0.13, N, 0.2, K, A*23
Name or Field 	Example 	Description
Message ID 	$GPVTG 	VTG protocol header
Course 	309.62 	degrees
Reference 	T 	True
Course 		Degrees
Reference 	M 	Magnetic
Speed 	0.13 	Knots, measured horizontal speed
Units 	N 	Knots
Speed 	0.2 	Km/Hr, Measured horizontal speed
Units 	K 	Kilometers per hour
Mode 	A 	A = Autonomous, D = DGPS, E = DR
Checksum 	*23 	
<CR><LF> 		End of message termination

GPS sentence | GPRMC

Following table mentions GPRMC sentence description with example.
➤Example of GPRMC GPS sentence:-
$GPRMC, 161229.487, A, 3723.2475, N, 12158.3416, W, 0.13, 309.62, 120598, , *10
Name or Field 	Example 	Description
Message ID 	$GPRMC 	RMC Protocol Header
UTC time 	161229.487 	hhmmss.sss
Status 	A 	A = data valid or V = data not valid
Latitude 	3723.2475 	ddmm.mmmm
N/S indicator 	N 	N = North or S = South
Longitude 	12158.3416 	dddmm.mmmm
E/W indicator 	W 	E = East or W = West
Speed over ground 	0.13 	knots
Course over ground 	309.62 	degrees
Date 	120598 	ddmmyy
Magnetic Variation 		Degrees (E= East or W = West)
Mode 	A 	A = Autonomous, D = DGPS, E =DR
Checksum 	*10 	
<CR><LF> 		End of message termination 



$GPGSV

2
	

# msgs
	

Total number of messages (1-9)
	

x
	

3

3
	

msg #
	

Message number (1-9)
	

x
	

1

4
	

# sats
	

Total number of satellites in view. May be different than the number of satellites in use (see also the GPGGA log)
	

xx
	

09

5
	

prn
	

Satellite PRN number

GPS = 1 to 32

Galileo = 1 to 36

Beidou = 1 to 63

NAVIC = 1 to 14

QZSS = 1 to 10

SBAS = 33 to 64 (add 87 for PRN#s)

GLO = 65 to 96 1
	

xx
	

03

6
	

elev
	

Elevation, degrees, 90 maximum
	

xx
	

51

7
	

azimuth
	

Azimuth, degrees True, 000 to 359
	

xxx
	

140

8
	

SNR
	

SNR (C/No) 00-99 dB, null when not tracking
	

xx
	

42

...

...

...
	

...

...

...
	

Next satellite PRN number, elev, azimuth, SNR,

...

Last satellite PRN number, elev, azimuth, SNR,
	

 
	

 

variable
	

system ID
	

GNSS system ID. See Table: System and Signal IDs. This field is only output if the NMEAVERSION is 4.11 (see the NMEAVERSION command).
	

 
	

 

variable
	

*xx
	

Check sum
	

*hh
	

*72

variable
	

[CR][LF]
	

Sentence terminator
	

 
	

[CR][LF]


FieldNo.NameUnitFormatExampleDescription
0xxTXT-string$GPTXTTXT Message ID (xx = current Talker ID, seeNMEA Talker IDs table)1numMsg-numeric
01Total number of messages in thistransmission (range: 1-99)2msgNum-numeric
01Message number in this transmission (range:1-numMsg)3msgType-numeric
02Text identifier (u-blox receivers specify thetype of the message with this number):00:  Error01:  Warning02:  Notice07:  User4text-stringwww.u-blox.comAny ASCII text5cs-hexadecimal*67Checksum
=cut


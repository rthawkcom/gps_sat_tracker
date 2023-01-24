#! /usr/bin/perl

use strict;
use warnings;

use LWP; # sudo cpanm install LWP 
$|++;

my $GPS_ENGINE = {
	ip => '192.169.1.1', # URL to the server that has the GPS module plugged into it and has gps_engine.pl running.  It run can on this server or a remote server outside.
	port => 1111, # gps_engine.pl requires an unblocked port not already running a service.
};

# Webpage below is calling us to update the satallite map.  maps.  Called by sat map down below using data from SDR server.
if( $ENV{QUERY_STRING} =~ /API/i ){
	my $LWP = LWP::UserAgent->new;
	$LWP->timeout(1); # Set to less than what the webpage will poll
	my $data = $LWP->get("http://$GPS_ENGINE->{ip}:$GPS_ENGINE->{port}");
	if($data->is_error){
		$data = sprintf qq({"error":"Unable retrieve data from gps_engine.pl using IP ['%s'] on Port ['%s']."}), $GPS_ENGINE->{ip}, $GPS_ENGINE->{port};
	}else{
		$data = $data->content;
	}

	print "Content-Type: application/json;\n\n".$data;
	exit;
}

if($ENV{QUERY_STRING} =~ /CAL/i){
	use JSON;
	print "Content-Type: application/json;\n\n".encode_json({
		lock_gll => 'A',
		lock_rmc => 'A',
		GSV=>{
		0=>{
			azimuth=>0,	# 0 = North, 180 = South,
			elevation=>0,	# Zenith=Map Center=90 degrees , Horizon=Map Edge=0 degrees
		},
		45=>{
			azimuth=>45,
			elevation=>0,
		},
		90=>{
			azimuth=>90,
			elevation=>0,
		},
		135=>{
			azimuth=>135,
			elevation=>0,
		},
		180=>{
			azimuth=>180,
			elevation=>0,
		},
		225=>{
			azimuth=>225,
			elevation=>0,
		},
		270=>{
			azimuth=>270,
			elevation=>0,
		},
		315=>{
			azimuth=>315,
			elevation=>0,
		},
	}});

	exit;
}

print <<SAT;
<!doctype html>
<html lang="en">
<head>

<meta charset="UTF-8">
<title>GPS - Satellite Tracker</title>

<style>
head{font: 14px arial, sans-serif;}
body,html{background-color:#000;margin:0;}

</style>


<script>

var gps={
	refresh:2, // Update webpage every 2 seconds
	url:{   
		//api:"/cgi-bin/gps.pl?CAL",// Change API to CAL (then save and refresh webpage) to calibrate map.
		api:"/cgi-bin/gps.pl?API",
		earth: '../pic/bg-earth_globe.jpg',
		sat:   '../pic/ico-sat.png'
	},
	earth:{
		x:0,
		y:0,
		r:0.8, // adjusts how close sats are to Earth's edge.  Uncomment calibration above ^^^ and refresh to see.
		pic: new Image()
	},
	sat:{
		not_active:[],
		timeout:60, // counts number of times called.
		path:{},
		pic: new Image()
	}
};

function init_telemetry(){
        gps.panel = document.getElementById("gps_panel").getContext("2d");
        gps.panel.center = gps.panel.canvas.width * 0.5;  
        gps.panel.radius = gps.panel.center * gps.earth.r;

        // Set pics 
	gps.sat.pic.src = gps.url.sat;
	gps.earth.pic.src = gps.url.earth;
console.log(gps.earth.pic);
	setInterval(update_gps_info, gps.refresh * 1000);//(function, time, param) 
	
	console.log("GPS Telemetry Initialized");
}

function update_gps_info(){
	s = new XMLHttpRequest();
	s.onreadystatechange = function (e){
		if(s.readyState === 4){
			if(s.status === 200){
				if(s.responseText){
					gps.sat.data=JSON.parse(s.responseText);
					//console.log(s.responseText);
					track_sats();
				}else{error("ERROR! GPS no response!")}
			}else{error("ERROR! XHR code: "+s.status)}
		}
	};
	s.open("GET", gps.url.api, true);
	s.send();
}

function error(msg){
	console.log( msg );
	
	gps.panel.font = "30px Ariel";
	gps.panel.fillStyle = '#f00';
	gps.panel.textAlign = 'center';
	gps.panel.fillText( msg, gps.panel.center, gps.panel.center );
}

function clear_panel(){
	gps.panel.clearRect(0,0, gps.panel.canvas.width, gps.panel.canvas.height);
        gps.panel.drawImage(
		gps.earth.pic,
		gps.panel.center * 0.5,
		gps.panel.center * 0.5,
		gps.panel.center,
		gps.panel.center
	);
}

function track_sats(){
	clear_panel();

	if(gps.sat.data.error){error(gps.sat.data.error);return}

	let locked = gps.sat.data.lock_gll + gps.sat.data.lock_rmc;
	if(locked == 'AA'){

		for(prn in gps.sat.data.GSV){
                        draw_sat(prn);
		}

		remove_sats_not_active();
		
	}else{
		console.log( "Waiting for GPS lock");
		gps.panel.font = "30px Ariel";
		gps.panel.fillStyle = '#f00';
		gps.panel.textalign = 'center';
		gps.panel.fillText( "Waiting for GPS lock.", gps.panel.center, 500 );
		gps.panel.fillText( "GLL: "+gps.sat.data.lock_gll, gps.panel.center, 540 );
		gps.panel.fillText( "RMC "+gps.sat.data.lock_rmc, gps.panel.center, 570 );
	}
}

function remove_sats_not_active(){
	for(prn in gps.sat.data.GSV){
		gps.sat.not_active[prn] += 1;
		if(gps.sat.not_active[prn] > gps.sat.timeout){
			delete gps.sat.not_active[prn];
			delete gps.sat.path[prn];
			console.log("Timeout for Sat: "+prn);
		};
	}
}

function draw_sat(prn){
	if( prn.match(/sats|checksum|GNSSID/)){
		return;
	}

	if( gps.sat.data.GSV[prn].elevation == null){
		console.log("No Sat elevation for "+prn+" got:"+gps.sat.data.GSV[prn]);
		return;
	}

	let r = gps.panel.radius * (90 - gps.sat.data.GSV[prn].elevation) / 90;
	let x = gps.panel.center + r *  Math.sin(gps.sat.data.GSV[prn].azimuth * Math.PI/180); // in Radians
	let y = gps.panel.center + r * -Math.cos(gps.sat.data.GSV[prn].azimuth * Math.PI/180);

	let path_color = parseInt(prn)+100;
	path_color=path_color.toString(16);

	// Remember current position
	if(gps.sat.path[prn] == undefined){
		gps.sat.path[prn]=[];
	}
	gps.sat.not_active[prn] = -1;

	if( JSON.stringify(gps.sat.path[prn][gps.sat.path[prn].length -1]) !== JSON.stringify({x:x, y:y}) ){
		gps.sat.path[prn].push({x:x, y:y});
	}

	// Set Sat ID on path origin 
	gps.panel.font = "10px Ariel";
	gps.panel.fillStyle = '#fff';
	gps.panel.fillText( prn, gps.sat.path[prn][0].x, gps.sat.path[prn][0].y );

	// Draw sat
        gps.panel.drawImage(gps.sat.pic, x-25, y-25, 50, 50); // draw image

        // Set track line
        //gps.panel.shadowColor = "#faa";
        //gps.panel.shadowBlur = 10;
        gps.panel.lineWidth=1;
        gps.panel.strokeStyle='#f00';
        gps.panel.beginPath();
        gps.panel.moveTo(x, y);
        gps.panel.lineTo(gps.panel.center, gps.panel.center);
        gps.panel.stroke();

        // Set path line
        //gps.panel.shadowColor = "#faa";
        //gps.panel.shadowBlur = 10;
        gps.panel.lineWidth=1;
        gps.panel.strokeStyle='#'+path_color+path_color+path_color;

	plot_smooth_path(gps.panel, gps.sat.path[prn], 0.5, 1.5);

	// Set Sat ID 
	let sat_id = prn;
	if( gps.sat.data.GSV[prn].sat){
		sat_id = gps.sat.data.GSV[prn].sat; // use calibration name for ID
	}
	gps.panel.textalign = 'center';
	gps.panel.font = "15px Ariel";
	gps.panel.fillStyle = '#fff';
	gps.panel.fillText( sat_id, x+20, y );
}

function plot_smooth_path(plot, data, f, t){
	let dx1 = 0;
	let dy1 = 0;
	let pdata = data[0];
      
        plot.beginPath();
        plot.moveTo(pdata.x, pdata.y);

	for (var i = 1; i < data.length; i++) {
                let this_point = data[i];
                let ndata = data[i + 1];
                if (ndata) {
			m = (ndata.y-pdata.y) / (ndata.x-pdata.x);
			dx2 = (ndata.x - this_point.x) * -f;
			dy2 = dx2 * m * t;
		}else{
			dx2 = dy2 = 0;
		}
                  
                plot.bezierCurveTo(
                    pdata.x - dx1, pdata.y - dy1,
                    this_point.x + dx2, this_point.y + dy2,
                    this_point.x, this_point.y
                );
              
                dx1 = dx2;
                dy1 = dy2;
		pdata = this_point;
	}

        plot.stroke();
}

window.onload = function(){
	init_telemetry();
}; 

</script>
</head>

<body>
        <canvas style="display:block;margin:auto;border:1px solid #f00" id="gps_panel" width="2000" height="2000"></canvas>
</body>
</html>


SAT

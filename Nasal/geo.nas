# geo functions
# -------------------------------------------------------------------------------------------------
#
#
# geo.Coord class
# -------------------------------------------------------------------------------------------------
#
# geo.Coord.new([<coord>])        ... class that holds and maintains geographical coordinates
#                                     can be initialized with another geo.Coord instance
#
# SETTER METHODS:
#
#     .set(<coord>)               ... sets coordinates from another geo.Coord instance
#
#     .set_lat(<num>)             ... functions for setting latitude/longitude/altitude
#     .set_lon(<num>)
#     .set_alt(<num>)
#     .set_latlon(<num>, <num> [, <num>])      (altitude is optional; default=0)
#
#     .set_x(<num>)               ... functions for setting cartesian x/y/z coordinates
#     .set_y(<num>)
#     .set_z(<num>)
#     .set_xyz(<num>, <num>, <num>)
#
#
# GETTER METHODS:
#
#     .lat()
#     .lon()                      ... functions for getting lat/lon/alt
#     .alt()                          ... returns altitude in m
#     .latlon()                       ... returns vector  [<lat>, <lon>, <alt>]
#
#     .x()                        ... functions for reading cartesian coords (in m)
#     .y()
#     .z()
#     .xyz()                          ... returns vector  [<x>, <y>, <z>]
#
#
# QUERY METHODS:
#
#     .is_defined()               ... returns whether the coords are defined
#     .dump()                     ... outputs coordinates
#     .course_to(<coord>)         ... returns course to another geo.Coord instance (degree)
#     .distance_to(<coord>)       ... returns distance in m along Earth curvature, ignoring altitudes
#                                     useful for map distance
#     .direct_distance_to(<coord>)      ...   distance in m direct, considers altitude,
#                                             but cuts through Earth surface
#
#
# MANIPULATION METHODS:
#
#     .apply_course_distance(<course>, <distance>)       ... guess what
#
#
#
#
# -------------------------------------------------------------------------------------------------
#
# geo.aircraft_position()         ... returns current aircraft position as geo.Coord
# geo.viewer_position()           ... returns viewer position as geo.Coord
# geo.click_position()            ... returns last click coords as geo.Coord or nil before first click
#
# geo.tile_path(<lat>, <lon>)     ... returns tile path string (e.g. "w130n30/w123n37/942056.stg")
# geo.elevation(<lat>, <lon> [, <top:10000>])
#                                 ... returns elevation in meter for given lat/lon, or nil on error;
#                                     <top> is the altitude at which the intersection test starts
#
# geo.normdeg(<angle>)            ... returns angle normalized to  0 <= angle < 360
#
# geo.put_model(<path>, <lat>, <lon> [, <elev:nil> [, <hdg:0> [, <pitch:0> [, <roll:0>]]]]);
#                                 ... put model <path> at location <lat>/<lon> with given elevation
#                                     (optional, default: surface). <hdg>/<pitch>/<roll> are optional
#                                     and default to zero.
# geo.put_model(<path>, <coord> [, <hdg:0> [, <pitch:0> [, <roll:0>]]]);
#                                 ... same as above, but lat/lon/elev are taken from a Coord object


var EPSILON = 1e-15;
var ERAD = 6378138.12;		# Earth radius (m)


var floor = func(v) v < 0.0 ? -int(-v) - 1 : int(v);


# class that maintains one set of geographical coordinates
#
var Coord = {
	new: func(copy = nil) {
		var m = { parents: [Coord] };
		m._pdirty = 1;  # polar
		m._cdirty = 1;  # cartesian
		m._lat = nil;   # in radian
		m._lon = nil;   #
		m._alt = nil;   # ASL
		m._x = nil;     # in m
		m._y = nil;
		m._z = nil;
		if (copy != nil)
			m.set(copy);
		return m;
	},
	_cupdate: func {
		me._cdirty or return;
		var xyz = geodtocart(me._lat * R2D, me._lon * R2D, me._alt);
		me._x = xyz[0];
		me._y = xyz[1];
		me._z = xyz[2];
		me._cdirty = 0;
	},
	_pupdate: func {
		me._pdirty or return;
		var lla = carttogeod(me._x, me._y, me._z);
		me._lat = lla[0] * D2R;
		me._lon = lla[1] * D2R;
		me._alt = lla[2];
		me._pdirty = 0;
	},

	x: func { me._cupdate(); me._x },
	y: func { me._cupdate(); me._y },
	z: func { me._cupdate(); me._z },
	xyz: func { me._cupdate(); [me._x, me._y, me._z] },

	lat: func { me._pupdate(); me._lat * R2D },  # return in degree
	lon: func { me._pupdate(); me._lon * R2D },
	alt: func { me._pupdate(); me._alt },
	latlon: func { me._pupdate(); [me._lat * R2D, me._lon * R2D, me._alt] },

	set_x: func(x) { me._pupdate(); me._pdirty = 1; me._x = x; me },
	set_y: func(y) { me._pupdate(); me._pdirty = 1; me._y = y; me },
	set_z: func(z) { me._pupdate(); me._pdirty = 1; me._z = z; me },

	set_lat: func(lat) { me._cupdate(); me._cdirty = 1; me._lat = lat * D2R; me },
	set_lon: func(lon) { me._cupdate(); me._cdirty = 1; me._lon = lon * D2R; me },
	set_alt: func(alt) { me._cupdate(); me._cdirty = 1; me._alt = alt; me },

	set: func(c) {
		c._pupdate();
		me._lat = c._lat;
		me._lon = c._lon;
		me._alt = c._alt;
		me._cdirty = 1;
		me._pdirty = 0;
		me;
	},
	set_latlon: func(lat, lon, alt = 0) {
		me._lat = lat * D2R;
		me._lon = lon * D2R;
		me._alt = alt;
		me._cdirty = 1;
		me._pdirty = 0;
		me;
	},
	set_xyz: func(x, y, z) {
		me._x = x;
		me._y = y;
		me._z = z;
		me._pdirty = 1;
		me._cdirty = 0;
		me;
	},
	apply_course_distance: func(course, dist) {
		me._pupdate();
		course *= D2R;
		dist /= ERAD;
		me._lat = math.asin(math.sin(me._lat) * math.cos(dist)
				+ math.cos(me._lat) * math.sin(dist) * math.cos(course));

		if (math.cos(me._lat) > EPSILON)
			me._lon = math.pi - math.mod(math.pi - me._lon
					- math.asin(math.sin(course) * math.sin(dist)
					/ math.cos(me._lat)), 2 * math.pi);

		me._cdirty = 1;
		me;
	},
	course_to: func(dest) {
		me._pupdate();
		dest._pupdate();

		if (me._lat == dest._lat and me._lon == dest._lon)
			return 0;

		var dlon = dest._lon - me._lon;
		var ret = nil;
		call(func ret = math.mod(math.atan2(math.sin(dlon) * math.cos(dest._lat),
				math.cos(me._lat) * math.sin(dest._lat)
				- math.sin(me._lat) * math.cos(dest._lat)
				* math.cos(dlon)), 2 * math.pi) * R2D, nil, var err = []);
		if (size(err)) {
			debug.printerror(err);
			debug.dump(me._lat, me._lon, dlon, dest._lat, dest._lon, "--------------------------");
		}
		return ret;
	},
	# arc distance on an earth sphere; doesn't consider altitude
	distance_to: func(dest) {
		me._pupdate();
		dest._pupdate();

		if (me._lat == dest._lat and me._lon == dest._lon)
			return 0;

		var a = math.sin((me._lat - dest._lat) * 0.5);
		var o = math.sin((me._lon - dest._lon) * 0.5);
		return 2.0 * ERAD * math.asin(math.sqrt(a * a + math.cos(me._lat)
				* math.cos(dest._lat) * o * o));
	},
	direct_distance_to: func(dest) {
		me._cupdate();
		dest._cupdate();
		var dx = dest._x - me._x;
		var dy = dest._y - me._y;
		var dz = dest._z - me._z;
		return math.sqrt(dx * dx + dy * dy + dz * dz);
	},
	is_defined: func {
		return !(me._cdirty and me._pdirty);
	},
	dump: func {
		if (me._cdirty and me._pdirty)
			print("Coord.dump(): coordinates undefined");

		me._cupdate();
		me._pupdate();
		printf("x=%f  y=%f  z=%f    lat=%f  lon=%f  alt=%f",
				me.x(), me.y(), me.z(), me.lat(), me.lon(), me.alt());
	},
};


# normalize degree to 0 <= angle < 360
#
var normdeg = func(angle) {
	while (angle < 0)
		angle += 360;
	while (angle >= 360)
		angle -= 360;
	return angle;
}


var _bucket_span = func(lat) {
	if (lat >= 89.0)
		360.0;
	elsif (lat >= 88.0)
		8.0;
	elsif (lat >= 86.0)
		4.0;
	elsif (lat >= 83.0)
		2.0;
	elsif (lat >= 76.0)
		1.0;
	elsif (lat >= 62.0)
		0.5;
	elsif (lat >= 22.0)
		0.25;
	elsif (lat >= -22.0)
		0.125;
	elsif (lat >= -62.0)
		0.25;
	elsif (lat >= -76.0)
		0.5;
	elsif (lat >= -83.0)
		1.0;
	elsif (lat >= -86.0)
		2.0;
	elsif (lat >= -88.0)
		4.0;
	elsif (lat >= -89.0)
		8.0;
	else
		360.0;
}


var tile_index = func(lat, lon) {
	var lat_floor = floor(lat);
	var lon_floor = floor(lon);
	var span = _bucket_span(lat);
	var x = 0;

	if (span < 0.0000001) {
		lon = 0;
	} elsif (span <= 1.0) {
		x = int((lon - lon_floor) / span);
	} else {
		if (lon >= 0) {
			lon = int(int(lon / span) * span);
		} else {
			lon = int(int((lon + 1) / span) * span - span);
			if (lon < -180)
				lon = -180;
		}
	}

	var y = int((lat - lat_floor) * 8);
	return (lon_floor + 180) * 16384 + (lat_floor + 90) * 64 + y * 8 + x;
}


var format = func(lat, lon) {
	sprintf("%s%03d%s%02d", lon < 0 ? "w" : "e", abs(lon), lat < 0 ? "s" : "n", abs(lat));
}


var tile_path = func(lat, lon) {
	var p = format(floor(lat / 10.0) * 10, floor(lon / 10.0) * 10);
	p ~= "/" ~ format(floor(lat), floor(lon));
	p ~= "/" ~ tile_index(lat, lon) ~ ".stg";
}


var put_model = func(path, c, arg...) {
	call(_put_model, [path] ~ (isa(c, Coord) ? c.latlon() : [c]) ~ arg);
}


var _put_model = func(path, lat, lon, elev_m = nil, hdg = 0, pitch = 0, roll = 0) {
	if (elev_m == nil)
		elev_m = elevation(lat, lon);
	if (elev_m == nil)
		die("geo.put_model(): cannot get elevation for " ~ lat ~ "/" ~ lon);
	fgcommand("add-model", var n = props.Node.new({ "path": path,
		"latitude-deg": lat, "longitude-deg": lon, "elevation-m": elev_m,
		"heading-deg": hdg, "pitch-deg": pitch, "roll-deg": roll,
	}));
	return props.globals.getNode(n.getNode("property").getValue());
}


var elevation = func(lat, lon, maxalt = 10000) {
	var d = geodinfo(lat, lon, maxalt);
	return d == nil ? nil : d[0];
}


var click_coord = Coord.new();

_setlistener("/sim/signals/click", func {
	var lat = getprop("/sim/input/click/latitude-deg");
	var lon = getprop("/sim/input/click/longitude-deg");
	var elev = getprop("/sim/input/click/elevation-m");
	click_coord.set_latlon(lat, lon, elev);
});

var click_position = func {
	return click_coord.is_defined() ? Coord.new(click_coord) : nil;
}


var aircraft_position = func {
	var lat = getprop("/position/latitude-deg");
	var lon = getprop("/position/longitude-deg");
	var alt = getprop("/position/altitude-ft") * FT2M;
	return Coord.new().set_latlon(lat, lon, alt);
}


var viewer_position = func {
	var x = getprop("/sim/current-view/viewer-x-m");
	var y = getprop("/sim/current-view/viewer-y-m");
	var z = getprop("/sim/current-view/viewer-z-m");
	return Coord.new().set_xyz(x, y, z);
}



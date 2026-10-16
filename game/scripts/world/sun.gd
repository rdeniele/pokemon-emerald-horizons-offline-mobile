@tool
extends DirectionalLight3D







signal sun_changed(elevation_deg: float, azimuth_deg: float)

@export_range(-90.0, 90.0) var latitude_deg: = 35.6:
	set(v):
		latitude_deg = v
		update_sun()
@export_range(1, 365) var day_of_year: = 340:
	set(v):
		day_of_year = v
		update_sun()
@export_range(0.0, 24.0) var time_of_day: = 14.5:
	set(v):
		time_of_day = v
		update_sun()



@export var override_angles: = false:
	set(v):
		override_angles = v
		update_sun()
@export_range(-90.0, 90.0) var elevation_override: = 21.75:
	set(v):
		elevation_override = v
		update_sun()
@export_range(0.0, 360.0) var azimuth_override: = 217.21:
	set(v):
		azimuth_override = v
		update_sun()

@export var base_energy: = 1.6:
	set(v):
		base_energy = v
		update_sun()

@export var energy_scale: = 1.0:
	set(v):
		energy_scale = v
		update_sun()
@export var horizon_color: = Color(1.0, 0.55, 0.3):
	set(v):
		horizon_color = v
		update_sun()
@export var golden_color: = Color(1.0, 0.86, 0.62):
	set(v):
		golden_color = v
		update_sun()
@export var noon_color: = Color(1.0, 0.97, 0.92):
	set(v):
		noon_color = v
		update_sun()

var elevation_deg: = 0.0
var azimuth_deg: = 0.0


func _ready() -> void :
	add_to_group("sun")
	update_sun()



static func solar_position(lat_deg: float, doy: int, hours: float) -> Vector2:
	var decl: = deg_to_rad(23.44) * sin(deg_to_rad(360.0 / 365.0 * (doy - 81)))
	var h: = deg_to_rad(15.0 * (hours - 12.0))
	var lat: = deg_to_rad(lat_deg)
	var el: = asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(h))
	var az: = atan2( - sin(h), tan(decl) * cos(lat) - sin(lat) * cos(h))
	return Vector2(rad_to_deg(el), fposmod(rad_to_deg(az), 360.0))



static func to_sun(el_deg: float, az_deg: float) -> Vector3:
	var el: = deg_to_rad(el_deg)
	var az: = deg_to_rad(az_deg)
	return Vector3(sin(az) * cos(el), sin(el), - cos(az) * cos(el))


func sun_color(el: float) -> Color:
	if el < 20.0:
		return horizon_color.lerp(golden_color, clampf(el / 20.0, 0.0, 1.0))
	return golden_color.lerp(noon_color, clampf((el - 20.0) / 40.0, 0.0, 1.0))


func update_sun() -> void :
	var p: = solar_position(latitude_deg, day_of_year, time_of_day)
	if override_angles:
		p = Vector2(elevation_override, azimuth_override)
	elevation_deg = p.x
	azimuth_deg = p.y
	var dir: = - to_sun(p.x, p.y)
	var up: = Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
	transform.basis = Basis.looking_at(dir, up)
	light_color = sun_color(p.x)
	if override_angles:

		light_energy = base_energy * energy_scale
		visible = true
	else:
		light_energy = base_energy * energy_scale * smoothstep(-4.0, 10.0, p.x)
		visible = p.x > -4.0
	sun_changed.emit(p.x, p.y)

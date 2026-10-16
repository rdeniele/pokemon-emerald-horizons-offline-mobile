class_name BattleProto
extends RefCounted





























const RT_INPUT: = 1
const RT_SNAP: = 2
const SNAP_HZ: = 20.0
const INPUT_HZ: = 30.0
const INTERP_DELAY: = 0.1
const SIZES: = [1, 2, 3, 4, 5, 6]
const ARENA: = "colosseum"
const WEATHER: = "sunny"
const SIDE_HOST: = 0
const SIDE_GUEST: = 1



static func snap_fighter(c, side: int) -> Dictionary:
	if c == null or not is_instance_valid(c):
		return {}
	return {
		"side": side, "species": String(c.species), "level": int(c.level), 
		"pos": c.global_position, "vel": c.velocity, "facing": c.facing, 
		"hp": int(c.hp), "max_hp": int(c.max_hp), "pp_max": float(c.pp_max), "stamina": float(c.stamina), 
		"status": String(c.status), "mode": int(c.mode), "air": bool(c.is_airborne()), 
		"move_cd": (c.move_cd as Dictionary).duplicate(), "gcd_t": float(c.gcd_t), 
		"sel": String(c.selected_move), "stagger_t": float(c.stagger_t), 
		"prep_id": String(c.combat.prepare_id), "prep_t": float(c.combat.prepare_t), 
	}



static func apply_fighter(c, d: Dictionary) -> void :
	if c == null or d.is_empty():
		return
	c.max_hp = int(d.get("max_hp", c.max_hp))
	c.hp = int(d.get("hp", c.hp))
	c.pp_max = float(d.get("pp_max", c.pp_max))
	c.stamina = float(d.get("stamina", c.stamina))
	c.status = String(d.get("status", ""))
	c.move_cd = (d.get("move_cd", {}) as Dictionary).duplicate()
	c.gcd_t = float(d.get("gcd_t", 0.0))
	c.selected_move = String(d.get("sel", ""))
	c.stagger_t = float(d.get("stagger_t", 0.0))
	c.combat.prepare_id = String(d.get("prep_id", ""))
	c.combat.prepare_t = float(d.get("prep_t", 0.0))



static func mirror(p: Vector3, center: Vector3) -> Vector3:
	return Vector3(2.0 * center.x - p.x, p.y, 2.0 * center.z - p.z)


static func mirror_dir(d: Vector3) -> Vector3:
	return Vector3( - d.x, d.y, - d.z)


static func mirror_stick(v: Vector2) -> Vector2:
	return - v


static func v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() >= 3 else Vector3.ZERO


static func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else Vector2.ZERO

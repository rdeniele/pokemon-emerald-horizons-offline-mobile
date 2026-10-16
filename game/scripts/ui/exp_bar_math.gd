extends RefCounted










const Growth: = preload("res://scripts/stats/growth.gd")
const Dex: = preload("res://scripts/dex.gd")


const LEVEL_SECS: = 0.7



static func level_at(growth: String, xp: int) -> int:
	return Growth.level_for_exp(growth, xp)



static func ratio(growth: String, xp: int) -> float:
	var lvl: = level_at(growth, xp)
	if lvl >= Growth.MAX_LEVEL:
		return 1.0
	var lo: = Growth.exp_for_level(growth, lvl)
	var hi: = Growth.exp_for_level(growth, lvl + 1)
	return clampf(float(xp - lo) / maxf(float(hi - lo), 1.0), 0.0, 1.0)



static func rate(growth: String, xp: int, secs: = LEVEL_SECS) -> float:
	var lvl: = level_at(growth, xp)
	if lvl >= Growth.MAX_LEVEL:
		return 0.0
	var span: = float(Growth.exp_for_level(growth, lvl + 1) - Growth.exp_for_level(growth, lvl))
	return maxf(span, 1.0) / maxf(secs, 0.01)




static func moves_at_level(mon: RefCounted, level: int) -> Array:
	var out: Array = []
	for e in Dex.species(mon.species).get("learnset", []):
		if int(e[0]) == level and mon.moves.has(e[1]):
			out.append(String(e[1]))
	return out

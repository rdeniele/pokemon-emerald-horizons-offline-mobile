extends RefCounted














const FRLG_TILE: = 0.8

const SPACING: = 2.0

const STEP_M: = FRLG_TILE * SPACING

const DENOM: = 1600.0

const COOLDOWN_BYPASS: = 0.05

const NEW_TILE_GATE: = 0.6

const GRACE_M: = 4.0



static func per_step_chance(rate: float) -> float:
	return clampf(rate * 16.0 / DENOM, 0.0, 1.0)



static func cooldown_steps(rate: float) -> int:
	if rate >= 80.0:
		return 0
	if rate < 10.0:
		return 8
	return 8 - int(rate / 10.0)





static func steps_to_encounter(rate: float) -> float:
	var p: = per_step_chance(rate)
	if p <= 0.0:
		return INF
	var q: = 1.0 - COOLDOWN_BYPASS * p
	var m: = cooldown_steps(rate)
	var total: = 0.0
	for k in m:
		total += pow(q, k)
	return total + pow(q, m) / p



static func metres_to_encounter(rate: float) -> float:
	return steps_to_encounter(rate) * STEP_M



static func grace_blocks(grace: float) -> bool:
	return grace > 0.0

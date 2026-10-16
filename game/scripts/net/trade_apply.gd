class_name TradeApply
extends RefCounted



const Dex: = preload("res://scripts/dex.gd")
const MonScript: = preload("res://scripts/stats/mon.gd")




static func offer_dict(i: int) -> Dictionary:
	var d: Dictionary = Game.party[i].to_dict()
	var o: = String(d.get("owner", ""))
	if o == "" or o == "player":
		d["owner"] = Game.state.player_name
	return d



static func valid_offer(d: Dictionary) -> bool:
	var sp: = String(d.get("species", ""))
	if sp == "" or Dex.species(sp).is_empty():
		return false
	var lv: = int(d.get("level", 0))
	if lv < 1 or lv > 100:
		return false
	return typeof(d.get("moves")) == TYPE_ARRAY



static func trade_evolution(species: String) -> String:
	var evo: Dictionary = Dex.species(species).get("evolution", {})
	if evo.is_empty() or String(evo.get("method", "")) != "trade":
		return ""
	return String(evo.get("into", ""))





static func apply(give_slot: int, got: Dictionary) -> Dictionary:
	if not valid_offer(got) or give_slot < 0 or give_slot >= Game.party.size():
		return {"ok": false}
	if Game.is_out(give_slot):
		Game.recall(give_slot)
	var m = MonScript.from_dict(got)
	m.heal_full()
	Game.party[give_slot] = m
	Game.state.mark_caught(m.species)
	Game.party_changed.emit()
	if SaveGame.enabled:
		SaveGame.save_now()
	return {"ok": true, "mon": m, "evolve_into": trade_evolution(m.species)}

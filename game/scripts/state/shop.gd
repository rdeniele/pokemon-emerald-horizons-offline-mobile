extends RefCounted







const Items: = preload("res://scripts/items.gd")

static var _shops: = {}


static func _ensure() -> void :
	if not _shops.is_empty():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/shops.json"))
	if d is Dictionary:
		_shops = d



static func stock(shop_id: String) -> Array:
	_ensure()
	var s = _shops.get(shop_id, [])
	return s.duplicate() if s is Array else []


static func price(id: String) -> int:
	return int(Items.item(id).get("price", 0))



static func sell_price(id: String) -> int:
	return price(id) / 2


static func can_sell(state, id: String, n: int) -> bool:
	n = maxi(n, 1)
	return price(id) > 0 and state.item_count(id) >= n



static func buy(state, id: String, n: int) -> bool:
	n = maxi(n, 1)
	var unit: = price(id)
	if unit <= 0:
		return false
	var cost: = unit * n
	if state.money < cost:
		return false
	state.money -= cost
	state.add_item(id, n)

	if id == "poke_ball" and n >= 10:
		state.add_item("premier_ball", 1)
	return true



static func sell(state, id: String, n: int) -> bool:
	n = maxi(n, 1)
	if not can_sell(state, id, n):
		return false
	state.remove_item(id, n)
	state.money += sell_price(id) * n
	return true



static func max_buy(state, id: String, n: int) -> int:
	var unit: = price(id)
	if unit <= 0:
		return 1
	return clampi(n, 1, mini(99, maxi(state.money / unit, 1)))



static func max_sell(state, id: String, n: int) -> int:
	return clampi(n, 1, maxi(state.item_count(id), 1))

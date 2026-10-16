class_name TradeSession
extends RefCounted





enum State{OFFERING, CONFIRMING, CONFIRMED, DONE, CANCELLED}

var state: = State.OFFERING
var my_slot: = -1
var my_mon: = {}
var their_mon: = {}
var my_accept: = false
var their_accept: = false
var outbox: Array = []

var _my_rev: = 0
var _their_rev: = 0
var _their_confirm: = false
var _step_at_cancel: = "offering"


func offer(slot: int, mon: Dictionary) -> bool:
	if state in [State.CONFIRMED, State.DONE, State.CANCELLED]:
		return false
	my_slot = slot
	my_mon = mon
	_my_rev += 1
	_reset_agreement()
	outbox.append({"t": "offer", "rev": _my_rev, "slot": slot, "mon": mon})
	return true


func accept() -> bool:
	if state != State.OFFERING or my_mon.is_empty() or their_mon.is_empty():
		return false
	my_accept = true
	outbox.append({"t": "accept", "mine": _my_rev, "yours": _their_rev})
	_maybe_confirming()
	return true


func unaccept() -> void :
	if state != State.OFFERING or not my_accept:
		return
	my_accept = false
	outbox.append({"t": "unaccept"})


func confirm() -> bool:
	if state != State.CONFIRMING:
		return false
	state = State.CONFIRMED
	outbox.append({"t": "confirm", "mine": _my_rev, "yours": _their_rev})
	_maybe_commit()
	return true


func decline() -> void :
	if state != State.CONFIRMING:
		return
	_reset_agreement()
	outbox.append({"t": "unaccept"})


func cancel() -> bool:
	if state in [State.CONFIRMED, State.DONE, State.CANCELLED]:
		return false
	_step_at_cancel = step_name()
	state = State.CANCELLED
	outbox.append({"t": "cancel"})
	return true


func step_name() -> String:
	if state == State.CANCELLED:
		return _step_at_cancel
	if state == State.CONFIRMING or state == State.CONFIRMED:
		return "confirming"
	return "accepted" if my_accept else "offering"


func handle(msg: Dictionary) -> void :
	if state == State.DONE or state == State.CANCELLED:
		return
	match String(msg.get("t", "")):
		"offer":
			if state == State.CONFIRMED:
				state = State.CONFIRMING
			their_mon = msg.get("mon", {}) if typeof(msg.get("mon")) == TYPE_DICTIONARY else {}
			_their_rev = int(msg.get("rev", 0))
			_reset_agreement()
		"accept":
			if _matches(msg) and state == State.OFFERING:
				their_accept = true
				_maybe_confirming()
		"unaccept":
			their_accept = false
			_their_confirm = false
			if state == State.CONFIRMING or state == State.CONFIRMED:
				state = State.OFFERING
				my_accept = false
		"confirm":
			if _matches(msg):
				_their_confirm = true
				_maybe_commit()
		"cancel":
			_step_at_cancel = step_name()
			state = State.CANCELLED


func _matches(msg: Dictionary) -> bool:

	return int(msg.get("mine", -1)) == _their_rev and int(msg.get("yours", -1)) == _my_rev


func _reset_agreement() -> void :
	my_accept = false
	their_accept = false
	_their_confirm = false
	state = State.OFFERING


func _maybe_confirming() -> void :
	if my_accept and their_accept and state == State.OFFERING:
		state = State.CONFIRMING


func _maybe_commit() -> void :
	if state == State.CONFIRMED and _their_confirm:
		state = State.DONE
		outbox.append({"t": "done"})

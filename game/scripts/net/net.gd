extends Node
















signal room_ready(id: String)
signal connected(role: String)
signal message(msg: Dictionary)
signal rt(arr: Array)
signal closed(reason: String)

const NET_PROTOCOL: = 1
const REASONS: = ["left", "timeout", "ice_timeout", "expired", "not_found", "bad_pin", 
	"full", "kind", "version", "http", "cancelled"]
const DATA_PATH: = "res://data/net.json"
const POLL_SECS: = 0.5
const ICE_TIMEOUT: = 20.0
const PING_SECS: = 1.0
const SILENCE_SECS: = 10.0
const MAX_ICE: = 32
const HTTP_TIMEOUT: = 10.0

const QUIET_REASONS: = ["left", "cancelled", "timeout"]

const ERROR_REASONS: = ["not_found", "bad_pin", "full", "kind", "version"]

var role: = ""
var kind: = ""
var room_id: = ""
var pin: = ""
var peer: = {}
var rtt_ms: = -1


var api: Callable = _http_call

var _server: = "https://pokemon-proto-matchmaker.vercel.app"
var _stun: Array = ["stun:stun.l.google.com:19302"]
var _link: NetLink
var _connected: = false
var _hello_sent: = false
var _answer_applied: = false
var _ice_applied: = 0
var _ice_out: Array = []
var _poll_t: = 0.0
var _ping_t: = 0.0
var _silence_t: = 0.0
var _ice_elapsed: = 0.0
var _ice_push_t: = 0.0


func _ready() -> void :
	var f: = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			_server = String(d.get("server", _server))
			if typeof(d.get("stun")) == TYPE_ARRAY:
				_stun = d["stun"]
	if not api.is_valid():
		api = _http_call


func _process(delta: float) -> void :
	_tick(delta)




func host(kind_: String, pin_: String) -> void :
	if busy() or not NetCodec.valid_pin(pin_):
		return
	role = "host"
	kind = kind_
	pin = pin_
	_start_link(true)


func join(kind_: String, id: String, pin_: String) -> void :
	if busy() or not NetCodec.valid_pin(pin_):
		return
	role = "guest"
	kind = kind_
	pin = pin_
	room_id = NetCodec.normalize_id(id)
	if room_id == "":
		_close("not_found")
		return
	var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/api/room/%s/join" % room_id, 
		{"kind": kind, "pin": pin, "v": NET_PROTOCOL})
	if role != "guest":
		return
	if int(r.code) != 200:
		_close(_reason(int(r.code), r.body))
		return
	var offer: = String(r.body.get("offer", ""))
	if offer == "":
		_close("http")
		return
	_start_link(false)
	_link.apply_sdp("offer", offer)
	var host_ice: Array = r.body.get("host_ice", [])
	for c in host_ice:
		if typeof(c) == TYPE_DICTIONARY:
			_link.apply_ice(c)
	_ice_applied = host_ice.size()


func send(msg: Dictionary) -> void :
	if _connected and typeof(msg.get("t")) == TYPE_STRING:
		_send_ctl(msg)


func send_rt(arr: Array) -> void :
	if _connected and _link != null:
		_link.send_rt(NetCodec.encode_rt(arr))


func leave() -> void :
	if role == "":
		return
	if _connected:
		_send_ctl({"t": "bye"})
		_close("cancelled")
		return
	var rid: = room_id
	var p: = pin
	var was_host: = role == "host"
	_close("cancelled")
	if was_host and rid != "":
		await _call(HTTPClient.METHOD_DELETE, "/api/room/%s?pin=%s" % [rid, p], {})


func busy() -> bool:
	return role != ""




func _tick(delta: float) -> void :
	if role == "":
		return
	if _link != null:
		_link.poll()
		_drain()
	if role == "":
		return
	if not _connected and _link != null:
		if _link.is_open():
			_on_link_open()
		elif _link.failed():
			_close("ice_timeout")
			return
	if _connected:
		_ping_t += delta
		if _ping_t >= PING_SECS:
			_ping_t = 0.0
			_send_ctl({"t": "ping", "ms": Time.get_ticks_msec()})
		_silence_t += delta
		if _silence_t >= SILENCE_SECS:
			_close("timeout")
			return
	elif role == "guest" or _answer_applied:


		_ice_elapsed += delta
		if _ice_elapsed >= ICE_TIMEOUT:
			_close("ice_timeout")
			return
	if not _hello_sent and room_id != "":
		_poll_t += delta
		if _poll_t >= POLL_SECS:
			_poll_t = 0.0
			_poll_matchmaker()
	if room_id != "" and not _ice_out.is_empty():
		_ice_push_t += delta
		if _ice_push_t >= POLL_SECS:
			_ice_push_t = 0.0
			_push_ice()


func _on_link_open() -> void :
	if _hello_sent:
		return
	_hello_sent = true
	_send_ctl({"t": "hello", "v": NET_PROTOCOL, "name": Game.state.player_name, 
		"trainer_id": Game.state.trainer_id})


func _drain() -> void :
	for s in _link.recv_ctl():
		_silence_t = 0.0
		var m: = NetCodec.decode(s)
		if m.is_empty():
			continue
		_handle_ctl(m)
		if role == "":
			return
	for p in _link.recv_rt():
		_silence_t = 0.0
		rt.emit(NetCodec.decode_rt(p))


func _handle_ctl(m: Dictionary) -> void :
	match String(m["t"]):
		"hello":
			if int(m.get("v", 0)) != NET_PROTOCOL:
				_close("version")
				return
			if _connected:
				return
			_on_link_open()
			peer = {"name": String(m.get("name", "")), "trainer_id": String(m.get("trainer_id", ""))}
			_connected = true
			_silence_t = 0.0
			_ping_t = 0.0
			connected.emit(role)
			Analytics.track("online_connected", {"kind": kind, "role": role, 
				"connect_ms": int(_ice_elapsed * 1000.0)})
			if role == "host":
				_cleanup_room()
		"ping":
			_send_ctl({"t": "pong", "ms": int(m.get("ms", 0))})
		"pong":
			rtt_ms = Time.get_ticks_msec() - int(m.get("ms", 0))
		"bye":
			_close("left")
		_:
			message.emit(m)




func _start_link(offerer: bool) -> void :
	_link = NetLink.new()
	_link.local_sdp.connect(_on_local_sdp)
	_link.local_ice.connect( func(c): _ice_out.append(c))
	_ice_elapsed = 0.0
	if _link.start(_stun, offerer) != OK:
		_close("ice_timeout")


func _on_local_sdp(type: String, sdp: String) -> void :
	if role == "host" and type == "offer":
		var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/api/room", 
			{"kind": kind, "pin": pin, "v": NET_PROTOCOL, "offer": sdp})
		if role != "host":
			return
		var id: = String(r.body.get("id", ""))
		if int(r.code) != 200 or id == "":
			_close(_reason(int(r.code), r.body))
			return
		room_id = id
		room_ready.emit(room_id)
		Analytics.track("online_room_created", {"kind": kind})
	elif role == "guest" and type == "answer":
		var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/api/room/%s/answer" % room_id, 
			{"pin": pin, "answer": sdp})
		if role != "guest":
			return
		if int(r.code) != 200:
			_close(_reason(int(r.code), r.body))


func _poll_matchmaker() -> void :
	var side: = "host" if role == "host" else "guest"
	var r: Dictionary = await _call(HTTPClient.METHOD_GET, 
		"/api/room/%s?pin=%s&side=%s" % [room_id, pin, side], {})
	if role == "":
		return
	if int(r.code) == 404:
		if _link != null and _link.is_open():
			return
		_close("expired" if role == "host" else "not_found")
		return
	if int(r.code) != 200:
		_close(_reason(int(r.code), r.body))
		return
	var body: Dictionary = r.body
	if role == "host" and not _answer_applied and typeof(body.get("answer")) == TYPE_STRING:
		_answer_applied = true
		_link.apply_sdp("answer", String(body["answer"]))
	var ice: Array = body.get("ice", [])
	while _ice_applied < ice.size():
		var c: Variant = ice[_ice_applied]
		_ice_applied += 1
		if typeof(c) == TYPE_DICTIONARY:
			_link.apply_ice(c)


func _push_ice() -> void :
	var batch: Array = _ice_out.slice(0, MAX_ICE)
	var side: = "host" if role == "host" else "guest"
	var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/api/room/%s/ice" % room_id, 
		{"pin": pin, "side": side, "candidates": batch})
	if role != "" and int(r.code) == 200:
		_ice_out = _ice_out.slice(batch.size())


func _cleanup_room() -> void :
	var rid: = room_id
	var p: = pin
	await _call(HTTPClient.METHOD_DELETE, "/api/room/%s?pin=%s" % [rid, p], {})


func _send_ctl(msg: Dictionary) -> void :
	if _link != null:
		_link.send_ctl(NetCodec.encode(msg))


func _reason(code: int, body: Dictionary) -> String:
	if code == 0 or code >= 500:
		return "http"
	var e: = String(body.get("error", ""))
	return e if ERROR_REASONS.has(e) else "http"





func _close(reason: String) -> void :
	if role == "" and _link == null and room_id == "":
		return
	var r: = role
	var k: = kind
	var was_connected: = _connected
	if _link != null:
		_link.close()
	_link = null
	role = ""
	kind = ""
	room_id = ""
	pin = ""
	peer = {}
	rtt_ms = -1
	_connected = false
	_hello_sent = false
	_answer_applied = false
	_ice_applied = 0
	_ice_out = []
	_poll_t = 0.0
	_ping_t = 0.0
	_silence_t = 0.0
	_ice_elapsed = 0.0
	_ice_push_t = 0.0
	if not was_connected and not QUIET_REASONS.has(reason):
		Analytics.track("online_connect_failed", {"kind": k, "role": r, "stage": reason})
	closed.emit(reason)





func _call(method: int, path: String, body: = {}) -> Dictionary:
	var r: Variant = await api.call(method, path, body)
	return r if typeof(r) == TYPE_DICTIONARY else {"code": 0, "body": {}}


func _http_call(method: int, path: String, body: Dictionary) -> Dictionary:
	var http: = HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	var payload: = JSON.stringify(body) if method != HTTPClient.METHOD_GET and method != HTTPClient.METHOD_DELETE else ""
	var e: = http.request(_server + path, PackedStringArray(["Content-Type: application/json"]), method, payload)
	if e != OK:
		http.queue_free()
		return {"code": 0, "body": {}}
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": {}}
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"code": int(res[1]), "body": parsed if typeof(parsed) == TYPE_DICTIONARY else {}}

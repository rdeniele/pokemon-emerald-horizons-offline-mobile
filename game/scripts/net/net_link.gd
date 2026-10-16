class_name NetLink
extends RefCounted












signal local_sdp(type: String, sdp: String)
signal local_ice(c: Dictionary)

var _pc: WebRTCPeerConnection
var _ctl: WebRTCDataChannel
var _rt: WebRTCDataChannel


func start(ice_servers: Array, offerer: bool) -> int:
	_pc = WebRTCPeerConnection.new()
	var cfg: = {"iceServers": []}
	if not ice_servers.is_empty():
		cfg = {"iceServers": [{"urls": ice_servers}]}
	var e: = _pc.initialize(cfg)
	if e != OK:
		return e
	_pc.session_description_created.connect(_on_sdp)
	_pc.ice_candidate_created.connect(_on_ice)
	_ctl = _pc.create_data_channel("ctl", {"negotiated": true, "id": 1})
	_rt = _pc.create_data_channel("rt", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	if _ctl == null or _rt == null:
		return FAILED
	_ctl.write_mode = WebRTCDataChannel.WRITE_MODE_TEXT
	_rt.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
	return _pc.create_offer() if offerer else OK


func apply_sdp(type: String, sdp: String) -> void :
	if _pc != null:
		_pc.set_remote_description(type, sdp)


func apply_ice(c: Dictionary) -> void :
	if _pc != null:
		_pc.add_ice_candidate(String(c.get("m", "")), int(c.get("i", 0)), String(c.get("n", "")))


func poll() -> void :
	if _pc != null:
		_pc.poll()


func is_open() -> bool:
	return _ctl != null and _rt != null\
	and _ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN\
	and _rt.get_ready_state() == WebRTCDataChannel.STATE_OPEN


func failed() -> bool:
	if _pc == null:
		return true
	var s: = _pc.get_connection_state()
	return s == WebRTCPeerConnection.STATE_FAILED or s == WebRTCPeerConnection.STATE_CLOSED


func send_ctl(text: String) -> void :
	if _ctl != null and _ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_ctl.put_packet(text.to_utf8_buffer())


func send_rt(b: PackedByteArray) -> void :
	if _rt != null and _rt.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_rt.put_packet(b)


func recv_ctl() -> PackedStringArray:
	var out: = PackedStringArray()
	while _ctl != null and _ctl.get_available_packet_count() > 0:
		out.append(_ctl.get_packet().get_string_from_utf8())
	return out


func recv_rt() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	while _rt != null and _rt.get_available_packet_count() > 0:
		out.append(_rt.get_packet())
	return out


func close() -> void :
	if _pc != null:
		_pc.close()
	_pc = null
	_ctl = null
	_rt = null


func _on_sdp(type: String, sdp: String) -> void :
	_pc.set_local_description(type, sdp)
	local_sdp.emit(type, sdp)


func _on_ice(media: String, index: int, name: String) -> void :
	local_ice.emit({"m": media, "i": index, "n": name})

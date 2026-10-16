class_name NetCodec




const ID_ALPHABET: = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const ID_LEN: = 6
const PIN_LEN: = 4


const VAR_HEADER: = 4


static func encode(msg: Dictionary) -> String:
	if typeof(msg.get("t")) != TYPE_STRING:
		push_error("NetCodec.encode: message needs a String \"t\"")
		return ""
	return JSON.stringify(msg)


static func decode(text: String) -> Dictionary:
	var v: Variant = JSON.parse_string(text)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	return d if typeof(d.get("t")) == TYPE_STRING else {}


static func encode_rt(arr: Array) -> PackedByteArray:
	return var_to_bytes(arr)


static func decode_rt(b: PackedByteArray) -> Array:
	if b.size() < VAR_HEADER:
		return []
	var v: Variant = bytes_to_var(b)
	return v if typeof(v) == TYPE_ARRAY else []


static func normalize_id(s: String) -> String:
	var id: = s.strip_edges().to_upper()
	if id.length() != ID_LEN:
		return ""
	for c in id:
		if not ID_ALPHABET.contains(c):
			return ""
	return id


static func valid_pin(s: String) -> bool:
	if s.length() != PIN_LEN:
		return false
	for c in s:
		if c < "0" or c > "9":
			return false
	return true

extends RefCounted






























const Dex: = preload("res://scripts/dex.gd")
const SpriteLook: = preload("res://scripts/sprite_look.gd")
const ROOT: = "res://assets/pokemon/"
const PMD_ANIMS: = "res://data/pmd_anims.json"
const DEFAULT_ROWS: = {"down": 0, "left": 1, "right": 2, "up": 3}
const PLACEHOLDER_PIXEL: = 0.05

static var _cache: = {}
const ACTOR_CACHE_LIMIT := 32
static var _preview_cache: Dictionary = {}


static func slug(species: String) -> String:
	var configured := String(Dex.species(species).get("asset_slug", ""))
	if configured != "":
		return configured
	return species.to_lower().replace(" ", "_").replace(".", "").replace("'", "")



static func spec(species: String) -> Dictionary:
	if _cache.has(species):
		var recent: Dictionary = _cache[species]
		_cache.erase(species)
		_cache[species] = recent
		return recent
	var sp: = Dex.species(species)
	var dir: = ROOT + slug(species) + "/"
	var s: = {}
	if ResourceLoader.exists(dir + "overworld.png"):
		var tex: Texture2D = load(dir + "overworld.png")
		var cfg: = {}
		if FileAccess.file_exists(dir + "sprite.json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "sprite.json"))
			if parsed is Dictionary:
				cfg = parsed
		var w: = tex.get_width()
		var h: = tex.get_height()
		var hf: = int(cfg.get("hframes", 0))
		var vf: = int(cfg.get("vframes", 0))
		if hf <= 0 or vf <= 0:
			if h == w * 2:
				hf = 2
				vf = 4
			else:
				hf = 1
				vf = 1
		var fh: = float(h) / vf
		var height_m: = float(cfg.get("height_m", sp.get("height_m", 1.4)))
		s = {"texture": tex, "hframes": hf, "vframes": vf, "rows": cfg.get("rows", DEFAULT_ROWS), 
			"frames_per_row": hf, "pixel_size": height_m / fh, "offset_y": fh / 2.0, 
			"visible_m": float(cfg.get("visible_m", height_m * 0.6)), 
			"tint": Color.WHITE, "static": hf * vf == 1, "faces": cfg.get("faces", "left"), "real": true}
	else:
		var tex2: Texture2D = load(sp.get("sprite", "res://assets/sprites/critter_green.png"))
		s = {"texture": tex2, "hframes": 2, "vframes": 4, "rows": DEFAULT_ROWS, "frames_per_row": 2, 
			"pixel_size": PLACEHOLDER_PIXEL * float(sp.get("placeholder_scale", 1.0)), "offset_y": 16.0, "static": false, "faces": "left", "real": false, 
			"visible_m": 1.0, "tint": Color(sp.get("placeholder_tint", "#ffffff"))}
	_pack_sprites(s, dir)
	_pack_pmd(s, dir + "pmd/")
	_cache[species] = s
	while _cache.size() > ACTOR_CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
	return s





static func _pack_pmd(s: Dictionary, pmd_dir: String) -> void :
	if not ResourceLoader.exists(pmd_dir + "anims.json"):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(pmd_dir + "anims.json"))
	if not raw is Dictionary:
		return
	var pmd: = {}
	for name in raw:
		var a: Dictionary = raw[name]
		var tex: Texture2D = load(pmd_dir + String(a.file))
		if tex == null:
			continue
		var secs: Array = []
		for t in a.durations:
			secs.append(float(t) / 60.0)
		pmd[name] = {"texture": tex, "w": int(a.w), "h": int(a.h), "dirs": int(a.dirs), 
			"frames": secs.size(), "durations": secs, "anchor": a.get("anchor", []), 
			"rush": int(a.get("rush", -1)), "hit": int(a.get("hit", -1)), "return": int(a.get("return", -1))}
	if not pmd.has("Idle"):
		return
	s["pmd"] = pmd
	var idle: Dictionary = pmd["Idle"]
	var fh: = int(idle.h)
	var used: = (idle.texture as Texture2D).get_image().get_region(Rect2i(0, 0, int(idle.w), fh)).get_used_rect()
	s["texture"] = idle.texture
	s["hframes"] = int(idle.frames)
	s["vframes"] = int(idle.dirs)
	s["frames_per_row"] = int(idle.frames)
	s["static"] = false
	s["pixel_size"] = float(s.get("visible_m", 1.0)) / maxf(float(used.size.y), 1.0)
	s["offset_y"] = float(used.position.y + used.size.y) - fh / 2.0


static var _pmd_data: = {}



static func pmd_anims() -> Dictionary:
	if _pmd_data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PMD_ANIMS))
		_pmd_data = parsed if parsed is Dictionary else {}
	return _pmd_data



static func resolve_chain(species: String, chain: Array) -> String:
	var pmd: Dictionary = spec(species).get("pmd", {})
	for name in chain:
		if pmd.has(name):
			return String(name)
	return ""


static var _footprint_cache: = {}





static func footprint_m(species: String) -> float:
	if _footprint_cache.has(species):
		return _footprint_cache[species]
	var s: = spec(species)
	var w: = 0.0
	if bool(s.get("real", false)):
		var tex: Texture2D = s.texture
		var fw: = int(tex.get_width() / maxi(1, int(s.hframes)))
		var fh: = int(tex.get_height() / maxi(1, int(s.vframes)))
		var img: = tex.get_image()
		if img != null and fw > 0 and fh > 0:
			w = float(img.get_region(Rect2i(0, 0, fw, fh)).get_used_rect().size.x) * float(s.pixel_size)
	if w <= 0.0:
		w = float(s.get("visible_m", 1.0)) * 0.9
	_footprint_cache[species] = w
	return w






static func _pack_sprites(s: Dictionary, dir: String) -> void :
	var icon: Texture2D = load(dir + "icon.png") if ResourceLoader.exists(dir + "icon.png") else _frame0(s)
	var front: = _strip(dir + "front.png")
	var back: = _strip(dir + "back.png")
	var party: = _strip(dir + "party_icon.png")
	s["icon"] = icon
	s["front"] = front.get("frame", icon)
	s["back"] = back.get("frame", s["front"])
	s["party_icon"] = party.get("frame", icon)
	s["front_frames"] = {"texture": front.get("texture", s["front"]), "frames": front.get("frames", 1)}
	s["back_frames"] = {"texture": back.get("texture", s["back"]), "frames": back.get("frames", 1)}
	s["party_icon_frames"] = {"texture": party.get("texture", s["party_icon"]), "frames": party.get("frames", 1)}


static func _strip(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var tex: Texture2D = load(path)
	var fh: = tex.get_height()
	if fh <= 0:
		return {}
	var frames: = maxi(1, int(tex.get_width() / fh))
	return {"texture": tex, "frames": frames, "frame": _atlas(tex, 0, frames)}


static func _atlas(tex: Texture2D, index: int, frames: int) -> AtlasTexture:
	var at: = AtlasTexture.new()
	at.atlas = tex
	var w: = tex.get_width() / float(maxi(1, frames))
	at.region = Rect2(index * w, 0, w, tex.get_height())
	return at


static func _frame0(s: Dictionary) -> Texture2D:
	var tex: Texture2D = s.texture
	var at: = AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width() / s.hframes, tex.get_height() / s.vframes)
	return at



static func icon(species: String) -> Texture2D:
	return _preview(species, "icon")



static func front(species: String) -> Texture2D:
	return _preview(species, "front")


static func back(species: String) -> Texture2D:
	return _preview(species, "back")


static func party_icon(species: String) -> Texture2D:
	return _preview(species, "party_icon")


static func _preview(species: String, kind: String) -> Texture2D:
	var key := species + ":" + kind
	if _preview_cache.has(key):
		return _preview_cache[key]
	var dir := ROOT + slug(species) + "/"
	var image: Texture2D
	if ResourceLoader.exists(dir + kind + ".png"):
		if kind == "icon":
			image = load(dir + kind + ".png")
		else:
			image = _strip(dir + kind + ".png").get("frame")
	elif ResourceLoader.exists(dir + "overworld.png"):
		var texture: Texture2D = load(dir + "overworld.png")
		var config = JSON.parse_string(FileAccess.get_file_as_string(dir + "sprite.json"))
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(0, 0, texture.get_width() / maxi(1, int(config.get("hframes", 1))), texture.get_height() / maxi(1, int(config.get("vframes", 1))))
		image = frame
	else:
		image = spec(species).icon
	# A collection thumbnail must not keep an entire directional sheet alive.
	if image is AtlasTexture:
		var atlas := image as AtlasTexture
		var pixels := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
		image = ImageTexture.create_from_image(pixels)
	_preview_cache[key] = image
	return image


static var _disc_cache: = {}




static func icon_fitted(species: String, size_px: int, fill: = 0.95) -> Texture2D:
	return _fit_icon(species, size_px, fill, false)





static func disc_icon(species: String, size_px: int, fill: = 0.85) -> Texture2D:
	return _fit_icon(species, size_px, fill, true)


static func _fit_icon(species: String, size_px: int, fill: float, circle: bool) -> Texture2D:
	var key: = "%s|%d|%.2f|%s" % [species, size_px, fill, circle]
	if _disc_cache.has(key):
		return _disc_cache[key]
	var tex: Texture2D = icon(species)
	if tex == null:
		return null
	var img: Image = null
	if tex is AtlasTexture:
		var at: = tex as AtlasTexture
		img = at.atlas.get_image().get_region(Rect2i(at.region))
	else:
		img = tex.get_image()
	if img == null:
		_disc_cache[key] = tex
		return tex
	var used: = img.get_used_rect()
	var crop: Image = img.get_region(used) if used.size.x > 0 and used.size.y > 0 else img.duplicate()
	var k: = (size_px * fill) / maxf(float(crop.get_width()), float(crop.get_height()))
	crop.resize(maxi(1, int(round(crop.get_width() * k))), maxi(1, int(round(crop.get_height() * k))), Image.INTERPOLATE_NEAREST)
	var canvas: = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), 
		Vector2i((size_px - crop.get_width()) / 2, (size_px - crop.get_height()) / 2))
	if circle:
		var r: = size_px * 0.5
		var rr: = r * r
		for y in size_px:
			for x in size_px:
				var dx: = x + 0.5 - r
				var dy: = y + 0.5 - r
				if dx * dx + dy * dy > rr:
					canvas.set_pixel(x, y, Color(0, 0, 0, 0))
	var out: = ImageTexture.create_from_image(canvas)
	_disc_cache[key] = out
	return out



static func front_frames(species: String) -> Dictionary:
	return spec(species).front_frames


static func back_frames(species: String) -> Dictionary:
	return spec(species).back_frames


static func party_icon_frames(species: String) -> Dictionary:
	return spec(species).party_icon_frames


static func tint(species: String) -> Color:
	if ResourceLoader.exists(ROOT + slug(species) + "/overworld.png"):
		return Color.WHITE
	return spec(species).tint



static func apply(sprite: Sprite3D, species: String) -> Dictionary:
	var s: = spec(species)
	sprite.texture = s.texture
	sprite.hframes = s.hframes
	sprite.vframes = s.vframes
	sprite.frame = 0
	sprite.pixel_size = s.pixel_size
	sprite.offset = Vector2(0, s.offset_y)
	sprite.modulate = s.tint
	sprite.flip_h = false
	SpriteLook.setup(sprite)
	return s



static func animate(sprite: Sprite3D, s: Dictionary, facing: Vector3, step: int) -> void :
	if s.static :
		sprite.frame = 0
		if absf(facing.x) > 0.1:
			var faces_right: bool = s.faces == "right"
			sprite.flip_h = (facing.x > 0.0) != faces_right
		return
	var dir: = "down"
	if absf(facing.x) > absf(facing.z):
		dir = "left" if facing.x < 0.0 else "right"
	else:
		dir = "down" if facing.z > 0.0 else "up"
	var row: = int(s.rows.get(dir, 0))
	sprite.frame = row * int(s.frames_per_row) + (step % int(s.frames_per_row))



static func reload() -> void :
	_cache.clear()
	_preview_cache.clear()

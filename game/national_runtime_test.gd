extends SceneTree

# Run after `godot --headless --editor --import --path game --quit` completes.
# This probe never reads or writes the player's save.
const Dex = preload("res://scripts/dex.gd")
const Mon = preload("res://scripts/stats/mon.gd")
const Sprites = preload("res://scripts/pokemon_sprites.gd")
const Capture = preload("res://scripts/stats/capture.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	await process_frame
	var State = load("res://scripts/state/game_state.gd")
	var names: Array = Dex.all_species()
	check(names.size() == 1025, "National roster contains 1025 species")
	check(Dex.all_types().has("fairy"), "Fairy type is registered")
	check(Dex.effectiveness("fairy", ["dragon"]) == 2.0, "Fairy is super effective against Dragon")
	check(Dex.effectiveness("dragon", ["fairy"]) == 0.0, "Fairy is immune to Dragon")
	check(Dex.effectiveness("poison", ["fairy"]) == 2.0, "Poison is super effective against Fairy")
	check(Dex.effectiveness("dark", ["steel"]) == 1.0 and Dex.effectiveness("ghost", ["steel"]) == 1.0, "Modern Steel matchup chart")
	var numbers: Dictionary = {}
	for name in names:
		var sp: Dictionary = Dex.species(name)
		var number: int = int(sp.get("dex_no", 0))
		check(number >= 1 and number <= 1025 and not numbers.has(number), "Unique dex number: " + name)
		numbers[number] = name
		var mon = Mon.create(name, 5)
		check(mon.max_hp > 0 and not mon.moves.is_empty(), "Playable stats and moves: " + name)
		for id in mon.moves:
			check(not Dex.move(id).is_empty(), "Implemented move: " + name + "/" + id)
		for learned in sp.get("learnset", []):
			check(not Dex.move(learned[1]).is_empty(), "Implemented learnset: " + name)
		var dir: String = Sprites.ROOT + Sprites.slug(name) + "/"
		check(ResourceLoader.exists(dir + "overworld.png"), "Imported overworld asset: " + name)
		check(Mon.from_dict(mon.to_dict()).species == name, "Save roundtrip: " + name)
	var encounters = root.get_node("Encounters")
	var available: Dictionary = {}
	for file in DirAccess.get_files_at("res://data/encounters"):
		if not file.ends_with(".json"):
			continue
		var path: String = "res://data/encounters/" + file
		var entries: Array = encounters.load_table(path)
		check(encounters.load_table(path).size() == entries.size(), "Encounter table cache is stable: " + file)
		for entry in entries:
			available[String(entry.get("species", ""))] = true
	for name in names:
		check(available.has(name), "Obtainable through encounter tables: " + name)
	var state = State.new()
	state.reset_new_game()
	for number in [1, 152, 252, 387, 494, 650, 722, 810, 906, 1025]:
		if not numbers.has(number):
			continue
		var name: String = numbers[number]
		var mon = Mon.create(name, 5)
		var look: Dictionary = Sprites.spec(name)
		check(look.get("real", false) and look.get("texture") != null, "Real representative sprite: " + name)
		var actor_count: int = Sprites._cache.size()
		check(Sprites.front(name) != null and Sprites.icon(name) != null, "Lightweight menu previews: " + name)
		check(Sprites._cache.size() == actor_count, "Menu previews do not load battle animation sets: " + name)
		check(Capture.throw_ball(mon.max_hp, 1, mon.catch_rate(), "master_ball").get("caught", false), "Capturable representative: " + name)
		state.mark_caught(name)
		state.box.append(mon)
	check(state.dex_caught_count() == 10, "All generation representatives enter the dex")
	check(State.BOX_CAPACITY >= 1025, "Storage supports a complete national collection")
	check(Sprites.ACTOR_CACHE_LIMIT == 32 and Sprites._cache.size() <= 32, "Animation cache is bounded for mobile")
	var restored = State.new()
	restored.from_dict(state.to_dict())
	check(restored.box.size() == state.box.size() and restored.dex_caught_count() == 10, "Storage and dex survive save roundtrip")
	print("NATIONAL_RUNTIME_RESULT failures=%d species=%d" % [failures.size(), names.size()])
	quit(0 if failures.is_empty() else 1)

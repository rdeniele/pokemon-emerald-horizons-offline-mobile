class_name AnalyticsBeats
extends RefCounted






static func beat(name: String, props: = {}) -> void :
	var p: = props.duplicate()
	p["beat"] = name
	p["minutes_since_new_game"] = int(Game.state.play_time / 60.0)
	Analytics.track("story_beat", p)


static func beat_once(name: String, props: = {}) -> void :
	var key: = "seen_" + name
	if Game.flags.get(key, false):
		return
	Game.flags[key] = true
	beat(name, props)

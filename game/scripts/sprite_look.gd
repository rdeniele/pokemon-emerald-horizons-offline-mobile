extends RefCounted








static func setup(sprite: Sprite3D) -> void :
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.material_overlay = null

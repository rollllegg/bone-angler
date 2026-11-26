extends RefCounted
## Holds story prop state. Held objects are drawn in front of the guest.

const TEXTURES := {
	"lyre": preload("res://assets/art/story/props/lyre_showcase.png"),
	"staff": preload("res://assets/art/story/props/staff_clean.png"),
	"tail": preload("res://assets/art/story/props/tail.png"),
	"coins": preload("res://assets/art/story/props/coins.png"),
	"bowl": preload("res://assets/art/story/props/bowl.png"),
	"gray_hand": preload("res://assets/art/story/props/gray_hand.png"),
	"peach": preload("res://assets/art/story/props/peach.png"),
	"cloud": preload("res://assets/art/story/props/cloud.png"),
	"scale": preload("res://assets/art/story/props/scale.png"),
}

const BEHIND := ["tail", "cloud"]

var _props: Dictionary = {}


func show_prop(id: String, position: Vector2, scale: float = 1.0) -> void:
	if not TEXTURES.has(id):
		return
	_props[id] = {"position": position, "scale": maxf(scale, 0.1)}


func hide_prop(id: String) -> void:
	_props.erase(id)


func clear() -> void:
	_props.clear()


func has_prop(id: String) -> bool:
	return _props.has(id)


func get_prop_ids() -> Array:
	return _props.keys()


func get_texture(id: String):
	return TEXTURES.get(id)


func get_state(id: String) -> Dictionary:
	return _props.get(id, {})


func layer_for(id: String) -> String:
	return "behind" if id in BEHIND else "front"

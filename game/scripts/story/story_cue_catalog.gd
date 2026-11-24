extends RefCounted
## Shared schema for story performance cues.
## Build validation and the runtime stage both read this file, so a cue can
## never name a type, prop or sprite that the stage does not know.

const TYPES := ["shake", "flash", "fade", "zoom", "sprite", "prop", "wait", "sound"]
const PROP_ACTIONS := ["show", "hide", "move"]
const PROP_IDS := ["lyre", "staff", "tail", "coins", "bowl", "gray_hand", "peach", "cloud"]
const SPRITE_IDS := ["wukong_disguise", "wukong_monkey", "wukong_turn", "orpheus_front", "orpheus_turn"]
const SOUND_IDS := []  # P4 audio arrives with the sound assets.
const MAX_DURATION := 3.0
const MAX_DELAY := 8.0

const DEFAULT_DURATIONS := {
	"shake": 0.35,
	"flash": 0.2,
	"fade": 0.45,
	"zoom": 0.4,
	"sprite": 0.0,
	"prop": 0.0,
	"wait": 0.3,
	"sound": 0.0,
}

const PROP_DEFAULT_POSITIONS := {
	"lyre": [236, 160],
	"staff": [198, 148],
	"tail": [218, 150],
	"coins": [216, 160],
	"bowl": [216, 160],
	"gray_hand": [222, 160],
	"peach": [214, 160],
	"cloud": [201, 190],
}


static func has_type(value: String) -> bool:
	return value in TYPES


static func has_prop(value: String) -> bool:
	return value in PROP_IDS


static func has_sprite(value: String) -> bool:
	return value in SPRITE_IDS


static func has_sound(value: String) -> bool:
	return value in SOUND_IDS


static func has_prop_action(value: String) -> bool:
	return value in PROP_ACTIONS


static func default_duration(value: String) -> float:
	return float(DEFAULT_DURATIONS.get(value, 0.0))


static func default_position(prop_id: String) -> Vector2:
	var point: Array = PROP_DEFAULT_POSITIONS.get(prop_id, [200, 150])
	return Vector2(float(point[0]), float(point[1]))

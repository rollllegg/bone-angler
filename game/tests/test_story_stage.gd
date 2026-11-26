extends SceneTree
## Verifies the shop stage effects without opening the full demo.

const Stage := preload("res://scripts/story/story_stage.gd")
const Catalog := preload("res://scripts/story/story_cue_catalog.gd")
const Shop := preload("res://scripts/demo/pixel_shop.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shop := FakeShop.new()
	shop.name = "FakeShop"
	var screen := Control.new()
	screen.size = Vector2(405, 243)
	root.add_child(shop)
	root.add_child(screen)
	var stage := Stage.new()
	root.add_child(stage)
	stage.bind(shop, screen)

	stage.begin_cue({"type": "flash", "color": "#ffffff", "alpha": 0.6}, 0.2)
	_check(is_equal_approx(stage.get_flash_alpha(), 0.6), "flash starts at its requested alpha")
	stage._process(0.1)
	_check(stage.get_flash_alpha() > 0.0 and stage.get_flash_alpha() < 0.6, "flash fades over time")
	stage.finish_cue({"type": "flash"})
	_check(is_equal_approx(stage.get_flash_alpha(), 0.0), "flash settles to transparent")

	stage.begin_cue({"type": "fade", "color": "#000000", "from": 0.0, "to": 1.0}, 0.2)
	stage._process(0.2)
	_check(is_equal_approx(stage.get_fade_alpha(), 1.0), "fade reaches its target")
	stage.reset()
	_check(is_equal_approx(stage.get_fade_alpha(), 0.0), "reset clears the fade")

	stage.begin_cue({"type": "shake", "strength": 6.0}, 0.4)
	stage._process(0.01)
	_check(shop.scale.x > 1.0, "shake slightly enlarges the shop to hide edges")
	_check(shop.position != Vector2.ZERO, "shake offsets the shop")
	stage.finish_cue({"type": "shake"})
	_check(shop.position.is_equal_approx(Vector2.ZERO), "shake settles back to the base transform")
	_check(shop.scale.is_equal_approx(Vector2.ONE), "shake restores the base scale")

	stage.begin_cue({"type": "zoom", "scale": 1.2}, 0.2)
	stage._process(0.2)
	_check(is_equal_approx(stage.get_zoom_scale(), 1.2), "zoom reaches its target scale")
	_check(shop.position.x < 0.0, "zoom recenters around the shop")
	stage.finish_cue({"type": "zoom"})
	_check(is_equal_approx(shop.scale.x, 1.2), "zoom final state stays after settle")
	stage.reset()
	stage.begin_cue({"type": "sprite", "id": "orpheus_front"}, 0.0)
	stage.begin_cue({"type": "prop", "id": "lyre", "action": "show"}, 0.0)
	stage.begin_cue({"type": "zoom", "scale": 1.12}, 0.25)
	stage._process(0.25)
	stage.finish_inspection()
	_check(not stage.has_prop("lyre") and shop.sprite == "orpheus_front", "ending inspection removes the prop and preserves the guest")
	stage._process(0.125)
	_check(stage.get_zoom_scale() > 1.0 and stage.get_zoom_scale() < 1.12, "the close-up returns smoothly")
	stage.finish_inspection()
	stage._process(0.125)
	_check(is_equal_approx(stage.get_zoom_scale(), 1.0), "repeated refreshes do not restart the return animation")
	_check(shop.position.is_equal_approx(Vector2.ZERO) and shop.scale.is_equal_approx(Vector2.ONE), "the original camera transform is restored")
	stage.reset()

	stage.begin_cue({"type": "prop", "id": "lyre", "action": "show", "position": [120, 130]}, 0.0)
	_check(stage.has_prop("lyre"), "prop cue shows the lyre")
	stage.begin_cue({"type": "prop", "id": "lyre", "action": "hide"}, 0.0)
	_check(not stage.has_prop("lyre"), "prop cue hides the lyre")
	for prop_id in Catalog.PROP_IDS:
		stage.begin_cue({"type": "prop", "id": prop_id, "action": "show"}, 0.0)
	_check(stage.get_prop_ids().size() == Catalog.PROP_IDS.size(), "every declared prop can be shown")
	stage.reset()
	_check(stage.get_prop_ids().is_empty(), "reset clears every prop")

	stage.begin_cue({"type": "sprite", "id": "wukong_monkey"}, 0.0)
	_check(shop.sprite == "wukong_monkey", "sprite cue swaps the story portrait")
	stage.finish_cue({"type": "sprite", "id": "wukong_monkey"})
	_check(shop.sprite == "wukong_monkey", "settled sprite keeps the final portrait")
	stage.ensure_story_sprite("orpheus_front")
	_check(shop.sprite == "wukong_monkey", "ensure keeps an existing portrait")
	stage.reset()
	_check(shop.sprite == "", "reset clears the story portrait")
	stage.ensure_story_sprite("orpheus_front")
	_check(shop.sprite == "orpheus_front", "ensure restores a default portrait after a reset")
	stage.reset()
	var layer = load("res://scripts/story/story_prop_layer.gd").new()
	_check(layer.layer_for("staff") == "front", "the displayed staff draws in front of the guest")
	_check(layer.layer_for("tail") == "behind", "tail prop draws behind the guest")
	_check(layer.layer_for("lyre") == "front", "lyre prop draws in front of the guest")
	_check(Shop.STORY_SPRITES.size() == Catalog.SPRITE_IDS.size(), "every declared sprite texture is loaded")
	for sprite_id in Catalog.SPRITE_IDS:
		_check(Shop.STORY_SPRITES.has(sprite_id), "sprite texture exists: " + sprite_id)
	var showroom := Shop.new()
	showroom.bind_story_props(layer)
	for sprite_id in Shop.CARRIED_PROPS:
		showroom.set_story_sprite(str(sprite_id))
		_check(showroom.get_story_texture() == Shop.STORY_SPRITES[sprite_id], "resting guest keeps the carried prop: " + str(sprite_id))
		var prop_id := str(Shop.CARRIED_PROPS[sprite_id])
		layer.show_prop(prop_id, Vector2.ZERO)
		_check(showroom.is_showing_held_prop() and showroom.get_story_texture() == Shop.PROP_FREE_SPRITES[sprite_id], "held prop selects the prop-free portrait: " + str(sprite_id))
		_check(showroom.get_story_shadow() == Shop.PROP_FREE_SHADOWS[sprite_id], "held prop also replaces its old shadow: " + str(sprite_id))
		layer.hide_prop(prop_id)
		_check(not showroom.is_showing_held_prop() and showroom.get_story_texture() == Shop.STORY_SPRITES[sprite_id], "putting the prop away restores the original portrait: " + str(sprite_id))
	showroom.free()

	if _failures == 0:
		print("StoryStage: %d checks, 0 failures" % _checks)
	else:
		print("StoryStage: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)


class FakeShop extends Node2D:
	var sprite := ""
	var flip := false

	func set_story_sprite(id: String, value: bool = false) -> void:
		sprite = id
		flip = value

	func has_story_sprite() -> bool:
		return sprite != ""

	func clear_story_sprite() -> void:
		sprite = ""
		flip = false

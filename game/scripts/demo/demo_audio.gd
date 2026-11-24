extends Node
## Sound cues for the playable demo.

enum Cue {
	UI_CLICK, UI_CONFIRM, PAGE_TURN, MARKET_OPEN, PURCHASE, COINS,
	CAST, BOBBER_SPLASH, BOBBER_WAIT, REEL, FERRY, FOOTSTEPS,
	RIG_SELECT, RIG_EQUIP, BREW, ESSENCE_SELECT, MEDICINE_SELECT, STRENGTHEN,
	TITLE_FISH_SPLASH,
}

const SOUNDS := {
	Cue.UI_CLICK: [-5.0, [preload("res://assets/audio/ui_click.wav")]],
	Cue.UI_CONFIRM: [-6.0, [preload("res://assets/audio/ui_confirm.wav")]],
	Cue.PAGE_TURN: [-7.0, [preload("res://assets/audio/page_turn.wav")]],
	Cue.MARKET_OPEN: [-8.0, [preload("res://assets/audio/market_open.wav")]],
	Cue.PURCHASE: [-6.0, [preload("res://assets/audio/purchase.wav")]],
	Cue.COINS: [-3.0, [preload("res://assets/audio/coins.wav")]],
	Cue.CAST: [-7.0, [
		preload("res://assets/audio/cast_1.wav"), preload("res://assets/audio/cast_2.wav"),
		preload("res://assets/audio/cast_3.wav"), preload("res://assets/audio/cast_4.wav"),
		preload("res://assets/audio/cast_5.wav"),
	]],
	Cue.BOBBER_SPLASH: [-6.0, [
		preload("res://assets/audio/bobber_splash_1.wav"), preload("res://assets/audio/bobber_splash_2.wav"),
		preload("res://assets/audio/bobber_splash_3.wav"), preload("res://assets/audio/bobber_splash_4.wav"),
		preload("res://assets/audio/bobber_splash_5.wav"),
	]],
	Cue.BOBBER_WAIT: [-12.0, [
		preload("res://assets/audio/bobber_wait_1.wav"), preload("res://assets/audio/bobber_wait_2.wav"),
		preload("res://assets/audio/bobber_wait_3.wav"),
	]],
	Cue.REEL: [-2.0, [
		preload("res://assets/audio/reel_1.wav"), preload("res://assets/audio/reel_2.wav"),
		preload("res://assets/audio/reel_3.wav"),
	]],
	Cue.FERRY: [-14.0, [preload("res://assets/audio/ferry_loop.wav")]],
	Cue.FOOTSTEPS: [-5.0, [preload("res://assets/audio/soul_footsteps.wav")]],
	Cue.RIG_SELECT: [-7.0, [preload("res://assets/audio/rig_select.wav")]],
	Cue.RIG_EQUIP: [-2.0, [preload("res://assets/audio/rig_equip.wav")]],
	Cue.BREW: [-3.0, [preload("res://assets/audio/brew.wav")]],
	Cue.ESSENCE_SELECT: [-8.0, [
		preload("res://assets/audio/essence_select_1.wav"), preload("res://assets/audio/essence_select_2.wav"),
	]],
	Cue.MEDICINE_SELECT: [-6.0, [preload("res://assets/audio/medicine_select.wav")]],
	Cue.STRENGTHEN: [-4.0, [preload("res://assets/audio/strengthen.wav")]],
	Cue.TITLE_FISH_SPLASH: [-12.0, [preload("res://assets/audio/fish_water_plip.wav")]],
}

var _players: Dictionary[Cue, AudioStreamPlayer] = {}
var _rng := RandomNumberGenerator.new()


func play(cue: Cue) -> void:
	var player := _players.get(cue) as AudioStreamPlayer
	var sound: Array = SOUNDS[cue]
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = Cue.find_key(cue)
		player.volume_db = sound[0]
		if cue == Cue.TITLE_FISH_SPLASH:
			player.max_polyphony = 12
		add_child(player)
		_players[cue] = player
	var clips: Array = sound[1]
	var clip: AudioStream = clips[_rng.randi_range(0, clips.size() - 1)]
	if player.stream != clip:
		player.stream = clip
	player.play()


func stop(cue: Cue) -> void:
	var player := _players.get(cue) as AudioStreamPlayer
	if player != null and player.playing:
		player.stream_paused = false
		player.stop()


func set_paused(cue: Cue, paused: bool) -> void:
	var player := _players.get(cue) as AudioStreamPlayer
	if player != null and player.playing and player.stream_paused != paused:
		player.stream_paused = paused


func sync_ferry(visible: bool, paused: bool) -> void:
	var player := _players.get(Cue.FERRY) as AudioStreamPlayer
	if not visible:
		stop(Cue.FERRY)
	elif player != null and player.playing:
		set_paused(Cue.FERRY, paused)
	elif not paused:
		play(Cue.FERRY)

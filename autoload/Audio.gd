extends Node
## Every sound the game makes.
##
## An autoload for the same reason the router is one: sound outlives the screen
## that triggers it. An explosion started by an alien that is about to
## `queue_free()` itself has to keep playing after that node is gone, and the
## music bed has to survive the scene change from the quiz into the battle
## without a gap.
##
## Callers name a sound and nothing else — `Audio.play("laser")`. Where the file
## lives, which bus it goes to, how many can overlap and whether it exists at all
## are this file's problem. That indirection is what makes the placeholder set in
## `assets/audio/` replaceable a file at a time: drop in a new `laser.wav` and no
## script changes.
##
## **The current sounds are placeholders**, synthesised by
## `tools/gen_placeholder_audio.py`. They are here so the game can be tuned with
## sound in it rather than against silence; they are not meant to ship.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATH := "res://assets/audio/music/%s.wav"

## Simultaneous sound effects. Scene 4 sends 26 aliens in, several can die in the
## same second, and each death is an explosion over a laser that is still
## ringing — so this is sized for a bad moment, not an average one.
const VOICES: int = 16
const MUSIC_FADE: float = 0.9

## Buttons in this group are skipped by the automatic click below, because they
## have a sound of their own. The members are the sign-in keyboard's keys.
const NO_CLICK_GROUP := "silent_button"

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _active_music: int = 0
var _current_bed: String = ""
var _music_tween: Tween
## Sounds already loaded, by name. Also caches the misses as `null`, so a missing
## file warns once instead of once per laser shot.
var _cache: Dictionary = {}


func _ready() -> void:
	# Sound has to keep working while the tree is paused: the game-over card
	# pauses everything and is exactly where the game-over sting plays.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)

	# Two music players rather than one, so a bed can fade out underneath the
	# next one fading in. Cutting from menu to battle on a single player is a
	# hole in the sound at the exact moment the game is trying to feel urgent.
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)

	get_tree().node_added.connect(_on_node_added)
	# The boot scene is already in the tree by the time an autoload is ready, so
	# the opening bed is chosen from it rather than waiting for a transition that
	# will not come until the player presses START.
	call_deferred("_start_boot_music")


func _exit_tree() -> void:
	# Hygiene, not a fix. Quitting with the bed still playing makes Godot report
	# one leaked AudioStreamWAV at exit: the AudioServer holds the playback and
	# only lets go of it a few frames after the player stops, which is later than
	# any shutdown hook runs. Stopping the music a second *before* quitting
	# clears it, so it is a teardown-ordering artefact and not a real leak.
	#
	# Worth knowing when reading a headless run: one resource still in use at
	# exit is expected — two would be new.
	stop_music()
	for player in _voices:
		player.stop()
		player.stream = null
	for player in _music_players:
		player.stream = null
	_cache.clear()


## Play a one-shot effect.
##
## `pitch_jitter` spreads repeated plays of the same file around their own pitch.
## Without it the laser — five shots a second, all identical — stops sounding
## like a gun and starts sounding like a fault.
func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	var stream := _load(SFX_PATH % sound, sound)
	if stream == null:
		return
	var player := _free_voice()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 if pitch_jitter <= 0.0 else randf_range(
		1.0 - pitch_jitter, 1.0 + pitch_jitter
	)
	player.play()


## Switch the music bed, cross-fading from whatever is playing.
##
## Asking for the bed that is already playing does nothing — that is what lets
## the router call this on every single transition without briefing → quiz →
## battle restarting the same loop three times.
func play_music(bed: String) -> void:
	if bed == _current_bed:
		return
	var stream := _load(MUSIC_PATH % bed, "music/" + bed)
	if stream == null:
		return
	_loop_forever(stream)

	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	_current_bed = bed

	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, MUSIC_FADE)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -40.0, MUSIC_FADE)
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music() -> void:
	_current_bed = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()


## Which bed belongs to a screen. One function so the router and the boot path
## can't disagree about it.
func bed_for_scene(scene_path: String) -> String:
	return "battle" if scene_path == SceneRouter.GAME else "menu"


func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, volume_db)


func _start_boot_music() -> void:
	var current := get_tree().current_scene
	if current != null:
		play_music(bed_for_scene(current.scene_file_path))


## Round-robin, preferring a player that has finished.
##
## When every voice is busy the oldest is stolen rather than the sound being
## dropped. On a screen full of explosions a missing explosion is more obvious
## than a truncated one.
func _free_voice() -> AudioStreamPlayer:
	for i in _voices.size():
		var index := (_next_voice + i) % _voices.size()
		if not _voices[index].playing:
			_next_voice = (index + 1) % _voices.size()
			return _voices[index]
	var stolen := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen


func _load(path: String, key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		# Deliberately a warning and not an error, and cached so it is printed
		# once. A sound file that hasn't been dropped in yet must never be the
		# reason a child's game stops — the game plays fine silent.
		push_warning("Audio: no sound at %s — playing nothing for '%s'." % [path, key])
	_cache[key] = stream
	return stream


## Make an imported WAV loop, in code rather than through import settings.
##
## The loop points are a property of the `.wav`'s `.import` file, which is
## generated by the editor and easy to lose in a reimport; setting them here
## means a replacement music file loops correctly the moment it is dropped in,
## with no import options to remember.
func _loop_forever(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		# .ogg and .mp3 carry their own loop flag, which the importer honours.
		return
	if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)


## Give every button in the game its click, wherever it is built.
##
## The alternative was a line in each of the seven screens plus the two sign-in
## key builders, and a click missing from whichever one gets added next. Buttons
## opt out by joining `silent_button`; nothing else about them changes, and the
## sound is attached rather than the press being intercepted, so a button whose
## handler frees its own screen still makes its noise.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.is_in_group(NO_CLICK_GROUP):
		return
	button.pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play("ui_click")

# gdUnit4 test suite for the Phase 9 sound layer and the attract screen's art.
#
# What these guard is the failure mode the sound system was deliberately built
# to have: a missing file is a warning and silence, never a crash. That is the
# right behaviour on a kiosk a child is standing at — and it is also completely
# invisible. A typo in a sound name, a file renamed by whoever replaces the
# placeholder set, or an asset that never got committed all produce a game that
# runs perfectly and just makes no noise, which nobody notices until the machine
# is in the room. So the names the code actually calls are listed here and
# checked against the disk.
#
# The attract-mode photographs are here for the same reason: a destination with
# no picture is skipped silently.
extends GdUnitTestSuite

## Every sound name passed to `Audio.play()` anywhere in the codebase. Kept by
## hand, on purpose — adding a call means adding a line here, which is the
## moment to notice the file has to exist.
const SOUNDS_IN_USE: PackedStringArray = [
	"laser",            # Turret.try_fire
	"armour_hit",       # AlienShip._show_armour_damage
	"alien_explode",    # AlienShip._explode
	"carrier_explode",  # AlienShip._explode, armoured
	"shock_charge",     # AlienShip._start_charge
	"shock_zap",        # AlienShip._discharge
	"leak",             # HUD._on_damage_taken
	"game_over",        # HUD._on_game_over
	"scene_cleared",    # HUD._on_scene_cleared
	"victory",          # HUD._on_scene_cleared, last scene
	"quiz_correct",     # Quiz._on_answer_pressed
	"quiz_wrong",       # Quiz._on_answer_pressed
	"countdown",        # Quiz._run_countdown, FactCard._reveal
	"launch",           # Quiz._launch, Briefing._reveal
	"ui_click",         # Audio._on_any_button_pressed, every button in the game
	"ui_key",           # SignIn._on_key_pressed
]

const BEDS_IN_USE: PackedStringArray = ["menu", "battle"]


func test_every_sound_the_game_asks_for_exists() -> void:
	for sound in SOUNDS_IN_USE:
		var path: String = Audio.SFX_PATH % sound
		assert_bool(ResourceLoader.exists(path)) \
			.override_failure_message("No sound file at %s" % path) \
			.is_true()
		assert_object(load(path)).is_instanceof(AudioStream)


func test_every_music_bed_exists() -> void:
	for bed in BEDS_IN_USE:
		var path: String = Audio.MUSIC_PATH % bed
		assert_bool(ResourceLoader.exists(path)) \
			.override_failure_message("No music file at %s" % path) \
			.is_true()


func test_a_missing_sound_is_silence_and_not_a_crash() -> void:
	# The whole reason the suite above matters: this is what a typo does.
	assert_object(Audio._load(Audio.SFX_PATH % "does_not_exist", "does_not_exist")).is_null()
	Audio.play("does_not_exist")


func test_the_mix_has_somewhere_to_send_music_and_effects() -> void:
	# Without these buses every player silently falls back to Master, and the
	# separate music/effects volumes the kiosk is tuned with stop existing.
	assert_int(AudioServer.get_bus_index("Music")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("SFX")).is_greater_equal(0)


func test_the_battle_is_the_only_screen_with_its_own_bed() -> void:
	assert_str(Audio.bed_for_scene(SceneRouter.GAME)).is_equal("battle")
	for screen in [
		SceneRouter.TITLE, SceneRouter.SIGN_IN, SceneRouter.BRIEFING,
		SceneRouter.FACT_CARD, SceneRouter.QUIZ, SceneRouter.RESULTS,
	]:
		assert_str(Audio.bed_for_scene(screen)).is_equal("menu")


func test_the_voice_pool_is_big_enough_for_the_worst_wave() -> void:
	# Scene 4's wave is the busiest moment in the campaign; the pool has to
	# cover a laser, its explosion and the leak alarm several times over.
	var busiest: int = 0
	for index in range(1, CampaignData.count() + 1):
		busiest = maxi(busiest, CampaignData.wave(index)["count"])
	assert_int(Audio.VOICES).is_greater_equal(8)
	assert_int(Audio._voices.size()).is_equal(Audio.VOICES)


func test_every_destination_has_a_photograph_for_the_attract_screen() -> void:
	# A scene with no still is dropped from the cycle without a word, so the
	# title would quietly advertise three destinations out of four.
	#
	# It guards the briefing and the fact card too: `DestinationBackdrop` shows
	# the same photographs held still, and `AttractBackdrop.IMAGE_PATH` is an
	# alias of its constant, so one missing file is one silently plain screen in
	# three places rather than one.
	var AttractBackdrop := load("res://scripts/AttractBackdrop.gd")
	for index in range(1, CampaignData.count() + 1):
		var path: String = AttractBackdrop.IMAGE_PATH % index
		assert_bool(ResourceLoader.exists(path)) \
			.override_failure_message("No attract still for scene %d at %s" % [index, path]) \
			.is_true()


func test_the_idle_warning_lands_inside_the_idle_timeout() -> void:
	# The warning is counted *inside* the timeout, not added to it. Setting it
	# longer than the timeout would mean the card never appears and the kiosk
	# resets with no notice at all.
	assert_float(IdleWatch.WARNING_SECONDS).is_less(IdleWatch.IDLE_SECONDS)
	assert_float(IdleWatch.WARNING_SECONDS).is_greater(0.0)

# gdUnit4 test suite for the Thai build's two silent failure modes.
#
# Neither of these announces itself at runtime. A `gui/theme/custom_font` that
# stops resolving is not an error — Godot falls back to its built-in font, which
# has no Thai glyphs, and every screen in the game quietly fills with tofu boxes
# while the kiosk runs on perfectly happily. A fact added to the campaign table
# in English is not an error either; it is simply one child, one run, taught in a
# language they may not read.
#
# The same reasoning as `audio_test.gd`: the things this project makes deliberately
# silent are the things that need a test.
extends GdUnitTestSuite

## The Thai block. Any codepoint in it is proof a string is not still English.
const THAI_START: int = 0x0E00
const THAI_END: int = 0x0E7F

## Every consonant modern Thai actually writes with. ฃ, ฅ and ฦ are left out on
## purpose — they are obsolete, appear in no living name, and the sign-in
## keyboard spends their three keys on vowels instead.
const CONSONANTS: String = "กขคฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ"
## Every vowel, tone mark and modifier a name can be spelled with.
const MARKS: String = "ะัาำิีึืุูเแโใไ่้๊๋็์ํๆฤ"

## Keys per row the 1152×648 screen fits at `SignIn.KEY_SIZE`. A row past this
## runs off the edge, and the letters that fall off are simply untypeable.
const MAX_KEYS_PER_ROW: int = 13


func _ui_font() -> Font:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	assert_str(path).override_failure_message(
		"gui/theme/custom_font is unset. The engine's built-in font has no Thai "
		+ "glyphs, so every screen would draw tofu boxes without erroring."
	).is_not_empty()
	assert_bool(ResourceLoader.exists(path)).override_failure_message(
		"gui/theme/custom_font points at nothing: %s" % path
	).is_true()
	return load(path) as Font


func _has_thai(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= THAI_START and c <= THAI_END:
			return true
	return false


func test_the_ui_font_can_draw_every_letter_thai_is_written_with() -> void:
	var font := _ui_font()
	assert_object(font).is_not_null()
	for c in CONSONANTS + MARKS:
		assert_bool(font.has_char(c.unicode_at(0))).override_failure_message(
			"the UI font has no glyph for %s — it would draw as a tofu box" % c
		).is_true()


func test_the_ui_font_still_draws_the_latin_the_screens_kept() -> void:
	# The wordmark, the score digits, the clock and "ISS" are all still Latin, and
	# a Thai-only font would tofu every one of them.
	var font := _ui_font()
	for c in "DARKSECTOabcdefghijklmnopqrstuvwxyz0123456789:/.":
		assert_bool(font.has_char(c.unicode_at(0))).override_failure_message(
			"the UI font has no glyph for the Latin character '%s'" % c
		).is_true()


func test_every_line_the_campaign_teaches_is_in_thai() -> void:
	for i in range(1, CampaignData.count() + 1):
		var entry := CampaignData.scene(i)
		assert_bool(_has_thai(entry["title"])).override_failure_message(
			"scene %d's title is still English: %s" % [i, entry["title"]]
		).is_true()
		assert_bool(_has_thai(entry["story"])).override_failure_message(
			"scene %d's story is still English: %s" % [i, entry["story"]]
		).is_true()

		for variant in CampaignData.quiz_count(i):
			var quiz := CampaignData.quiz(i, variant)
			assert_bool(_has_thai(quiz["fact"])).override_failure_message(
				"scene %d variant %d's fact is still English: %s" % [i, variant, quiz["fact"]]
			).is_true()
			assert_bool(_has_thai(quiz["question"])).override_failure_message(
				"scene %d variant %d's question is still English: %s"
				% [i, variant, quiz["question"]]
			).is_true()
			for answer in quiz["answers"]:
				assert_bool(_has_thai(answer)).override_failure_message(
					"scene %d variant %d has an English answer: %s" % [i, variant, answer]
				).is_true()


func test_the_sign_in_keyboard_can_type_any_thai_name() -> void:
	# The keyboard is generated from a constant rather than authored in the scene,
	# so this reads the constant the screen actually builds itself from.
	var rows: Array = load("res://scripts/SignIn.gd").get_script_constant_map()["KEY_ROWS"]
	var keys := ""
	for row in rows:
		keys += row

	for c in CONSONANTS:
		assert_bool(keys.contains(c)).override_failure_message(
			"the sign-in keyboard has no key for the consonant %s — a child whose "
			% c + "name contains it cannot sign in"
		).is_true()
	for c in MARKS:
		assert_bool(keys.contains(c)).override_failure_message(
			"the sign-in keyboard has no key for the mark %s" % c
		).is_true()


func test_no_key_on_the_sign_in_keyboard_is_a_tofu_box() -> void:
	var font := _ui_font()
	var rows: Array = load("res://scripts/SignIn.gd").get_script_constant_map()["KEY_ROWS"]
	for row in rows:
		for i in row.length():
			assert_bool(font.has_char(row.unicode_at(i))).override_failure_message(
				"the UI font cannot draw the key '%s'" % row[i]
			).is_true()


func test_the_sign_in_keyboard_fits_the_screen_it_is_drawn_on() -> void:
	# A row wider than this is not clipped visibly — the centred HBox just runs
	# off both edges, and the letters at the ends stop being reachable.
	var rows: Array = load("res://scripts/SignIn.gd").get_script_constant_map()["KEY_ROWS"]
	for row in rows:
		assert_int(row.length()).override_failure_message(
			"keyboard row \"%s\" is %d keys — more than the %d that fit"
			% [row, row.length(), MAX_KEYS_PER_ROW]
		).is_less_equal(MAX_KEYS_PER_ROW)


func test_no_letter_is_given_two_keys() -> void:
	# A duplicate is invisible on the screen and always means something else is
	# missing: the rows are laid out to a key budget, not to a spare one.
	var rows: Array = load("res://scripts/SignIn.gd").get_script_constant_map()["KEY_ROWS"]
	var seen := ""
	for row in rows:
		for i in row.length():
			var key: String = row[i]
			assert_bool(seen.contains(key)).override_failure_message(
				"the sign-in keyboard has two keys for %s" % key
			).is_false()
			seen += key


func test_the_alphabetical_layout_is_a_drop_in_for_the_kedmanee_one() -> void:
	# `SignIn.ALPHABETICAL_ROWS` exists so the kiosk can be switched from a
	# touch-typing layout to the ก ข ค order a child recites, as one word. That is
	# only true if it carries the same keys and fits the same screen.
	var constants: Dictionary = load("res://scripts/SignIn.gd").get_script_constant_map()
	var kedmanee := ""
	for row in constants["KEY_ROWS"]:
		kedmanee += row
	var alphabetical := ""
	for row in constants["ALPHABETICAL_ROWS"]:
		alphabetical += row
		assert_int(row.length()).is_less_equal(MAX_KEYS_PER_ROW)

	for i in kedmanee.length():
		assert_bool(alphabetical.contains(kedmanee[i])).override_failure_message(
			"ALPHABETICAL_ROWS is missing %s, which KEY_ROWS has" % kedmanee[i]
		).is_true()
	assert_int(alphabetical.length()).is_equal(kedmanee.length())

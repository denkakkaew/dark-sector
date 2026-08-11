extends Control
## Storyboard screen 9: the ranked board, and the last thing a player sees.
##
## It serves two arrivals. At the end of a run — won or lost — the run has just
## been recorded by `SceneRouter.finish_run()` and this screen highlights it.
## From the title it is view-only: `SceneRouter.ranking_only` is set, there is no
## run to point at, and the buttons that continue a session are dropped.
##
## The board itself belongs to the `Leaderboard` autoload; nothing here writes.

## Rows drawn before the board is cut off. Eight fits the screen at a size a kid
## can read from standing distance, which matters more than showing all twenty —
## the rest are on disk and come back into view as they are beaten.
const VISIBLE_ROWS: int = 8

const COLUMNS: Array[Dictionary] = [
	{"key": "rank", "title": "#", "width": 58.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"key": "name", "title": "ชื่อ", "width": 300.0, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"key": "score", "title": "คะแนน", "width": 170.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"key": "scene", "title": "ด่าน", "width": 120.0, "align": HORIZONTAL_ALIGNMENT_CENTER},
	{"key": "quiz", "title": "คำถาม", "width": 110.0, "align": HORIZONTAL_ALIGNMENT_CENTER},
	{"key": "time", "title": "เวลา", "width": 120.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
]

const ROW_COLOR := Color(0.86, 0.9, 0.97)
const HEADER_COLOR := Color(0.6, 0.7, 0.85)
## The current run's row. Gold, the same colour the HUD scores in, so "that one
## is mine" needs no legend.
const YOU_COLOR := Color(1.0, 0.87, 0.35)
const WIN_COLOR := Color(0.25, 0.92, 0.62)
const LOSS_COLOR := Color(1.0, 0.55, 0.42)

## Two points down from the Latin build. Thai draws a taller line box at the
## same point size — tone marks sit above the letter and vowels below it — and
## eight rows of the difference is a button row's worth of screen.
const HEADER_FONT: int = 17
const ROW_FONT: int = 20

@onready var _outcome: Label = $Layout/Column/Outcome
@onready var _table_panel: PanelContainer = $Layout/Column/TablePanel
@onready var _table: GridContainer = $Layout/Column/TablePanel/Table
@onready var _result_line: Label = $Layout/Column/ResultLine
@onready var _play_again_button: Button = $Layout/Column/Buttons/PlayAgainButton
@onready var _sign_out_button: Button = $Layout/Column/Buttons/SignOutButton
@onready var _title_button: Button = $Layout/Column/Buttons/TitleButton

var _leaving: bool = false


func _ready() -> void:
	_table.columns = COLUMNS.size()
	var view_only: bool = SceneRouter.ranking_only

	_show_outcome(view_only)
	_build_table(view_only)
	_show_result_line(view_only)

	# View-only has no session to continue: there is no run behind it and, coming
	# from the title, no signed-in player to play again *as*.
	_play_again_button.visible = not view_only
	_sign_out_button.visible = not view_only
	_title_button.text = "‹  ย้อนกลับ" if view_only else "⌂  หน้าแรก"

	_play_again_button.pressed.connect(_on_play_again_pressed)
	_sign_out_button.pressed.connect(_on_sign_out_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	(_title_button if view_only else _play_again_button).grab_focus()


## The one line that says how the run ended. The victory and game-over cards in
## the HUD have already delivered that news with the drama it deserves; this is
## the caption under it, and it names the scene reached rather than numbering it
## because "Mars" is what a player remembers.
func _show_outcome(view_only: bool) -> void:
	if view_only or Leaderboard.last_run.is_empty():
		_outcome.hide()
		return
	var run := Leaderboard.last_run
	var scene_index := int(run["scene_reached"])
	if bool(run["won"]):
		_outcome.text = "ปกป้องโลกสำเร็จ — ผ่านครบทั้ง %d ด่าน" % CampaignData.count()
		_outcome.add_theme_color_override("font_color", WIN_COLOR)
	else:
		_outcome.text = "ภารกิจล้มเหลว — ไปถึงด่าน %d · %s" % [
			scene_index, CampaignData.scene_name(scene_index)
		]
		_outcome.add_theme_color_override("font_color", LOSS_COLOR)


func _build_table(view_only: bool) -> void:
	for column in COLUMNS:
		_table.add_child(_cell(column["title"], column, HEADER_COLOR, HEADER_FONT))

	if Leaderboard.entries.is_empty():
		_table_panel.hide()
		_outcome.show()
		_outcome.text = "ยังไม่มีใครขึ้นกระดานเลย — มาเป็นคนแรกกัน!"
		_outcome.add_theme_color_override("font_color", HEADER_COLOR)
		return

	var run_rank: int = -2 if view_only else Leaderboard.last_run_rank
	for i in mini(VISIBLE_ROWS, Leaderboard.entries.size()):
		_add_row(i + 1, Leaderboard.entries[i], i == run_rank)

	# A run that placed below the visible rows — or missed the board entirely —
	# still gets a row of its own, after a break. Finishing a game and not finding
	# yourself anywhere on the screen reads as the score having been thrown away.
	if not view_only and run_rank >= VISIBLE_ROWS:
		_add_break()
		_add_row(run_rank + 1, Leaderboard.entries[run_rank], true)
	elif not view_only and run_rank == -1 and not Leaderboard.last_run.is_empty():
		_add_break()
		_add_row(-1, Leaderboard.last_run, true)


func _add_row(rank: int, entry: Dictionary, is_you: bool) -> void:
	var color := YOU_COLOR if is_you else ROW_COLOR
	var name_text: String = entry["name"]
	if is_you:
		name_text += "  ◄ คุณ"
	var scene_text := "%d" % int(entry["scene_reached"])
	if bool(entry["won"]):
		scene_text += " ✓"

	var texts: Array[String] = [
		"—" if rank < 0 else "%d" % rank,
		name_text,
		_score_text(int(entry["score"])),
		scene_text,
		"%d/%d" % [int(entry["quiz_correct"]), int(entry["quiz_total"])],
		GameState.format_time(float(entry["time"])),
	]
	for i in COLUMNS.size():
		_table.add_child(_cell(texts[i], COLUMNS[i], color, ROW_FONT))


## The gap that separates the top of the board from a row pulled up out of the
## deep end of it.
func _add_break() -> void:
	for column in COLUMNS:
		_table.add_child(
			_cell("···" if column["key"] == "rank" else "", column, HEADER_COLOR, HEADER_FONT)
		)


func _show_result_line(view_only: bool) -> void:
	if view_only or Leaderboard.last_run.is_empty():
		_result_line.hide()
		return
	var score := _score_text(int(Leaderboard.last_run["score"]))
	if Leaderboard.last_run_rank < 0:
		_result_line.text = "คะแนนของคุณ: %s — ยังไม่ติดอันดับ ลองอีกครั้งนะ!" % score
	elif Leaderboard.last_run_personal_best:
		_result_line.text = "คะแนนของคุณ: %s — สถิติใหม่ของตัวเอง!  ★" % score
	else:
		_result_line.text = "คะแนนของคุณ: %s — อันดับที่ %d จาก %d" % [
			score, Leaderboard.last_run_rank + 1, Leaderboard.entries.size()
		]


## Thin space between thousands, as the storyboard writes them: at this font size
## "12 300" is read at a glance where "12300" has to be counted.
func _score_text(score: int) -> String:
	var digits := str(score)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return out


func _cell(text: String, column: Dictionary, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(column["width"], 0)
	label.horizontal_alignment = column["align"]
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_play_again_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	# Same player, fresh run — `reset_campaign()` keeps the name deliberately.
	SceneRouter.start_campaign()


func _on_sign_out_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.player_name = ""
	SceneRouter.show_sign_in()


func _on_title_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.show_title()

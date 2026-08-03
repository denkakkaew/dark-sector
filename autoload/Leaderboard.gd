extends Node
## The ranking board, persisted locally in a `user://` file.
##
## The third of the three subsystems that outlive a level (sign-in, timer,
## ranking). It is an autoload for the same reason the other two are: a run is
## recorded at the very end, from a screen that knows nothing about the six
## screens the score was earned on.
##
## No backend, by design — this is a kiosk. The board is a JSON array on disk,
## rewritten whole on every insert. At MAX_ENTRIES rows that costs nothing and
## keeps the file readable by a human with a text editor, which matters when the
## only debugging available on a locked-down machine is opening the file.

## Rows kept on disk. The screen shows fewer (see `VISIBLE_ROWS` in Results.gd);
## the surplus is what a player has to beat their way through over a long day.
const MAX_ENTRIES: int = 20
## Longest name accepted. Kiosk names are call-signs, and the board has a fixed
## column for them — SignIn enforces the same number on the field itself.
const NAME_LIMIT: int = 12
## Shown for a run recorded with no name, which only happens when the game is
## launched straight into a gameplay scene during development.
const ANONYMOUS: String = "CADET"

## Every row currently on the board, best first.
var entries: Array[Dictionary] = []
## Where the board is read from and written to. A variable rather than a
## constant so a test can point it at a throwaway file instead of stomping the
## player's real board.
var file_path: String = "user://leaderboard.json"

## The run recorded most recently, its position on the board, and whether it beat
## that player's previous best. Results reads these to highlight the row and to
## write its result line; they are the only reason `record()` returns anything.
var last_run: Dictionary = {}
var last_run_rank: int = -1
var last_run_personal_best: bool = false


func _ready() -> void:
	load_board()


## Take the current `GameState` as a finished run and put it on the board.
##
## `won` is passed in rather than derived here: reaching scene 4 and *clearing*
## scene 4 are the same `scene_index`, and only the screen that ended the run
## knows which of the two happened.
func record_run(won: bool) -> int:
	var name := GameState.player_name.strip_edges()
	return record({
		"name": ANONYMOUS if name.is_empty() else name,
		"score": GameState.score,
		"scene_reached": GameState.scene_index,
		"quiz_correct": GameState.quiz_correct_count,
		"quiz_total": GameState.quiz_total_count,
		"time": GameState.elapsed_time,
		"won": won,
	})


## Insert one run, re-sort, trim and save. Returns the run's rank (0-based), or
## -1 when the board was already full of better scores and it didn't make it.
func record(fields: Dictionary) -> int:
	var entry := _sanitised(fields)
	# Measured before the insert, or the run would always be its own best.
	last_run_personal_best = entry["score"] > best_score_for(entry["name"])

	entries.append(entry)
	sort_board()
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)

	last_run = entry
	# `is_same` and not `==`: two players can post identical rows, and Dictionary
	# equality compares contents, so `find()` would happily return the other one.
	last_run_rank = -1
	for i in entries.size():
		if is_same(entries[i], entry):
			last_run_rank = i
			break

	save_board()
	return last_run_rank


## Forget the last recorded run — the board itself is untouched. Called when a
## new run starts, so a board opened from the title has nothing highlighted on it.
func forget_last_run() -> void:
	last_run = {}
	last_run_rank = -1
	last_run_personal_best = false


## The best score this player has already posted, or -1 if they are new. -1 and
## not 0 so that a genuine zero-score first run still counts as a personal best.
func best_score_for(name: String) -> int:
	var best: int = -1
	var wanted := name.strip_edges().to_lower()
	for entry in entries:
		if String(entry["name"]).to_lower() == wanted:
			best = maxi(best, int(entry["score"]))
	return best


func top(count: int) -> Array[Dictionary]:
	var slice: Array[Dictionary] = []
	for i in mini(count, entries.size()):
		slice.append(entries[i])
	return slice


## Best first. Score decides it; the tie-breaks are there so that two players on
## the same score are separated by how far they got, then by how much of the
## science they got right, then by how fast — in that order, because that is the
## order the game asks for those things.
func sort_board() -> void:
	entries.sort_custom(_ranks_above)


static func _ranks_above(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] != b["score"]:
		return a["score"] > b["score"]
	if a["scene_reached"] != b["scene_reached"]:
		return a["scene_reached"] > b["scene_reached"]
	if a["quiz_correct"] != b["quiz_correct"]:
		return a["quiz_correct"] > b["quiz_correct"]
	return a["time"] < b["time"]


func load_board() -> void:
	entries = []
	if not FileAccess.file_exists(file_path):
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Leaderboard: could not open %s" % file_path)
		return
	# A parser instance rather than `JSON.parse_string()`: the static helper logs
	# an engine ERROR of its own on bad input, and a corrupt board is a condition
	# this handles, not a fault to shout about on a kiosk screen.
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	# A board that has been corrupted — a kiosk killed mid-write, an edited file —
	# must not take the game down with it. An unreadable board is an empty board.
	if json.parse(text) != OK or not (json.data is Array):
		push_warning("Leaderboard: %s is not a board; starting empty" % file_path)
		return
	var parsed: Array = json.data
	for row in parsed:
		if row is Dictionary:
			entries.append(_sanitised(row))
	sort_board()
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)


func save_board() -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Leaderboard: could not write %s" % file_path)
		return
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()


func clear() -> void:
	entries = []
	forget_last_run()
	save_board()


## Coerce one row into the shape the rest of this file assumes.
##
## Everything JSON gives back is a float, and anything hand-edited into the file
## may be missing or the wrong type entirely. Doing this once on the way in means
## no caller — sorter, board, screen — has to defend itself.
func _sanitised(row: Dictionary) -> Dictionary:
	var quiz_total := maxi(0, int(row.get("quiz_total", 0)))
	return {
		"name": String(row.get("name", ANONYMOUS)).strip_edges().substr(0, NAME_LIMIT),
		"score": maxi(0, int(row.get("score", 0))),
		"scene_reached": clampi(int(row.get("scene_reached", 1)), 1, CampaignData.count()),
		"quiz_correct": clampi(int(row.get("quiz_correct", 0)), 0, quiz_total),
		"quiz_total": quiz_total,
		"time": maxf(0.0, float(row.get("time", 0.0))),
		"won": bool(row.get("won", false)),
	}

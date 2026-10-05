class_name CampaignData
extends RefCounted
## The campaign's content table: one entry per scene, read by everything.
##
## The storyboard's "extensible" principle lives here — the briefing, the quiz,
## the HUD and the spawner all read this table, so adding a fact or a fifth
## scene is a data change rather than a code change.
##
## Phase 5 uses `name` and `wave`. The story/fact/quiz fields are already filled
## in from `planning/STORYBOARD.md` so Phases 6–7 are wiring rather than writing.
##
## Each scene carries a **pool** of quiz variants rather than a single question,
## and one is drawn per scene per run (see `random_quiz_variant()`). A kiosk gets
## played over and over by the same kids, and a fact they have already been shown
## teaches nothing the second time.
##
## Scene indices are **1-based** everywhere (ด่าน 1·ISS … ด่าน 4·โลก) to
## match the HUD; use `scene()` / `wave()` rather than indexing `SCENES` directly.

## Flight-mode weights are positional, in `AlienShip.FlightMode` order. Kept as
## plain numbers rather than enum keys so this table has no dependency on the
## gameplay scripts — it is read by the briefing and quiz screens too.
const MODE_DIRECT: int = 0
const MODE_STRAFE: int = 1
const MODE_WEAVE: int = 2
const MODE_SWOOP: int = 3

## Per-scene content and difficulty. `wave` fields:
##
## - `count` — aliens in the wave; the scene is cleared once all of them are
##   resolved (shot down or got through).
## - `interval` — seconds between spawns.
## - `speed` — alien travel speed.
## - `mode_weights` — relative likelihood of each flight mode, MODE_* order.
##   The storyboard introduces the modes scene by scene, so early scenes leave
##   the later modes at 0.
## - `ore_carriers` — Mars' slow armoured carriers. Phase 6 implements them;
##   the number they should spawn is recorded here now.
## - `time_limit` — seconds before the scene ends on its own. A safety valve,
##   not the main pressure: a wave flies itself out in well under this, so a
##   scene normally ends by being cleared. It exists so an idle kiosk can never
##   sit in a scene forever. One flat minute for every scene — the later waves
##   are longer, but they are also faster, so they do not need more clock.
##
## `quiz` is the scene's pool of teaching moments — one is drawn per run and the
## fact card and the quiz screen both read that same one, so the question is
## always about the fact the player was just shown. Each entry is self-contained:
##
## - `fact` — the fact card screen's "รู้หรือไม่?". True, and short enough to read
##   at a glance; the card is sized for roughly the length of the ones here.
## - `question` / `answers` / `correct` — three big touch buttons and the index of
##   the right one. The correct index is varied deliberately across the pool: kids
##   spot "it's always the first one" long before they learn any astronomy.
##
## `accent` is the scene's signature colour, from the storyboard's per-scene
## palette. The briefing, fact card and quiz tint themselves with it so the four missions
## read as different places before any real art exists; the `look` block below
## keeps the battle in step with them.
##
## `look` is the battlefield's dressing, read by `SceneLook.gd`:
##
## - `space` — what the camera sees where nothing else is: the sky colour.
## - `ambient` / `sun` / `fill` — the scene's lighting. Ambient is what lifts the
##   turret and the aliens out of black, so it carries most of a scene's mood.
## - `photo` — the painted backdrop authored in `Game.tscn`. `texture` is the
##   image to hang on it, `tint` knocks it back so it stays scenery, and a scene
##   with nothing to hang sets `visible` false. Its placement was tuned by hand
##   and stays where it is; only its *height* moves, so an image of a different
##   shape keeps its proportions instead of being stretched to Earth's.
## - `bodies` — flat-shaded spheres the scene builds for itself. A huge one
##   parked low is a planet surface curving away below the guns; a small one high
##   up is a distant world. `mottle` dusts the surface with noise (craters, dust);
##   `emission` keeps a distant body from going black on its night side. A scene
##   whose `photo` already paints its ground and horizon has no need of them.
## - `stars` — density of the procedural star field, 0 for a sky that has none
##   (Mars' is full of dust, and the photographic backdrops bring their own).
const SCENES: Array = [
	{
		# "ISS" stays Latin: it is what the station is called in Thai too, and the
		# HUD's scene chip has room for three characters, not for สถานีอวกาศนานาชาติ.
		"name": "ISS",
		"title": "สถานีอวกาศ ISS — เผชิญหน้าครั้งแรก",
		"accent": Color(0.24, 0.55, 0.9),
		"story": "ยานสอดแนมต่างดาวกำลังบุกสถานีอวกาศนานาชาติ — ประจำป้อมปืนเดี๋ยวนี้!",
		"quiz": [
			{
				"fact": "สถานีอวกาศ ISS โคจรสูงราว 400 กม. เหนือพื้นโลก ด้วยความเร็วราว 28,000 กม./ชม. นักบินอวกาศบนสถานีจึงเห็นดวงอาทิตย์ขึ้นถึง 16 ครั้งต่อวัน!",
				"question": "นักบินอวกาศบน ISS เห็นดวงอาทิตย์ขึ้นวันละกี่ครั้ง?",
				"answers": ["1 ครั้ง", "16 ครั้ง", "100 ครั้ง"],
				"correct": 1,
			},
			{
				"fact": "ISS วิ่งรอบโลกครบหนึ่งรอบทุก ๆ 90 นาที นั่นคือ 16 รอบโลกในหนึ่งวัน",
				"question": "ISS ใช้เวลาโคจรรอบโลกหนึ่งรอบนานเท่าไร?",
				"answers": ["ประมาณ 24 ชั่วโมง", "ประมาณหนึ่งเดือน", "ประมาณ 90 นาที"],
				"correct": 2,
			},
			{
				"fact": "ISS ใช้พลังงานจากแสงอาทิตย์ล้วน ๆ ปีกแผงโซลาร์เซลล์ยักษ์ทั้งแปดแผงเปลี่ยนแสงเป็นไฟฟ้าทั้งหมดที่สถานีต้องใช้",
				"question": "ISS ได้ไฟฟ้ามาจากไหน?",
				"answers": ["จากแผงโซลาร์เซลล์ยักษ์", "จากสายไฟยาวมากที่ต่อลงมาจากโลก", "จากเครื่องยนต์น้ำมัน"],
				"correct": 0,
			},
			{
				"fact": "ISS เป็นสิ่งที่ใหญ่ที่สุดที่มนุษย์เคยสร้างในอวกาศ วัดจากปลายด้านหนึ่งไปอีกด้านยาวพอ ๆ กับสนามฟุตบอลหนึ่งสนาม",
				"question": "สถานีอวกาศ ISS ใหญ่แค่ไหน?",
				"answers": ["ประมาณรถบัสหนึ่งคัน", "ยาวพอ ๆ กับสนามฟุตบอล", "ใหญ่เท่าดวงจันทร์"],
				"correct": 1,
			},
			{
				"fact": "ทุกอย่างบน ISS ลอยได้หมด นักบินอวกาศจึงต้องนอนในถุงนอนที่หนีบติดผนัง และผูกเครื่องมือทุกชิ้นไว้กันลอยหาย",
				"question": "ทำไมนักบินอวกาศบน ISS ต้องหนีบถุงนอนติดผนัง?",
				"answers": ["เพื่อให้ร่างกายอบอุ่น", "เพื่อไม่ให้ถุงนอนเปื้อน", "เพื่อไม่ให้ลอยไปมาตอนหลับ"],
				"correct": 2,
			},
		],
		# Low orbit: the Earth photograph fills the lower view and lights the
		# station. This is the look the gameplay scene was built against.
		"look": {
			"space": Color(0.02, 0.02, 0.06),
			"ambient": Color(0.12, 0.12, 0.18),
			"sun": {"color": Color(1, 1, 1), "energy": 0.35},
			"fill": {"color": Color(0.88, 0.92, 1), "energy": 0.55},
			# The painted Earth limb stays: it is the scene's best feature and a 3D
			# globe could not match its sharpness across half the screen. It is
			# pushed far back so the 3D station — trusses, a module, a Soyuz, the
			# robot arm and solar arrays at the screen edges — can stand in front.
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/space_earth.png",
				"tint": Color(0.7, 0.7, 0.7),
				"distance": 220.0,
			},
			"set": "res://scenes/sets/ISSSet.tscn",
			"bodies": [],
			"stars": 0.0,
		},
		"wave": {
			"count": 12,
			"interval": 1.6,
			"speed": 7.0,
			"mode_weights": [0.85, 0.15, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
	{
		"name": "ดวงจันทร์",
		"title": "ดวงจันทร์ — ฐานทัพหน้า",
		"accent": Color(0.62, 0.66, 0.72),
		"story": "มนุษย์ต่างดาวกำลังสร้างฐานลับอยู่ด้านไกลของดวงจันทร์ สกัดยานลงจอดให้ได้!",
		"quiz": [
			{
				"fact": "ดวงจันทร์อยู่ห่างจากโลก 384,400 กม. และมีแรงโน้มถ่วงเพียง 1 ใน 6 ของโลก แถมเรายังเห็นด้านเดิมของมันเสมอ!",
				"question": "แรงโน้มถ่วงของดวงจันทร์เทียบกับของโลกเป็นเท่าไร?",
				"answers": ["เท่ากันพอดี", "หนึ่งในหก", "มากกว่าสองเท่า"],
				"correct": 1,
			},
			{
				"fact": "ดวงจันทร์ไม่มีอากาศ จึงไม่มีทั้งลมและฝน รอยเท้าที่นักบินอวกาศอะพอลโลทิ้งไว้เมื่อปี 1969 จึงยังอยู่ครบจนถึงวันนี้",
				"question": "ทำไมรอยเท้าของนักบินอะพอลโลถึงยังอยู่บนดวงจันทร์?",
				"answers": ["ไม่มีลมและฝนมาลบรอย", "รอยถูกสลักลงบนหินแข็ง", "มีคนไปทาสีใหม่ทุกปี"],
				"correct": 0,
			},
			{
				"fact": "ดวงจันทร์หมุนรอบตัวเองหนึ่งรอบพอดีกับที่โคจรรอบโลกหนึ่งรอบ หน้าเดิมจึงหันมาทางเราเสมอ ไม่มีใครเห็นด้านไกลของมันเลยจนถึงปี 1959!",
				"question": "ทำไมเราถึงเห็นดวงจันทร์ด้านเดิมเสมอ?",
				"answers": ["เพราะมันอยู่นิ่ง ไม่หมุนเลย", "เพราะมันหมุนรอบตัวเองหนึ่งรอบต่อการโคจรรอบโลกหนึ่งรอบ", "เพราะอีกด้านหนึ่งมองไม่เห็น"],
				"correct": 1,
			},
			{
				"fact": "ดวงจันทร์อยู่ไกลถึง 384,400 กม. นักบินอวกาศอะพอลโลต้องบินราวสามวันกว่าจะไปถึง",
				"question": "นักบินอวกาศอะพอลโลใช้เวลาเดินทางไปดวงจันทร์นานเท่าไร?",
				"answers": ["ประมาณสามชั่วโมง", "ประมาณสามปี", "ประมาณสามวัน"],
				"correct": 2,
			},
			{
				"fact": "เสียงต้องอาศัยอากาศในการเดินทาง แต่ดวงจันทร์ไม่มีอากาศเลย ต่อให้ยืนอยู่ข้าง ๆ กัน นักบินอวกาศก็ยังต้องคุยกันผ่านวิทยุ",
				"question": "ทำไมนักบินอวกาศบนดวงจันทร์ต้องคุยกันทางวิทยุ?",
				"answers": ["เพราะไม่มีอากาศพาเสียงไปถึงกัน", "เพราะบนดวงจันทร์เสียงดังเกินไป", "เพราะยืนอยู่ห่างกันหลายกิโลเมตร"],
				"correct": 0,
			},
		],
		# No air to soften anything: a hard white sun and a black sky. The ground,
		# the horizon ridge, the alien base and the landing pads are a real 3D set
		# now (`set`); what stays painted is only the star field behind it, hung
		# far back (`distance`) so the set can stand in front of it. Earth is the
		# one procedural body: the storyboard's small blue marble over the ridge.
		"look": {
			"space": Color(0.01, 0.01, 0.02),
			"ambient": Color(0.1, 0.1, 0.13),
			"sun": {"color": Color(1, 1, 0.97), "energy": 0.95},
			"fill": {"color": Color(0.6, 0.65, 0.78), "energy": 0.18},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/sky_stars.png",
				"tint": Color(0.92, 0.92, 0.96),
				"distance": 330.0,
			},
			"set": "res://scenes/sets/MoonSet.tscn",
			"bodies": [
				{
					"position": Vector3(-95.0, 62.0, -250.0),
					"radius": 9.0,
					"color": Color(0.22, 0.45, 0.9),
					"mottle": 0.45,
					"emission": 0.55,
				},
			],
			"stars": 0.0,
		},
		"wave": {
			"count": 16,
			"interval": 1.3,
			"speed": 8.5,
			"mode_weights": [0.5, 0.5, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
	{
		"name": "ดาวอังคาร",
		"title": "ดาวอังคาร — ศึกชิงแร่",
		"accent": Color(0.82, 0.38, 0.2),
		"story": "โดรนต่างดาวกำลังขโมยแร่จากดาวอังคารไปเป็นเชื้อเพลิงให้กองยาน สกัดยานขนแร่ให้ได้!",
		"quiz": [
			{
				"fact": "ดาวอังคารมีสีแดงเพราะสนิมเหล็กในดิน และยังมีภูเขาไฟที่สูงที่สุดในระบบสุริยะชื่อ โอลิมปัส มอนส์",
				"question": "ทำไมดาวอังคารถึงดูเป็นสีแดง?",
				"answers": ["เพราะดินเต็มไปด้วยสนิมเหล็ก", "เพราะมันร้อนมาก", "เพราะมนุษย์ต่างดาวทาสีไว้"],
				"correct": 0,
			},
			{
				"fact": "หนึ่งวันบนดาวอังคารยาวพอ ๆ กับของเรา ดาวดวงนี้หมุนรอบตัวเองครบหนึ่งรอบทุก 24 ชั่วโมง 37 นาที",
				"question": "หนึ่งวันบนดาวอังคารยาวแค่ไหน?",
				"answers": ["ยาวกว่าบนโลกสิบเท่า", "ยาวพอ ๆ กับบนโลก", "แค่สิบนาทีเท่านั้น"],
				"correct": 1,
			},
			{
				"fact": "โอลิมปัส มอนส์ บนดาวอังคารคือภูเขาไฟที่สูงที่สุดในระบบสุริยะ สูงราวสามเท่าของยอดเขาเอเวอเรสต์",
				"question": "โอลิมปัส มอนส์ สูงเทียบกับยอดเขาเอเวอเรสต์อย่างไร?",
				"answers": ["สูงกว่าราวสามเท่า", "สูงแค่ครึ่งเดียว", "สูงเท่ากันพอดี"],
				"correct": 0,
			},
			{
				"fact": "ดาวอังคารมีดวงจันทร์เล็ก ๆ ขรุขระสองดวง ชื่อโฟบอสกับดีมอส หน้าตาเหมือนมันฝรั่งมากกว่าดวงจันทร์ของเรา",
				"question": "ดาวอังคารมีดวงจันทร์กี่ดวง?",
				"answers": ["ไม่มีเลยสักดวง", "สิบสองดวง", "สองดวง"],
				"correct": 2,
			},
			{
				"fact": "ดาวอังคารมีแรงโน้มถ่วงราวหนึ่งในสามของโลก กระโดดแรงเท่าเดิมจึงลอยสูงขึ้นได้เกือบสามเท่า",
				"question": "ถ้ากระโดดบนดาวอังคารจะเป็นอย่างไร?",
				"answers": ["เหมือนกับบนโลกทุกอย่าง", "ลอยสูงขึ้นเกือบสามเท่า", "กระโดดไม่ขึ้นเลย"],
				"correct": 1,
			},
		],
		# The only scene with an atmosphere: dust turns the sky rust-pink, mutes
		# the sun and bounces light back up, so nothing here goes fully black.
		# No stars — you cannot see them through the dust.
		#
		# The one scene fought over a painted surface rather than open space. The
		# backdrop carries the mining outpost the aliens are raiding, so the
		# procedural ground sphere the other surface scene uses is gone: the photo
		# paints its own ground, horizon and dust haze, and a sphere in front of it
		# would only cut the outpost in half.
		"look": {
			# The sky is the only one in the campaign that isn't black. Barely any
			# of it survives behind the photo, but it has to agree with the image's
			# own haze at the edges rather than framing it in a darker band.
			"space": Color(0.4, 0.21, 0.16),
			"ambient": Color(0.34, 0.2, 0.16),
			"sun": {"color": Color(1, 0.85, 0.68), "energy": 0.7},
			"fill": {"color": Color(1, 0.66, 0.5), "energy": 0.4},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/mars_surface.png",
				# Knocked further back than Earth's, and towards grey: the image is
				# a saturated orange edge to edge, and the aliens have to stay the
				# most colourful thing on the screen.
				"tint": Color(0.55, 0.51, 0.52),
			},
			"bodies": [],
			"stars": 0.0,
		},
		"wave": {
			"count": 20,
			"interval": 1.1,
			"speed": 9.5,
			"mode_weights": [0.3, 0.25, 0.45, 0.0],
			"ore_carriers": 3,
			"time_limit": 60.0,
		},
	},
	{
		"name": "โลก",
		"title": "วงโคจรโลก — ด่านสุดท้าย",
		"accent": Color(0.86, 0.24, 0.28),
		"story": "ถึงเวลาแล้ว กองทัพต่างดาวมาถึงโลกของเรา ตั้งรับให้อยู่นะ ผู้พิทักษ์!",
		"quiz": [
			{
				"fact": "ชั้นบรรยากาศและสนามแม่เหล็กของโลกคอยปกป้องเราจากรังสีในอวกาศอยู่ทุกวัน",
				"question": "อะไรคอยปกป้องโลกจากรังสีในอวกาศ?",
				"answers": ["ชั้นบรรยากาศและสนามแม่เหล็ก", "ก้อนเมฆ", "ดาวเทียม"],
				"correct": 0,
			},
			{
				"fact": "อากาศที่เราหายใจส่วนใหญ่เป็นไนโตรเจน ราว 78% มีออกซิเจนที่ร่างกายใช้จริงเพียงราวหนึ่งในห้าเท่านั้น",
				"question": "อากาศของโลกส่วนใหญ่เป็นแก๊สอะไร?",
				"answers": ["ออกซิเจน", "ไนโตรเจน", "คาร์บอนไดออกไซด์"],
				"correct": 1,
			},
			{
				"fact": "มหาสมุทรปกคลุมพื้นผิวโลกราว 71% น้ำทั้งหมดนี่เองที่ทำให้โลกของเราดูเป็นสีน้ำเงินเมื่อมองจากอวกาศ",
				"question": "พื้นผิวโลกถูกมหาสมุทรปกคลุมมากแค่ไหน?",
				"answers": ["ราวหนึ่งในสิบ", "ราวหนึ่งในสาม", "ราวเจ็ดในสิบ"],
				"correct": 2,
			},
			{
				"fact": "อวกาศเริ่มต้นที่ความสูงเพียง 100 กม. เหนือหัวเรา ใกล้กว่าการนั่งรถเที่ยวหลายทริปเสียอีก ถ้าขับรถขึ้นข้างบนได้นะ!",
				"question": "อวกาศเริ่มต้นที่ความสูงเท่าไร?",
				"answers": ["ราว 100 กิโลเมตร", "ราว 100 เมตร", "ราวหนึ่งล้านกิโลเมตร"],
				"correct": 0,
			},
			{
				"fact": "โลกกำลังวิ่งรอบดวงอาทิตย์ด้วยความเร็วราว 107,000 กม./ชม. พาทุกคนที่ยืนอยู่บนนั้นไปด้วยกันหมด",
				"question": "โลกโคจรรอบดวงอาทิตย์เร็วแค่ไหน?",
				"answers": ["อยู่นิ่ง ๆ ไม่ได้เคลื่อนที่", "ราว 100 กม./ชม. เท่ารถยนต์", "ราว 100,000 กม./ชม."],
				"correct": 2,
			},
		],
		# The darkest scene, and the only one lit in red: everything in front of the
		# backdrop is washed in alert light, and the sun is turned down so the red
		# reads as an alarm rather than as a sunset. The backdrop is the city
		# itself, at night — the thing the whole campaign has been defending, and
		# the only scene where losing has an address.
		"look": {
			"space": Color(0.01, 0.01, 0.03),
			"ambient": Color(0.2, 0.07, 0.09),
			"sun": {"color": Color(1, 0.94, 0.92), "energy": 0.3},
			"fill": {"color": Color(1, 0.34, 0.32), "energy": 0.5},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/earth_city.png",
				# The lightest knock-back in the campaign, and barely shifted: a
				# night city is already dark and mostly black, so the usual push
				# would put the lights out. The small warm bias is the alert light
				# reaching the skyline.
				"tint": Color(0.86, 0.74, 0.76),
			},
			"bodies": [],
			# None: the photograph covers the whole frustum and brings its own.
			"stars": 0.0,
		},
		"wave": {
			"count": 26,
			"interval": 0.85,
			"speed": 11.0,
			"mode_weights": [0.25, 0.25, 0.25, 0.25],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
]


## Mars' armoured ore carrier, relative to the ordinary scout of the same scene.
## One dictionary rather than four exports on the variant scene, so the whole
## trade — slow and tough, but worth four kills — is retuned in one place.
##
## Note there is no leak penalty here: a carrier that escapes costs the same
## energy as any other alien. It is worth stopping for the score, not because
## missing it hurts more, and Mars is already the scene that adds weaving.
const ORE_CARRIER := {
	"hit_points": 3,
	"score": 400,
	"speed_scale": 0.55,
	"size": 1.7,
}

## Spawns at the head of a wave that are never carriers, so a scene opens on the
## enemy the player already knows how to shoot.
const ORE_CARRIER_LEAD_IN: int = 3


## Number of scenes in the campaign — the campaign length is the table's length.
static func count() -> int:
	return SCENES.size()


## The entry for a 1-based scene index, clamped to the table.
static func scene(index: int) -> Dictionary:
	return SCENES[clampi(index - 1, 0, SCENES.size() - 1)]


## Just the spawn table for a 1-based scene index.
static func wave(index: int) -> Dictionary:
	return scene(index)["wave"]


## Display name for the HUD's scene indicator ("ISS", "ดวงจันทร์", …).
static func scene_name(index: int) -> String:
	return scene(index)["name"]


## The scene's signature colour, for screens and backdrops to tint themselves.
static func accent(index: int) -> Color:
	return scene(index)["accent"]


## The battlefield's dressing for a 1-based scene index — see `look` above.
static func look(index: int) -> Dictionary:
	return scene(index)["look"]


## How many quiz variants a scene has to draw from.
static func quiz_count(index: int) -> int:
	return scene(index)["quiz"].size()


## One variant from a scene's pool: the fact card and the question about it.
##
## `variant` is clamped rather than trusted, for the same reason `scene()` clamps
## its index — it is carried in `GameState` across a scene change, and a pool of
## a different length would otherwise be an out-of-bounds crash on the briefing.
static func quiz(index: int, variant: int) -> Dictionary:
	var pool: Array = scene(index)["quiz"]
	return pool[clampi(variant, 0, pool.size() - 1)]


## A fresh variant for a scene, avoiding `previous` where the pool allows it.
##
## The avoidance is the point on a kiosk: the same child plays three runs in a
## row, and drawing them the fact they were shown five minutes ago wastes the
## one screen in the scene that is actually teaching something.
static func random_quiz_variant(index: int, previous: int = -1) -> int:
	var pool_size := quiz_count(index)
	if pool_size <= 1:
		return 0
	var picked := randi() % pool_size
	if picked == previous:
		# One step along rather than re-rolling: a re-roll can land on `previous`
		# again, and this keeps every other variant equally likely.
		picked = (picked + 1 + randi() % (pool_size - 1)) % pool_size
	return picked


## The order a scene's wave arrives in: one entry per spawn, true where an ore
## carrier flies instead of a scout.
##
## Built up front rather than rolled per spawn, because a scene has to end up
## with exactly the number of carriers its table asks for — a per-spawn chance
## would sometimes send none at all, and Mars' whole story is the carriers. They
## are spread one to a band so they arrive spaced out across the wave instead of
## bunching into a convoy, and never in the opening spawns.
static func spawn_plan(index: int) -> Array:
	var table := wave(index)
	var count: int = table["count"]
	var plan: Array = []
	plan.resize(count)
	plan.fill(false)

	var first := mini(ORE_CARRIER_LEAD_IN, count)
	var carriers: int = clampi(table["ore_carriers"], 0, count - first)
	if carriers <= 0:
		return plan

	var band := float(count - first) / float(carriers)
	for i in carriers:
		var start := first + int(i * band)
		var slot := start + randi() % maxi(1, int(band))
		plan[clampi(slot, first, count - 1)] = true
	return plan

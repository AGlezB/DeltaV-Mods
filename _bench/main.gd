extends Node

# The bench's entry point (run by bench.ps1): builds one run from the command line and writes its results.
#   --mode=run    the control scenario: the K225 on its course through the field for --minutes, with --pdw and its
#                 --tuning (key=value,key=value), --seed, --speed (m/s); writes <out>/<label>.csv (one row), <label>-chunks.csv and pictures
#   --mode=pdw    PDW tuning calibration: for each Tuning of --sweep (ONMWG or NDPT) and each test roid, breaks the roid
#                 in front of the stationary ship with its PDWs and records break times and the chunks' speeds
#                 (--part=<i> --parts=<n>: this process's share of the tests); writes <out>/<label>.csv
#   --mode=spot   prints the ring map's densest spot, or with --spot-kind=be the dense spot whose course of --course px
#                 crosses the most Be, or with --spot-kind=be-chaos the high-chaos spot whose course crosses the most Be,
#                 and its course's chaos (bench.ps1 caches them and passes --spot=<x>,<y> --spot-name=<name> to the runs,
#                 and for be-chaos --chaos=<value> --density-spot=<the densest>)
#   --hold=keep   the hold keeps what it takes (default: a body taken in leaves the simulation)
# Common: --game=<decompiled game folder> --out=<folder> --label=<name>; --candidate=<script> installs a candidate
# ranking over the game's drone-plant.gd first, with --params (key=value,key=value; Engine meta benchParams);
# --geologist=<talent>,<experience>; --mod-zip=<zip> --mod-name=<ModName> mounts a mod's zip, installs its Code.gd over
# the game's drone-plant.gd and turns its switch on, with its default settings.

const Scenes = preload("res://bench/scenes.gd")
const Field = preload("res://bench/field.gd")
const Scenario = preload("res://bench/scenario.gd")
const Geologist = preload("res://bench/geologist.gd")
const Recorder = preload("res://bench/recorder.gd")
const ShipScript = preload("res://bench/ship.gd")

const GAME_SCRIPTS = [
	"res://weapons/drone-plant.gd",
	"res://weapons/drones/DroneLaunchManager.gd",
	"res://asteroids/mineral.gd",
	"res://asteroids/asteroid.gd",
	"res://ships/modules/PDT.gd",
	"res://weapons/emp.gd",
	"res://weapons/massdriver.gd",
	"res://weapons/projectiles/projectile.gd",
	"res://weapons/projectiles/Explosion.gd",
	"res://ships/Front Bumper.gd",
]
const CORRIDOR_HALF_WIDTH = 15000.0 # px each side of the course where roids are placed
const BEHIND = 15000.0 # px behind the start
const AHEAD_MARGIN = 35000.0 # px past the end of the course
const CLEAR_START = 1500.0 # px around the start kept free of roids
const TEST_TIMEOUT = 120.0 # s
const IDLE_UNLIMITED = 1000000.0 # Tool.gd physicsIdleTarget: frames, so the idle queue always has time to drain
const TEST_SETTLE = 3.0 # s with no fracture before a calibration test ends

var args = {}
var scenes
var field
var built = {}
var geologist
var recorder
var frames = 0
var maxFrames = 0
var startMs = 0

func _ready():
	for a in OS.get_cmdline_args():
		if a.begins_with("--") and "=" in a:
			var kv = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	seed(1)
	# Tool.gd runs its idle queue on a wall-clock budget; with no limit it drains every frame, the same way in every
	# run (what it runs allocates, and which freed addresses get reused feeds the target bus's hashes).
	Tool.physicsIdleTarget = IDLE_UNLIMITED
	if args.get("candidate", "") != "":
		Engine.set_meta("benchParams", keyValues(args.get("params", "")))
		_install(args.candidate)
	if args.get("mod-zip", "") != "":
		if not ProjectSettings.load_resource_pack(args["mod-zip"], true):
			printerr("BENCH ERROR: cannot mount %s" % args["mod-zip"])
			get_tree().quit(100)
			return
		_install("res://%s/Code.gd" % args.get("mod-name", ""))
	scenes = Scenes.new(args.get("game", ""), GAME_SCRIPTS)
	startMs = OS.get_ticks_msec()
	match args.get("mode", "run"):
		"run":
			_run()
		"pdw":
			_pdw()
		"spot":
			_newField()
			var course = float(args.get("course", "60000"))
			match args.get("spot-kind", ""):
				"be":
					field.spot = field.beRichSpot(course)
				"be-chaos":
					field.spot = field.beChaosSpot(course)
			print("BENCH spot %d,%d chaos %.3f be %.3f" % [field.spot.x, field.spot.y, field.courseChaos(field.spot, course),
				field.courseShare(field.spot, course, "Be")])
			get_tree().quit(0)
		_:
			printerr("BENCH ERROR: unknown mode %s" % args.get("mode"))
			get_tree().quit(100)

# As the game's ModLoader installScriptExtension: a throwaway instance, then the candidate takes over the game's path.
func _install(path: String):
	var child = load(path)
	child.new()
	child.take_over_path(child.get_base_script().resource_path)

# The field at --spot (x,y on the ring map; bench.ps1 finds the densest once and passes it), or at the densest spot;
# with --density-spot, that spot's density instead, and with --chaos, that chaos instead of the field's default.
func _newField():
	field = Field.new()
	field.name = "Field"
	add_child(field)
	field.setup(scenes, args.get("game", ""), _spotArg("spot"))
	field.densitySpot = _spotArg("density-spot")
	if args.get("chaos", "") != "":
		field.chaos = float(args.chaos)

func _spotArg(key: String):
	if args.get(key, "") == "":
		return null
	var xy = args[key].split(",")
	return Vector2(float(xy[0]), float(xy[1]))

# --mod-zip: the mod's switch on, with its default settings, where the mod reads it: an entry under its id (from the
# zip's Mod.manifest) in the HUD's Geologist-tab config, which the bench's ship has no HUD to make.
func _switchModOn(ship):
	var manifest = ConfigFile.new()
	manifest.load("res://%s/Mod.manifest" % args.get("mod-name", ""))
	var config = {"minerals": CurrentGame.traceMinerals.duplicate(), "minValue": 0, "albedo": 0}
	config[manifest.get_value("mod_information", "id", "")] = {"enabled": true}
	ship.setConfig("hud.config", config)

func _tuning() -> Dictionary:
	return keyValues(args.get("tuning", ""))

# "a=1,b=x" -> {"a": 1.0, "b": "x"}: how --tuning and --params travel (Windows strips the quotes JSON would need).
static func keyValues(text: String) -> Dictionary:
	var out = {}
	for pair in text.split(",", false):
		var kv = pair.split("=", true, 1)
		if kv.size() == 2:
			out[kv[0].strip_edges()] = float(kv[1]) if kv[1].is_valid_float() else kv[1].strip_edges()
	return out

# --- the control scenario ---

func _run():
	_newField()
	var speed = float(args.get("speed", "5")) * 10.0
	var minutes = float(args.get("minutes", "10"))
	var seedValue = int(args.get("seed", "1"))
	built = Scenario.buildShip(scenes, field, ShipScript, args.get("pdw", "ONMWG"), _tuning(), true)
	var ship = built.ship
	ship.linear_velocity = Vector2(0, -speed)
	ship.removeOnCapture = args.get("hold", "remove") != "keep"
	if args.get("mod-zip", "") != "":
		_switchModOn(ship)
	var rng = RandomNumberGenerator.new()
	rng.seed = seedValue
	var length = speed * minutes * 60.0
	field.placeRoids(Rect2(-CORRIDOR_HALF_WIDTH, -length - AHEAD_MARGIN, CORRIDOR_HALF_WIDTH * 2, length + AHEAD_MARGIN + BEHIND), rng, CLEAR_START)
	geologist = Geologist.new()
	geologist.name = "Geologist"
	var geo = args.get("geologist", "0.5,0.5").split(",")
	geologist.talent = float(geo[0])
	geologist.experience = float(geo[1])
	add_child(geologist)
	geologist.setup(args.get("game", ""), scenes, field, ship, seedValue)
	recorder = Recorder.new()
	recorder.name = "Recorder"
	add_child(recorder)
	recorder.setup(ship, field, built.plants, built.turrets, geologist, args.get("out", ""), args.get("label", "run"))
	maxFrames = int(minutes * 60.0 * Engine.iterations_per_second)
	if args.get("tuning", "") != "" and ship.tuning.empty():
		printerr("BENCH ERROR: --tuning %s gave no Tuning" % args.tuning)
	print("BENCH run %s: spot %s, chaos %.3f, %d roids placed, rocks per cell %s, geologist %s, Tuning %s, params %s" % [
		args.get("label", ""), field.spot, field.chaos, field.pendingCount(), field.rocksPerCell(field.densityPixel()),
		args.get("geologist", "0.5,0.5"), to_json(ship.tuning), to_json(Engine.get_meta("benchParams") if Engine.has_meta("benchParams") else {})])

func _physics_process(_delta):
	if maxFrames <= 0:
		return
	frames += 1
	if args.get("trace", "") != "":
		_trace()
	if frames >= maxFrames:
		maxFrames = 0
		_finish()

# --trace: a checksum of every body in the field each frame (positions, velocities, spins), and of the global random
# state, to find the first frame where two runs that should be the same part ways.
func _trace():
	var sum = 0.0
	var n = 0
	for kid in field.get_children():
		if kid is RigidBody2D:
			n += 1
			sum += kid.position.x * 1.3 + kid.position.y * 1.7 + kid.linear_velocity.x * 2.9 + kid.linear_velocity.y * 3.1 + kid.angular_velocity * 5.3
	var r = randi()
	seed(r)
	print("TRACE %d %d %.6f %d" % [frames, n, sum, r])
	var from = int(args.get("trace-from", "-1"))
	if frames >= from and frames <= int(args.get("trace-to", str(from + 3))):
		var i = 0
		for kid in field.get_children():
			if kid is PhysicsBody2D:
				var kind = kid.get_script().resource_path.get_file() if kid.get_script() else kid.get_class()
				var v = kid.linear_velocity if "linear_velocity" in kid else Vector2()
				print("BODY %d %d %s %s %.4f,%.4f %.4f,%.4f" % [frames, i, kind, kid.name, kid.position.x, kid.position.y, v.x, v.y])
			i += 1

func _finish():
	var out = args.get("out", "")
	var label = args.get("label", "run")
	var row = recorder.row()
	var meta = {"spot": args.get("spot-name", ""), "pdw": args.get("pdw", ""), "seed": args.get("seed", ""), "speed_mps": args.get("speed", ""),
		"minutes": args.get("minutes", ""),
		"candidate": args.get("candidate", "").get_file() if args.get("mod-zip", "") == "" else args["mod-zip"].get_file(),
		"params": args.get("params", ""), "tuning": args.get("tuning", ""), "chaos": stepify(field.chaos, 0.001),
		"geologist": args.get("geologist", "0.5,0.5")}
	_writeCsv(out.plus_file(label + ".csv"), ["spot", "pdw", "seed", "speed_mps", "minutes", "candidate", "params", "tuning",
		"chaos", "geologist"] + recorder.header(), [meta, row])
	recorder.writeChunks(out.plus_file(label + "-chunks.csv"))
	recorder.drawRun(out.plus_file(label + "-run.png"))
	print("BENCH done %s in %.1f s wall: %s" % [label, (OS.get_ticks_msec() - startMs) / 1000.0, to_json(row)])
	get_tree().quit(0)

func _writeCsv(path: String, columns: Array, rows: Array):
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		printerr("BENCH ERROR: cannot write %s" % path)
		return
	f.store_line(PoolStringArray(columns).join(","))
	var values = []
	for c in columns:
		var v = ""
		for r in rows:
			if c in r:
				v = str(r[c])
		values.append("\"%s\"" % v.replace("\"", "'") if "," in v else v)
	f.store_line(PoolStringArray(values).join(","))
	f.close()

# --- PDW tuning calibration ---

func _pdw():
	_newField()
	var tests = _sweep(args.get("sweep", "ONMWG"))
	var parts = int(args.get("parts", "1"))
	var part = int(args.get("part", "0"))
	var mine = []
	for i in range(tests.size()):
		if i % parts == part:
			mine.append(tests[i])
	tests = mine
	var rows = []
	for test in tests:
		var r = yield(_pdwTest(test), "completed")
		rows.append(r)
		print("BENCH test %s" % to_json(r))
	var columns = ["pdw", "tuning", "path", "scale", "seed", "broken", "break_s", "cascade_s", "rocks", "chunks",
		"born_mean", "born_max", "after3_mean", "after3_max"]
	var out = File.new()
	out.open(args.get("out", "").plus_file(args.get("label", "pdw") + ".csv"), File.WRITE)
	out.store_line(PoolStringArray(columns).join(","))
	for r in rows:
		var values = []
		for c in columns:
			var v = str(r.get(c, ""))
			values.append("\"%s\"" % v.replace("\"", "'") if "," in v else v)
		out.store_line(PoolStringArray(values).join(","))
	out.close()
	print("BENCH done pdw in %.1f s wall" % ((OS.get_ticks_msec() - startMs) / 1000.0))
	get_tree().quit(0)

# Every Tuning of the PDW in its Tuning screen's steps (--steps thins them: every n-th value, the ends kept), the
# weights left at their defaults, against the first and last scene of every class (--classes) at the smallest and
# largest scale (--scales), for each --seeds. The Tuning entries and their ranges come from the turret itself
# (PDT.gd getTuneables).
func _sweep(pdw: String) -> Array:
	built = Scenario.buildShip(scenes, field, ShipScript, pdw, {}, false)
	var tuneables = built.turrets[0].getTuneables()
	_testPoint = _deepestPoint()
	print("BENCH test point %s" % _testPoint)
	for kid in field.get_children():
		field.remove_child(kid)
		kid.free()
	var steps = int(args.get("steps", "1"))
	var grid = [{}]
	for key in tuneables:
		var tune = tuneables[key]
		if tune.get("type", "") != "float" or key.begins_with("TUNE_WEIGHT_"):
			continue
		var values = []
		var n = int(round((tune.max - tune.min) / tune.step))
		for i in range(n + 1):
			if i % steps == 0 or i == n:
				values.append(stepify(tune.min + i * tune.step, 0.001))
		var next = []
		for g in grid:
			for v in values:
				var d = g.duplicate()
				d[key] = v
				next.append(d)
		grid = next
	var classes = []
	for c in args.get("classes", "0,1,2,3,4").split(","):
		classes.append(int(c))
	var scales = []
	for s in args.get("scales", "0.75,1.25").split(","):
		scales.append(float(s))
	var seeds = []
	for s in args.get("seeds", "1").split(","):
		seeds.append(int(s))
	var tests = []
	for g in grid:
		for oc in classes:
			var list = field.objectClass[oc]
			for path in [list[0], list[list.size() - 1]]:
				for s in scales:
					for sd in seeds:
						tests.append({"pdw": pdw, "tuning": g, "path": path, "oc": oc, "scale": s, "seed": sd})
	return tests

func _pdwTest(test: Dictionary):
	for kid in field.get_children():
		field.remove_child(kid)
		kid.queue_free()
	field._sources.clear()
	yield(get_tree(), "physics_frame")
	built = Scenario.buildShip(scenes, field, ShipScript, test.pdw, test.tuning, false)
	var ship = built.ship
	seed(int(test.seed))
	var rock = field.packed(test.path).instance()
	rock.position = _testPoint
	rock.setScale(float(test.scale))
	rock.set_meta("benchSeed", int(test.seed))
	field.add_child(rock)
	var oc = int(test.oc)
	rock.asteroidClass = oc
	rock.estimatedRadius = field.estimatedRadiusByClass[oc] * float(test.scale)
	rock.splitsTo = int(clamp(5 - oc, 1, 4))
	field._watch(rock)
	var chunks = {}
	var rocks = [rock]
	field.connect("chunkSpawned", self, "_testChunk", [chunks])
	field.connect("rockAdded", self, "_testRock", [rocks])
	var t = 0.0
	var breakAt = -1.0
	var lastFracture = 0.0
	while t < TEST_TIMEOUT:
		yield(get_tree(), "physics_frame")
		t += 1.0 / Engine.iterations_per_second
		_testT = t
		if breakAt < 0 and is_instance_valid(rock) and rock.fracturing:
			breakAt = t
		for rk in rocks:
			if is_instance_valid(rk) and rk.fracturing and not rk.has_meta("benchFractured"):
				rk.set_meta("benchFractured", t)
				lastFracture = t
		for c in chunks:
			var rec = chunks[c]
			if not is_instance_valid(c):
				continue
			var age = t - rec.born
			if rec.born_speed < 0 and age >= 2.0 / 60.0:
				rec.born_speed = c.linear_velocity.length() / 10.0
			if rec.after3 < 0 and age >= 3.0:
				rec.after3 = c.linear_velocity.length() / 10.0
		if breakAt >= 0 and t - lastFracture > TEST_SETTLE and _turretsIdle():
			break
	field.disconnect("chunkSpawned", self, "_testChunk")
	field.disconnect("rockAdded", self, "_testRock")
	var bornS = []
	var afterS = []
	for c in chunks:
		if chunks[c].born_speed >= 0:
			bornS.append(chunks[c].born_speed)
		if chunks[c].after3 >= 0:
			afterS.append(chunks[c].after3)
	return {"pdw": test.pdw, "tuning": to_json(test.tuning), "path": test.path.get_file(), "scale": test.scale,
		"seed": test.seed, "broken": 1 if breakAt >= 0 else 0, "break_s": stepify(breakAt, 0.01),
		"cascade_s": stepify(lastFracture, 0.01), "rocks": rocks.size(), "chunks": chunks.size(),
		"born_mean": stepify(_mean(bornS), 0.01), "born_max": stepify(_max(bornS), 0.01),
		"after3_mean": stepify(_mean(afterS), 0.01), "after3_max": stepify(_max(afterS), 0.01)}

func _turretsIdle() -> bool:
	for tr in built.turrets:
		if is_instance_valid(tr) and tr.queue.size() > 0:
			return false
	return true

func _testChunk(chunk, _parent, chunks):
	chunks[chunk] = {"born": 0.0, "born_speed": -1.0, "after3": -1.0}
	chunks[chunk].born = _testT

func _testRock(rock, rocks):
	rocks.append(rock)

var _testT = 0.0
var _testPoint = Vector2()

# Where a calibration roid goes: the point ahead of the ship deepest inside both PDWs' rock areas (the turrets'
# RockArea shapes, as built), or deepest inside one where the two areas don't meet (the ONMWG-650s of the K225, turned
# 60° outward, leave a strip ahead that neither sees).
func _deepestPoint() -> Vector2:
	var both = Vector2()
	var bothMargin = -INF
	var one = Vector2()
	var oneMargin = -INF
	for y in range(-500, -4001, -50):
		for x in range(0, 1501, 50):
			var p = Vector2(x, y)
			var low = INF
			var high = -INF
			for tr in built.turrets:
				var m = _inside(tr.get_node("RockArea/CollisionShape2D"), p)
				low = min(low, m)
				high = max(high, m)
			if low > bothMargin:
				bothMargin = low
				both = p
			if high > oneMargin:
				oneMargin = high
				one = p
	return both if bothMargin > 0 else one

# How far inside a shape a point is (negative: outside).
static func _inside(cs: CollisionShape2D, p: Vector2) -> float:
	var local = cs.global_transform.affine_inverse().xform(p)
	var s = cs.shape
	if s is CapsuleShape2D:
		var half = s.height / 2
		return s.radius - local.distance_to(Vector2(0, clamp(local.y, -half, half)))
	if s is CircleShape2D:
		return s.radius - local.length()
	return -INF

static func _mean(values: Array) -> float:
	if values.empty():
		return -1.0
	var s = 0.0
	for v in values:
		s += v
	return s / values.size()

static func _max(values: Array) -> float:
	var m = -1.0
	for v in values:
		m = max(m, v)
	return m

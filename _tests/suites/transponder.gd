extends "res://harness/suite.gd"

# AltTransponderCodes: new transponder codes say what carries them. The game's CurrentGame.gd (copied from the decompiled
# game to res://CurrentGame.gd, where the mod's Code.gd extends it) is instanced under the suite, with the game's
# Shipyard, Namer and Agenda autoloads as stubs; the CurrentGame autoload stays the stub, which hands
# menu/NewGamePlus.gd's transponder calls to this instance. The game's ship-ctrl.gd, story/body.gd,
# ships/modules/ClaimOwner.gd and the story claim beacons stand for the objects that get a suffix. The control checks
# (vanilla codes, nothing added) run on the game's own scripts.

const Models = preload("res://harness/transponder_models.gd") # the models the game's Shipyard builds
const SHIP = "res://ships/ship-ctrl.gd"
const BODY = "res://story/body.gd"
const DOCK = "res://ships/modules/ClaimOwner.gd"
const BODY_BEACON = "res://story/DeadTalkingBeacon.tscn"
const STORY_BEACONS = ["res://story/ClaimBeacon-1.gd", "res://story/ClaimBeaconForeign.gd"]
const SEEDS = [1, 2, 777, 12345, 987654321]

var ext # res://CurrentGame.gd: with the mod, its extension
var cg # an instance of it, in the tree

func run():
	var mod = hasMod("AltTransponderCodes")
	ext = load("res://CurrentGame.gd")
	var game = ext.get_base_script() if mod else ext
	cg = ext.new()
	cg.name = "TransponderGame"
	add_child(cg)
	# getActiveTransponders, which getTransponder calls, lists the player's ships.
	cg.state.ship = {"model": "TRTL", "transponder": "TK37-0001", "config": {}, "faction": "player"}
	cg.state.garage = []
	yield(get_tree(), "physics_frame")
	var prefixes = []
	for f in cg.transponderFormats:
		prefixes.append(f.split("-")[0] + "-")
	if not mod:
		var code = cg.getNewTransponder(12345)
		check("control: a code has one of the game's prefixes", code.substr(0, 4) in prefixes, code)
		var b = body("C212-3127")
		check("control: a frozen body's code is the group's plus its initials", b.getTransponder() == "C212-3127-AB", b.getTransponder())
		var d = dock(true, "{ship}-CC{nr}")
		check("control: a container dock keeps the game's code", d.transponderFormat == "{ship}-CC{nr}", d.transponderFormat)
		cleanUp()
		return
	check("res://CurrentGame.gd has the extension", game != null)
	checkCodes(prefixes)
	checkGetTransponder()
	yield(get_tree(), "physics_frame")
	checkReuse()
	checkPlayerShip()
	yield(checkNewGamePlus(), "completed")
	checkPods()
	yield(checkBodies(), "completed")
	yield(checkDocks(), "completed")
	checkStoryBeacons()
	cleanUp()

func cleanUp():
	CurrentGame.game = null
	cg.queue_free()

func codeOf(model) -> String:
	return ext.MODEL_CODES[model]

func serial(code: String) -> String:
	return code.substr(code.find("-"))

func checkCodes(prefixes):
	var length = ext.MODEL_CODES.values()[0].length()
	var missing = []
	for m in Models.MODELS:
		if not m in ext.MODEL_CODES:
			missing.append(m)
	check("every model the game's Shipyard builds has a code", missing.empty(), missing)
	var seen = {}
	var bad = []
	for m in ext.MODEL_CODES:
		var c = ext.MODEL_CODES[m]
		if c.length() != length or c in seen or "-" in c:
			bad.append(m)
		seen[c] = true
	check("the codes are all different, the same length, without a dash", bad.empty(), bad)
	var wrong = []
	var differs = []
	var bySeed = {}
	for s in SEEDS:
		for m in ["COTHON", "PROSPECTOR-VP", "TRTL"]:
			cg._atcModel = m
			var code = cg.getNewTransponder(s)
			var ser = code.substr(code.find("-") + 1)
			if not code.begins_with(codeOf(m) + "-") or not isSerial(ser) or code != cg.getNewTransponder(s):
				wrong.append([m, s, code])
			if s in bySeed and bySeed[s] != ser:
				differs.append([m, s, ser, bySeed[s]])
			bySeed[s] = ser
	cg._atcModel = null
	check("a model's code, a dash, then a serial of SERIAL_LENGTH characters of SERIAL_CHARS, the same for a seed", wrong.empty(), wrong)
	check("a seed gives the same serial whatever the model", differs.empty(), differs)
	cg._atcModel = "SPARROW-9"
	var unknown = cg.getNewTransponder(5)
	cg._atcModel = "ab"
	var short = cg.getNewTransponder(5)
	cg._atcModel = null
	var pad = ext.MODEL_CODE_PAD
	check("a model not in the table: its key's first letters and digits", unknown.begins_with("SPAR-"), unknown)
	check("a short key is padded to the codes' length", short.begins_with("AB" + pad + pad + "-") and serial(short).length() == serial(unknown).length(), short)
	var pool = {}
	for entry in cg.usedShipsPool:
		pool[codeOf(entry.name)] = true
	var notPool = []
	var drawn = {}
	var used = {}
	for s in range(1, 201):
		var code = cg.getNewTransponder(s)
		var prefix = code.split("-")[0]
		drawn[prefix] = true
		for c in code.substr(code.find("-") + 1):
			used[c] = true
		if not prefix in pool or code != cg.getNewTransponder(s) or code.substr(0, 4) in prefixes or not isSerial(code.substr(code.find("-") + 1)):
			notPool.append(code)
	check("no model given: a ship from the game's usedShipsPool, the same for a seed", notPool.empty() and not pool.empty(), notPool)
	check("no model given: different ships for different seeds", drawn.size() > 3, drawn.keys())
	var unused = []
	for c in ext.SERIAL_CHARS:
		if not c in used:
			unused.append(c)
	check("across the seeds, the serials use every character of SERIAL_CHARS", unused.empty(), unused)

# SERIAL_LENGTH characters, all of SERIAL_CHARS.
func isSerial(ser: String) -> bool:
	if ser.length() != ext.SERIAL_LENGTH:
		return false
	for c in ser:
		if not c in ext.SERIAL_CHARS:
			return false
	return true

var built # the config the first getTransponder coded
var builtCode

func checkGetTransponder():
	var kept = cg.getTransponder(true, {"model": "EIME", "faction": "civilian", "config": {}, "transponder": "XYZ-1"}, 9)
	check("a config's own code is kept", kept == "XYZ-1", kept)
	built = {"model": "EIME", "faction": "civilian", "config": {"fuel": {"capacity": 1.0}}}
	cg._atcModel = "EIME"
	var expected = cg.getNewTransponder(777)
	cg._atcModel = null
	builtCode = cg.getTransponder(true, built.duplicate(true), 777)
	check("a ship the Shipyard builds gets its model's code, with the seed's serial", builtCode == expected and builtCode.begins_with(codeOf("EIME") + "-"), [builtCode, expected])
	check("the code is stored in the save as the game stores it", builtCode in cg.state.transponders.lookup, cg.state.transponders.lookup.keys())
	check("after it, no model is left set", cg._atcModel == null, cg._atcModel)

func checkReuse():
	var again = cg.getTransponder(false, built.duplicate(true), 888)
	check("a ship met again (same build, not new) gets its stored code back", again == builtCode, again)
	var old = {"model": "COTHON", "faction": "civilian", "config": {"ammo": {"capacity": 2.0}}}
	var h = String(Shipyard.stripEmpheralsFromConfig(old).hash())
	cg.state.transponders.lookup["MRS-1234"] = h
	cg.state.transponders.hashes[h] = ["MRS-1234"]
	var reused = cg.getTransponder(false, old.duplicate(true), 5)
	check("a code stored before the mod is reused as it is", reused == "MRS-1234", reused)

func checkPlayerShip():
	var saved = cg.state.ship
	cg.state.ship = {"model": "COTHON-V", "config": {}, "faction": "player"}
	cg.createPlayerShip()
	check("new game: the player's ship gets its model's code", cg.state.ship.transponder.begins_with(codeOf("COTHON-V") + "-"), cg.state.ship.transponder)
	check("after it, no model is left set", cg._atcModel == null, cg._atcModel)
	var state = cg.state
	cg.state = cg.initialState.duplicate(true)
	cg.state.ship = {"model": "PROSPECTOR-VP", "config": {}, "faction": "player"}
	cg.validateState()
	check("a save whose ship has no code: it gets its model's code", cg.state.ship.transponder.begins_with(codeOf("PROSPECTOR-VP") + "-"), cg.state.ship.transponder)
	cg.state = cg.initialState.duplicate(true)
	cg.state.ship = {"model": "PROSPECTOR-VP", "config": {}, "faction": "player", "transponder": "MRS-1111"}
	cg.validateState()
	check("a save's ship keeps its code", cg.state.ship.transponder == "MRS-1111", cg.state.ship.transponder)
	check("after it, no model is left set", cg._atcModel == null, cg._atcModel)
	cg.state = state
	cg.state.ship = saved

# The game's New Game+ screen (menu/NewGamePlus.gd, with the mod's extension) on the node paths its script reads.
func checkNewGamePlus():
	CurrentGame.game = cg
	var script = load("res://menu/NewGamePlus.gd")
	check("menu/NewGamePlus.gd has the extension", script.get_base_script() != null)
	var popup = Popup.new()
	var parent = popup
	for n in ["CenterContainer", "PanelContainer", "MarginContainer", "VBoxContainer"]:
		var c = Container.new() if n != "VBoxContainer" else VBoxContainer.new()
		c.name = n
		parent.add_child(c)
		parent = c
	var seedBox = SpinBox.new()
	seedBox.name = "Seed"
	parent.add_child(seedBox)
	var row = HBoxContainer.new()
	row.name = "HBoxContainer3"
	parent.add_child(row)
	for n in ["ShipName", "Transponder"]:
		var label = Label.new()
		label.name = n
		row.add_child(label)
	popup.set_script(script)
	add_child(popup)
	yield(get_tree(), "idle_frame")
	var code = popup.transponderLabel.text
	check("New Game+: the screen shows a code of the new game's ship model", code.begins_with(codeOf(cg.initialShip.model) + "-"), code)
	check("New Game+: and the name the game makes from that code", popup.nameLabel.text == cg.generateShipNameFromTransponder(code), popup.nameLabel.text)
	check("after it, no model is left set", cg._atcModel == null, cg._atcModel)
	popup.queue_free()

# A node of the game's ship-ctrl.gd, out of the tree (its _ready never runs), as a lifepod, AI core or beacon.
func ship(special, code, filename = ""):
	var s = RigidBody2D.new()
	s.set_script(load(SHIP))
	s.specialName = special
	s.transponder = code
	s.filename = filename
	return s

func checkPods():
	cg.state.shipNames = {"PVUL-2222": "Rocinante"}
	var pod = ship("ODDITY_LIFEPOD", "C212-3127")
	cg._atcNodeAdded(pod)
	check("a ship's lifepod: the ship's code and the lifepod suffix", pod.transponder == "C212-3127" + ext.LIFEPOD_SUFFIX and pod.fullConfig.transponder == pod.transponder, pod.transponder)
	check("it keeps the name the game gives the ship's code", cg.state.shipNames.get(pod.transponder) == cg.generateShipNameFromTransponder("C212-3127"), cg.state.shipNames)
	check("the dead ship's code (forgotten by the game) isn't stored back", not "C212-3127" in cg.state.shipNames, cg.state.shipNames.keys())
	cg._atcNodeAdded(pod)
	check("added again, unchanged", pod.transponder == "C212-3127" + ext.LIFEPOD_SUFFIX, pod.transponder)
	var named = ship("ODDITY_LIFEPOD", "PVUL-2222")
	cg._atcNodeAdded(named)
	check("a ship's lifepod keeps the ship's stored name", cg.state.shipNames.get(named.transponder) == "Rocinante", cg.state.shipNames)
	var pool = {}
	for entry in cg.usedShipsPool:
		pool[codeOf(entry.name)] = true
	var lone = ship("ODDITY_LIFEPOD", "")
	cg._atcModel = "EIME"
	cg._atcNodeAdded(lone)
	var parts = lone.transponder.split("-")
	check("a lone lifepod: a ship's code from usedShipsPool, then the lifepod suffix", parts.size() == 3 and parts[0] in pool and lone.transponder.ends_with(ext.LIFEPOD_SUFFIX), lone.transponder)
	check("a model set around it is kept", cg._atcModel == "EIME", cg._atcModel)
	cg._atcModel = null
	var core = ship("ODDITY_AICORE", "ATLS-1234")
	cg._atcNodeAdded(core)
	check("the ATLAS's AI core: the drone's code and the AI core suffix", core.transponder == "ATLS-1234" + ext.AI_CORE_SUFFIX, core.transponder)
	var bare = ship("ODDITY_AICORE", "")
	cg._atcNodeAdded(bare)
	check("an AI core without a code keeps none", bare.transponder == "", bare.transponder)
	var plain = ship("", "TK37-1234")
	cg._atcNodeAdded(plain)
	check("another ship is untouched", plain.transponder == "TK37-1234", plain.transponder)
	var beacon = ship("", "C212-3127", BODY_BEACON)
	cg._atcNodeAdded(beacon)
	check("the frozen bodies' beacon: their code and the crew suffix", beacon.transponder == "C212-3127" + ext.CREW_SUFFIX, beacon.transponder)
	var habitat = ship("", "", BODY_BEACON)
	cg._atcNodeAdded(habitat)
	check("the destroyed habitat's beacon, without a code yet, is untouched", habitat.transponder == "", habitat.transponder)
	for s in [pod, named, lone, core, bare, plain, beacon, habitat]:
		s.free()

# A frozen body (the game's story/body.gd) added to the tree with `code`.
func body(code):
	var b = RigidBody2D.new()
	b.set_script(load(BODY))
	b.transponder = code
	add_child(b)
	return b

func checkBodies():
	var b = body("C212-3127")
	var habitat = body("SRA-01")
	var bare = body("")
	yield(get_tree(), "physics_frame")
	check("a frozen body: the group's code, the crew suffix, its initials", b.getTransponder() == "C212-3127" + ext.CREW_SUFFIX + "-AB", b.getTransponder())
	check("a body at the destroyed habitat: the habitat's code, the crew suffix, its initials", habitat.getTransponder() == "SRA-01" + ext.CREW_SUFFIX + "-AB", habitat.getTransponder())
	check("a body without a code: its initials only, as the game's", bare.getTransponder() == "AB", bare.getTransponder())
	remove_child(b)
	add_child(b)
	check("a body added again is unchanged", b.getTransponder() == "C212-3127" + ext.CREW_SUFFIX + "-AB", b.getTransponder())
	for n in [b, habitat, bare]:
		n.queue_free()

# A dock (the game's ClaimOwner.gd) with `format`, added under a ship (the game's ship-ctrl.gd, given its script once
# in the tree, so its _ready doesn't run) or under a frozen body, which isn't one.
var hosts = []

func dock(onShip, format):
	var host
	if onShip:
		host = RigidBody2D.new()
		add_child(host)
		host.set_script(load(SHIP))
	else:
		host = body("SRA-01")
	hosts.append(host)
	var d = Node2D.new()
	d.set_script(load(DOCK))
	d.transponderFormat = format
	host.add_child(d)
	return d

func checkDocks():
	for type in ext.DRONE_CODES:
		var d = dock(true, "{ship}-%s{nr}" % type)
		var expected = "{ship}-%s-{nr}" % ext.DRONE_CODES[type]
		check("a ship's %s dock: the mod's type, a dash, the number" % type, d.transponderFormat == expected and d.transponderFormat.format({"ship": "TK37-3127", "nr": 42}) == "TK37-3127-%s-42" % ext.DRONE_CODES[type], d.transponderFormat)
	var other = dock(true, "{ship}-XX{nr}")
	check("a dock with another format is untouched", other.transponderFormat == "{ship}-XX{nr}", other.transponderFormat)
	var habitat = dock(false, "{ship}-CC{nr}")
	check("a dock that isn't on a ship (the destroyed habitat's) is untouched", habitat.transponderFormat == "{ship}-CC{nr}", habitat.transponderFormat)
	yield(get_tree(), "physics_frame")
	for h in hosts:
		h.queue_free()

func checkStoryBeacons():
	for path in STORY_BEACONS:
		var n = Node.new()
		n.set_script(load(path))
		add_child(n)
		var expected = "%%s-%s-%%d" % ext.DRONE_CODES["CB"]
		check("%s: the claim beacon's type, a dash, the number" % path.get_file(), n.transponderFormat == expected and n.transponderFormat % ["TK37-3127", 42] == "TK37-3127-%s-42" % ext.DRONE_CODES["CB"], n.transponderFormat)
		n.queue_free()

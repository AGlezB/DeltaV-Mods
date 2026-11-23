extends "res://harness/suite.gd"

# LidarContactCallout: in a dive or a simulator, a crew member calls out each new row of the OMS Pilot tab (the ship's
# identifiedShips), and each object with no transponder and no row the LIDAR has seen, on the HUD's comms line and in
# the OMS's Comms log, once no new one has come for CALLOUT_SETTLE (or the first has waited CALLOUT_MAX_WAIT), with its
# bearing and distance: the Pilot tab's for a marked row, approximate ones otherwise, then Updated once marked. HUDs
# from harness/callout_hud.tscn (the game's Hud.gd, with a display of the game's Display-K37.gd, whose Dialog is the
# HUD's comms line, and the geology suite's OMS, whose Comms is the log; its dialogLineNode the game's
# comms/MessageLine.tscn) on harness/callout_ship.gd, among objects of the field (harness/callout_object.gd,
# callout_contact.gd); the crew is the CurrentGame stub's state.crew. The OMS is built on the ship's instance signal,
# as the game builds it, and the mod's timer is stopped once its set-up is checked, so the suite calls its ticks: time
# passes tick by tick, as the mod counts it. Expected texts are built with tr() from the mod's keys; its constants are
# read from the mod, so any value of them passes. The control checks run on the game's own Hud.gd.

const MOD = "LidarContactCallout"
const HUD_SCRIPT = "res://hud/Hud.gd"
const HUD_SCENE = "res://harness/callout_hud.tscn"
const SHIP = "res://harness/callout_ship.gd"
const LIDAR = "res://harness/callout_lidar.gd"
const OBJECT = "res://harness/callout_object.gd"
const CONTACT = "res://harness/callout_contact.gd"
const CONVERSATION = "res://comms/ConversationPlayer.gd"
const PILOT_FIGURES = "res://hud/components/ShipOnOMSBearingDistance.tscn"
const UIO_LABEL = "res://hud/components/ShipOnOMSLabel.tscn"
const UIO_SCRIPT = "res://hud/components/ShipOnOMSLabel.gd"
# The game's crew occupations (CurrentGame.gd occupations, and the passengers listed with the crew).
const ASTROGATOR = "CREW_OCCUPATION_ASTROGATOR"
const PILOT = "CREW_OCCUPATION_PILOT"
const MECHANIC = "CREW_OCCUPATION_MECHANIC"
const PASSENGER = "CREW_OCCUPATION_PASSENGER"
# The game's comms line (comms/MessageLine.tscn): its text, who it is from, and the speaker's face.
const MESSAGE = "H/Message"
const FROM = "H/MarginContainer/From"
const FACE = "H/MarginContainer/PanelContainer/Face"
const CONTROL_SECONDS = 20.0 # how long the control run waits for a callout that never comes
const DRAWS = 400 # approximate figures drawn for each experience
const REPORTS = 12 # reports made to see who speaks

var C = {} # the mod's constants (Code.gd's constant map)
var _fields = []
var _gameUio = "" # the game's UIO text, read from an instance of its label

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# The player's ship (harness/callout_ship.gd, its LIDAR a child) at `at`, in a field of its own (its parent).
func makeShip(zone = "rings", player = true, at = Vector2.ZERO):
	var field = Node2D.new()
	add_child(field)
	_fields.append(field)
	var ship = Node2D.new()
	ship.set_script(load(SHIP))
	ship.zone = zone
	ship.playerControlled = player
	ship.position = at
	var lidar = Node.new()
	lidar.set_script(load(LIDAR))
	ship.add_child(lidar)
	ship.lidar = lidar
	field.add_child(ship)
	return ship

# Its HUD, as the ship's scene holds it. Hud.gd's processing goes off at once: it would draw power and drive the
# displays, which neither the stub nor the suite has.
func makeHud(ship):
	var hud = load(HUD_SCENE).instance()
	ship.add_child(hud)
	hud.set_process(false)
	hud.set_physics_process(false)
	return hud

# The game builds the OMS and the display on the ship's instance signal (Hud.gd _ready connects it); the mod sets up
# once the frame is idle. In flight the display shows and the OMS doesn't (Hud.gd _process, off here).
func buildOms(ship, hud):
	ship.emit_signal("instance")
	yield(idle(), "completed")
	if hud.display != null:
		hud.display.visible = true

# A ship in a dive with its HUD set up and the mod's timer stopped, so the suite calls its ticks: [ship, hud].
func dive(at = Vector2.ZERO):
	var ship = makeShip("rings", true, at)
	var hud = makeHud(ship)
	yield(buildOms(ship, hud), "completed")
	if hud._calloutTimer != null:
		hud._calloutTimer.stop()
	return [ship, hud]

func endDive():
	for field in _fields:
		field.queue_free()
	_fields = []
	yield(idle(), "completed")

# An object of the field at `offset` from `ship` (world units, 10 a metre): with `code` a transponder
# (harness/callout_contact.gd; "" for a pirate, which broadcasts none), without one none at all (callout_object.gd);
# `price` a reward of its own (an oddity), `groups` the groups it is in.
func object(ship, offset, code = null, price = 0, groups = [], specialName = ""):
	var o = RigidBody2D.new()
	o.set_script(load(OBJECT if code == null else CONTACT))
	if code != null:
		o.transponder = code
	o.specialPrice = price
	o.specialName = specialName
	for g in groups:
		o.add_to_group(g)
	o.position = ship.position + offset
	ship.get_parent().add_child(o)
	return o

# A row of the Pilot tab for `o`, as the LIDAR or the astrogator's mark adds it (ship-ctrl.gd addIdentifiedShip).
func row(ship, o, code = "", marked = false):
	ship.addIdentifiedShip(o, code, "", marked)
	return o

# A crew member for CurrentGame.state.crew: in the dive crew unless `aboard` is false, on leave with `onLeave`.
func member(fullName, occupation, experience = 0.5, aboard = true, onLeave = false, gender = 0.3) -> Dictionary:
	var m = {"fullName": fullName, "occupation": occupation, "experience": experience, "talent": 0.5, "active": aboard, "details": [0, 0, gender]}
	if onLeave:
		m.leave = CurrentGame.getInGameTimestamp() + 24 * 3600
	return m

func hire(members):
	CurrentGame.state.crew = {}
	for m in members:
		CurrentGame.state.crew[m.fullName] = m

# A conversation of the game's (comms/ConversationPlayer.gd), for a broadcast's message.
func conversation(key):
	var c = load(CONVERSATION).new()
	c.name = key
	_fields.back().add_child(c)
	return c

# The lines under `parent` not being freed.
func live(parent) -> Array:
	var list = []
	for c in parent.get_children():
		if not c.is_queued_for_deletion():
			list.append(c)
	return list

func hudLines(hud) -> Array:
	return live(hud.dialogDisplay)

func logLines(hud) -> Array:
	return live(hud.inventory.dialogNode)

func text(line) -> String:
	return line.get_node(MESSAGE).text

func from(line) -> String:
	return line.get_node(FROM).text

# The mod's line, as the game shows a crew member's: "[Name, Occupation]" (comms/MessageLine.gd).
func fromOf(m) -> String:
	return "[%s, %s]" % [m.fullName, tr(m.occupation)]

func tick(hud, count = 1):
	for i in count:
		hud._calloutTick()

# How many ticks it takes from now for `seconds` to pass, as the mod counts them (its clock, by the tick).
func ticksFor(hud, seconds) -> int:
	var clock = hud._calloutClock
	var start = clock
	var count = 0
	while clock - start < seconds:
		clock += C._CALLOUT_TICK
		count += 1
	return count

# The lines the Comms log gained over `count` ticks (the HUD gets each too).
func said(hud, count) -> Array:
	var before = logLines(hud).size()
	tick(hud, count)
	var after = logLines(hud)
	return after.slice(before, after.size() - 1) if after.size() > before else []

# The lines said at the tick `seconds` have passed from now; null when one came a tick early.
func saidAfter(hud, seconds):
	var early = said(hud, ticksFor(hud, seconds) - 1)
	if not early.empty():
		return null
	return said(hud, 1)

# The one line of `lines` (said()), or null.
func one(lines):
	return lines[0] if lines is Array and lines.size() == 1 else null

# The callouts of a line: its text alone, or each item of its numbered list, in order (null for an item not in the
# list's form).
func callouts(line) -> Array:
	if line == null:
		return []
	if line.dialog != C._CALLOUT_LIST:
		return [text(line)]
	var list = tr(C._CALLOUT_LIST).split("{items}")
	var whole = text(line)
	if list.size() != 2 or not whole.begins_with(list[0]) or not whole.ends_with(list[1]):
		return [null]
	var items = []
	var n = 0
	for item in whole.substr(list[0].length(), whole.length() - list[0].length() - list[1].length()).split("\n"):
		n += 1
		var form = tr(C._CALLOUT_LIST_ITEM).format({"number": n}).split("{line}")
		if form.size() != 2 or not item.begins_with(form[0]) or not item.ends_with(form[1]):
			items.append(null)
		else:
			items.append(item.substr(form[0].length(), item.length() - form[0].length() - form[1].length()))
	return items

func identified(code) -> String:
	return tr(C._CALLOUT_IDENTIFIED).format({"transponder": code})

func uio() -> String:
	return tr(_gameUio)

# The Pilot tab's bearing and distance of `o` from `ship` (the game's hud/components/ShipOnOMSBearingDistance.tscn and
# its compute), as the mod writes them: the bearing in three digits from 000 to 359, the distance with
# CurrentGame.formatThousands.
func pilotFigures(ship, o) -> Dictionary:
	var shown = load(PILOT_FIGURES).instance()
	shown.setData(ship, o)
	var bearing = int(shown.get_node("BearingValue").text)
	var distance = int(shown.get_node("DistanceValue").text)
	shown.free()
	return {"bearing": "%03d" % posmod(bearing, 360), "distance": CurrentGame.formatThousands(distance)}

func contactText(status, identity, precision, f) -> String:
	return tr(C._CALLOUT_CONTACT).format({"status": tr(status), "identity": identity, "precision": precision, "bearing": f.bearing, "distance": f.distance})

# A callout with the Pilot tab's figures.
func exactText(ship, o, status, identity) -> String:
	return contactText(status, identity, "", pilotFigures(ship, o))

# An approximate callout at the centre of its circle: the Pilot tab's bearing, the distance rounded to
# CALLOUT_DISTANCE_STEP, at least one step.
func centreText(ship, o, status, identity) -> String:
	var metres = (o.global_position - ship.global_position).length() / 10.0
	var f = pilotFigures(ship, o)
	f.distance = CurrentGame.formatThousands(int(max(C.CALLOUT_DISTANCE_STEP, stepify(metres, C.CALLOUT_DISTANCE_STEP))))
	return contactText(status, identity, tr(C._CALLOUT_APPROXIMATE), f)

func escapeRegex(s: String) -> String:
	var out = ""
	for ch in s:
		out += ("\\" + ch) if ch in "\\.^$|?*+()[]{}" else ch
	return out

func number(s: String) -> int:
	var digits = ""
	for ch in s:
		if ch in "0123456789":
			digits += ch
	return int(digits)

# The figures of an approximate callout of `status` and `identity` ({"bearing", "distance"} as numbers), or {} when the
# rest of its text isn't that callout's.
func figuresOf(callout, status, identity) -> Dictionary:
	if callout == null:
		return {}
	var form = tr(C._CALLOUT_CONTACT).format({"status": tr(status), "identity": identity, "precision": tr(C._CALLOUT_APPROXIMATE)})
	var token = RegEx.new()
	token.compile("\\{(bearing|distance)\\}")
	var pattern = "^"
	var at = 0
	for m in token.search_all(form):
		pattern += escapeRegex(form.substr(at, m.get_start() - at)) + "(?<%s>[0-9]+(?:.[0-9]+)*)" % m.get_string(1)
		at = m.get_end()
	pattern += escapeRegex(form.substr(at)) + "$"
	var re = RegEx.new()
	re.compile(pattern)
	var found = re.search(callout)
	if found == null:
		return {}
	return {"bearing": number(found.get_string("bearing")), "distance": number(found.get_string("distance"))}

# Whether `bearing` and `distance` (as said) can be those of a point in the circle around `o` of radius its distance
# times CALLOUT_ERROR_RADIUS times (1 - experience), rounded as the mod rounds them: the bearing to a whole degree, the
# distance to a multiple of CALLOUT_DISTANCE_STEP, at least one step.
func withinCircle(ship, o, bearing, distance, experience) -> bool:
	var toward = o.global_position - ship.global_position
	var metres = toward.length() / 10.0
	var k = C.CALLOUT_ERROR_RADIUS * (1.0 - experience)
	var step = float(C.CALLOUT_DISTANCE_STEP)
	if not is_equal_approx(fmod(float(distance), step), 0.0) or distance < step:
		return false
	if distance > metres * (1.0 + k) + step / 2.0 + 0.01:
		return false
	if distance < metres * (1.0 - k) - step / 2.0 - 0.01 and distance != step:
		return false
	if k < 1.0:
		var off = abs(wrapf(bearing - rad2deg(Vector2(0, -1).angle_to(toward)), -180.0, 180.0))
		if off > rad2deg(asin(k)) + 0.5 + 0.01:
			return false
	return true

# Whether `callout` is `o`'s, of `status` and `identity`: with the Pilot tab's figures when `exact`, else approximate
# ones in the circle of `experience`.
func isCallout(callout, ship, o, status, identity, exact, experience = 0.0) -> bool:
	if not callout is String:
		return false
	if exact:
		return callout == exactText(ship, o, status, identity)
	var f = figuresOf(callout, status, identity)
	return not f.empty() and withinCircle(ship, o, f.bearing, f.distance, experience)

func childrenOf(node, type) -> Array:
	var list = []
	for c in node.get_children():
		if c.is_class(type) and not c.is_queued_for_deletion():
			list.append(c)
	return list

func connections(emitter, signalName, target, method) -> int:
	var count = 0
	for c in emitter.get_signal_connection_list(signalName):
		if c.target == target and c.method == method:
			count += 1
	return count

# The constants of the mod's Code.gd: the script at the game's Hud.gd path is the top of the chain of its extensions
# (take_over_path), whatever other mods extend it too; Code.gd can't be loaded again by its own path, since it would
# extend itself.
func modConstants() -> Dictionary:
	var script = load(HUD_SCRIPT)
	while script != null:
		var constants = script.get_script_constant_map()
		if constants.has("_CALLOUT_CONTACT"):
			return constants
		script = script.get_base_script()
	return {}

func run():
	if not hasMod(MOD):
		yield(control(), "completed")
		return
	C = modConstants()
	var label = load(UIO_LABEL).instance()
	_gameUio = label.placeholder
	label.free()
	texts()
	yield(setUp(), "completed")
	yield(timing(), "completed")
	yield(kinds(), "completed")
	yield(sighted(), "completed")
	yield(skipped(), "completed")
	yield(speakers(), "completed")
	yield(figures(), "completed")
	yield(holds(), "completed")
	yield(theLine(), "completed")

# The game's Hud.gd alone.
func control():
	hire([member("Ann Bell", ASTROGATOR)])
	var ship = makeShip()
	var hud = makeHud(ship)
	var children = hud.get_child_count()
	yield(buildOms(ship, hud), "completed")
	row(ship, object(ship, Vector2(500, -3000), "ABC-1"), "ABC-1")
	var pirate = object(ship, Vector2(-800, 2000), "", 0, ["ships"])
	ship.lidar.see(pirate)
	yield(frames(int(CONTROL_SECONDS * Engine.iterations_per_second)), "completed")
	check("control: the HUD gets nothing of its own (no timer, no conversation)", hud.get_child_count() == children, hud.get_children())
	check("control: in a dive, the game says nothing of a new row of the Pilot tab or an object the LIDAR has seen, on the HUD or in the Comms log", hudLines(hud).empty() and logLines(hud).empty())
	var sender = object(ship, Vector2(0, -900), "XYZ-9")
	CurrentGame.emit_signal("broadcast", sender, ship, conversation("DIALOG_TEST"), [])
	yield(frames(2), "completed")
	var shown = hudLines(hud)
	check("control: the game's own comms line to the ship shows on the HUD and in the Comms log, from its transponder", shown.size() == 1 and logLines(hud).size() == 1 and from(shown[0]) == "[XYZ-9]", [shown.size(), logLines(hud).size()])
	yield(endDive(), "completed")

# The texts (i18n/en.po), also in a language without them (Godot's fallback, en).
func texts():
	var keys = [C._CALLOUT_CONTACT, C._CALLOUT_IDENTIFIED, C._CALLOUT_APPROXIMATE, C._CALLOUT_LIST, C._CALLOUT_LIST_ITEM, C._CALLOUT_NEW, C._CALLOUT_UPDATED, C._CALLOUT_ANOMALOUS]
	var translated = true
	for key in keys:
		translated = translated and tr(key) != key
	check("the callouts' texts are translated", translated, keys)
	var locale = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	translated = true
	for key in keys:
		translated = translated and tr(key) != key
	TranslationServer.set_locale(locale)
	check("a language without them shows the English texts", translated)
	var parts = true
	for p in ["{status}", "{identity}", "{precision}", "{bearing}", "{distance}"]:
		parts = parts and p in tr(C._CALLOUT_CONTACT)
	parts = parts and "{transponder}" in tr(C._CALLOUT_IDENTIFIED) and "{items}" in tr(C._CALLOUT_LIST) and "{number}" in tr(C._CALLOUT_LIST_ITEM) and "{line}" in tr(C._CALLOUT_LIST_ITEM)
	check("each text holds the parts the mod fills in", parts)

func setUp():
	var ann = member("Ann Bell", ASTROGATOR)
	hire([ann])
	var ship = makeShip()
	var hud = makeHud(ship)
	ship.emit_signal("instance")
	var atOnce = hud._calloutOn
	yield(idle(), "completed")
	hud.display.visible = true
	check("in a dive (zone rings), set up once the frame is idle after the OMS is built", not atOnce and hud._calloutOn)
	var timer = hud._calloutTimer
	var timers = childrenOf(hud, "Timer")
	check("a timer of its own on the HUD, in physics time, every _CALLOUT_TICK, running, calling the tick", timers.size() == 1 and timers[0] == timer and timer.process_mode == Timer.TIMER_PROCESS_PHYSICS and is_equal_approx(timer.wait_time, C._CALLOUT_TICK) and not timer.is_stopped() and connections(timer, "timeout", hud, "_calloutTick") == 1)
	check("it follows the Pilot tab's rows and the game's comms lines", connections(ship, "identifiedShipsChanged", hud, "_calloutContactsChanged") == 1 and connections(CurrentGame, "broadcast", hud, "_calloutHeard") == 1)
	var conv = hud._calloutConversation
	check("its lines' conversation: the game's (comms/ConversationPlayer.gd), crew-spoken (agendaNPC), on the HUD", conv != null and conv.get_parent() == hud and conv.get_script().resource_path == CONVERSATION and conv.agendaNPC)
	ship.emit_signal("instance")
	hud.instance()
	yield(idle(), "completed")
	var conversations = 0
	for c in hud.get_children():
		if c.get_script() != null and c.get_script().resource_path == CONVERSATION:
			conversations += 1
	check("set up once, however often the OMS is built", childrenOf(hud, "Timer").size() == 1 and conversations == 1 and connections(ship, "identifiedShipsChanged", hud, "_calloutContactsChanged") == 1 and connections(CurrentGame, "broadcast", hud, "_calloutHeard") == 1)
	check("the UIO text is read from the Pilot tab's label (the placeholder of the game's ShipOnOMSLabel.tscn)", hud._calloutUio == _gameUio and _gameUio != "", [hud._calloutUio, _gameUio])
	# Another label scene at that path (take_over_path, as the mod loader puts a script at a game path): its
	# placeholder; a root without one, or an empty one: CALLOUT_UIO_FALLBACK. A resource that takes the path over keeps
	# it until it is freed, and the one it took it from keeps it too, out of the cache: the stand-ins are freed first,
	# then the game's scene, given another path, takes it back.
	var original = load(C._CALLOUT_UIO_SCENE)
	var standIns = []
	var reads = []
	for placeholder in ["TEST-UIO", null, ""]:
		var node = Label.new()
		if placeholder != null:
			node.set_script(load(UIO_SCRIPT))
			node.placeholder = placeholder
		standIns.append(PackedScene.new())
		standIns.back().pack(node)
		node.free()
		standIns.back().take_over_path(C._CALLOUT_UIO_SCENE)
		reads.append(hud._calloutReadUio())
	standIns.clear()
	original.take_over_path("")
	original.take_over_path(C._CALLOUT_UIO_SCENE)
	check("another label's placeholder is read as it is; a label without one, or with an empty one, gives CALLOUT_UIO_FALLBACK", reads == ["TEST-UIO", C.CALLOUT_UIO_FALLBACK, C.CALLOUT_UIO_FALLBACK], reads)
	check("the game's label scene is back", load(C._CALLOUT_UIO_SCENE) == original and hud._calloutReadUio() == _gameUio, [load(C._CALLOUT_UIO_SCENE), original, hud._calloutReadUio()])

	# In game time: the timer says a new row once it has waited CALLOUT_SETTLE.
	row(ship, object(ship, Vector2(1200, -5000), "RT-1"), "RT-1")
	var perSecond = Engine.iterations_per_second
	yield(frames(int((C.CALLOUT_SETTLE - 2 * C._CALLOUT_TICK) * perSecond)), "completed")
	var early = logLines(hud).size()
	yield(frames(int(4 * C._CALLOUT_TICK * perSecond)), "completed")
	check("in game time, a new row is said by the timer once it has waited CALLOUT_SETTLE (nothing two ticks before, said two ticks after)", early == 0 and logLines(hud).size() == 1 and hudLines(hud).size() == 1, [early, logLines(hud).size()])
	yield(endDive(), "completed")

	# Where it doesn't set up: another zone, none, or a ship that isn't the player's (the Tuning and Equipment
	# previews'); and where it does: the simulator's zone (the dive's is checked above).
	var cases = []
	for zone in ["", null, "enceladus"]:
		cases.append(["the zone %s" % ("null" if zone == null else "\"%s\"" % zone), makeShip(zone), false])
	cases.append(["a ship in the rings that isn't the player's (a preview's)", makeShip("rings", false), false])
	cases.append(["the simulator (zone sim)", makeShip("sim"), true])
	for c in cases:
		c.append(makeHud(c[1]))
		c[1].emit_signal("instance")
	yield(idle(), "completed")
	for c in cases:
		c[3].display.visible = true
		row(c[1], object(c[1], Vector2(700, -6000), "OFF-1"), "OFF-1")
	yield(frames(int((C.CALLOUT_MAX_WAIT + C.CALLOUT_SETTLE) * perSecond) + 30), "completed")
	for c in cases:
		var s = c[1]
		var h = c[3]
		if c[2]:
			check("set up in %s, and says a new row" % c[0], h._calloutOn and h._calloutTimer != null and logLines(h).size() == 1 and hudLines(h).size() == 1, logLines(h).size())
		else:
			check("not set up for %s: no timer or conversation, nothing followed, nothing said" % c[0], not h._calloutOn and h._calloutTimer == null and h._calloutConversation == null and connections(s, "identifiedShipsChanged", h, "_calloutContactsChanged") == 0 and connections(CurrentGame, "broadcast", h, "_calloutHeard") == 0 and hudLines(h).empty() and logLines(h).empty())
	yield(endDive(), "completed")

# When a row is said: after CALLOUT_SETTLE, once; several in one report; a trickle by CALLOUT_MAX_WAIT.
func timing():
	var ann = member("Ann Bell", ASTROGATOR, 0.5)
	hire([ann])
	var d = yield(dive(Vector2(-3000, 7000)), "completed")
	var ship = d[0]
	var hud = d[1]
	var maxWait = ticksFor(hud, C.CALLOUT_MAX_WAIT)
	var contact = row(ship, object(ship, Vector2(4300, -21000), "ABC-1"), "ABC-1")
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("a new row of the Pilot tab: nothing before CALLOUT_SETTLE, then one line in the Comms log and one on the HUD", line != null and hudLines(hud).size() == 1)
	check("one callout (the text of _CALLOUT_CONTACT): New, identified by its transponder, approximate, in the speaking astrogator's circle", line != null and line.dialog == C._CALLOUT_CONTACT and isCallout(text(line), ship, contact, C._CALLOUT_NEW, identified("ABC-1"), false, ann.experience), text(line) if line != null else "")
	var hudLine = hudLines(hud)[0] if not hudLines(hud).empty() else null
	check("the HUD's line says the same", line != null and hudLine != null and text(hudLine) == text(line))
	ship.emit_signal("identifiedShipsChanged")
	check("said once: nothing more while the row stays", said(hud, maxWait).empty())
	row(ship, contact, "ABC-1", true)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("once the row is marked: Updated after CALLOUT_SETTLE, with the Pilot tab's figures", line != null and text(line) == exactText(ship, contact, C._CALLOUT_UPDATED, identified("ABC-1")), text(line) if line != null else "")
	ship.emit_signal("identifiedShipsChanged")
	check("and only once", said(hud, maxWait).empty())

	var marked = row(ship, object(ship, Vector2(-9000, -2500), "DEF-2"), "DEF-2")
	var settle = ticksFor(hud, C.CALLOUT_SETTLE)
	tick(hud)
	row(ship, marked, "DEF-2", true)
	var lines = said(hud, settle - 1)
	check("a row marked before it is said: one New, with the Pilot tab's figures, at the time the row came", lines.size() == 1 and text(lines[0]) == exactText(ship, marked, C._CALLOUT_NEW, identified("DEF-2")), lines.size())
	check("and no Updated after", said(hud, maxWait).empty())
	var mark = row(ship, object(ship, Vector2(2500, 2500)), "", true)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("the astrogator's mark on an object with no transponder (a marked row without one): New, the game's UIO, exact", line != null and text(line) == exactText(ship, mark, C._CALLOUT_NEW, uio()), text(line) if line != null else "")

	# Several together
	var a = row(ship, object(ship, Vector2(6000, 0), "LST-1"), "LST-1", true)
	var b = row(ship, object(ship, Vector2(0, 9000), "LST-2"), "LST-2")
	var core = row(ship, object(ship, Vector2(-7000, -7000), "AIC-3", 5000), "AIC-3") # an AI core: an oddity in no markable group
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	var items = callouts(line)
	check("several new rows together: one line, a numbered list (_CALLOUT_LIST of _CALLOUT_LIST_ITEMs), in the order they came", line != null and line.dialog == C._CALLOUT_LIST and items.size() == 3 and not items.has(null), items)
	check("each its own callout: the marked row exact, the other approximate, the oddity in none of CALLOUT_MARKABLE_GROUPS Anomalous", items.size() == 3 and isCallout(items[0], ship, a, C._CALLOUT_NEW, identified("LST-1"), true) and isCallout(items[1], ship, b, C._CALLOUT_NEW, identified("LST-2"), false, ann.experience) and isCallout(items[2], ship, core, C._CALLOUT_ANOMALOUS, identified("AIC-3"), false, ann.experience), items)
	row(ship, b, "LST-2", true)
	row(ship, core, "AIC-3", true)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("both marked later: the New one gets an Updated, the Anomalous one never", line != null and line.dialog == C._CALLOUT_CONTACT and text(line) == exactText(ship, b, C._CALLOUT_UPDATED, identified("LST-2")), text(line) if line != null else "")
	var grouped = []
	var n = 0
	for g in C.CALLOUT_MARKABLE_GROUPS:
		n += 1
		grouped.append(row(ship, object(ship, Vector2(1000 * n, -8000), "GRP-%d" % n, 5000, [g]), "GRP-%d" % n))
	for ignored in C.CALLOUT_IGNORED_ODDITIES:
		n += 1
		grouped.append(row(ship, object(ship, Vector2(1000 * n, -8000), "GRP-%d" % n, 5000, [], ignored), "GRP-%d" % n))
	items = callouts(one(saidAfter(hud, C.CALLOUT_SETTLE)))
	var asNew = items.size() == grouped.size()
	for i in min(items.size(), grouped.size()):
		asNew = asNew and isCallout(items[i], ship, grouped[i], C._CALLOUT_NEW, identified("GRP-%d" % (i + 1)), false, ann.experience)
	check("an oddity in one of CALLOUT_MARKABLE_GROUPS, or one of CALLOUT_IGNORED_ODDITIES, is New", asNew, items)
	yield(endDive(), "completed")

	# A steady trickle: a new row each time the newest is a tick short of settling.
	d = yield(dive(), "completed")
	ship = d[0]
	hud = d[1]
	var gap = ticksFor(hud, C.CALLOUT_SETTLE) - 1
	maxWait = ticksFor(hud, C.CALLOUT_MAX_WAIT)
	if gap < 1 or maxWait <= gap:
		note("CALLOUT_SETTLE and CALLOUT_MAX_WAIT leave no room for a trickle: not checked")
	else:
		var added = []
		var ticks = 0
		line = null
		while ticks < maxWait + gap and line == null:
			if ticks % gap == 0:
				added.append(row(ship, object(ship, Vector2(500 * (added.size() + 1), 4000), "TRK-%d" % added.size()), "TRK-%d" % added.size()))
			line = one(said(hud, 1))
			ticks += 1
		check("a steady trickle (a new row every CALLOUT_SETTLE less a tick) is said once the first has waited CALLOUT_MAX_WAIT, all in one report", line != null and ticks == maxWait and callouts(line).size() == added.size() and added.size() > 1, [ticks, maxWait, added.size()])
	yield(endDive(), "completed")

# Statuses and identities across crews: Anomalous with and without an astrogator aboard.
func kinds():
	var ann = member("Ann Bell", ASTROGATOR, 0.5)
	var eve = member("Eve Ford", PILOT, 0.5)
	hire([eve])
	var d = yield(dive(), "completed")
	var ship = d[0]
	var hud = d[1]
	var body = object(ship, Vector2(-6000, -6000), null, 3000) # an oddity with no transponder and no row (frozen bodies)
	ship.lidar.see(body)
	var core = row(ship, object(ship, Vector2(7000, -3000), "AIC-7", 4000), "AIC-7")
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("with no astrogator aboard, an oddity in no markable group with a row is said as New (approximate, the largest circle), and one with no row isn't sighted", line != null and line.dialog == C._CALLOUT_CONTACT and isCallout(text(line), ship, core, C._CALLOUT_NEW, identified("AIC-7"), false, 0.0), text(line) if line != null else "")
	check("by the pilot", line != null and from(line) == fromOf(eve))
	hire([eve, ann])
	tick(hud)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("so once an astrogator is aboard, it is, and the astrogator calls it Anomalous, with the game's UIO", line != null and isCallout(text(line), ship, body, C._CALLOUT_ANOMALOUS, uio(), false, ann.experience) and from(line) == fromOf(ann), text(line) if line != null else "")
	check("once only", said(hud, ticksFor(hud, C.CALLOUT_MAX_WAIT)).empty())
	var later = object(ship, Vector2(3000, 6000), null, 3000)
	ship.lidar.see(later)
	tick(hud)
	ann.active = false
	var other = row(ship, object(ship, Vector2(-2000, 5000), "OTH-1"), "OTH-1")
	var lines = said(hud, ticksFor(hud, C.CALLOUT_SETTLE))
	check("one sighted while an astrogator was aboard but said by someone else is dropped; the rest of the report is said", lines.size() == 1 and lines[0].dialog == C._CALLOUT_CONTACT and isCallout(text(lines[0]), ship, other, C._CALLOUT_NEW, identified("OTH-1"), false, 0.0), text(lines[0]) if lines.size() == 1 else lines.size())
	check("and the list is cleared", hud._calloutWaiting.empty())
	yield(endDive(), "completed")

# Objects with no row: once each, when the LIDAR has seen them; never what is gone.
func sighted():
	var ann = member("Ann Bell", ASTROGATOR, 0.5)
	hire([ann])
	var d = yield(dive(Vector2(5000, 5000)), "completed")
	var ship = d[0]
	var hud = d[1]
	var maxWait = ticksFor(hud, C.CALLOUT_MAX_WAIT)
	var pirate = object(ship, Vector2(-5000, 3000), "", 0, ["ships"]) # a ship broadcasting no transponder
	var bare = object(ship, Vector2(4000, 3000), null, 0, ["ships"]) # one with no getTransponder at all
	check("a ship with no transponder and no row the LIDAR hasn't seen: nothing", said(hud, maxWait).empty())
	ship.lidar.see(pirate)
	tick(hud)
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("once the LIDAR has seen it (LIDAR.gd hasSeen): New, the game's UIO, approximate, after CALLOUT_SETTLE", line != null and isCallout(text(line), ship, pirate, C._CALLOUT_NEW, uio(), false, ann.experience), text(line) if line != null else "")
	check("once only", said(hud, maxWait).empty())
	row(ship, pirate, "", true)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("given a marked row later (the astrogator's mark): Updated, exact", line != null and text(line) == exactText(ship, pirate, C._CALLOUT_UPDATED, uio()), text(line) if line != null else "")
	ship.lidar.see(bare)
	tick(hud)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("a ship without getTransponder: the same", line != null and isCallout(text(line), ship, bare, C._CALLOUT_NEW, uio(), false, ann.experience))

	var body = object(ship, Vector2(8000, 1000), null, 3000)
	var unnamed = object(ship, Vector2(-8000, 1000), "", 3000) # an oddity whose getTransponder gives none
	var chunk = object(ship, Vector2(0, 8000))
	var bullets = []
	for ignored in C.CALLOUT_IGNORED_ODDITIES:
		bullets.append(object(ship, Vector2(100 * bullets.size(), -8000), null, 10, [], ignored))
	var coded = object(ship, Vector2(2000, 8000), "TRN-1", 0, ["ships"]) # its row comes from the LIDAR
	var queued = object(ship, Vector2(-2000, 8000), "", 0, ["ships"])
	var held = object(ship, Vector2(-3000, 8000), "", 0, ["ships"])
	ship.temporaryCargo.append(held)
	var inHold = object(ship, Vector2(-4000, 8000), null, 3000)
	inHold.inCargoHold = true
	var dead = object(ship, Vector2(-5000, 8000), "", 0, ["ships"])
	dead.dead = true
	for o in [body, unnamed, chunk, coded, queued, held, inHold, dead] + bullets:
		ship.lidar.see(o)
	queued.queue_free()
	tick(hud)
	var items = callouts(one(saidAfter(hud, C.CALLOUT_SETTLE)))
	check("seen together: only the oddities with no transponder in no markable group, Anomalous, the game's UIO, approximate, in one report", items.size() == 2 and isCallout(items[0], ship, body, C._CALLOUT_ANOMALOUS, uio(), false, ann.experience) and isCallout(items[1], ship, unnamed, C._CALLOUT_ANOMALOUS, uio(), false, ann.experience), items)
	check("nothing for a chunk, a bullet (CALLOUT_IGNORED_ODDITIES), a ship with a transponder and no row yet, or something gone (being freed, held by the arm, in a hold, dead)", items.size() == 2)

	var early = object(ship, Vector2(6000, -1000), "", 0, ["ships"])
	ship.lidar.see(early)
	tick(hud)
	row(ship, early, "", true)
	line = one(said(hud, ticksFor(hud, C.CALLOUT_SETTLE)))
	check("sighted, then given a row before it is said: said once, as its row stands (marked: exact)", line != null and text(line) == exactText(ship, early, C._CALLOUT_NEW, uio()), text(line) if line != null else "")
	check("and not again", said(hud, maxWait).empty())
	var lost = object(ship, Vector2(6000, -2000), "", 0, ["ships"])
	ship.lidar.see(lost)
	tick(hud)
	row(ship, lost)
	ship.removeIdentifiedShip(lost)
	check("sighted, given a row, and the row gone before it is said: dropped", said(hud, maxWait).empty())
	yield(endDive(), "completed")

# Rows never said: the ship's own drones, what the arm holds, rows gone before they are said.
func skipped():
	hire([member("Ann Bell", ASTROGATOR, 0.5)])
	var d = yield(dive(), "completed")
	var ship = d[0]
	var hud = d[1]
	var experience = 0.5
	row(ship, object(ship, Vector2(2000, 2000), ship.transponder + "-D1"), ship.transponder + "-D1")
	var held = object(ship, Vector2(300, -900), "HLD-1")
	ship.temporaryCargo.append(held)
	row(ship, held, "HLD-1")
	var lookalike = row(ship, object(ship, Vector2(-2000, 2000), ship.transponder + "2"), ship.transponder + "2")
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("the ship's own drones (its transponder and a dash) and what the arm holds aren't said; a transponder that only starts like the ship's is", line != null and line.dialog == C._CALLOUT_CONTACT and isCallout(text(line), ship, lookalike, C._CALLOUT_NEW, identified(lookalike.transponder), false, experience), text(line) if line != null else "")
	var gone = row(ship, object(ship, Vector2(5000, -5000), "GON-1"), "GON-1")
	var stays = row(ship, object(ship, Vector2(-5000, -5000), "STY-1"), "STY-1")
	tick(hud)
	ship.removeIdentifiedShip(gone)
	line = one(said(hud, ticksFor(hud, C.CALLOUT_SETTLE)))
	check("a row gone from the Pilot tab before it is said is dropped, the others said", line != null and line.dialog == C._CALLOUT_CONTACT and isCallout(text(line), ship, stays, C._CALLOUT_NEW, identified("STY-1"), false, experience), text(line) if line != null else "")
	row(ship, gone, "GON-1")
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("found again later: New", line != null and isCallout(text(line), ship, gone, C._CALLOUT_NEW, identified("GON-1"), false, experience))
	ship.removeIdentifiedShip(gone)
	row(ship, gone, "GON-1", true)
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("said, gone and found again: New again (marked this time: exact)", line != null and text(line) == exactText(ship, gone, C._CALLOUT_NEW, identified("GON-1")), text(line) if line != null else "")
	row(ship, object(ship, Vector2(4000, 4000), "AWY-1"), "AWY-1")
	ship.zone = ""
	var away = said(hud, ticksFor(hud, C.CALLOUT_MAX_WAIT) + 1)
	ship.zone = "rings"
	var back = said(hud, 1)
	row(ship, object(ship, Vector2(4000, -4000), "AWY-2"), "AWY-2")
	ship.playerControlled = false
	var notPlayer = said(hud, ticksFor(hud, C.CALLOUT_MAX_WAIT) + 1)
	ship.playerControlled = true
	var player = said(hud, 1)
	check("nothing while the ship is out of the zones, or isn't the player's; said at the next tick once it is again", away.empty() and back.size() == 1 and notPlayer.empty() and player.size() == 1, [away.size(), back.size(), notPlayer.size(), player.size()])
	yield(endDive(), "completed")

# Who calls out: an astrogator aboard, at random among several; with none, anyone aboard with a job, at random; never a
# passenger, a member not in the dive crew or on leave; with nobody, nothing.
func reportsBy(ship, hud, count) -> Array:
	var froms = []
	for i in count:
		row(ship, object(ship, Vector2(-1500 + 300 * i, -6000), "SPK-%d" % i), "SPK-%d" % i)
		var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
		froms.append(from(line) if line != null else null)
	return froms

func speakers():
	var ann = member("Ann Bell", ASTROGATOR, 0.5, true, false, 0.2)
	var cy = member("Cy Dunn", ASTROGATOR, 0.5, true, false, 0.7)
	var eve = member("Eve Ford", PILOT, 0.5)
	var gus = member("Gus Hale", MECHANIC, 0.5)
	var ida = member("Ida Jones", PASSENGER, 0.5)
	hire([eve, ann, gus])
	var d = yield(dive(), "completed")
	var ship = d[0]
	var hud = d[1]
	var froms = reportsBy(ship, hud, REPORTS)
	check("an astrogator aboard speaks, with others aboard", froms.count(fromOf(ann)) == REPORTS, froms)
	hire([eve, ann, cy, ida])
	froms = reportsBy(ship, hud, REPORTS)
	check("one of the astrogators aboard, at random: each speaks, nobody else", froms.count(fromOf(ann)) + froms.count(fromOf(cy)) == REPORTS and froms.count(fromOf(ann)) > 0 and froms.count(fromOf(cy)) > 0, froms)
	hire([eve, gus, ida])
	froms = reportsBy(ship, hud, REPORTS)
	check("with no astrogator, anyone aboard with a job, at random: each speaks, never the passenger", froms.count(fromOf(eve)) + froms.count(fromOf(gus)) == REPORTS and froms.count(fromOf(eve)) > 0 and froms.count(fromOf(gus)) > 0, froms)
	hire([member("Ann Bell", ASTROGATOR, 0.5, false), member("Cy Dunn", ASTROGATOR, 0.5, true, true), eve])
	froms = reportsBy(ship, hud, 4)
	check("an astrogator not in the dive crew or on leave never speaks", froms.count(fromOf(eve)) == 4, froms)
	for crew in [[ida, member("Gus Hale", MECHANIC, 0.5, false), member("Eve Ford", PILOT, 0.5, true, true)], []]:
		hire(crew)
		row(ship, object(ship, Vector2(3000, 3000), "NOB-%d" % crew.size()), "NOB-%d" % crew.size())
		var lines = said(hud, ticksFor(hud, C.CALLOUT_SETTLE))
		var cleared = hud._calloutWaiting.empty()
		hire([eve])
		check("nobody aboard to speak (%s): nothing said, and the list cleared (nothing later either)" % ("only a passenger, someone not in the dive crew and someone on leave" if not crew.empty() else "no crew"), lines.empty() and cleared and said(hud, ticksFor(hud, C.CALLOUT_MAX_WAIT)).empty())
	yield(endDive(), "completed")

# The figures: the Pilot tab's for a marked row, approximate ones in the circle of the speaking astrogator's experience.
func figures():
	var ann = member("Ann Bell", ASTROGATOR, 1.0)
	hire([ann])
	var d = yield(dive(Vector2(-12000, 34000)), "completed")
	var ship = d[0]
	var hud = d[1]
	var target = object(ship, Vector2(31000, -12000), "FIG-1")
	var centre = pilotFigures(ship, target)
	var metres = (target.global_position - ship.global_position).length() / 10.0
	centre.distance = CurrentGame.formatThousands(int(max(C.CALLOUT_DISTANCE_STEP, stepify(metres, C.CALLOUT_DISTANCE_STEP))))
	for experience in [0.0, 0.5]:
		var inside = true
		var spread = false
		for i in DRAWS:
			var v = hud._calloutValues({"object": target}, C._CALLOUT_NEW, null, experience)
			inside = inside and v.precision == tr(C._CALLOUT_APPROXIMATE) and v.identity == uio() and withinCircle(ship, target, number(v.bearing), number(v.distance), experience)
			spread = spread or v.bearing != centre.bearing or v.distance != centre.distance
		check("approximate figures (%d draws, experience %s): in the circle of CALLOUT_ERROR_RADIUS x (1 - experience) of the distance around the contact, the distance a multiple of CALLOUT_DISTANCE_STEP" % [DRAWS, experience], inside)
		if C.CALLOUT_ERROR_RADIUS > 0:
			check("and spread over it (experience %s)" % experience, spread)
	var v = hud._calloutValues({"object": target}, C._CALLOUT_NEW, null, 1.0)
	check("at experience 1, the contact's own figures: the Pilot tab's bearing, the distance rounded to CALLOUT_DISTANCE_STEP", v.bearing == centre.bearing and v.distance == centre.distance, [v, centre])
	var near = object(ship, Vector2(30, 0))
	v = hud._calloutValues({"object": near}, C._CALLOUT_NEW, null, 1.0)
	check("a contact nearer than half a step: one step", v.distance == CurrentGame.formatThousands(int(C.CALLOUT_DISTANCE_STEP)), v)
	var exact = true
	var offsets = [Vector2(0, -5000), Vector2(5000, 0), Vector2(0, 5000), Vector2(-5000, 0), Vector2(-30, -5000), Vector2(12345, 67890), Vector2(-77, 41)]
	for offset in offsets:
		var o = object(ship, offset, "EXA-1")
		var shown = pilotFigures(ship, o)
		for experience in [0.0, 1.0]:
			v = hud._calloutValues({"object": o}, C._CALLOUT_NEW, ["EXA-1", "", o, true, 1], experience)
			exact = exact and v.bearing == shown.bearing and v.distance == shown.distance and v.precision == "" and v.identity == identified("EXA-1")
	check("a marked row's figures are the Pilot tab's (ShipOnOMSBearingDistance.gd compute), with no precision text, whatever the experience, all around the ship", exact)
	# The speaker's experience: an astrogator's counts (clamped), anyone else's is 0.
	var placed = []
	for i in 6:
		placed.append(row(ship, object(ship, Vector2(20000 * cos(i), 20000 * sin(i)), "SPR-%d" % i), "SPR-%d" % i))
	var items = callouts(one(saidAfter(hud, C.CALLOUT_SETTLE)))
	var centred = items.size() == placed.size()
	for i in min(items.size(), placed.size()):
		centred = centred and items[i] == centreText(ship, placed[i], C._CALLOUT_NEW, identified("SPR-%d" % i))
	check("said by an astrogator of experience 1: approximate, at the centre", centred, items)
	ann.experience = 1.5
	var single = row(ship, object(ship, Vector2(-15000, 2000), "SPR-X"), "SPR-X")
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	check("an experience above 1 counts as 1", line != null and text(line) == centreText(ship, single, C._CALLOUT_NEW, identified("SPR-X")), text(line) if line != null else "")
	hire([member("Eve Ford", PILOT, 1.0)])
	placed = []
	for i in 6:
		placed.append(row(ship, object(ship, Vector2(25000 * cos(i), 25000 * sin(i)), "PLT-%d" % i), "PLT-%d" % i))
	items = callouts(one(saidAfter(hud, C.CALLOUT_SETTLE)))
	var widest = items.size() == placed.size()
	centred = items.size() == placed.size()
	for i in min(items.size(), placed.size()):
		widest = widest and isCallout(items[i], ship, placed[i], C._CALLOUT_NEW, identified("PLT-%d" % i), false, 0.0)
		centred = centred and items[i] == centreText(ship, placed[i], C._CALLOUT_NEW, identified("PLT-%d" % i))
	check("said by a pilot of experience 1: the largest circle (experience 0)%s" % (", not at the centre" if C.CALLOUT_ERROR_RADIUS > 0 else ""), widest and (not centred or C.CALLOUT_ERROR_RADIUS <= 0), items)
	yield(endDive(), "completed")

# The holds: a cutscene, a conversation, a comms line to the ship.
func holds():
	var ann = member("Ann Bell", ASTROGATOR, 0.5)
	hire([ann])
	var d = yield(dive(), "completed")
	var ship = d[0]
	var hud = d[1]
	var settle = ticksFor(hud, C.CALLOUT_SETTLE)
	var maxWait = ticksFor(hud, C.CALLOUT_MAX_WAIT)
	var sender = object(ship, Vector2(0, -4000), "SND-1")
	row(ship, object(ship, Vector2(3000, 0), "HLD-A"), "HLD-A")
	ship.cutscene = true
	var held = said(hud, settle + maxWait)
	ship.cutscene = false
	var released = said(hud, 1)
	check("held during a cutscene, said at the next tick after it", held.empty() and released.size() == 1, [held.size(), released.size()])
	row(ship, object(ship, Vector2(-3000, 0), "HLD-B"), "HLD-B")
	ship.talkingWith = sender
	held = said(hud, settle + maxWait)
	ship.talkingWith = null
	released = said(hud, 1)
	check("held while the ship talks with another (talkingWith), said at the next tick after", held.empty() and released.size() == 1, [held.size(), released.size()])

	row(ship, object(ship, Vector2(0, 3000), "HLD-C"), "HLD-C")
	tick(hud, settle - 1)
	var msg = conversation("DIALOG_TEST")
	CurrentGame.emit_signal("broadcast", sender, ship, msg, [])
	var after = ticksFor(hud, C.CALLOUT_AFTER_COMMS)
	yield(frames(2), "completed") # the game adds its line in physics (Hud.gd gotMessage, Tool.deferCallInPhysics)
	var gameLine = hudLines(hud)[0] if hudLines(hud).size() == 1 else null
	var gameLog = logLines(hud).back()
	var shown = gameLine != null and gameLine.dialogConversation == msg and gameLog.dialogConversation == msg
	held = said(hud, max(1, after) - 1)
	released = said(hud, 1)
	check("held for CALLOUT_AFTER_COMMS after the game's comms line to the ship, said at the tick it has passed", shown and held.empty() and released.size() == 1, [shown, held.size(), released.size()])
	check("the game's line on the HUD freed, the HUD showing the callout; the Comms log keeping it", gameLine != null and gameLine.is_queued_for_deletion() and hudLines(hud).size() == 1 and hudLines(hud)[0].dialogConversation == hud._calloutConversation and not gameLog.is_queued_for_deletion())
	var others = makeShip("rings", false)
	row(ship, object(ship, Vector2(0, -3000), "HLD-D"), "HLD-D")
	tick(hud)
	CurrentGame.emit_signal("broadcast", sender, others, msg, [])
	CurrentGame.emit_signal("broadcast", sender, ship, null, [])
	yield(frames(2), "completed")
	var lines = said(hud, settle - 1)
	check("not held by a comms line to another ship, nor by a broadcast to the ship with no message (the game clearing its line)", lines.size() == 1, lines.size())
	yield(endDive(), "completed")

# The line itself: as hud/Hud.gd gotMessage adds the game's, on the HUD and in the Comms log.
func theLine():
	var ann = member("Ann Bell", ASTROGATOR, 0.5, true, false, 0.2)
	hire([ann])
	var d = yield(dive(), "completed")
	var ship = d[0]
	var hud = d[1]
	var older = logLines(hud).size()
	row(ship, object(ship, Vector2(1000, -9000), "LIN-1"), "LIN-1")
	var line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	var onHud = hudLines(hud)
	var hudLine = onHud[0] if onHud.size() == 1 else null
	check("one line on the HUD, one more in the Comms log", line != null and hudLine != null and logLines(hud).size() == older + 1)
	if line == null or hudLine == null:
		yield(endDive(), "completed")
		return
	check("the game's comms line (comms/MessageLine.tscn, the HUD's dialogLineNode), with the same text", hudLine.filename == hud.dialogLineNode.resource_path and line.filename == hud.dialogLineNode.resource_path and text(hudLine) == text(line))
	# A line shown in the tree plays its animation once the engine tells it it is visible, a frame later.
	yield(idle(), "completed")
	check("the HUD's fades (playing the game's incoming-fade), the Comms log's doesn't and waits stale for the OMS to show", hudLine.fading and hudLine.get_node("Player").current_animation == "incoming-fade" and not line.fading and line.stale and not line.get_node("Player").is_playing(), [hudLine.fading, hudLine.get_node("Player").current_animation, line.fading, line.stale, line.get_node("Player").current_animation])
	var conv = hud._calloutConversation
	check("both from the ship to itself, through the mod's conversation, whose member is the speaker", hudLine.origin == ship and hudLine.target == ship and line.origin == ship and hudLine.dialogConversation == conv and line.dialogConversation == conv and conv.cachedAgendaMember == ann)
	check("the speaker's name and occupation, as the game shows a crew member's: [Name, Occupation]", from(hudLine) == fromOf(ann) and from(line) == fromOf(ann), [from(hudLine), from(line)])
	var face = hudLine.get_node(FACE)
	var logFace = line.get_node(FACE)
	check("and their face (comms/MessageLine.gd _ready: name, gender, the crew's colour)", face.fullName == ann.fullName and face.gender == ann.details[2] and face.visible and face.modulate == hudLine.crewTalkingColor and logFace.fullName == ann.fullName and logFace.modulate == line.crewTalkingColor)
	# With the OMS open (the display hidden): the HUD's line waits stale, and hides itself once the HUD shows again.
	hud.display.visible = false
	hud.inventory.visible = true
	row(ship, object(ship, Vector2(-1000, -9000), "LIN-2"), "LIN-2")
	line = one(saidAfter(hud, C.CALLOUT_SETTLE))
	hudLine = hudLines(hud)[0] if hudLines(hud).size() == 1 else null
	yield(idle(), "completed")
	check("with the OMS open, the Comms log's line plays the game's incoming, and the HUD's waits stale", line != null and hudLine != null and line.get_node("Player").current_animation == "incoming" and hudLine.stale and not hudLine.get_node("Player").is_playing(), [line.get_node("Player").current_animation if line != null else "", hudLine.stale if hudLine != null else "", hudLine.get_node("Player").current_animation if hudLine != null else ""])
	hud.inventory.visible = false
	hud.display.visible = true
	yield(idle(), "completed")
	check("and once the HUD shows again, that line hides itself, as the game's stale lines do", hudLine != null and not hudLine.visible)
	yield(endDive(), "completed")

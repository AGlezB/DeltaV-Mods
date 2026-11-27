extends "res://hud/Hud.gd"

# LidarContactCallout: in a dive or a simulator, a crew member calls out on the comms line each new contact of the OMS Pilot tab, and
# each object with no transponder the LIDAR sees that the Pilot tab doesn't list, with its bearing and distance.
#
# - The Pilot tab's rows are the ship's identifiedShips, [transponder, shipName, object, marked, flags] by
#   hash(object) (ships/ship-ctrl.gd addIdentifiedShip, removeIdentifiedShip, which emit identifiedShipsChanged). The
#   LIDAR adds a row for each object with a transponder it hits (hud/LIDAR.gd _physics_process); the astrogator's
#   mark makes a row marked, also for an object with no transponder (hud/ShipMark.gd scanTarget). The Pilot tab shows
#   bearing and distance only for a marked row (hud/ShipList.gd redraw).
# - Who watches the LIDAR: when a report is due, one of the astrogators aboard, at random, or with none, anyone aboard
#   with a job (not a passenger), at random.
# - A marked row's callout gives the Pilot tab's figures; any other gives approximate ones, those of a random point in a
#   circle around the contact that shrinks with the speaking astrogator's experience (the largest when no astrogator
#   speaks), and gets an Updated callout with the exact ones once its row is marked.
# - An object with no transponder and no row is called out once per object per dive, when the LIDAR has seen it
#   (LIDAR.gd hasSeen, as hud/AutopilotOverlay.gd astrogatorTacticalMarkers asks).
# - An oddity the astrogator can't mark is Anomalous: called out once, with approximate figures. Only an astrogator
#   can tell one apart from the chunks around it: with no astrogator aboard, one with no row isn't called out, and one
#   in the Pilot tab (the AI core, with its transponder) is called out as New.
# - A contact first found within CALLOUT_MIN_RANGE of the ship, by its exact distance, isn't called out (a ship the arm
#   lets go of, something out of the hold): not while its row stands, or, with no row, for the rest of the dive.
# - The callouts wait until no new one has come for CALLOUT_SETTLE seconds, then go in one comms line: one alone, or
#   several as a numbered list. The line is the game's (comms/MessageLine.tscn), added as hud/Hud.gd gotMessage adds
#   one, with the speaker's face and "[Name, Occupation]" from a crew-spoken Conversation (comms/MessageLine.gd
#   _ready, agendaNPC).
#
# Stacking: instance falls through to the parent with `.instance()`; new members start with `_callout` or `CALLOUT_`.

# Seconds with no new callout before the waiting ones are said, so a group of contacts found together comes in one
# report.
const CALLOUT_SETTLE = 3.0
# The longest the first waiting callout waits, in seconds, so a steady trickle of contacts can't hold the report back
# for good.
const CALLOUT_MAX_WAIT = 10.0
# Seconds to wait after the game's last comms line to the ship, so a callout doesn't replace a line still being read
# (the HUD shows one comms line at a time).
const CALLOUT_AFTER_COMMS = 8.0
# Oddities (CurrentGame.isOddity: a reward of their own) never called out, by specialName: bullets
# (weapons/projectiles/projectile.gd).
const CALLOUT_IGNORED_ODDITIES = ["ODDITY_BULLET"]
# The groups whose objects the astrogator marks (hud/AutopilotOverlay.gd astrogatorTacticalMarkers names them inline).
# An oddity in none of them is Anomalous.
const CALLOUT_MARKABLE_GROUPS = ["ships", "tactical", "stations"]
# Approximate figures are those of a random point in a circle around the contact, whose radius is this share of the
# contact's distance × (1 − the speaking astrogator's experience; 0 when no astrogator speaks). As a share of the
# distance, the bearing's error stays the same angle at any distance, and the circle never reaches the ship.
const CALLOUT_ERROR_RADIUS = 0.2
# An approximate distance is rounded to this many metres.
const CALLOUT_DISTANCE_STEP = 100
# Contacts first found nearer than this, in metres from the ship's centre (a ship the arm lets go of, something out of
# the hold), aren't called out: the crew can see them.
const CALLOUT_MIN_RANGE = 200
# What the Pilot tab shows for a contact with no transponder, if its label can't be read.
const CALLOUT_UIO_FALLBACK = "UIO"

const _CALLOUT_TICK = 0.25 # seconds between two checks of the waiting callouts
const _CALLOUT_UNITS_PER_METRE = 10.0 # the game shows 10 world units as 1 m
# The ship zones the callouts work in: a dive (Game.gd _respawn_ship) and a simulator (the station's,
# enceladus/Simulator/SimulationLayer.gd startSimulation).
const _CALLOUT_ZONES = ["rings", "sim"]
const _CALLOUT_ASTROGATOR = "CREW_OCCUPATION_ASTROGATOR"
const _CALLOUT_PASSENGER = "CREW_OCCUPATION_PASSENGER" # listed with the crew, but never on the bridge
# The Pilot tab's label for a transponder, whose placeholder (its text for none) is the UIO text.
const _CALLOUT_UIO_SCENE = "res://hud/components/ShipOnOMSLabel.tscn"
const _CALLOUT_UIO_PROPERTY = "placeholder"
const _CALLOUT_CONTACT = "LIDARCONTACTCALLOUT_CONTACT"
const _CALLOUT_IDENTIFIED = "LIDARCONTACTCALLOUT_IDENTIFIED"
const _CALLOUT_APPROXIMATE = "LIDARCONTACTCALLOUT_APPROXIMATE"
const _CALLOUT_LIST = "LIDARCONTACTCALLOUT_LIST"
const _CALLOUT_LIST_ITEM = "LIDARCONTACTCALLOUT_LIST_ITEM"
# Each status's text.
const _CALLOUT_NEW = "LIDARCONTACTCALLOUT_NEW"
const _CALLOUT_UPDATED = "LIDARCONTACTCALLOUT_UPDATED"
const _CALLOUT_ANOMALOUS = "LIDARCONTACTCALLOUT_ANOMALOUS"

var _calloutOn = false # set up: the player's ship, in a dive or a simulator
var _calloutTimer = null
var _calloutConversation = null # the crew-spoken Conversation every callout line is given
var _calloutUio = CALLOUT_UIO_FALLBACK
var _calloutClock = 0.0 # seconds of game time since the set-up
var _calloutLastComms = -CALLOUT_AFTER_COMMS # when the game's last comms line to the ship came
var _calloutWaiting = [] # the callouts to say, in the order they came: {key, object, status, fromRow, added}
var _calloutWaitingKeys = {} # the same, by key
var _calloutRows = {} # the keys of the Pilot tab's rows, as last seen
var _calloutApprox = {} # keys said with approximate figures, waiting for their row to be marked
var _calloutSighted = {} # keys of the objects with no transponder and no row already added this dive

# The game builds the OMS here (the HUD's `Inventory` placeholder of hud/OMS.tscn), for the player's ship and for the
# Tuning and Upgrades previews. Set up once the frame is idle: the HUD's _ready can call this.
func instance():
	.instance()
	call_deferred("_calloutSetup")

# Only on the player's ship in a dive or a simulator: the zone is set before the ship's HUD is built (Game.gd
# _respawn_ship, SimulationLayer.gd startSimulation); the previews' ships aren't player-controlled.
func _calloutSetup():
	if _calloutOn or ship == null or not is_instance_valid(ship):
		return
	if not _calloutInZone() or not ship.isPlayerControlled():
		return
	_calloutOn = true
	_calloutUio = _calloutReadUio()
	_calloutConversation = load("res://comms/ConversationPlayer.gd").new()
	_calloutConversation.name = "LidarContactCallout"
	_calloutConversation.agendaNPC = true
	add_child(_calloutConversation)
	_calloutTimer = Timer.new()
	_calloutTimer.process_mode = Timer.TIMER_PROCESS_PHYSICS
	_calloutTimer.wait_time = _CALLOUT_TICK
	add_child(_calloutTimer)
	_calloutTimer.connect("timeout", self, "_calloutTick")
	_calloutTimer.start()
	ship.connect("identifiedShipsChanged", self, "_calloutContactsChanged")
	CurrentGame.connect("broadcast", self, "_calloutHeard")
	_calloutContactsChanged()

func _calloutInZone() -> bool:
	return ship.get("zone") in _CALLOUT_ZONES

# The Pilot tab's text for a contact with no transponder, read from its label's scene without instancing it
# (ShipOnOMSLabel.gd set_text shows the placeholder for an empty transponder).
func _calloutReadUio() -> String:
	var scene = load(_CALLOUT_UIO_SCENE)
	if scene is PackedScene:
		var state = scene.get_state()
		for i in range(state.get_node_property_count(0)):
			if state.get_node_property_name(0, i) == _CALLOUT_UIO_PROPERTY:
				var value = state.get_node_property_value(0, i)
				if value is String and value != "":
					return value
	return CALLOUT_UIO_FALLBACK

# The game's comms lines to the ship (hud/Hud.gd gotMessage shows those with a message), emitted with four arguments.
func _calloutHeard(from = null, to = null, msg = null, replies = null):
	if to == ship and msg != null:
		_calloutLastComms = _calloutClock

# The Pilot tab's rows compared with those seen before.
func _calloutContactsChanged():
	if not is_instance_valid(ship):
		return
	var rows = ship.identifiedShips
	for key in rows:
		var row = rows[key]
		var object = row[2]
		if not _calloutRows.has(key):
			_calloutRows[key] = true
			if not is_instance_valid(object) or ship.temporaryCargo.has(object) or _calloutIsOwn(row[0]):
				continue
			if _calloutWaitingKeys.has(key):
				# Seen before it had a row, and not said yet: said as its row stands when the time comes.
				_calloutWaitingKeys[key].fromRow = true
			elif _calloutApprox.has(key):
				# Said before it had a row: updated once marked (below).
				pass
			elif not _calloutTooClose(object):
				_calloutAdd(key, object, _CALLOUT_ANOMALOUS if _calloutIsAnomalous(object) else _CALLOUT_NEW, true)
		if _calloutApprox.has(key) and row[3] and not _calloutWaitingKeys.has(key):
			_calloutApprox.erase(key)
			_calloutAdd(key, object, _CALLOUT_UPDATED, true)
	for key in _calloutRows.keys():
		if not rows.has(key):
			# Gone from the Pilot tab: found again later, it is new again.
			_calloutRows.erase(key)
			_calloutApprox.erase(key)
			if _calloutWaitingKeys.has(key) and _calloutWaitingKeys[key].fromRow:
				_calloutRemove(key)

func _calloutAdd(key, object, status, fromRow):
	var entry = {"key": key, "object": object, "status": status, "fromRow": fromRow, "added": _calloutClock}
	_calloutWaiting.append(entry)
	_calloutWaitingKeys[key] = entry

func _calloutRemove(key):
	_calloutWaiting.erase(_calloutWaitingKeys[key])
	_calloutWaitingKeys.erase(key)

# The ship's own drones carry the ship's transponder and a dash (ships/modules/ClaimOwner.gd).
func _calloutIsOwn(transponder) -> bool:
	var own = ship.transponder
	return own != "" and transponder != "" and transponder.begins_with(own + "-")

func _calloutIsOddity(object) -> bool:
	return CurrentGame.isOddity(object) and not (object.get("specialName") in CALLOUT_IGNORED_ODDITIES)

func _calloutIsAnomalous(object) -> bool:
	if not _calloutIsOddity(object):
		return false
	for group in CALLOUT_MARKABLE_GROUPS:
		if object.is_in_group(group):
			return false
	return true

# By the exact distance, whatever the astrogator's experience: the error only ever applies to what is said.
func _calloutTooClose(object) -> bool:
	return object.global_position.distance_to(ship.global_position) / _CALLOUT_UNITS_PER_METRE < CALLOUT_MIN_RANGE

func _calloutHasNoTransponder(object) -> bool:
	return not object.has_method("getTransponder") or object.getTransponder() == ""

func _calloutIsGone(object) -> bool:
	return not is_instance_valid(object) or object.is_queued_for_deletion() or ship.temporaryCargo.has(object) \
			or object.get("inCargoHold") or object.get("dead")

# Objects with no transponder and no row that the LIDAR has seen: oddities and ships (pirates), each once per dive. An
# anomalous one only while an astrogator is aboard: to anyone else it is one more chunk.
func _calloutScan():
	var lidar = ship.lidar
	if not is_instance_valid(lidar) or not lidar.has_method("hasSeen"):
		return
	var astrogatorAboard = CurrentGame.getCrewNumberWithRole(_CALLOUT_ASTROGATOR) > 0
	var rows = ship.identifiedShips
	for object in ship.get_parent().get_children():
		if object == ship:
			continue
		var key = hash(object)
		if _calloutSighted.has(key) or rows.has(key):
			continue
		if not (_calloutIsOddity(object) or object.is_in_group("ships")) or not _calloutHasNoTransponder(object):
			continue
		if _calloutIsGone(object) or not lidar.hasSeen(object):
			continue
		var anomalous = _calloutIsAnomalous(object)
		if anomalous and not astrogatorAboard:
			continue
		_calloutSighted[key] = true
		if _calloutTooClose(object):
			continue
		_calloutAdd(key, object, _CALLOUT_ANOMALOUS if anomalous else _CALLOUT_NEW, false)

func _calloutTick():
	_calloutClock += _CALLOUT_TICK
	if not is_instance_valid(ship) or not ship.isPlayerControlled() or not _calloutInZone():
		return
	_calloutScan()
	if _calloutWaiting.empty():
		return
	var newest = _calloutClock - _calloutWaiting.back().added
	var oldest = _calloutClock - _calloutWaiting.front().added
	if newest < CALLOUT_SETTLE and oldest < CALLOUT_MAX_WAIT:
		return
	if ship.cutscene or ship.talkingWith != null or _calloutClock - _calloutLastComms < CALLOUT_AFTER_COMMS:
		return
	if dialogDisplay == null or not is_instance_valid(inventory) or not ("dialogNode" in inventory):
		return
	_calloutSpeak()

# Who watches the LIDAR when a report is due: the ship goes on alert and a stand-by crew member answers, one of the
# astrogators aboard at random, or with none, anyone aboard with a job at random (CurrentGame.isCrewMemberActive:
# hired, not left at the station, not on leave). Null with nobody.
func _calloutSpeaker():
	var astrogators = []
	var others = []
	var crew = CurrentGame.getCrew()
	for memberName in crew:
		var member = crew[memberName]
		if not CurrentGame.isCrewMemberActive(member):
			continue
		var occupation = member.get("occupation", "")
		if occupation == _CALLOUT_ASTROGATOR:
			astrogators.append(member)
		elif occupation != "" and occupation != _CALLOUT_PASSENGER:
			others.append(member)
	var pool = astrogators if not astrogators.empty() else others
	if pool.empty():
		return null
	return pool[randi() % pool.size()]

func _calloutSpeak():
	var rows = ship.identifiedShips
	var member = _calloutSpeaker()
	var astrogator = member != null and member.get("occupation") == _CALLOUT_ASTROGATOR
	var said = [] # [entry, status] for each callout said
	for entry in _calloutWaiting:
		if _calloutIsGone(entry.object) or (entry.fromRow and not rows.has(entry.key)):
			continue
		var status = entry.status
		# Only an astrogator tells an anomalous object from a chunk; anyone else sees only what the Pilot tab lists.
		if status == _CALLOUT_ANOMALOUS and not astrogator:
			if not rows.has(entry.key):
				continue
			status = _CALLOUT_NEW
		said.append([entry, status])
	_calloutWaiting = []
	_calloutWaitingKeys = {}
	if member == null or said.empty():
		return
	var experience = clamp(float(member.get("experience", 0.0)), 0.0, 1.0) if astrogator else 0.0
	var values = []
	for pair in said:
		var entry = pair[0]
		var status = pair[1]
		var row = rows.get(entry.key)
		if status == _CALLOUT_NEW and not (row != null and row[3]):
			# Said with approximate figures: updated once its row is marked (_calloutContactsChanged).
			_calloutApprox[entry.key] = true
		values.append(_calloutValues(entry, status, row, experience))
	_calloutSay(values, member)

# What fills the callout's text for one entry. A marked row gives the Pilot tab's figures
# (hud/components/ShipOnOMSBearingDistance.gd compute: metres rounded up; bearing from the screen's up, clockwise);
# anything else, approximate ones: those of a random point spread evenly over a circle around the contact (the square
# root keeps the points from crowding its centre).
func _calloutValues(entry, status, row, experience) -> Dictionary:
	var object = entry.object
	var transponder = row[0] if row != null else ""
	var marked = row != null and row[3]
	var toward = object.global_position - ship.global_position
	if not marked:
		var radius = toward.length() * CALLOUT_ERROR_RADIUS * (1.0 - experience)
		toward += Vector2(radius * sqrt(randf()), 0).rotated(randf() * TAU)
	var distance = toward.length() / _CALLOUT_UNITS_PER_METRE
	var bearing = rad2deg(Vector2(0, -1).angle_to(toward))
	if marked:
		distance = ceil(distance)
	else:
		distance = max(CALLOUT_DISTANCE_STEP, stepify(distance, CALLOUT_DISTANCE_STEP))
	return {
		"status": tr(status),
		"identity": tr(_CALLOUT_IDENTIFIED).format({"transponder": transponder}) if transponder != "" else tr(_calloutUio),
		"precision": "" if marked else tr(_CALLOUT_APPROXIMATE),
		"bearing": "%03d" % posmod(int(round(bearing)), 360),
		"distance": CurrentGame.formatThousands(int(distance)),
	}

# One comms line, as hud/Hud.gd gotMessage adds the game's: on the HUD, replacing the line there, and in the OMS's
# Comms log. Not through the game's broadcast signal, which would cancel the reply buttons of a conversation
# (comms/PlayerReply.gd _heardBroadcast).
func _calloutSay(values, member):
	var dialog = _CALLOUT_CONTACT
	var dict = values[0]
	if values.size() > 1:
		var items = []
		var contact = tr(_CALLOUT_CONTACT)
		var item = tr(_CALLOUT_LIST_ITEM)
		for i in range(values.size()):
			items.append(item.format({"number": i + 1, "line": contact.format(values[i])}))
		dialog = _CALLOUT_LIST
		dict = {"items": PoolStringArray(items).join("\n")}
	_calloutConversation.cachedAgendaMember = member
	for c in dialogDisplay.get_children():
		c.queue_free()
	_calloutAddLine(dialogDisplay, true, dialog, dict)
	_calloutAddLine(inventory.dialogNode, false, dialog, dict)

# The line's _ready fills its dict from the game (Tool.getTranslationDictionary) and the face and name from the
# Conversation's member; the callout's values go in after it, before its first draw shows the text.
func _calloutAddLine(parent, fading, dialog, dict):
	var line = dialogLineNode.instance()
	line.origin = ship
	line.target = ship
	line.dialog = dialog
	line.dialogConversation = _calloutConversation
	line.fading = fading
	line.stale = not parent.is_visible_in_tree()
	parent.add_child(line)
	for key in dict:
		line.dict[key] = dict[key]
	line.translate()

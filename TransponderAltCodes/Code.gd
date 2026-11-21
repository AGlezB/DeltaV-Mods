extends "res://CurrentGame.gd"

# Transponder codes that say what carries them. The game makes every random code in getNewTransponder: a prefix
# picked from a seed (SE1-, JG4-, ETH-, MRS-, BLT-) and four digits from the same seed. This extension makes the code
# from the same seed instead: the ship's model code, then a serial of letters and digits. The model is the one a
# caller names (getTransponder, which every ship the Shipyard builds goes through, and the player's ship), or else a
# ship drawn from the game's usedShipsPool.
# The objects whose code is built from a ship's get a suffix as they enter the scene tree (_tacNodeAdded), before
# their own _ready. Codes already stored in a save are never changed: the game derives a ship's name, its captain and
# what it remembers about the ship from its code.

# The code of each ship model, by its key in the game's ships/Shipyard.gd (`ships`; the `model` of a ship's config):
# a series letter and the model. They are all the same length, so all ships' codes are too.
const MODEL_CODES = {
	"TRTL": "TK37", # K37 TNTRL
	"TRTL-LCB": "TX37", # KX37 TNTRL
	"TRTL-R": "TR37", # Runasimi KR37 TNTRL
	"TRTL-T": "TA24", # KTA24 TNTRL
	"TRTL-44": "MK44", # K44 MHFTR Prototype
	"PROSPECTOR": "PEGL", # Eagle Prospector
	"PROSPECTOR-VP": "PVUL", # Vulture Prospector
	"PROSPECTOR-LUX": "PPCK", # Peacock Prospector
	"PROSPECTOR-FAT": "PPLC", # Pelican Prospector
	"PROSPECTOR-BALD": "PBLD", # Bald Eagle
	"COTHON": "C212", # Cothon-212
	"COTHON-CHK": "C211", # Cothon-211 "Chonker"
	"COTHON-LND": "C213", # Cothon-213 "Triplet"
	"COTHON-V": "C217", # Cothon-217 "Bender"
	"AT225": "AK25", # Antonoff-Titan K225
	"AT225-R": "AR25", # Antonoff-Titan K225 (modified)
	"AT225-B": "AB25", # Antonoff-Titan K225-BB
	"EIME": "EIME", # Eon Interstellar Model E
	"OCP209": "O209", # OCP-209
	"KITSUNE": "NKTS", # ND-LIS Kitsune
	"MADCERF": "MCRF", # MAD-CERF, the rescue ship
	"HYBRID": "HYBR", # the hybrid hunter's ship
	"TSUKUYOMI": "TSKY", # Tsukuyomi, Vilcy's
	"DRONE": "RDRN", # the racing drone
	"ATLAS": "ATLS", # the ATLAS drone
	"OBONTO": "OBNT", # the Obonto habitat
}
# A model missing from MODEL_CODES (added by a game update or another mod) gets the first letters and digits of its
# key, upper case, padded with this to the length of the codes above.
const MODEL_CODE_PAD = "X"
# The serial after the model's code: this many characters, each drawn from the seed among SERIAL_CHARS.
const SERIAL_LENGTH = 5
# Digits and capitals without I, O and Q, which read like 1 and 0 (as vehicle identification numbers leave them out).
const SERIAL_CHARS = "0123456789ABCDEFGHJKLMNPRSTUVWXYZ"

# Added to the code of the ship a lifepod left (the game gives the pod the ship's code), or to a random ship's for a
# lifepod found floating.
const LIFEPOD_SUFFIX = "-LPD"
# Added to the code of the ATLAS drone its AI core left.
const AI_CORE_SUFFIX = "-AIC"
# Added to the code a group of frozen bodies shares: their beacon shows it so, and each body adds its initials.
const CREW_SUFFIX = "-CRW"
# The drones a ship launches: the type in the game's code ("{ship}-CC{nr}") and the mod's ("{ship}-CGO-{nr}").
# CC: THI Cargo and Monocargo Containers; CS: the NT Mining Companion; CB: the B8 Claim Beacon.
const DRONE_CODES = {
	"CC": "CGO",
	"CS": "MNC",
	"CB": "CLM",
}

# The game's (not settings).
const _TAC_SHIP_SCRIPT = "res://ships/ship-ctrl.gd"
const _TAC_BODY_SCRIPT = "res://story/body.gd" # a frozen body; its getTransponder adds "-" and the initials
const _TAC_DOCK_SCRIPT = "res://ships/modules/ClaimOwner.gd" # launches a drone, coded by its transponderFormat
const _TAC_DOCK_FORMAT = "{ship}-%s{nr}" # the docks' transponderFormat (ClaimOwner.gd, the dock scenes), by type
const _TAC_STORY_BEACON_SCRIPTS = ["res://story/ClaimBeacon-1.gd", "res://story/ClaimBeaconForeign.gd"]
const _TAC_STORY_BEACON_FORMAT = "%%s-%s%%d" # their transponderFormat, "%s-CB%d"
const _TAC_BODY_BEACON_SCENE = "res://story/DeadTalkingBeacon.tscn" # the frozen bodies' beacon (story/DeadBody.gd)
const _TAC_LIFEPOD_NAME = "ODDITY_LIFEPOD" # specialName of ships/Lifepod.tscn and the scenes inheriting it
const _TAC_AI_CORE_NAME = "ODDITY_AICORE" # specialName of ships/drone/AICore.tscn, the ATLAS's lifepod

var _tacModel = null # the model the next getNewTransponder codes for; null: a ship from usedShipsPool

func _ready():
	get_tree().connect("node_added", self, "_tacNodeAdded")

# The seed's draws (srai): the first picks the ship when no model is given, as the game's picks its prefix; each of the
# others a character of the serial. Each draw starts from the previous one's output, so neighbouring seeds don't give
# related serials. The same seed always gives the same code, so the Dealer's ships keep theirs from day to day.
func getNewTransponder(s: int) -> String:
	var d = srai(s, 1 + SERIAL_LENGTH)
	var model = _tacModel
	if model == null:
		if usedShipsPool.empty():
			return .getNewTransponder(s)
		model = usedShipsPool[d[0] % usedShipsPool.size()].name
	var serial = ""
	for i in range(1, 1 + SERIAL_LENGTH):
		serial += SERIAL_CHARS[d[i] % SERIAL_CHARS.length()]
	return "%s-%s" % [_tacModelCode(model), serial]

# Every ship the Shipyard builds without a code (Shipyard.gd createShipByConfig) gets it here, from its model.
func getTransponder(new: bool, config: Dictionary, sd: int) -> String:
	var previous = _tacModel
	_tacModel = config.get("model")
	var code = .getTransponder(new, config, sd)
	_tacModel = previous
	return code

# Both give the player's ship a code when it has none: a save loaded, a new game.
func validateState():
	var previous = _tacModel
	_tacModel = state.ship.get("model")
	.validateState()
	_tacModel = previous

func createPlayerShip():
	var previous = _tacModel
	_tacModel = state.ship.get("model")
	var ship = .createPlayerShip()
	_tacModel = previous
	return ship

func _tacModelCode(model) -> String:
	if model in MODEL_CODES:
		return MODEL_CODES[model]
	var length = MODEL_CODES.values()[0].length()
	var code = ""
	for c in String(model).to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			code += c
	while code.length() < length:
		code += MODEL_CODE_PAD
	return code.substr(0, length)

# Before the node's _ready, so lifepods keep the code (ships/LifepodFeedback.gd makes one only when there is none).
# Each step leaves a code that already has its suffix, so a node added again isn't changed twice.
func _tacNodeAdded(node: Node):
	var script = node.get_script()
	if script == null:
		return
	var path = script.resource_path
	if path == _TAC_SHIP_SCRIPT:
		_tacShipAdded(node)
	elif path == _TAC_BODY_SCRIPT:
		if node.transponder and not node.transponder.ends_with(CREW_SUFFIX):
			node.transponder += CREW_SUFFIX
	elif path == _TAC_DOCK_SCRIPT:
		_tacDockAdded(node)
	elif path in _TAC_STORY_BEACON_SCRIPTS:
		for type in DRONE_CODES:
			if node.transponderFormat == _TAC_STORY_BEACON_FORMAT % type:
				node.transponderFormat = "%%s-%s-%%d" % DRONE_CODES[type]

func _tacShipAdded(ship: Node):
	match ship.specialName:
		_TAC_LIFEPOD_NAME:
			if ship.transponder == "":
				var previous = _tacModel
				_tacModel = null
				ship.transponder = getNewTransponder(randi()) + LIFEPOD_SUFFIX
				_tacModel = previous
			else:
				_tacAddSuffix(ship, LIFEPOD_SUFFIX)
		_TAC_AI_CORE_NAME:
			if ship.transponder != "":
				_tacAddSuffix(ship, AI_CORE_SUFFIX)
		_:
			# The destroyed habitat's beacon (story/habitat/DestoryedHabitat.tscn) gets its code later, from its
			# ClaimOwner: it has none yet, and keeps the game's.
			if ship.filename == _TAC_BODY_BEACON_SCENE and ship.transponder != "" and not ship.transponder.ends_with(CREW_SUFFIX):
				ship.transponder += CREW_SUFFIX

# Keeps the name the game gives the old code (a lifepod shows its ship's, as without the mod). The game has already
# forgotten the dead ship's code (ship-ctrl.gd vanish, forgetTransponser), so its name isn't stored back.
func _tacAddSuffix(ship: Node, suffix: String):
	var old = ship.transponder
	if old.ends_with(suffix):
		return
	var names = state.get("shipNames", {})
	var shipName = names[old] if old in names else generateShipNameFromTransponder(old)
	ship.transponder = old + suffix
	setShipNameByTransponder(ship.transponder, shipName)

# Only a dock on a ship: the destroyed habitat's ClaimOwner codes its beacon with the habitat's fixed code.
func _tacDockAdded(dock: Node):
	var host = dock.get_parent()
	while host != null and not "transponder" in host:
		host = host.get_parent()
	if host == null or host.get_script() == null or host.get_script().resource_path != _TAC_SHIP_SCRIPT:
		return
	for type in DRONE_CODES:
		if dock.transponderFormat == _TAC_DOCK_FORMAT % type:
			dock.transponderFormat = "{ship}-%s-{nr}" % DRONE_CODES[type]
			return

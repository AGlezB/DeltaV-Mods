extends "res://harness/suite.gd"

# DealerNotifier: the station menu's Dealer entry (the `ShipMarket` Button of the game's enceladus/EnceladusMenu.tscn,
# with no script and the translation key ENCELADUS_SHIP_MARKET as its text) shows the mod's alert text while the dealer
# has a ship of a model switched on in its settings that came after the switch went on and after the Dealer screen was
# last open, and that the player didn't sell. Opening the Dealer screen clears it, and gives the entries of those ships
# a badge until the station is left.
#
# The station is built in code as enceladus/Enceladus.tscn nests it: the menu, and the right-hand screens' container
# (the game's HidingMarginContainer.gd) with the station's Dealer screen (harness/station_dealer.tscn: the stub of
# enceladus/Dealer.tscn, whose root has the game's Dealer.gd, with the station's values), Fleet (the stub of
# enceladus/Owned.tscn) and a Tuning screen stub. The Dealer's entries are the game's SystemBuyUI.gd in a stub of its
# scene with the game's tooltip node (harness/dealer_entry.tscn); the dealer's stock is the CurrentGame stub's
# (`forSale`, harness/fleet_ship.gd ships), refreshed as the game refreshes it (hourPassed). The ship models are the
# suite's own scenes (harness/dealer/*.tscn, harness/dealer_ship.gd) in the Shipyard stub, with the game's model keys,
# so the mod's NEW_STOCK finds some of them; their names are test keys, translated here in two languages, in a
# different order in each. The mod's texts are its i18n/en.po, and every expected text is built with tr() from the
# mod's keys, so any wording passes. The control checks run on the game's own scripts: with the mod loaded, those are
# the bases of the extensions.

const KEY = "ENCELADUS_SHIP_MARKET"
const TEXT_EN = "Dealer"
const TEXT_DE = "Haendler"
const CREW_KEY = "ENCELADUS_CREW"
const DIVE_KEY = "ENCELADUS_RETURN_TO_RING"
const MANIFEST = "res://DealerNotifier/Mod.manifest"
const SETTINGS_SCRIPT = "res://DealerNotifier/Settings.gd"
# The scripts the mod extends: once installed, its extensions load by these paths (take_over_path).
const MENU_SCRIPT = "res://enceladus/EnceladusMenu.gd"
const DEALER_SCRIPT = "res://enceladus/Dealer.gd"
const SHIP_SCRIPT = "res://harness/dealer_ship.gd"
const STOCK_SHIP = "res://harness/fleet_ship.gd"
const WATCHED = "watched"

# The suite's ship models: the game's keys, the suite's scenes. Two series with a variant each (TRTL-R of TRTL,
# PROSPECTOR-VP of PROSPECTOR), two models alone in their series. AT225 (in the mod's NEW_STOCK) and NOSCENE (in the
# pool) have no scene, UNUSED has a scene but the dealer never offers it: none of the three is listed.
const SCENES = {
	"TRTL": "res://harness/dealer/trtl.tscn",
	"TRTL-R": "res://harness/dealer/trtl_r.tscn",
	"PROSPECTOR": "res://harness/dealer/prospector.tscn",
	"PROSPECTOR-VP": "res://harness/dealer/prospector_vp.tscn",
	"EIME": "res://harness/dealer/eime.tscn",
	"KITSUNE": "res://harness/dealer/kitsune.tscn",
	"UNUSED": "res://harness/dealer/unused.tscn",
}
const ALIASES = {"TRTL-R": "TRTL", "PROSPECTOR-VP": "PROSPECTOR"}
const POOL = ["TRTL", "TRTL", "TRTL-R", "PROSPECTOR-VP", "KITSUNE", "KITSUNE", "NOSCENE"]
# Each model's names, as its scene gives them (shipName, baseShipName): set in the scene; in the scene it inherits from
# (TRTL-R's base); left to the script's defaults (PROSPECTOR, and EIME's base), which only an instance gives.
const NAMES = {
	"TRTL": ["TEST_SHIP_TRTL", "TEST_SHIP_TRTL"],
	"TRTL-R": ["TEST_SHIP_TRTL_R", "TEST_SHIP_TRTL"],
	"PROSPECTOR": ["TEST_SHIP_DEFAULT", ""],
	"PROSPECTOR-VP": ["TEST_SHIP_PROSPECTOR_VP", "TEST_SHIP_DEFAULT"],
	"EIME": ["TEST_SHIP_EIME", ""],
	"KITSUNE": ["TEST_SHIP_KITSUNE", "TEST_SHIP_KITSUNE"],
}
const MADE_FOR_NAMES = 2 # PROSPECTOR and EIME: a name only an instance gives
# The names in the two test languages. One English name is lowercase: sorted by case, it would come last.
const NAMES_EN = {"TEST_SHIP_TRTL": "Tortoise", "TEST_SHIP_TRTL_R": "runner", "TEST_SHIP_DEFAULT": "Eagle", "TEST_SHIP_PROSPECTOR_VP": "Vulture", "TEST_SHIP_EIME": "Model E", "TEST_SHIP_KITSUNE": "Fox"}
const NAMES_DE = {"TEST_SHIP_TRTL": "Kroete", "TEST_SHIP_TRTL_R": "Renner", "TEST_SHIP_DEFAULT": "Seeadler", "TEST_SHIP_PROSPECTOR_VP": "Geier", "TEST_SHIP_EIME": "Modell E", "TEST_SHIP_KITSUNE": "Fuchs"}
# The settings screen's groups in each language: [title key, the models' rows in order]; null stands for the mod's
# OTHERS_LABEL.
const GROUPS_EN = [["TEST_SHIP_DEFAULT", ["PROSPECTOR", "PROSPECTOR-VP"]], ["TEST_SHIP_TRTL", ["TRTL-R", "TRTL"]], [null, ["KITSUNE", "EIME"]]]
const GROUPS_DE = [["TEST_SHIP_TRTL", ["TRTL", "TRTL-R"]], ["TEST_SHIP_DEFAULT", ["PROSPECTOR-VP", "PROSPECTOR"]], [null, ["KITSUNE", "EIME"]]]
# A German text for the mod's settings tooltip, which its en.po has only in English.
const SETTINGS_TOOLTIP_DE = "Mit %s klicken: Einstellungen von %s"

# The models' default configs, as the game's Shipyard.gd defaultShipConfig: TRTL's (TRTL-R's too, through its base
# model) fits a system on its left hardpoint, with settings of the hardpoint's own, as the Antonoff-Titan K225's fits
# THI Cargo Containers, and has thrusters and propellant; the others fit nothing.
const DEALER_CONFIGS = {"TRTL": {"config": {"weaponSlot": {"left": {"type": "SYSTEM_TEST_CONTAINER", "config": {"test": true}}}, "propulsion": {"rcs": "SYSTEM_TEST_RCS"}, "fuel": {"capacity": 30000.0, "initial": 30000.0}}}}
# The config two models' ships enter the tree with: the dealer's, with every hardpoint empty. TRTL
# (harness/dealer/trtl.tscn): its inline left hardpoint, where the dealer fits a system, keeping its other settings; its
# main one, a placeholder that leaves its slot to the hardpoint scene and has a gun as its default; not its other
# placeholder's slot, which isn't a hardpoint's; its thrusters and propellant kept. KITSUNE: a nested inline hardpoint
# and a placeholder that names its slot.
const PICTURED = {
	"TRTL": {"weaponSlot": {"left": {"type": "SYSTEM_NONE", "config": {"test": true}}, "main": {"type": "SYSTEM_NONE"}}, "propulsion": {"rcs": "SYSTEM_TEST_RCS"}, "fuel": {"capacity": 30000.0, "initial": 30000.0}},
	"KITSUNE": {"weaponSlot": {"mainLow": {"type": "SYSTEM_NONE"}, "right": {"type": "SYSTEM_NONE"}}},
}

var settings = null
var changes = 0 # settingsChanged signals counted
var made = [] # the stock ships the suite made, freed at the end

func _countChange():
	changes += 1

func addTranslation(locale, text, names):
	var t = Translation.new()
	t.locale = locale
	t.add_message(KEY, text)
	for key in names:
		t.add_message(key, names[key])
	TranslationServer.add_translation(t)

func manifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return manifest.get_value(section, key)

func shipsMade() -> int:
	var script = load(SHIP_SCRIPT)
	return script.get_meta("made") if script.has_meta("made") else 0

# A ship for sale, as CurrentGame.gd getShipsAvailableForSale returns them (Shipyard.gd keeps the config by reference).
func offer(model, transponder):
	var ship = load(STOCK_SHIP).new()
	ship.useConfig({"config": {}, "model": model, "transponder": transponder, "faction": "dealer"})
	made.append(ship)
	return ship

# A new in-game hour, with the dealer's stock as `ships`: the game's refreshes the Dealer and Fleet screens on it.
func hour(ships):
	CurrentGame.forSale = ships
	CurrentGame.emit_signal("hourPassed")
	yield(settle(), "completed")

# Long enough for a refresh of a hidden screen, which waits an idle physics frame per ship (Dealer.gd doAddShips), and
# for its entries to add their ships.
func settle():
	yield(frames(CurrentGame.forSale.size() + CurrentGame.ownedShips.size() + 8), "completed")

func entry(s) -> String:
	return s.market.text

func marked(s) -> String:
	return tr(s.menu._DN_ALERT) % tr(KEY)

func settingsTip(s) -> String:
	return tr(s.menu._DN_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")]

# The station as enceladus/Enceladus.tscn nests the menu and the right-hand screens: MarginContainer > HBoxContainer >
# Options (the menu, the game's EnceladusMenu.gd, with its ShipMarket, OwnedShips and Logs entries, and the Crew and
# RingDive entries of the other mods loaded), and MarginContainer > CanvasLayer > MarginContainer (HidingMarginContainer.gd)
# > the Dealer screen (wired to the entry's `pressed` as the scene does), Fleet, and the Tuning screen with its
# description window nested as enceladus/Tuning.tscn nests it (CrewCheapHireNotifier's and DiveSkipTransit's screens
# copy it), and the Crew screen stub when CrewCheapHireNotifier is loaded.
func station(withDealer = true):
	var root = MarginContainer.new()
	root.name = "MarginContainer"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var hbox = HBoxContainer.new(); hbox.name = "HBoxContainer"
	root.add_child(hbox)
	var menu = VBoxContainer.new(); menu.name = "Options"
	menu.set_script(load(MENU_SCRIPT))
	var market = Button.new(); market.name = "ShipMarket"; market.text = KEY
	menu.add_child(market)
	var owned = Button.new(); owned.name = "OwnedShips"; owned.text = "ENCELADUS_OWNED_SHIPS"
	menu.add_child(owned)
	var crew = null
	if hasMod("CrewCheapHireNotifier"):
		crew = Button.new(); crew.name = "Crew"; crew.text = CREW_KEY
		menu.add_child(crew)
	var dive = null
	if hasMod("DiveSkipTransit"):
		dive = Button.new(); dive.name = "RingDive"; dive.text = DIVE_KEY
		menu.add_child(dive)
	var logs = Button.new(); logs.name = "Logs"; logs.text = "ENCELADUS_LOGS"
	menu.add_child(logs)
	hbox.add_child(menu)
	var layer = CanvasLayer.new(); layer.name = "CanvasLayer"
	root.add_child(layer)
	var screens = MarginContainer.new(); screens.name = "MarginContainer"
	screens.set_script(load("res://enceladus/HidingMarginContainer.gd"))
	screens.hideOnFocusOf = NodePath("../../HBoxContainer/Options")
	screens.anchor_right = 1.0
	screens.anchor_bottom = 1.0
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screens)
	var dealer = null
	if withDealer:
		dealer = load("res://harness/station_dealer.tscn").instance()
		dealer.name = "Dealer"
		screens.add_child(dealer)
		market.connect("pressed", dealer, "show")
	var fleet = load("res://harness/station_owned.tscn").instance()
	fleet.name = "Owned"
	screens.add_child(fleet)
	owned.connect("pressed", fleet, "show")
	if crew != null:
		var crewScreen = Control.new(); crewScreen.name = "Crew"; crewScreen.visible = false
		crewScreen.set_script(load("res://harness/crew_screen.gd"))
		screens.add_child(crewScreen)
		crew.connect("pressed", crewScreen, "_on_Crew_pressed")
	var tuning = PanelContainer.new(); tuning.name = "Tuning"; tuning.visible = false
	tuning.theme = Theme.new()
	tuning.add_stylebox_override("panel", StyleBoxFlat.new())
	tuning.rect_min_size = Vector2(600, 0)
	tuning.size_flags_horizontal = Control.SIZE_SHRINK_END
	var tuningVb = VBoxContainer.new(); tuningVb.name = "VB"
	tuning.add_child(tuningVb)
	var windowMargin = MarginContainer.new(); windowMargin.name = "WindowMargin"
	tuningVb.add_child(windowMargin)
	var window = PanelContainer.new(); window.name = "Window"
	windowMargin.add_child(window)
	var windowVb = VBoxContainer.new(); windowVb.name = "VBoxContainer"
	window.add_child(windowVb)
	var inside = MarginContainer.new(); inside.name = "MarginContainer"
	windowVb.add_child(inside)
	screens.add_child(tuning)
	add_child(root)
	return {"root": root, "menu": menu, "market": market, "owned": owned, "crew": crew, "dive": dive, "logs": logs, "screens": screens, "dealer": dealer, "fleet": fleet, "tuning": tuning}

func freeStation(s):
	s.root.queue_free()
	yield(frames(2), "completed")

# A left click on `button` through the scene tree's input, as the mouse makes it: the press, then the release.
func click(button, shift):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = BUTTON_LEFT
		event.pressed = pressed
		event.shift = shift
		event.position = button.rect_global_position + button.rect_size / 2
		event.global_position = event.position
		get_tree().input_event(event)

# A press and release of a key or button, as Input delivers a player's, in the idle part of a frame (crew suite's tap).
func tap(event):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var e = event.duplicate()
		e.pressed = pressed
		Input.parse_input_event(e)

func escKey():
	var event = InputEventKey.new()
	event.scancode = KEY_ESCAPE
	return event

# The game's bindings (its project.godot): ui_cancel is Esc, pause is Esc too.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["pause", escKey()]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

# The Dealer screen's entries of ships for sale, in order.
func offers(dealer) -> Array:
	var out = []
	for e in dealer.items.get_children():
		if "ship" in e and not e.is_queued_for_deletion() and not e.owned:
			out.append(e)
	return out

func entryOf(dealer, transponder):
	for e in offers(dealer):
		if e.ship.transponder == transponder:
			return e
	return null

func badgeOf(dealer, e):
	return e.get_node_or_null("HBox/ShipName/" + dealer._DN_BADGE)

func badged(dealer, transponder) -> bool:
	var e = entryOf(dealer, transponder)
	var badge = badgeOf(dealer, e) if e != null else null
	return badge != null and badge.visible

# The transponders of the entries with a visible badge, sorted (ShipSortByTypeAndPrice, loaded too, reorders the
# entries).
func badges(dealer) -> Array:
	var out = []
	for e in offers(dealer):
		var badge = badgeOf(dealer, e)
		if badge != null and badge.visible:
			out.append(e.ship.transponder)
	out.sort()
	return out

func screenOf(s):
	return s.screens.get_node_or_null("DealerNotifierSettings")

# The settings screen's groups (the game's TuningItems), in order, in its Items box (as Tuning.tscn's).
func groups(screen) -> Array:
	var out = []
	for items in screen.get_node("VB/ScrollContainer").get_children():
		if items.is_queued_for_deletion() or items.name != "Items":
			continue
		for group in items.get_children():
			if "tuning" in group and not group.is_queued_for_deletion():
				out.append(group)
	return out

func rowsOf(group) -> Array:
	var out = []
	for row in group.get_children():
		if "tune" in row:
			out.append(row)
	return out

func allRows(screen) -> Array:
	var out = []
	for group in groups(screen):
		out += rowsOf(group)
	return out

# The groups the screen should show: [title, [row names]], from the suite's expectations in the language set.
func expectedGroups(spec, others) -> Array:
	var out = []
	for g in spec:
		var names = []
		for model in g[1]:
			names.append(NAMES[model][0])
		out.append([g[0] if g[0] != null else others, names])
	return out

func shownGroups(screen) -> Array:
	var out = []
	for group in groups(screen):
		var names = []
		for row in rowsOf(group):
			names.append(row.tuningItem)
		out.append([group.system, names])
	return out

func rowOf(screen, model):
	for row in allRows(screen):
		if row.tuningItem == NAMES[model][0]:
			return row
	return null

func run():
	var mod = hasMod("DealerNotifier")
	addTranslation("en", TEXT_EN, NAMES_EN)
	addTranslation("de", TEXT_DE, NAMES_DE)
	TranslationServer.set_locale("en")
	for model in SCENES:
		Shipyard.ships[model] = load(SCENES[model])
	Shipyard.configAlias = ALIASES.duplicate()
	Shipyard.defaults = DEALER_CONFIGS.duplicate(true)
	CurrentGame.usedShipsPool = []
	for model in POOL:
		CurrentGame.usedShipsPool.append({"name": model, "age": 0})
	CurrentGame.state.erase("soldShips")
	CurrentGame.state.erase("transponders")
	# The player's ship, which the game's state always has (Fleet entries, and ShipCopyPaste's, read it).
	CurrentGame.state.ship = {"transponder": "OWN-0", "model": "TRTL", "config": {}}
	Input.set_use_accumulated_input(false)
	bindGameKeys()
	if not mod:
		yield(controls(), "completed")
		freeMade()
		return
	yield(model(), "completed")
	yield(rule(), "completed")
	yield(screen(), "completed")
	yield(together(), "completed")
	freeMade()

func freeMade():
	for ship in made:
		if is_instance_valid(ship) and not ship.is_inside_tree():
			ship.free()
	made.clear()

# The control checks, on the game's own scripts: the Dealer entry keeps its key, the Dealer screen lists the stock, and
# no entry gets a badge.
func controls():
	var s = station()
	CurrentGame.forSale = [offer("TRTL", "C-1"), offer("EIME", "C-2")]
	yield(settle(), "completed")
	yield(hour([offer("TRTL", "C-1"), offer("TRTL", "C-3")]), "completed")
	check("control: the Dealer entry keeps its key", entry(s) == KEY, entry(s))
	click(s.market, false)
	yield(settle(), "completed")
	var added = 0
	for e in offers(s.dealer):
		for child in e.get_node("HBox/ShipName").get_children():
			if child is Control:
				added += 1
	check("control: the Dealer screen opens and lists the stock, and no entry gets a badge", s.dealer.visible and offers(s.dealer).size() == 2 and added == 0, [offers(s.dealer).size(), added])
	yield(freeStation(s), "completed")

# The settings model: one shared instance, the models and their names, the defaults, what is stored and read back.
func model():
	var script = load(SETTINGS_SCRIPT)
	settings = script.shared()
	settings.connect("settingsChanged", self, "_countChange")
	check("the settings model is one shared instance", settings == script.shared())
	check("the mod's texts are loaded (i18n/en.po)", tr("DEALERNOTIFIER_ALERT") != "DEALERNOTIFIER_ALERT" and tr("DEALERNOTIFIER_OTHERS") != "DEALERNOTIFIER_OTHERS")
	# The models: NEW_STOCK, then the pool in order, each once, only those with a scene.
	var expected = []
	for m in script.NEW_STOCK + POOL:
		if not m in expected and SCENES.has(m):
			expected.append(m)
	check("the models are the weekly ones (NEW_STOCK) and the pool's, each once, only those the game has a scene for", settings.models() == expected and not "UNUSED" in settings.models(), settings.models())
	check("a variant's series is its base model (Shipyard.getShipAlias), a base model's itself", settings.series("TRTL-R") == "TRTL" and settings.series("TRTL") == "TRTL" and settings.series("EIME") == "EIME")
	var before = shipsMade()
	var namesOk = true
	for m in NAMES:
		namesOk = namesOk and settings.shipNameKey(m) == NAMES[m][0] and settings.baseShipNameKey(m) == NAMES[m][1]
	check("each model's names are its scene's: set in it, in the scene it inherits from, or the script's default", namesOk)
	check("a ship is made only for a name the scenes leave to the script", shipsMade() - before == MADE_FOR_NAMES, shipsMade() - before)
	before = shipsMade()
	for m in NAMES:
		settings.shipNameKey(m)
	check("and only once", shipsMade() == before)
	CurrentGame.state.ui = {}
	settings.loadFromState()
	var off = true
	for m in settings.models():
		off = off and settings.getValue(WATCHED, m) == false
	check("every model starts switched off (the setting's default)", off and script.SETTINGS[WATCHED].default == false)
	changes = 0
	var id = manifestValue("mod_information", "id")
	settings.setValue(WATCHED, "yes", "TRTL")
	settings.setValue(WATCHED, 1, "TRTL")
	check("a value that isn't a switch's gives the default, storing nothing", settings.getValue(WATCHED, "TRTL") == false and changes == 0 and not CurrentGame.state.ui.has(id), CurrentGame.state.ui)
	settings.setValue(WATCHED, true, "TRTL")
	var saved = CurrentGame.state.ui.get(id, {})
	check("switching a model on stores it in the save game, under the manifest's id, signalling once", changes == 1 and saved.get(WATCHED, {}).get("TRTL") == true and saved.get(WATCHED, {}).get("EIME") == false, saved)
	var version = "%d.%d.%d" % [manifestValue("version", "version_major"), manifestValue("version", "version_minor"), manifestValue("version", "version_bugfix")]
	check("with the format and mod versions and the ships seen", saved.get("formatVersion") == script.FORMAT_VERSION and saved.get("modVersion") == version and saved.get("known") is Array, saved)
	settings.setValue(WATCHED, true, "TRTL")
	check("setting it again signals nothing", changes == 1)
	settings.cfg[WATCHED]["EIME"] = true
	check("the saved entry is a copy", saved[WATCHED].get("EIME") == false)
	settings.cfg[WATCHED]["EIME"] = false
	# Read back after a JSON round trip, as the game saves and loads.
	CurrentGame.state = parse_json(to_json(CurrentGame.state))
	settings.cfg[WATCHED]["TRTL"] = false
	settings.loadFromState()
	check("a save game's switches are read back", settings.getValue(WATCHED, "TRTL") == true and settings.getValue(WATCHED, "EIME") == false)
	# A hand-edited entry can't break it.
	CurrentGame.state.ui[id] = {WATCHED: {"TRTL": "on", "EIME": true}, "known": ["A", 5, "A", null, "B"]}
	settings.loadFromState()
	check("a hand-edited entry: a switch that isn't one gives the default, the ships seen keep only transponders, once", settings.getValue(WATCHED, "TRTL") == false and settings.getValue(WATCHED, "EIME") == true and settings.known == ["A", "B"], [settings.cfg[WATCHED], settings.known])
	CurrentGame.state.ui[id] = {WATCHED: "all", "known": "A"}
	settings.loadFromState()
	check("and switches or ships seen that aren't a dictionary or a list give the defaults", settings.getValue(WATCHED, "EIME") == false and settings.known.empty())
	CurrentGame.state.ui = {}
	settings.loadFromState()
	yield(frames(1), "completed")

# The rule, on a station: the mark, opening the Dealer screen, the badges, Fleet, a new station after a save and a load.
func rule():
	var s = station()
	var dealer = s.dealer
	CurrentGame.forSale = [offer("TRTL", "T-1"), offer("EIME", "E-1")]
	yield(settle(), "completed")
	check("the Dealer screen lists the stock (the game's refresh)", offers(dealer).size() == 2, offers(dealer).size())
	check("nothing switched on: the Dealer entry keeps its key", entry(s) == KEY, entry(s))
	check("the Dealer entry's tooltip tells about Shift+Click", s.market.hint_tooltip == settingsTip(s), s.market.hint_tooltip)
	check("the stock reached the settings model", settings.stock.size() == 2, settings.stock)
	settings.setValue(WATCHED, true, "TRTL")
	check("switching a model on doesn't mark the ships of it the dealer has already", entry(s) == KEY and "T-1" in settings.known and not "E-1" in settings.known, settings.known)
	yield(hour([offer("TRTL", "T-1"), offer("EIME", "E-1"), offer("EIME", "E-2")]), "completed")
	check("a new ship of a model switched off doesn't mark it", entry(s) == KEY, entry(s))
	CurrentGame.state.soldShips = [{"at": 0, "config": {"transponder": "S-1", "model": "TRTL"}}]
	yield(hour([offer("TRTL", "T-1"), offer("EIME", "E-1"), offer("EIME", "E-2"), offer("TRTL", "S-1")]), "completed")
	check("a ship the player sold, back at the dealer, doesn't mark it", entry(s) == KEY, entry(s))
	yield(hour([offer("TRTL", "T-1"), offer("EIME", "E-1"), offer("EIME", "E-2"), offer("TRTL", "S-1"), offer("TRTL", "T-2")]), "completed")
	check("a new ship of a model switched on marks the Dealer entry at the refresh", entry(s) == marked(s), entry(s))
	var german = Translation.new()
	german.locale = "de"
	german.add_message(s.menu._DN_SETTINGS_TOOLTIP, SETTINGS_TOOLTIP_DE)
	TranslationServer.add_translation(german)
	TranslationServer.set_locale("de")
	check("after a language change the mark is in the new language", entry(s) == marked(s) and entry(s).find(TEXT_DE) >= 0, entry(s))
	check("and so is the tooltip", s.market.hint_tooltip == SETTINGS_TOOLTIP_DE % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")], s.market.hint_tooltip)
	TranslationServer.set_locale("en")
	check("and back", entry(s) == marked(s) and s.market.hint_tooltip == settingsTip(s), entry(s))
	settings.setValue(WATCHED, false, "TRTL")
	check("switching the model off unmarks it", entry(s) == KEY, entry(s))
	settings.setValue(WATCHED, true, "TRTL")
	check("and on again doesn't mark it: the ship was there when the switch went on", entry(s) == KEY and "T-2" in settings.known, entry(s))
	yield(hour([offer("TRTL", "T-1"), offer("EIME", "E-1"), offer("EIME", "E-2"), offer("TRTL", "S-1"), offer("TRTL", "T-2"), offer("TRTL", "T-3")]), "completed")
	check("a ship that comes later marks it", entry(s) == marked(s), entry(s))
	# Fleet's refreshes and its opening change nothing.
	CurrentGame.ownedShips = [offer("KITSUNE", "O-1")]
	var stock = settings.stock.duplicate()
	var known = settings.known.duplicate()
	s.fleet.addShips()
	yield(settle(), "completed")
	click(s.owned, false)
	yield(settle(), "completed")
	check("Fleet (the same script, listing no stock) changes neither the stock nor the ships seen", settings.stock == stock and settings.known == known and entry(s) == marked(s), settings.stock)
	var fleetBadges = 0
	for e in s.fleet.items.get_children():
		if badgeOf(dealer, e) != null:
			fleetBadges += 1
	check("and its entries get no badge", fleetBadges == 0 and s.fleet.items.get_child_count() > 0, s.fleet.items.get_child_count())
	CurrentGame.ownedShips = []
	# The harness's window is narrower than the game's, so an open screen covers the menu: closed first.
	s.fleet.hide()
	yield(frames(40), "completed")
	# Opening the Dealer screen (a plain click, the entry's `pressed`) clears the mark and badges the ship.
	click(s.market, false)
	check("a plain click opens the Dealer screen", dealer.visible and screenOf(s) == null)
	check("opening the Dealer screen clears the mark at once", entry(s) == KEY, entry(s))
	check("everything the dealer has is seen", "T-1" in settings.known and "T-3" in settings.known and "E-2" in settings.known and "S-1" in settings.known, settings.known)
	check("the ship that marked it gets a badge, and only it", badges(dealer) == ["T-3"], badges(dealer))
	yield(settle(), "completed")
	check("the refresh the screen's opening makes keeps it so", entry(s) == KEY and badges(dealer) == ["T-3"], [entry(s), badges(dealer)])
	var e = entryOf(dealer, "T-3")
	var badge = badgeOf(dealer, e) if e != null else null
	if badge == null:
		yield(freeStation(s), "completed")
		return
	# The badge: CrewCheapHireNotifier's, in the entry's name column, coloured as its Owned label.
	var initials = ""
	for c in manifestValue("mod_information", "name"):
		if c != c.to_lower():
			initials += c
	var label = badge.get_child(0)
	var buy = e.get_node("HBox/Buy")
	var owned = e.get_node("HBox/V/Owned").modulate
	check("the badge shows the capitals of the manifest's name, in the Buy button's font colour times the Owned label's", label is Label and label.text == initials and label.get_color("font_color") == buy.get_color("font_color") * owned, label.text if label is Label else label)
	var pictureFont = e.get_node("HBox/Margin").get_font("font", "Label")
	var nameFont = e.get_node("HBox/ShipName").get_font("font")
	check("in the font a Label gets in the entry's picture, smaller than the name's", label is Label and label.get_font("font") == pictureFont and pictureFont.get_height() < nameFont.get_height(), [pictureFont.get_height(), nameFont.get_height()])
	var frame = badge.get_stylebox("panel")
	var buyFrame = buy.get_stylebox("normal")
	check("in a copy of the Buy button's frame, its border in the Owned label's colour, the button's own frame unchanged", frame is StyleBoxFlat and frame != buyFrame and frame.border_color == owned and buyFrame.border_color != owned, frame)
	var shipName = e.get_node("HBox/ShipName")
	check("letting the mouse through to the entry's name", badge.mouse_filter == Control.MOUSE_FILTER_PASS and badge.get_parent() == shipName)
	var text = shipName.get_stylebox("normal")
	var right = text.get_margin(MARGIN_RIGHT) if text != null else 0.0
	var nameRect = shipName.get_global_rect()
	var badgeRect = badge.get_global_rect()
	var placed = is_equal_approx(badgeRect.end.x, nameRect.end.x - right) and abs(badgeRect.get_center().y - nameRect.get_center().y) <= 0.5
	check("at the right end of the entry's name, inside the right margin around its text, centred from top to bottom, at its least size", nameRect.encloses(badgeRect) and placed and badge.rect_size == badge.get_combined_minimum_size(), [badgeRect, nameRect, right])
	var tooltips = e.get_node("PlaySoundsOnTheseButtons")
	check("its tooltip is the game's (the entry's PlaySoundsOnTheseButtons registered it)", tooltips.tooltips.has(badge) and badge.hint_tooltip == tr(dealer._DN_BADGE_TOOLTIP) and tr(dealer._DN_BADGE_TOOLTIP) != dealer._DN_BADGE_TOOLTIP, badge.hint_tooltip)
	# Closed, a later ship marks it again; the badge stays; opened again, both have one.
	dealer.hide()
	yield(frames(40), "completed")
	yield(hour([offer("TRTL", "T-1"), offer("EIME", "E-2"), offer("TRTL", "S-1"), offer("TRTL", "T-2"), offer("TRTL", "T-3"), offer("TRTL", "T-4")]), "completed")
	check("a later ship of a model switched on marks the entry again", entry(s) == marked(s), entry(s))
	check("ships no longer for sale are forgotten from the ships seen", not "E-1" in settings.known and "E-2" in settings.known, settings.known)
	check("the badge stays through hourly refreshes, and the new ship has none yet", badges(dealer) == ["T-3"], badges(dealer))
	click(s.market, false)
	yield(settle(), "completed")
	check("opened again: the mark is cleared, and both ships have a badge", entry(s) == KEY and badges(dealer) == ["T-3", "T-4"], badges(dealer))
	# After a save and a load (CurrentGame writes the state as JSON and reads it back), a new station has the switches
	# and the ships seen, and no badges.
	dealer.hide()
	yield(frames(40), "completed")
	CurrentGame.state = parse_json(to_json(CurrentGame.state))
	settings.cfg[WATCHED]["TRTL"] = false
	settings.known = []
	yield(freeStation(s), "completed")
	# The ships went with the station's entries, as the game frees its ships for sale on leaving the station
	# (CurrentGame.gd freeShipInstanceCache): the same ships anew, as the next visit makes them.
	CurrentGame.forSale = [offer("TRTL", "T-1"), offer("EIME", "E-2"), offer("TRTL", "S-1"), offer("TRTL", "T-2"), offer("TRTL", "T-3"), offer("TRTL", "T-4")]
	s = station()
	dealer = s.dealer
	check("a new station reads the save game's switches and ships seen", settings.getValue(WATCHED, "TRTL") == true and "T-4" in settings.known and settings.stock.empty(), settings.known)
	yield(settle(), "completed")
	check("the same stock: nothing new, no mark", entry(s) == KEY and settings.stock.size() == CurrentGame.forSale.size(), entry(s))
	click(s.market, false)
	yield(settle(), "completed")
	check("and no badges: they last until the station is left", badges(dealer).empty(), badges(dealer))
	dealer.hide()
	yield(frames(40), "completed")
	yield(freeStation(s), "completed")
	CurrentGame.state.erase("soldShips")

# The settings screen.
func screen():
	var script = load(SETTINGS_SCRIPT)
	CurrentGame.state.ui = {}
	settings.loadFromState()
	var s = station()
	CurrentGame.forSale = [offer("TRTL", "T-1"), offer("KITSUNE", "K-1")]
	yield(settle(), "completed")
	s.market.disabled = true
	click(s.market, true)
	yield(frames(2), "completed")
	check("Shift+Click on a disabled Dealer entry does nothing", screenOf(s) == null and not s.dealer.visible)
	s.market.disabled = false
	Shipyard.configs.clear()
	CurrentGame.state.erase("transponders")
	load(SHIP_SCRIPT).set_meta("drawn", [])
	var before = shipsMade()
	click(s.market, true)
	yield(frames(5), "completed")
	var screen = screenOf(s)
	check("Shift+Click on the Dealer entry opens the settings screen", screen != null and screen.visible)
	check("and not the Dealer screen", not s.dealer.visible)
	if screen == null:
		yield(freeStation(s), "completed")
		return
	var viewports = 0
	var holder = screen.get_node_or_null("Pictures")
	for child in (holder.get_children() if holder != null else []):
		if child is Viewport:
			viewports += 1
	check("the pictures are drawn all at once, as the Dealer draws its entries': a viewport for each model", viewports == settings.models().size(), viewports)
	var ui = screen.get_script().get_script_constant_map()
	check("opening it stores nothing", CurrentGame.state.ui.empty(), CurrentGame.state.ui)
	check("it has the Dealer screen's theme and frame", screen.theme == s.dealer.theme and screen.get_stylebox("panel") == s.dealer.get_stylebox("panel") and screen.theme != null)
	check("and its size and size flags", screen.rect_min_size == s.dealer.rect_min_size and screen.size_flags_horizontal == s.dealer.size_flags_horizontal and screen.size_flags_vertical == s.dealer.size_flags_vertical)
	check("its title is the Dealer entry's", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == KEY)
	var order = []
	for child in screen.get_node("VB").get_children():
		order.append(child.name)
	check("under the header, the description's window, then the note, then the groups", order == ["HeaderWithMoney", "WindowMargin", "Note", "ScrollContainer"], order)
	# The window copies the Dealer's.
	var margin = screen.get_node("VB/WindowMargin")
	var window = screen.get_node("VB/WindowMargin/Window")
	var inside = screen.get_node("VB/WindowMargin/Window/MarginContainer")
	var texts = screen.get_node("VB/WindowMargin/Window/MarginContainer/VBoxContainer")
	var gameMargin = s.dealer.get_node(ui.GAME_WINDOW_MARGIN)
	var gameWindow = s.dealer.get_node(ui.GAME_WINDOW)
	var gameInside = s.dealer.get_node(ui.GAME_WINDOW_INSIDE)
	var copied = margin.theme == gameMargin.theme and margin.theme != null and window.get_stylebox("panel") == gameWindow.get_stylebox("panel") and window.rect_min_size == gameWindow.rect_min_size and window.rect_min_size.y > 0
	for side in ["left", "top", "right", "bottom"]:
		copied = copied and margin.get_constant("margin_" + side) == gameMargin.get_constant("margin_" + side) and inside.get_constant("margin_" + side) == gameInside.get_constant("margin_" + side)
	copied = copied and texts.get_constant("separation") == s.dealer.get_node(ui.GAME_WINDOW_TEXTS).get_constant("separation")
	check("the description's window copies the Dealer's: theme, margins around and inside, panel, least height, the texts' spacing", copied)
	check("and clips its texts, as the Dealer's", inside.rect_clip_content and texts.get_node("Base").autowrap and texts.get_node("Description").autowrap)
	var note = screen.get_node("VB/Note")
	var noteKey = script.SETTINGS[WATCHED].label + ui.DESCRIPTION_SUFFIX
	check("the note is the setting's description (its label and DESCRIPTION_SUFFIX), in i18n/en.po", note.text == noteKey and tr(noteKey) != noteKey and note.autowrap, note.text)
	# The groups: one per series, titled by its base model's name, then the models alone in their series, under Others.
	var others = ui.OTHERS_LABEL
	check("one Tuning group per series, titled by its name, in alphabetical order of the names; the models alone in their series last, under Others", shownGroups(screen) == expectedGroups(GROUPS_EN, others), shownGroups(screen))
	check("in an Items box in the scroll, as the Tuning screen's", screen.get_node_or_null("VB/ScrollContainer/Items") is VBoxContainer)
	check("Others is in i18n/en.po", tr(others) != others)
	var rows = allRows(screen)
	var first = rows[0] if rows.size() > 0 else null
	check("the first switch has the focus", first != null and first.get_node("HBoxContainer/Value").has_focus())
	check("each switch shows its model's setting", rowOf(screen, "TRTL").get_node("HBoxContainer/Value").pressed == false and rowOf(screen, "EIME").get_node("HBoxContainer/Value").pressed == false)
	# Each row dressed as a Dealer entry.
	var entry = load("res://enceladus/SystemBuyUI.tscn").instance()
	var gamePicture = entry.get_node(ui.GAME_ENTRY_PICTURE)
	var gameSprite = entry.get_node(ui.GAME_ENTRY_SPRITE)
	var buyWidth = entry.get_node(ui.GAME_ENTRY_BUY).rect_size.x
	var pictureSize = gamePicture.rect_min_size
	var spriteProps = [gameSprite.position, gameSprite.scale, gameSprite.flip_v]
	entry.free()
	var dressed = rows.size() == settings.models().size()
	var atEnd = dressed
	for row in rows:
		var hbox = row.get_node("HBoxContainer")
		var picture = hbox.get_child(0)
		var sprite = picture.get_node_or_null("Sprite")
		var value = hbox.get_node("Value")
		dressed = dressed and picture.name == "Picture" and picture.rect_min_size == pictureSize and picture.rect_clip_content and sprite is Sprite and [sprite.position, sprite.scale, sprite.flip_v] == spriteProps
		dressed = dressed and not hbox.get_node("Reset").visible and value.rect_min_size.x >= buyWidth and value.hint_tooltip == script.SETTINGS[WATCHED].label
		atEnd = atEnd and is_equal_approx(value.rect_position.x + value.rect_size.x, hbox.rect_size.x) and value.rect_size.x >= buyWidth
	check("each row: the ship's picture first, as a Dealer entry's (size, sprite), no reset, the switch's tooltip the setting's label", dressed and buyWidth > 0, [pictureSize, spriteProps, buyWidth])
	check("the switch at the row's right end, as wide as the entry's Buy button at least", atEnd)
	check("the switch's tooltip is in i18n/en.po", tr(script.SETTINGS[WATCHED].label) != script.SETTINGS[WATCHED].label)
	# The window: the focused ship's description, as Dealer.gd displayShip shows it.
	var base = texts.get_node("Base")
	var description = texts.get_node("Description")
	var described = true
	for m in ["TRTL-R", "TRTL", "PROSPECTOR", "PROSPECTOR-VP", "EIME"]:
		rowOf(screen, m).get_node("HBoxContainer/Value").grab_focus()
		yield(frames(1), "completed")
		var differs = NAMES[m][1] != "" and NAMES[m][1] != NAMES[m][0]
		described = described and description.text == NAMES[m][0] + ui.DESCRIPTION_SUFFIX and base.visible == differs and (not differs or base.text == NAMES[m][1] + ui.DESCRIPTION_SUFFIX)
	check("focusing a row shows its ship's description, after its series' where that differs", described, [base.text, base.visible, description.text])
	# Switching a model on stores it; a ship of it the dealer has now doesn't mark.
	var kitsune = rowOf(screen, "KITSUNE").get_node("HBoxContainer/Value")
	kitsune.pressed = true
	check("switching a model on stores it at once", settings.getValue(WATCHED, "KITSUNE") == true and CurrentGame.state.ui.get(manifestValue("mod_information", "id"), {}).get(WATCHED, {}).get("KITSUNE") == true)
	check("and shows its description", description.text == NAMES["KITSUNE"][0] + ui.DESCRIPTION_SUFFIX)
	check("the ship of it the dealer has doesn't mark the entry", entry(s) == KEY and "K-1" in settings.known)
	first.get_node("HBoxContainer/Value").grab_focus()
	kitsune.grab_focus()
	yield(frames(1), "completed")
	check("focusing it again doesn't switch it back", settings.getValue(WATCHED, "KITSUNE") == true and kitsune.pressed)
	yield(hour([offer("TRTL", "T-1"), offer("KITSUNE", "K-1"), offer("KITSUNE", "K-2")]), "completed")
	check("a later ship of it marks the entry", entry(s) == marked(s), entry(s))
	# The pictures: one ship of each model, each in a Dealer entry's viewport of its own, nothing written to the save
	# game; made from the dealer's config, with every hardpoint emptied before it enters the tree.
	var waited = yield(_waitForPictures(screen), "completed")
	var drawn = []
	for config in Shipyard.configs:
		drawn.append(config.model)
	check("one ship of each model is made to draw, in the screen's order, from the dealer's config", drawn == _screenModels(screen) and _asSold(Shipyard.configs), drawn)
	var clean = true
	for config in Shipyard.configs:
		clean = clean and config.get("transponder") == settings.modId() and config.get("shipName") == settings.modName() and config.get("madeIn") == CurrentGame.getInGameTimestamp() and config.get("faction") == ui.GAME_DEALER_FACTION
	check("with a transponder, a name and a making time, so the game writes nothing to the save game", clean and not CurrentGame.state.has("transponders"), Shipyard.configs)
	var parents = {}
	for ship in _drawn():
		parents[ship.parent] = true
	check("each ship in a viewport of its own", _drawn().size() == drawn.size() and parents.size() == drawn.size(), _drawn().size())
	for m in PICTURED:
		var config = _drawnConfig(m)
		check("%s enters the tree with every hardpoint empty, its scene's nodes' and placeholders' too, the rest as the dealer sells it (see PICTURED)" % m, same(config, PICTURED[m]), config)
	check("every row shows its picture", _allPictures(screen), waited)
	check("the ships drawn are gone once the pictures are taken", screen.get_node_or_null("Pictures") == null or screen.get_node("Pictures").is_queued_for_deletion())
	check("only the ships drawn and those read for names were made", shipsMade() - before == settings.models().size(), shipsMade() - before)
	# Closing, as the game's screens close.
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("Esc closes it after the game's fade", not screen.visible)
	check("the focus goes back to the Dealer entry", s.market.has_focus())
	# Opened in another language, the groups follow its names; the pictures are kept.
	TranslationServer.set_locale("de")
	Shipyard.configs.clear()
	click(s.market, true)
	yield(frames(5), "completed")
	check("opened in another language, the groups and rows follow its names", shownGroups(screen) == expectedGroups(GROUPS_DE, others) and GROUPS_DE != GROUPS_EN, shownGroups(screen))
	check("the pictures are kept: no ship is made again", Shipyard.configs.empty() and _allPictures(screen), Shipyard.configs.size())
	TranslationServer.set_locale("en")
	s.logs.grab_focus()
	yield(frames(40), "completed")
	check("focusing another menu entry hides it, as it hides the game's screens", not screen.visible)
	click(s.market, false)
	yield(settle(), "completed")
	check("a plain click still opens the Dealer screen, clearing the mark", s.dealer.visible and not screen.visible and entry(s) == KEY)
	s.dealer.hide()
	yield(frames(40), "completed")
	yield(freeStation(s), "completed")
	s = station(false)
	yield(frames(2), "completed")
	check("without a Dealer screen there is no tooltip", s.market.hint_tooltip == "", s.market.hint_tooltip)
	click(s.market, true)
	yield(frames(2), "completed")
	check("and Shift+Click opens no settings", screenOf(s) == null)
	yield(freeStation(s), "completed")

func _screenModels(screen) -> Array:
	var out = []
	for row in allRows(screen):
		for m in NAMES:
			if NAMES[m][0] == row.tuningItem:
				out.append(m)
	return out

# Waits until every row shows its picture, or for 600 frames; the frames waited. The viewport draws only when told to:
# the harness runs without the render loop.
func _waitForPictures(screen):
	yield(frames(1), "completed")
	var waited = 0
	while waited < 600 and not _allPictures(screen):
		VisualServer.force_draw(false)
		yield(frames(5), "completed")
		waited += 5
	return waited

# The ships that entered the tree since `drawn` was cleared (harness/dealer_ship.gd): model, config, parent.
func _drawn() -> Array:
	var script = load(SHIP_SCRIPT)
	return script.get_meta("drawn") if script.has_meta("drawn") else []

# The config the ship of `model` entered the tree with, {} if none did.
func _drawnConfig(model) -> Dictionary:
	for ship in _drawn():
		if ship.model == model:
			return ship.config
	return {}

# Whether each config is its model's default config, as the dealer sells it.
func _asSold(configs: Array) -> bool:
	for config in configs:
		if not same(config.config, Shipyard.getDefaultConfigByName(config.model).config):
			return false
	return not configs.empty()

func _allPictures(screen) -> bool:
	var rows = allRows(screen)
	if rows.empty():
		return false
	for row in rows:
		var sprite = row.get_node_or_null("HBoxContainer/Picture/Sprite")
		if sprite == null or not sprite.texture is ImageTexture:
			return false
	return true

# With CrewCheapHireNotifier and DiveSkipTransit loaded too: three extensions of EnceladusMenu.gd, each opening its own
# screen, which hides the others, and keeping its own tooltip. Theirs are as wide as the Tuning stub, which leaves the
# menu free to click, so they are opened first.
func together():
	var others = []
	if hasMod("CrewCheapHireNotifier"):
		others.append(["crew", "CrewCheapHireNotifierSettings", "CrewCheapHireNotifier"])
	if hasMod("DiveSkipTransit"):
		others.append(["dive", "DiveSkipTransitSettings", "DiveSkipTransit"])
	yield(frames(1), "completed")
	if others.empty():
		return
	var s = station()
	yield(settle(), "completed")
	var tips = true
	for other in others:
		var button = s[other[0]]
		click(button, true)
		yield(frames(40), "completed")
		var theirs = s.screens.get_node_or_null(other[1])
		var opened = theirs != null and theirs.visible
		click(s.market, true)
		yield(frames(40), "completed")
		var mine = screenOf(s)
		check("with %s: Shift+Click on its entry opens its settings, then Shift+Click on Dealer opens these and hides its" % other[2], opened and mine != null and mine.visible and not theirs.visible)
		tips = tips and button.hint_tooltip.find(other[2]) >= 0
		yield(tap(escKey()), "completed")
		yield(frames(40), "completed")
	check("every entry keeps its own tooltip", tips and s.market.hint_tooltip.find(settings.modName()) >= 0, s.market.hint_tooltip)
	yield(freeStation(s), "completed")

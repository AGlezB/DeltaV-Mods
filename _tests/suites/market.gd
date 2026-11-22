extends "res://harness/suite.gd"

# MarketAdvisor: the Mineral Market screen (the game's enceladus/MineralMarket.gd, in the stub of its scene, with a
# slider row per mineral, the game's MineralSellSlider.gd and MineralPriceChart.gd) gets a row at its bottom with the
# advice and a Trade button that keeps the cash reserve, within its tolerance's range, by buying ore with the cash above
# the range and selling it below, back to the reserve itself, and a row in its header with what the ore it bought
# (parked) would sell for today. The station menu's Mineral Market entry shows an alert mark while a trade is due, and
# opens the mod's settings with Shift+Click; its Services entry is ServiceNotifier's (the services suite), which this mod
# leaves alone.
#
# The station is built in code as enceladus/Enceladus.tscn nests it: MarginContainer > HBoxContainer > Options (the
# game's EnceladusMenu.gd, with MineralMarket, Services and Logs entries), and MarginContainer > CanvasLayer >
# MarginContainer (the game's HidingMarginContainer.gd) > the Mineral Market (wired to its entry's `pressed` as the
# scene wires it), the Services screen (its rows nested as enceladus/Services.tscn nests them, with the game's values for
# the rows given, by default the three that cost a monthly fee) and a Tuning screen stub with its description window.
# The services suite builds the same station, without the market. The prices are the CurrentGame
# stub's port of the game's market code, drawn from a save's seed, and moved by the trades in its log. In-game time
# passes with the game's signals. The mod's texts are its i18n/en.po, and every expected text is built with tr() from
# the mod's keys, so any wording passes. The control checks run on the game's own scripts.

const MARKET_KEY = "ENCELADUS_MINERAL_MARKET"
const SERVICES_KEY = "ENCELADUS_SERVICES"
# Test names of the two entries, and the Services rows' cooldown text (ServiceUI.gd formats it with the time left), in
# two languages.
const ENTRY_TEXTS = {
	"en": {MARKET_KEY: "Mineral Market", SERVICES_KEY: "Services", "SERVICE_IN_COOLDOWN": "Available in: %s"},
	"de": {MARKET_KEY: "Mineralienmarkt", SERVICES_KEY: "Dienste", "SERVICE_IN_COOLDOWN": "Verfuegbar in: %s"},
}
const MANIFEST = "res://MarketAdvisor/Mod.manifest"
const SETTINGS_SCRIPT = "res://MarketAdvisor/Settings.gd"
const UI_SCRIPT = "res://MarketAdvisor/SettingsUI.gd"
const MENU_SCRIPT = "res://enceladus/EnceladusMenu.gd"
const MARKET_SCENE = "res://enceladus/MineralMarket.tscn"
const PARKED_ROW = "Details/HeaderWithMoney/VBoxContainer/MarketAdvisorParked"
const SCREEN = "MarketAdvisorSettings"
const DAY = 86400
const HOUR = 3600
# The Services screen's rows with a monthly fee, as enceladus/Services.tscn sets them: each row's scene, then the values
# set on it (its node is named by its serviceName).
const SERVICES = [
	{"scene": "res://enceladus/ServiceUIInsurance.tscn", "serviceName": "SERVICE_JAMESON", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 50000.0},
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_SALVAGE_LICENCE", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 300000.0},
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_SIMULATOR", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 4000.0},
]
const ADVISOR_SCRIPT = "res://MarketAdvisor/Advisor.gd"

var settings = null
var ma = null # the settings script, for its constants
var changes = 0 # settingsChanged signals counted
var rng = RandomNumberGenerator.new()

func _countChange():
	changes += 1

# The game's start (CurrentGame.gd getGameStartTime), a date its calendar knows.
func gameStart():
	return OS.get_unix_time_from_datetime({"year": 2273, "month": 9, "day": 16, "hour": 11, "minute": 50, "second": 0}) - 96 * HOUR

# A save loaded into CurrentGame.state, `at` that time: no money, minerals, insurance, log or ship maintenance, and in
# the UI store only `ui`. The prices are drawn from the save's seed, as the game draws them on loading.
func loadSave(at, ui = {}):
	CurrentGame.state = {"seed": 0, "time": at, "crew": {}, "ui": ui, "insurance": 0, "storage": {"minerals": {}, "oddities": []}, "logs": [], "ship": {}}
	CurrentGame.time = at
	CurrentGame.money = 0
	CurrentGame.initializePrices()

# In-game time passing, with the game's day and hour signals (CurrentGame.gd advanceTimeBySeconds; the stub's sends
# none).
func advance(seconds):
	var day = floor(CurrentGame.time / DAY)
	var hour = floor(CurrentGame.time / HOUR)
	CurrentGame.advanceTimeBySeconds(seconds)
	if day != floor(CurrentGame.time / DAY):
		CurrentGame.emit_signal("dayPassed")
	if hour != floor(CurrentGame.time / HOUR):
		CurrentGame.emit_signal("hourPassed")
	yield(frames(3), "completed")

func addTranslations():
	for locale in ENTRY_TEXTS:
		var t = Translation.new()
		t.locale = locale
		for key in ENTRY_TEXTS[locale]:
			t.add_message(key, ENTRY_TEXTS[locale][key])
		TranslationServer.add_translation(t)

func manifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return manifest.get_value(section, key)

# The station as enceladus/Enceladus.tscn nests the menu and the right-hand screens. The screens have the station's
# values (hidden, shrunk to the right, a panel of their own), with a width that leaves the menu free to click in the
# harness's window. `services`: the Services screen's rows, as SERVICES lists them.
func station(withMarket = true, services = SERVICES):
	var root = MarginContainer.new(); root.name = "MarginContainer"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var hbox = HBoxContainer.new(); hbox.name = "HBoxContainer"
	root.add_child(hbox)
	var menu = VBoxContainer.new(); menu.name = "Options"
	menu.set_script(load(MENU_SCRIPT))
	addMenuTooltips(menu)
	var marketEntry = Button.new(); marketEntry.name = "MineralMarket"; marketEntry.text = MARKET_KEY
	menu.add_child(marketEntry)
	var servicesEntry = Button.new(); servicesEntry.name = "Services"; servicesEntry.text = SERVICES_KEY
	menu.add_child(servicesEntry)
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
	var market = null
	if withMarket:
		market = load(MARKET_SCENE).instance()
		market.name = "MineralMarket"
		stationScreen(market)
		screens.add_child(market)
		marketEntry.connect("pressed", market, "_on_MineralMarket_pressed")
	var servicesScreen = PanelContainer.new(); servicesScreen.name = "Services"
	stationScreen(servicesScreen)
	var node = servicesScreen
	for part in [["VB", VBoxContainer], ["MarginContainer", MarginContainer], ["ScrollContainer", ScrollContainer], ["MarginContainer", MarginContainer], ["Items", VBoxContainer]]:
		var child = part[1].new()
		child.name = part[0]
		node.add_child(child)
		node = child
	var rows = {}
	for spec in services:
		var row = load(spec.scene).instance()
		row.name = spec.serviceName
		for key in spec:
			if key != "scene":
				row.set(key, spec[key])
		node.add_child(row)
		rows[spec.serviceName] = row
	screens.add_child(servicesScreen)
	var tuning = PanelContainer.new(); tuning.name = "Tuning"
	stationScreen(tuning)
	tuning.theme = Theme.new()
	var tuningVb = VBoxContainer.new(); tuningVb.name = "VB"
	tuning.add_child(tuningVb)
	var windowMargin = MarginContainer.new(); windowMargin.name = "WindowMargin"
	windowMargin.theme = Theme.new()
	windowMargin.add_constant_override("margin_top", 7)
	tuningVb.add_child(windowMargin)
	var window = PanelContainer.new(); window.name = "Window"
	window.add_stylebox_override("panel", StyleBoxFlat.new())
	windowMargin.add_child(window)
	var windowVb = VBoxContainer.new(); windowVb.name = "VBoxContainer"
	window.add_child(windowVb)
	var inside = MarginContainer.new(); inside.name = "MarginContainer"
	inside.add_constant_override("margin_left", 5)
	windowVb.add_child(inside)
	screens.add_child(tuning)
	add_child(root)
	return {"root": root, "menu": menu, "marketEntry": marketEntry, "servicesEntry": servicesEntry, "logs": logs, "screens": screens, "market": market, "services": rows, "servicesScreen": servicesScreen, "tuning": tuning}

func stationScreen(screen):
	screen.visible = false
	screen.rect_min_size = Vector2(600, 0)
	screen.size_flags_horizontal = Control.SIZE_SHRINK_END
	screen.add_stylebox_override("panel", StyleBoxFlat.new())

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

# A press and release of a key, as Input delivers a player's, in the idle part of a frame.
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

func joyButton(index):
	var event = InputEventJoypadButton.new()
	event.button_index = index
	return event

# A press and release of a gamepad button (JOY_*), then a frame: Input hands parsed events on at the next one.
func tapJoy(index):
	yield(tap(joyButton(index)), "completed")
	yield(get_tree(), "idle_frame")

# A gamepad button pressed, or released, and left so, as Input delivers it (Input.is_joy_button_pressed follows).
func holdJoy(index, pressed):
	yield(get_tree(), "idle_frame")
	var event = joyButton(index)
	event.pressed = pressed
	Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# The game's bindings (its project.godot): ui_cancel is Esc, pause is Esc too.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["pause", escKey()]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

func row(s, m):
	return s.market._maSlider(m)

# A tonne's price today, as the slider sells it.
func tonne(s, m):
	var r = row(s, m)
	return r.multiplier * r.price

func held(s, m) -> int:
	return int(floor(CurrentGame.getMinerals(m) / float(row(s, m).multiplier)))

func names(s) -> Array:
	return s.market._maNames()

func parked(m) -> int:
	var record = settings.getParked()
	return int(record.get(m, 0)) if record != null else -1

func cheapestTonne(s, minerals) -> float:
	var cheapest = INF
	for m in minerals:
		cheapest = min(cheapest, tonne(s, m))
	return cheapest

func marked(s, button, key) -> bool:
	return button.text == tr(s.menu._MA_ALERT) % tr(key)

func advice(s) -> String:
	return s.market._maAdvice.text

func button(s):
	return s.market._maButton

# The Trade button pressed, as a click presses it; a disabled one does nothing.
func trade(s):
	var b = button(s)
	if not b.disabled:
		b.emit_signal("pressed")
	yield(frames(2), "completed")

# What changes the advice without the money or the time changing (the crew, as the game signals it).
func refresh():
	CurrentGame.emit_signal("employmentChanged")
	yield(frames(3), "completed")

func entry():
	return CurrentGame.state.ui.get(settings.modId())

# The parked row's expected value: the parked tonnes at each slider's price for the day, written as the header's
# Money label writes your cash.
func parkedText(s) -> String:
	var worth = 0.0
	for m in names(s):
		worth += max(parked(m), 0) * tonne(s, m)
	var money = s.market.get_node("Details/HeaderWithMoney/VBoxContainer/Money")
	return money.format % CurrentGame.formatThousands(int(round(worth)))

func parkedValue(s) -> String:
	var r = s.market.get_node_or_null(PARKED_ROW)
	return r.get_node("Insurance").text if r != null else "no row"

func run():
	bindGameKeys()
	addTranslations()
	TranslationServer.set_locale("en")
	rng.seed = 20261120
	if not hasMod("MarketAdvisor"):
		yield(control(), "completed")
		return
	ma = load(SETTINGS_SCRIPT)
	settings = ma.shared()
	settings.connect("settingsChanged", self, "_countChange")
	model()
	tolerance()
	advisor()
	yield(market(), "completed")
	yield(alerts(), "completed")
	yield(screen(), "completed")
	yield(year(false), "completed")
	yield(year(true), "completed")

# The game alone: the entry keeps its key, the market has no row of the mod's, and Shift+Click opens the market.
func control():
	loadSave(gameStart() + 400 * DAY)
	CurrentGame.money = 10500000
	var s = station()
	yield(frames(5), "completed")
	check("control: the market's entry keeps its key, and has no tooltip", s.marketEntry.text == MARKET_KEY and s.marketEntry.hint_tooltip == "", s.marketEntry.text)
	check("control: the market has no row of the mod's, at the bottom or in the header", not s.market.has_node("Details/MarketAdvisor") and not s.market.has_node(PARKED_ROW))
	# The gamepad twin of Shift+Click, with the buttons of Badge.gd's PAD_MODIFIER and PAD_BUTTON (a control run can't
	# read them).
	s.marketEntry.grab_focus()
	yield(holdJoy(JOY_L2, true), "completed")
	yield(tapJoy(JOY_XBOX_X), "completed")
	yield(holdJoy(JOY_L2, false), "completed")
	yield(frames(5), "completed")
	check("control: PAD_MODIFIER+PAD_BUTTON on the highlighted entry opens nothing", not s.market.visible and s.screens.get_node_or_null(SCREEN) == null)
	click(s.marketEntry, true)
	yield(frames(40), "completed")
	check("control: Shift+Click opens the market", s.market.visible)
	yield(freeStation(s), "completed")

# The settings model, alone.
func model():
	loadSave(gameStart())
	settings.loadFromState()
	check("settings: one shared instance", load(SETTINGS_SCRIPT).shared() == settings)
	var defaults = true
	for key in ma.SETTINGS:
		defaults = defaults and settings.getValue(key) == ma.SETTINGS[key].default
	check("settings: a save without the mod's entry has the defaults, and no parked tonnes", defaults and settings.getParked() == null)
	check("settings: the cash reserve is the amount times ten to the power", settings.floorCash() == settings.getValue("cashAmount") * pow(10, settings.getValue("cashPower")), settings.floorCash())
	# Every amount at every power, both notations: the text reads back as the cash reserve, a whole number below a
	# thousand before its suffix, or the amount before its power of ten.
	var amounts = ma.SETTINGS.cashAmount
	var powers = ma.SETTINGS.cashPower
	var wrong = []
	for a in range(amounts.min, amounts.max + 1):
		for p in range(powers.min, powers.max + 1):
			var plain = ma.formatFloor(a, p, false)
			var scientific = ma.formatFloor(a, p, true)
			if floorValue(plain, false) != a * pow(10, p) or floorValue(scientific, true) != a * pow(10, p):
				wrong.append([a, p, plain, scientific])
	check("settings: every cash reserve, written plain (500K) or in scientific notation (5e5), reads back as itself", wrong.empty(), wrong)
	changes = 0
	settings.setValue("cashAmount", ma.SETTINGS.cashAmount.default)
	check("settings: an unchanged value stores nothing and signals nothing", entry() == null and changes == 0)
	settings.setValue("cashAmount", 7)
	var saved = entry()
	var complete = saved is Dictionary
	for key in ma.SETTINGS:
		complete = complete and saved.has(key) and saved[key] == settings.getValue(key)
	var version = "%d.%d.%d" % [manifestValue("version", "version_major"), manifestValue("version", "version_minor"), manifestValue("version", "version_bugfix")]
	check("settings: a change is stored under the manifest's id, with the format and mod versions and every setting, and signalled once", complete and saved.formatVersion == ma.FORMAT_VERSION and saved.modVersion == version and changes == 1 and settings.modId() == manifestValue("mod_information", "id"), saved)
	settings.setValue("cashAmount", amounts.max + 3)
	var high = settings.getValue("cashAmount")
	settings.setValue("cashAmount", 3.4)
	var snapped = settings.getValue("cashAmount")
	settings.setValue("cashPower", powers.min - 2)
	var low = settings.getValue("cashPower")
	settings.setValue("cashAmount", "lots")
	var text = settings.getValue("cashAmount")
	settings.setValue("tradeAll", 1)
	check("settings: a slider's value kept in its range and snapped to its step, its default for one that isn't a number; a switch's default for one that isn't a bool", high == amounts.max and snapped == 3 and low == powers.min and text == amounts.default and settings.getValue("tradeAll") == ma.SETTINGS.tradeAll.default, [high, snapped, low, text])
	var minerals = CurrentGame.mineralPrices.keys()
	var only = settings.parkingMinerals(minerals)
	settings.setValue("tradeAll", true)
	var all = settings.parkingMinerals(minerals)
	var each = true
	for m in minerals:
		each = each and all.count(m) == 1
	check("settings: cash goes into MAIN_MINERAL alone, or with Trade all ores into every mineral of the market, MAIN_MINERAL first", only == [ma.MAIN_MINERAL] and all.size() == minerals.size() and all[0] == ma.MAIN_MINERAL and each, [only, all])
	changes = 0
	var tonnes = {ma.MAIN_MINERAL: 12}
	settings.setParked(tonnes)
	tonnes[ma.MAIN_MINERAL] = 99
	check("settings: the parked tonnes stored with the save, as a copy, without a signal", same(entry().parked, {ma.MAIN_MINERAL: 12}) and settings.getParked()[ma.MAIN_MINERAL] == 12 and changes == 0, entry().parked)
	CurrentGame.state.ui = parse_json(to_json(CurrentGame.state.ui))
	var expected = settings.cfg.duplicate()
	settings.cfg = {}
	for key in ma.SETTINGS:
		settings.cfg[key] = ma.SETTINGS[key].default
	settings.parked = null
	settings.loadFromState()
	var back = true
	for key in expected:
		back = back and same(settings.getValue(key), expected[key])
	check("settings: read back after a JSON round trip of the save, the parked tonnes as whole tonnes", back and typeof(settings.getParked()[ma.MAIN_MINERAL]) == TYPE_INT and settings.getParked()[ma.MAIN_MINERAL] == 12, settings.getParked())
	CurrentGame.state.ui[settings.modId()] = {"cashAmount": "lots", "scientific": 3, "parked": {"Be": -5, "W": "x", "Fe": 12.7}}
	settings.loadFromState()
	check("settings: a hand-edited entry read safely (defaults for what isn't a number or a bool, parked tonnes whole and not below 0)", settings.getValue("cashAmount") == amounts.default and settings.getValue("scientific") == ma.SETTINGS.scientific.default and same(settings.getParked(), {"Be": 0, "Fe": 12}), settings.getParked())
	CurrentGame.state.ui[settings.modId()] = "garbage"
	settings.loadFromState()
	check("settings: an entry that isn't a dictionary gives the defaults and no parked tonnes", settings.getValue("tradeAll") == ma.SETTINGS.tradeAll.default and settings.getParked() == null)

# The cash reserve's tolerance: its range, how the screens write amounts and the range, and the slider's conversion.
func tolerance():
	loadSave(gameStart())
	settings.loadFromState()
	var written = [[450000, false, "450K"], [46500, false, "46.5K"], [1200000, false, "1.2M"], [10170000000, false, "10.17B"], [999, false, "999"], [1500, false, "1.5K"], [0, false, "0"], [450000, true, "4.5e5"], [500000, true, "5e5"], [10170000000, true, "1.017e10"], [0, true, "0"]]
	var wrong = []
	for w in written:
		if ma.formatCash(w[0], w[1]) != w[2]:
			wrong.append([w, ma.formatCash(w[0], w[1])])
	check("tolerance: any amount written with the largest suffix that fits and no trailing zeros, or in scientific notation", wrong.empty(), wrong)
	var t = ma.SETTINGS.tolerance
	var reserve = settings.floorCash()
	var bounds = [int(round(reserve * (1 - t.default))), int(round(reserve * (1 + t.default)))]
	check("tolerance: the range is the reserve less and plus its tolerance's share, in whole E$", same(settings.floorRange(), bounds), settings.floorRange())
	check("tolerance: the cash reserve shown as its range", settings.floorText() == tr(ma.RANGE) % [ma.formatCash(bounds[0], false), ma.formatCash(bounds[1], false)] and tr(ma.RANGE) != ma.RANGE, settings.floorText())
	settings.setValue("scientific", true)
	check("tolerance: and in scientific notation", settings.floorText() == tr(ma.RANGE) % [ma.formatCash(bounds[0], true), ma.formatCash(bounds[1], true)], settings.floorText())
	settings.setValue("scientific", false)
	settings.setValue("tolerance", t.min)
	check("tolerance: none, the reserve alone, as formatFloor writes it", same(settings.floorRange(), [int(reserve), int(reserve)]) and settings.floorText() == ma.formatFloor(settings.getValue("cashAmount"), settings.getValue("cashPower"), false), settings.floorText())
	settings.setValue("tolerance", t.default)
	settings.setValue("cashAmount", 0)
	check("tolerance: a reserve of 0 shows 0, not a range", settings.floorText() == "0", settings.floorText())
	settings.setValue("cashAmount", ma.SETTINGS.cashAmount.default)
	settings.setValue("tolerance", t.max + 0.5)
	var high = settings.getValue("tolerance")
	settings.setValue("tolerance", t.default + t.step * 0.3)
	var snapped = settings.getValue("tolerance")
	check("tolerance: kept in its range and snapped to its step", near(high, t.max) and near(snapped, t.default), [high, snapped])
	check("tolerance: shown as the screen shows it, and back", near(settings.toShown("tolerance", t.default), t.default * t.shown) and near(settings.fromShown("tolerance", t.default * t.shown), t.default) and settings.toShown("cashAmount", 3) == 3)
	settings.setValue("tolerance", t.default)

func near(a, b) -> bool:
	return abs(a - b) < 1e-9

# The advice alone (Advisor.gd plan) around the cash reserve's range: 500,000 E$, from 450,000 to 550,000 E$ (10 %), in
# Be at 10,000 E$ a tonne. Nothing inside the range; outside it, trades that bring the cash back to the reserve itself;
# short only where selling everything can't reach the range. With no tolerance, the range is the reserve alone, and the
# advice is as before: a tonne's price above it is bought, any shortfall sold.
func advisor():
	var advisorScript = load(ADVISOR_SCRIPT)
	var some = {"Be": 100, "W": 0}
	var few = {"Be": 10, "W": 0}
	var p = advisorScript.plan(planInput(530000, 450000, 550000, some))
	check("advice: inside the range, above the reserve, nothing to trade", p.now.empty() and not p.short, p)
	p = advisorScript.plan(planInput(470000, 450000, 550000, some))
	check("advice: inside the range, below the reserve, nothing to trade", p.now.empty() and not p.short, p)
	p = advisorScript.plan(planInput(560000, 450000, 550000, some))
	check("advice: above the range, buys down to the reserve", same(p.now, [{"mineral": "Be", "from": 100, "to": 106}]) and p.cashAfter == 500000, p)
	p = advisorScript.plan(planInput(440000, 450000, 550000, some))
	check("advice: below the range, sells up to the reserve", same(p.now, [{"mineral": "Be", "from": 100, "to": 94}]) and p.cashAfter == 500000 and not p.short, p)
	p = advisorScript.plan(planInput(380000, 450000, 550000, few))
	check("advice: everything sold reaches the range but not the reserve: not short", same(p.now, [{"mineral": "Be", "from": 10, "to": 0}]) and p.cashAfter == 480000 and not p.short, p)
	p = advisorScript.plan(planInput(300000, 450000, 550000, few))
	check("advice: everything sold doesn't reach the range: short", p.cashAfter == 400000 and p.short, p)
	p = advisorScript.plan(planInput(505000, 500000, 500000, some))
	var above = advisorScript.plan(planInput(515000, 500000, 500000, some))
	var below = advisorScript.plan(planInput(495000, 500000, 500000, some))
	check("advice: with no tolerance, less than a tonne above the reserve is nothing; a tonne above is bought, a shortfall sold", p.now.empty() and same(above.now, [{"mineral": "Be", "from": 100, "to": 101}]) and above.cashAfter == 505000 and same(below.now, [{"mineral": "Be", "from": 100, "to": 99}]) and below.cashAfter == 505000, [p, above, below])

# Advisor.gd plan's input: a reserve of 500,000 E$ with the range given, Be the parking mineral at 10 E$/kg (its
# average), every tonne of it parked, no forecast (the ship ready).
func planInput(cash, low, high, held) -> Dictionary:
	return {
		"cash": float(cash), "floor": 500000.0, "low": low, "high": high,
		"parking": ["Be"], "sellOre": true, "minerals": ["Be", "W"],
		"held": held, "parked": {"Be": held.Be},
		"price": {"Be": 10.0, "W": 20.0}, "average": {"Be": 10.0},
		"future": {}, "maxTonnes": 100000, "kgPerTonne": 1000.0,
	}

# A cash reserve as formatFloor writes it, read back as a number; -1 for a text it shouldn't write.
func floorValue(text: String, scientific: bool) -> float:
	if text == "0":
		return 0.0
	if scientific:
		var parts = text.split("e")
		if parts.size() != 2 or not parts[0].is_valid_integer() or not parts[1].is_valid_integer() or int(parts[0]) > 9:
			return -1.0
		return int(parts[0]) * pow(10, int(parts[1]))
	for i in range(ma.THOUSANDS_SUFFIXES.size() - 1, -1, -1):
		var suffix = ma.THOUSANDS_SUFFIXES[i]
		var number = text.substr(0, text.length() - suffix.length())
		if text.ends_with(suffix) and number.is_valid_integer() and int(number) < 1000:
			return int(number) * pow(1000, i)
	return -1.0

# The market screen, the Trade button and the parked row.
func market():
	var start = gameStart() + 400 * DAY
	loadSave(start)
	var s = station()
	yield(frames(5), "completed")
	var codeKeys = s.market.get_script().get_script_constant_map()
	var listMargin = s.market.get_node("Details/MarginContainer")
	var adviceRow = s.market.get_node_or_null("Details/MarketAdvisor")
	check("market: the mod's row at the bottom, inside the list's side margins", adviceRow != null and adviceRow.get_index() == adviceRow.get_parent().get_child_count() - 1 and adviceRow.get_constant("margin_left") == listMargin.get_constant("margin_left") and adviceRow.get_constant("margin_right") == listMargin.get_constant("margin_right"))
	check("market: its Trade button, disabled with nothing to trade", button(s).text == codeKeys._MA_TRADE and button(s).disabled)
	check("market: no cash and no ore: the advice says the cash reserve is out of reach", advice(s) == tr(codeKeys._MA_SHORT) % settings.floorText(), advice(s))
	var nothing = entry().parked is Dictionary and entry().parked.has(ma.MAIN_MINERAL)
	for m in entry().parked if nothing else []:
		nothing = nothing and entry().parked[m] == 0
	check("market: a new save takes what it holds of the parking minerals (nothing) as parked", nothing and parked(ma.MAIN_MINERAL) == 0, entry())
	check("market: the line comparing today's prices with the chart's average names the parking mineral", s.market._maPrices.text.begins_with(tr(codeKeys._MA_VS_AVERAGE).split("%s")[0]) and s.market._maPrices.text.find(ma.MAIN_MINERAL) >= 0, s.market._maPrices.text)
	var box = s.market.get_node("Details/HeaderWithMoney/VBoxContainer")
	var r = s.market.get_node_or_null(PARKED_ROW)
	check("market: the parked row shown in the header, right under your cash", r != null and r.visible and r.get_index() == box.get_node("Money").get_index() + 1)
	if r == null:
		yield(freeStation(s), "completed")
		return
	check("market: its caption, the mod's text", r.get_node("InsuranceLabel").text == codeKeys._MA_PARKED and tr(codeKeys._MA_PARKED) != codeKeys._MA_PARKED)
	check("market: a copy of the game's insurance row without the insurance display's script and sound", r.get_node("Insurance").get_script() == null and not r.has_node("Insurance/Pinger"))
	check("market: the game's insurance row stays hidden", not box.get_node("Insurence").visible)
	check("market: nothing parked, nothing worth", parkedValue(s) == parkedText(s) and parkedValue(s) == box.get_node("Money").format % CurrentGame.formatThousands(0), parkedValue(s))
	var floorCash = settings.floorCash()
	var main = ma.MAIN_MINERAL
	CurrentGame.changeMoney(10500000.0)
	yield(frames(3), "completed")
	var promised = s.market._maPlan.cashAfter
	check("market: with cash above the reserve, the advice is to buy, and says what it leaves", not s.market._maPlan.now.empty() and advice(s).find(tr(codeKeys._MA_LEAVES) % CurrentGame.formatThousands(int(round(promised)))) >= 0 and not button(s).disabled, advice(s))
	check("market: the market's entry has its alert mark while a trade is due", marked(s, s.marketEntry, MARKET_KEY), s.marketEntry.text)
	var trades = CurrentGame.logs.size()
	yield(trade(s), "completed")
	var cash = CurrentGame.getMoney()
	check("market: Trade buys %s, within one tonne's price above the cash reserve" % main, cash >= floorCash and cash < floorCash + tonne(s, main), cash)
	check("market: what the advice said it leaves", abs(cash - promised) < 1.0, [cash, promised])
	check("market: %s alone bought, and parked" % main, held(s, main) > 0 and parked(main) == held(s, main) and held(s, "W") == 0 and same(entry().parked, settings.getParked()), settings.getParked())
	var logged = CurrentGame.logs.slice(trades, CurrentGame.logs.size() - 1) if CurrentGame.logs.size() > trades else []
	check("market: bought through the market's slider: its holdings and its trade log", row(s, main).ownedLabel.text == CurrentGame.formatThousands(held(s, main)) and logged.size() == 1 and logged[0][0] == "LOG_EVENT_TRADE" and logged[0][1].has(main), logged)
	check("market: no alert mark once traded, the button disabled", not marked(s, s.marketEntry, MARKET_KEY) and button(s).disabled and advice(s) == tr(codeKeys._MA_AT_FLOOR) % settings.floorText(), advice(s))
	check("market: the parked row shows what the parked tonnes sell for today", parkedValue(s) == parkedText(s) and parkedValue(s) != box.get_node("Money").format % CurrentGame.formatThousands(0), parkedValue(s))
	var before = parkedValue(s)
	yield(advance(DAY), "completed")
	check("market: a day later, at the new day's prices", parkedValue(s) == parkedText(s) and parkedValue(s) != before, [before, parkedValue(s)])
	# Ore brought back, with the ship ready now: sold today, and the cash parked again.
	CurrentGame.changeMinerals("W", 300 * row(s, "W").multiplier)
	yield(refresh(), "completed")
	var sells = false
	for t in s.market._maPlan.now:
		sells = sells or (t.mineral == "W" and t.to == 0)
	check("market: ore brought back with the ship ready is sold now", sells and parked("W") <= 0, s.market._maPlan.now)
	yield(trade(s), "completed")
	cash = CurrentGame.getMoney()
	check("market: and the cash parked in %s again" % main, held(s, "W") == 0 and cash >= floorCash and cash < floorCash + tonne(s, main) and parked(main) == held(s, main), cash)
	# A save without a record of the parked tonnes takes what it holds of the parking minerals, once.
	CurrentGame.state.ui[settings.modId()].erase("parked")
	settings.loadFromState()
	var none = settings.getParked() == null
	yield(refresh(), "completed")
	check("market: a save without a record takes its %s as parked, once, and has nothing to trade" % main, none and parked(main) == held(s, main) and s.market._maPlan.now.empty())
	# A sale by hand with the slider takes parked tonnes too: the record follows.
	var r0 = row(s, main)
	r0.slider.value = held(s, main) - 1
	yield(refresh(), "completed")
	check("market: parked tonnes sold by hand leave the record", parked(main) == held(s, main), [parked(main), held(s, main)])
	# The focus chain, set as the screen opens, goes on down to the Trade button.
	click(s.marketEntry, false)
	yield(frames(40), "completed")
	var last = s.market.minerals[s.market.minerals.size() - 1].slider
	check("market: a plain click opens the market, and its sliders' focus chain goes on down to the Trade button", s.market.visible and last.focus_neighbour_bottom == button(s).get_path() and button(s).focus_neighbour_top == last.get_path())
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	yield(freeStation(s), "completed")
	yield(allOres(start + 40 * DAY), "completed")
	yield(full(start + 80 * DAY), "completed")

# Trade all ores: the cash spread over the ores cheapest against their average, ore brought back sold on its best day,
# and the cash reserve raised.
func allOres(at):
	loadSave(at)
	var s = station()
	yield(frames(5), "completed")
	settings.setValue("tradeAll", true)
	CurrentGame.changeMoney(25000000.0)
	yield(frames(3), "completed")
	var floorCash = settings.floorCash()
	yield(trade(s), "completed")
	var cash = CurrentGame.getMoney()
	check("all ores: within the cheapest tonne's price above the cash reserve", cash >= floorCash and cash < floorCash + cheapestTonne(s, names(s)), cash)
	var bought = 0
	var asBought = true
	for m in names(s):
		if held(s, m) > 0:
			bought += 1
		asBought = asBought and parked(m) == held(s, m)
	check("all ores: more than one ore bought, each parked as bought", bought >= 2 and asBought, settings.getParked())
	# Ore brought back, with the ship ready in two days: each ore sold on the day the chart forecasts best, never the
	# parked tonnes, and the cash parked again.
	var parkedBefore = settings.getParked().duplicate()
	CurrentGame.changeMinerals("Pt", 60 * row(s, "Pt").multiplier)
	CurrentGame.changeMinerals("Fe", 200 * row(s, "Fe").multiplier)
	CurrentGame.state.ship.maintaineceUntil = CurrentGame.getInGameTimestamp() + 2 * DAY
	yield(refresh(), "completed")
	var onlyOre = true
	for day in range(3):
		for t in s.market._maPlan.now:
			if t.to < t.from and CurrentGame.getMoney() >= floorCash:
				onlyOre = onlyOre and t.to >= parkedBefore.get(t.mineral, 0)
		yield(trade(s), "completed")
		if day < 2:
			yield(advance(DAY), "completed")
	check("all ores: during the stay only ore brought back is sold, never parked tonnes", onlyOre)
	cash = CurrentGame.getMoney()
	var stored = 0
	for m in names(s):
		stored += held(s, m) - parked(m)
	check("all ores: the stay ends at the cash reserve, with no ore left beyond the parked tonnes", cash >= floorCash and cash < floorCash + cheapestTonne(s, names(s)) and stored == 0, [cash, stored])
	# A higher cash reserve: parked ore sold, ending within a tonne of the cheapest ore sold that has tonnes left.
	settings.setValue("cashAmount", 9)
	settings.setValue("cashPower", 6)
	yield(frames(3), "completed")
	floorCash = settings.floorCash()
	var sold = []
	for t in s.market._maPlan.now:
		if t.to < t.from:
			sold.append(t.mineral)
	yield(trade(s), "completed")
	cash = CurrentGame.getMoney()
	var left = []
	for m in sold:
		if held(s, m) > 0:
			left.append(m)
	check("all ores: a higher cash reserve sells parked ore, ending within a tonne of the cheapest ore sold that has tonnes left", not sold.empty() and cash >= floorCash and cash < floorCash + (cheapestTonne(s, left) if not left.empty() else INF), [cash, sold, left])
	asBought = true
	for m in names(s):
		asBought = asBought and parked(m) == held(s, m)
	check("all ores: the parked tonnes follow, and the parked row with them", asBought and parkedValue(s) == parkedText(s), parkedValue(s))
	settings.setValue("cashAmount", ma.SETTINGS.cashAmount.default)
	settings.setValue("cashPower", ma.SETTINGS.cashPower.default)
	settings.setValue("tradeAll", false)
	yield(freeStation(s), "completed")

# Every tonne the market allows already held: nothing to trade, and no alert mark.
func full(at):
	loadSave(at)
	var s = station()
	yield(frames(5), "completed")
	var main = ma.MAIN_MINERAL
	var r = row(s, main)
	CurrentGame.changeMinerals(main, r.maxOre * r.multiplier)
	CurrentGame.changeMoney(1e12)
	yield(frames(3), "completed")
	var codeKeys = s.market.get_script().get_script_constant_map()
	check("full: no room left, nothing to trade, and the advice says so", s.market._maPlan.capped and s.market._maPlan.now.empty() and advice(s) == tr(codeKeys._MA_CAPPED) % [main, CurrentGame.formatThousands(r.maxOre)], advice(s))
	check("full: no alert mark", not marked(s, s.marketEntry, MARKET_KEY))
	yield(freeStation(s), "completed")

# The station menu: the market entry's tooltip and alert mark in two languages; the Services entry left alone.
func alerts():
	loadSave(gameStart() + 500 * DAY)
	var s = station()
	yield(frames(5), "completed")
	var menuKeys = s.menu
	check("menu: the mod's texts are loaded (i18n/en.po)", tr(menuKeys._MA_SETTINGS_TOOLTIP) != menuKeys._MA_SETTINGS_TOOLTIP and tr(menuKeys._MA_ALERT) != menuKeys._MA_ALERT)
	check("menu: the market entry's Shift badge has the tooltip, which tells about Shift+Click; the entry has none of its own", badgeTip(s.marketEntry) == tr(menuKeys._MA_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")] and s.marketEntry.hint_tooltip == "", [badgeTip(s.marketEntry), s.marketEntry.hint_tooltip])
	check("menu: no alert marks with nothing to do", s.marketEntry.text == MARKET_KEY and s.servicesEntry.text == SERVICES_KEY, [s.marketEntry.text, s.servicesEntry.text])
	CurrentGame.changeMoney(10500000.0)
	yield(frames(3), "completed")
	s.services.SERVICE_JAMESON.checkPrice()
	check("menu: the market entry's alert mark while a trade is due", marked(s, s.marketEntry, MARKET_KEY), s.marketEntry.text)
	check("menu: the Services entry left alone, even while Jameson's Insurance can be bought (ServiceNotifier marks it)", s.servicesEntry.text == SERVICES_KEY and not s.services.SERVICE_JAMESON.buyButton.disabled, s.servicesEntry.text)
	TranslationServer.set_locale("de")
	yield(frames(2), "completed")
	check("menu: the alert mark follows a language change", s.marketEntry.text == tr(menuKeys._MA_ALERT) % ENTRY_TEXTS.de[MARKET_KEY], s.marketEntry.text)
	TranslationServer.set_locale("en")
	yield(frames(2), "completed")
	yield(freeStation(s), "completed")
	var bare = station(false)
	yield(frames(5), "completed")
	check("menu: without the market screen, no tooltip", bare.marketEntry.hint_tooltip == "")
	click(bare.marketEntry, true)
	yield(frames(5), "completed")
	check("menu: and Shift+Click opens no settings", bare.screens.get_node_or_null(SCREEN) == null)
	yield(freeStation(bare), "completed")

# The settings screen, opened with Shift+Click on the market's entry.
func screen():
	loadSave(gameStart() + 600 * DAY)
	settings.loadFromState()
	var s = station()
	yield(frames(5), "completed")
	var ui = load(UI_SCRIPT).get_script_constant_map()
	s.marketEntry.disabled = true
	click(s.marketEntry, true)
	yield(frames(5), "completed")
	check("screen: Shift+Click on a disabled entry does nothing", s.screens.get_node_or_null(SCREEN) == null and not s.market.visible)
	s.marketEntry.disabled = false
	var stored = to_json(CurrentGame.state.ui)
	click(s.marketEntry, true)
	yield(frames(40), "completed")
	var screen = s.screens.get_node_or_null(SCREEN)
	check("screen: Shift+Click on the market's entry opens the settings, not the market", screen != null and screen.visible and not s.market.visible)
	if screen == null:
		yield(freeStation(s), "completed")
		return
	check("screen: opening it stores nothing", to_json(CurrentGame.state.ui) == stored)
	check("screen: the market's frame: theme, panel, width and place", screen.theme == s.market.theme and screen.get_stylebox("panel") == s.market.get_stylebox("panel") and screen.rect_min_size == s.market.rect_min_size and screen.size_flags_horizontal == s.market.size_flags_horizontal)
	var order = []
	for child in screen.get_node("VB").get_children():
		order.append(child.name)
	check("screen: titled by the market's entry; under the header, the description's window, then the groups", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == MARKET_KEY and order == ["HeaderWithMoney", "WindowMargin", "ScrollContainer"], order)
	var windowMargin = screen.get_node("VB/WindowMargin")
	var inside = screen.get_node("VB/WindowMargin/Window/MarginContainer")
	var gameMargin = s.tuning.get_node("VB/WindowMargin")
	var gameInside = s.tuning.get_node("VB/WindowMargin/Window/VBoxContainer/MarginContainer")
	var copied = windowMargin.theme == gameMargin.theme and inside.get_parent().get_stylebox("panel") == s.tuning.get_node("VB/WindowMargin/Window").get_stylebox("panel")
	for side in ["left", "top", "right", "bottom"]:
		copied = copied and windowMargin.get_constant("margin_" + side) == gameMargin.get_constant("margin_" + side) and inside.get_constant("margin_" + side) == gameInside.get_constant("margin_" + side)
	check("screen: the description's window copies the Tuning screen's: theme, margins around and inside, panel", copied)
	# The groups and rows the screen should have: each group of GROUPS, its settings in SETTINGS order, named by their
	# label.
	var groups = []
	for items in screen.get_node("VB/ScrollContainer").get_children():
		if items.name == "Items" and not items.is_queued_for_deletion():
			for g in items.get_children():
				if "tuning" in g:
					groups.append(g)
	var expected = []
	var keys = []
	for entry in ui.GROUPS:
		var labels = []
		for key in ma.SETTINGS:
			var setting = ma.SETTINGS[key]
			if setting.group == entry[0]:
				var arg = setting.get("labelArg", "")
				labels.append(tr(setting.label) if arg == "" else tr(setting.label) % tr(arg))
				keys.append(key)
		expected.append([entry[1], labels])
	var shown = []
	var rows = []
	for g in groups:
		var labels = []
		for r in g.get_children():
			if "tune" in r:
				labels.append(r.tuningItem)
				rows.append(r)
		shown.append([g.system, labels])
	check("screen: a group per GROUPS entry, in order, titled by it, with a row per setting of that group named by its label", same(shown, expected), shown)
	check("screen: the notation switch first", keys[0] == "scientific" and rows[0].get_script().resource_path.ends_with("TuningBoolValue.gd"))
	var values = true
	for i in rows.size():
		var setting = ma.SETTINGS[keys[i]]
		if setting.type == "bool":
			values = values and rows[i].get_node("HBoxContainer/Value").pressed == settings.getValue(keys[i])
		else:
			var slider = rows[i].get_node("HSlider")
			var key = keys[i]
			values = values and near(slider.min_value, settings.toShown(key, setting.min)) and near(slider.max_value, settings.toShown(key, setting.max)) and near(slider.step, settings.toShown(key, setting.step)) and near(slider.value, settings.toShown(key, settings.getValue(key)))
	check("screen: each switch and slider shows its setting, each slider with its range and step as the screen shows them", values)
	var amountRow = rows[keys.find("cashAmount")]
	var powerRow = rows[keys.find("cashPower")]
	var toleranceRow = rows[keys.find("tolerance")]
	var cashGroup = amountRow.get_parent()
	var total = cashGroup.get_node_or_null("CashTotal")
	check("screen: the power of ten's row shows the power it stands for", powerRow.get_node("HBoxContainer/Value").text == ma.formatFloor(1, settings.getValue("cashPower"), false), powerRow.get_node("HBoxContainer/Value").text)
	check("screen: under the cash group's rows, the cash reserve's row", total != null and total.get_index() == cashGroup.get_child_count() - 1 and total.get_index() > powerRow.get_index())
	var tol = ma.SETTINGS.tolerance
	check("screen: the tolerance's row between the power of ten's and the cash reserve's, in its unit", toleranceRow.get_index() == powerRow.get_index() + 1 and total != null and total.get_index() == toleranceRow.get_index() + 1 and toleranceRow.get_node("HBoxContainer/Unit").text == tol.unit and toleranceRow.get_node("HBoxContainer/Value").text == tol.format % settings.toShown("tolerance", tol.default), toleranceRow.get_node("HBoxContainer/Value").text)
	if total == null:
		yield(freeStation(s), "completed")
		return
	var reset = total.get_node("Reset")
	check("screen: named by its text, which can't be focused or clicked; its reset button keeps its room but can't be seen, pressed or focused", total.get_node("Name").text == tr(ui.CASH_TOTAL) and total.get_node("Name").focus_mode == Control.FOCUS_NONE and total.get_node("Name").mouse_filter == Control.MOUSE_FILTER_IGNORE and reset.modulate.a == 0.0 and reset.disabled and reset.focus_mode == Control.FOCUS_NONE and reset.mouse_filter == Control.MOUSE_FILTER_IGNORE and reset.visible)
	check("screen: its value is the cash reserve with its tolerance's range", total.get_node("Value").text == settings.floorText() and settings.floorText() == rangeText(settings.floorCash(), false), total.get_node("Value").text)
	yield(frames(3), "completed")
	var rightEdges = []
	for line in [amountRow.get_node("HBoxContainer"), powerRow.get_node("HBoxContainer"), total]:
		var value = line.get_node("Value")
		rightEdges.append(value.rect_global_position.x + value.rect_size.x)
	check("screen: its value right-aligned under the values of the two sliders without a unit (once laid out)", rightEdges[0] == rightEdges[1] and rightEdges[1] == rightEdges[2] and rightEdges[0] > 0, rightEdges)
	var description = screen.get_node("VB/WindowMargin/Window/MarginContainer/Description")
	var described = true
	for i in rows.size():
		var setting = ma.SETTINGS[keys[i]]
		var control = rows[i].get_node("HSlider") if setting.type == "float" else rows[i].get_node("HBoxContainer/Value")
		control.grab_focus()
		yield(frames(1), "completed")
		var arg = setting.get("descriptionArg", setting.get("labelArg", ""))
		var text = tr(setting.label + ui.DESCRIPTION_SUFFIX)
		if arg != "":
			text = text % tr(arg)
		described = described and description.text == text and text != setting.label + ui.DESCRIPTION_SUFFIX
	check("screen: focusing a row, a switch or a slider, shows its description, with the mineral it names", described)
	check("screen: focusing stores nothing", to_json(CurrentGame.state.ui) == stored)
	amountRow.get_node("HSlider").value = 3
	check("screen: moving the amount stores it, and the cash reserve's row follows", settings.getValue("cashAmount") == 3 and total.get_node("Value").text == settings.floorText() and settings.floorText() == rangeText(3 * pow(10, settings.getValue("cashPower")), false), total.get_node("Value").text)
	powerRow.get_node("HSlider").value = ma.SETTINGS.cashPower.max
	check("screen: moving the power stores it; its row shows the power and the cash reserve's row follows", settings.getValue("cashPower") == ma.SETTINGS.cashPower.max and powerRow.get_node("HBoxContainer/Value").text == ma.formatFloor(1, ma.SETTINGS.cashPower.max, false) and total.get_node("Value").text == settings.floorText())
	rows[0].get_node("HBoxContainer/Value").pressed = true
	check("screen: scientific notation on, both shown in it", settings.getValue("scientific") and powerRow.get_node("HBoxContainer/Value").text == ma.formatFloor(1, ma.SETTINGS.cashPower.max, true) and total.get_node("Value").text == rangeText(3 * pow(10, ma.SETTINGS.cashPower.max), true), total.get_node("Value").text)
	toleranceRow.get_node("HSlider").value = settings.toShown("tolerance", tol.min)
	check("screen: the tolerance at its lowest stores it, and the cash reserve's row shows the reserve alone", near(settings.getValue("tolerance"), tol.min) and total.get_node("Value").text == ma.formatFloor(3, ma.SETTINGS.cashPower.max, true), total.get_node("Value").text)
	toleranceRow.get_node("HSlider").value = settings.toShown("tolerance", tol.max)
	check("screen: at its highest, stored as a fraction, and the range follows", near(settings.getValue("tolerance"), tol.max) and total.get_node("Value").text == rangeText(3 * pow(10, ma.SETTINGS.cashPower.max), true), total.get_node("Value").text)
	toleranceRow.get_node("HBoxContainer/Reset").emit_signal("pressed")
	check("screen: its reset button puts back its default", near(settings.getValue("tolerance"), tol.default))
	rows[1].get_node("HSlider").grab_focus()
	rows[0].get_node("HBoxContainer/Value").grab_focus()
	yield(frames(1), "completed")
	check("screen: focusing the switch again doesn't switch it back", settings.getValue("scientific") and rows[0].get_node("HBoxContainer/Value").pressed)
	amountRow.get_node("HBoxContainer/Reset").emit_signal("pressed")
	check("screen: the amount's reset button puts back its default", settings.getValue("cashAmount") == ma.SETTINGS.cashAmount.default and total.get_node("Value").text == settings.floorText())
	var tradeAllRow = rows[keys.find("tradeAll")]
	tradeAllRow.get_node("HBoxContainer/Value").pressed = true
	check("screen: a switch stores what it shows", settings.getValue("tradeAll"))
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("screen: Esc closes it after the game's fade", not screen.visible)
	click(s.marketEntry, true)
	yield(frames(40), "completed")
	var reopened = screen.visible
	click(s.logs, false)
	yield(frames(40), "completed")
	check("screen: focusing another entry of the menu closes it", reopened and not screen.visible)
	# With a gamepad: the Shift badge reads the gamepad twin while the game is played with one, and PAD_BUTTON pressed on
	# the highlighted entry while PAD_MODIFIER is held opens the settings, as Shift+Click does (Badge.gd).
	var shiftBadge = s.menu._maShiftBadge
	var padModifier = shiftBadge.PAD_MODIFIER
	var padButton = shiftBadge.PAD_BUTTON
	var keyText = OS.get_scancode_string(KEY_SHIFT)
	var keyRead = shiftBadge._label.text
	Settings.controlScheme = Settings.control.gamepad
	var padRead = shiftBadge._label.text
	var padTip = shiftBadge.hint_tooltip
	Settings.controlScheme = Settings.control.keyMouse
	var keyTip = shiftBadge.hint_tooltip
	check("gamepad: the Shift badge reads Shift with keyboard and mouse, the gamepad twin with a gamepad, and Shift again", keyRead == keyText and padRead == shiftBadge.PAD_TEXT and shiftBadge._label.text == keyText, [keyRead, padRead, shiftBadge._label.text])
	var modName = manifestValue("mod_information", "name")
	var padKey = s.menu._MA_SETTINGS_TOOLTIP_PAD
	var padExpected = tr(padKey) % [shiftBadge.PAD_BUTTON_NAME, shiftBadge.PAD_MODIFIER_NAME, modName]
	check("gamepad: its tooltip tells about the gamepad twin with a gamepad, and about Shift+Click again with keyboard and mouse", padTip == padExpected and keyTip == tr(s.menu._MA_SETTINGS_TOOLTIP) % [keyText, modName] and tr(padKey) != padKey, [padTip, keyTip])
	# A gamepad shows no hover: with one, the badge's tooltip shows while the entry, where the D-pad lands, has the focus.
	shiftBadgeTipChecks("tooltip", s.marketEntry, s.logs, s.menu.get_node("PlaySoundsOnTheseButtons"), tr(s.menu._MA_SETTINGS_TOOLTIP) % [keyText, modName], padExpected)
	Settings.controlScheme = Settings.control.gamepad
	s.marketEntry.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: PAD_BUTTON alone on the highlighted entry does nothing", not screen.visible and not s.market.visible)
	yield(holdJoy(padModifier, true), "completed")
	s.marketEntry.disabled = true
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: PAD_MODIFIER+PAD_BUTTON on a disabled entry does nothing", not screen.visible and not s.market.visible)
	s.marketEntry.disabled = false
	s.logs.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: PAD_MODIFIER+PAD_BUTTON with another entry highlighted doesn't open these settings", not screen.visible and not s.market.visible)
	s.marketEntry.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: PAD_MODIFIER+PAD_BUTTON on the highlighted market entry opens the settings, not the market", screen.visible and not s.market.visible)
	yield(holdJoy(padModifier, false), "completed")
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("gamepad: closing them highlights the entry again", not screen.visible and s.marketEntry.has_focus())
	Settings.controlScheme = Settings.control.keyMouse
	for key in ma.SETTINGS:
		settings.setValue(key, ma.SETTINGS[key].default)
	yield(freeStation(s), "completed")

# The cash reserve's row's expected text for `reserve` E$ at the current tolerance: the range of the reserve less and
# plus its share, each end written by formatCash, or the reserve alone where the range is none.
func rangeText(reserve, scientific) -> String:
	var share = settings.getValue("tolerance")
	var low = int(round(reserve * (1 - share)))
	var high = int(round(reserve * (1 + share)))
	if low == high:
		return ma.formatCash(low, scientific)
	return tr(ma.RANGE) % [ma.formatCash(low, scientific), ma.formatCash(high, scientific)]

# A year of station stays from a new save with 100,000 E$: ore brought back each time, 1 to 3 days of maintenance, the
# Trade button pressed every day of the stay, money spent between stays. Every stay ends inside the cash reserve's range
# with the ore sold (or within a tonne above the reserve, where a tonne is more than the range above it), unless the
# market is full or the ore doesn't reach the range.
func year(all):
	loadSave(gameStart() + 30 * DAY)
	settings.loadFromState()
	var s = station()
	yield(frames(5), "completed")
	settings.setValue("tradeAll", all)
	CurrentGame.changeMoney(100000.0)
	yield(frames(3), "completed")
	var stays = 0
	var bad = []
	var end = CurrentGame.getInGameTimestamp() + 365 * DAY
	while CurrentGame.getInGameTimestamp() < end:
		stays += 1
		for m in ["Fe", "Pt", "Pd", "V", "H2O"]:
			CurrentGame.changeMinerals(m, rng.randi_range(0, 150) * row(s, m).multiplier)
		var days = rng.randi_range(1, 3)
		CurrentGame.state.ship.maintaineceUntil = CurrentGame.getInGameTimestamp() + days * DAY
		yield(refresh(), "completed")
		for day in range(days + 1):
			yield(trade(s), "completed")
			if day < days:
				yield(advance(DAY), "completed")
		var cash = CurrentGame.getMoney()
		var plan = s.market._maPlan
		var limit = 0.0
		for m in settings.parkingMinerals(names(s)):
			limit = max(limit, tonne(s, m))
		var bounds = settings.floorRange()
		if not plan.capped and not plan.short and (cash < bounds[0] or cash > max(bounds[1], settings.floorCash() + limit)):
			bad.append([stays, cash])
		for m in names(s):
			if held(s, m) != parked(m):
				bad.append([stays, m, held(s, m), parked(m)])
		CurrentGame.state.ship.maintaineceUntil = 0
		yield(advance(rng.randi_range(2, 6) * DAY), "completed")
		CurrentGame.changeMoney(- rng.randf_range(0, 400000))
		yield(frames(2), "completed")
	note("a year with Trade all ores %s: %d stays, %s E$ in cash, %s" % ["on" if all else "off", stays, CurrentGame.formatThousands(CurrentGame.getMoney()), parkedValue(s)])
	check("a year with Trade all ores %s: every stay ends inside the cash reserve's range with the ore sold" % ("on" if all else "off"), bad.empty() and stays > 30, bad)
	settings.setValue("tradeAll", false)
	yield(freeStation(s), "completed")

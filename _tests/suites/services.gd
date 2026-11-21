extends "res://suites/market.gd"

# ServiceNotifier: the station menu's Services entry shows an alert mark while a service whose switch is on can be
# bought, as the game's own row for it decides (enceladus/ServiceUI.gd checkPrice: its cooldown, its price against the
# money, its story condition; a compensation, enceladus/ServiceUIFactionChange.gd, costs nothing while there is none to
# pay), and opens the mod's settings with Shift+Click: a switch per service it watches (those with a cooldown or a
# faction to compensate), in a group per kind, with a description.
#
# The station is market.gd's (whose saves, time, clicks and translations this suite shares), without the Mineral
# Market, with rows of the Services screen at the game's values (enceladus/Services.tscn): a hotel (bought again at
# once), The Twins (a day's cooldown), the three that cost a monthly fee, and The Miner's Guild, whose price follows the
# miners' hostility and fear towards the player (the Factions stub's dispositions). The mod's texts are its i18n/en.po,
# and every expected text is built with tr() from the mod's keys. The control checks run on the game's own scripts.

const SN_MANIFEST = "res://ServiceNotifier/Mod.manifest"
const SN_SETTINGS_SCRIPT = "res://ServiceNotifier/Settings.gd"
const SN_UI_SCRIPT = "res://ServiceNotifier/SettingsUI.gd"
const SN_SCREEN = "ServiceNotifierSettings"
const SN_ROW_SWITCH = "HBoxContainer/Value"
# The rows, in the Services screen's order: the scene, then the values set on it (its node is named by its
# serviceName).
const ROWS = [
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_BAR_TWINS", "serviceHours": 4, "cooldownHours": 24, "flatPrice": 300.0, "totalMemberPrice": 300.0},
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_HOTEL_CAPSULES_MOON", "serviceHours": 24, "flatPrice": 300.0, "totalMemberPrice": 300.0},
	{"scene": "res://enceladus/ServiceUIInsurance.tscn", "serviceName": "SERVICE_JAMESON", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 50000.0},
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_SALVAGE_LICENCE", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 300000.0},
	{"scene": "res://enceladus/ServiceUI.tscn", "serviceName": "SERVICE_SIMULATOR", "serviceHours": 1, "cooldownHours": 720, "flatPrice": 4000.0},
	{"scene": "res://enceladus/ServiceUIFactionChange.tscn", "serviceName": "SERVICE_MINERS", "serviceHours": 1, "factionBased": "civilian", "fearPrice": 50000.0, "hostilityPrice": 20000.0},
]

var sn = null # the settings script, for its constants
var snSettings = null

func run():
	bindGameKeys()
	addTranslations()
	TranslationServer.set_locale("en")
	if not hasMod("ServiceNotifier"):
		yield(serviceControl(), "completed")
		return
	sn = load(SN_SETTINGS_SCRIPT)
	snSettings = sn.shared()
	snSettings.connect("settingsChanged", self, "_countChange")
	serviceModel()
	yield(serviceMark(), "completed")
	yield(serviceScreen(), "completed")

func snManifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(SN_MANIFEST)
	return manifest.get_value(section, key)

func snMarked(s) -> bool:
	return s.servicesEntry.text == tr(s.menu._SN_ALERT) % tr(SERVICES_KEY)

func snEntry():
	return CurrentGame.state.ui.get(snSettings.modId())

# A row of the Services screen alone, with `values`, for the rule of which services are watched; freed by the caller.
func serviceRow(values: Dictionary):
	var row = load(values.scene).instance()
	for key in values:
		if key != "scene":
			row.set(key, values[key])
	return row

# The game alone: the entry keeps its key and has no tooltip, and Shift+Click opens no settings.
func serviceControl():
	loadSave(gameStart() + 400 * DAY)
	CurrentGame.money = 10500000
	var s = station(false, ROWS)
	yield(frames(5), "completed")
	check("control: the Services entry keeps its key, and has no tooltip", s.servicesEntry.text == SERVICES_KEY and s.servicesEntry.hint_tooltip == "", s.servicesEntry.text)
	# The gamepad twin of Shift+Click (the mod's Badge.gd, not loaded here: LT and X).
	s.servicesEntry.grab_focus()
	yield(holdJoy(JOY_L2, true), "completed")
	yield(tapJoy(JOY_XBOX_X), "completed")
	yield(holdJoy(JOY_L2, false), "completed")
	yield(frames(5), "completed")
	check("control: LT+X on the highlighted entry opens nothing", s.screens.get_node_or_null(SN_SCREEN) == null and not s.servicesScreen.visible)
	click(s.servicesEntry, true)
	yield(frames(10), "completed")
	check("control: Shift+Click opens no settings", s.screens.get_node_or_null(SN_SCREEN) == null)
	yield(freeStation(s), "completed")

# The settings model, alone, and the rule of which services it watches.
func serviceModel():
	loadSave(gameStart())
	snSettings.loadFromState()
	check("settings: one shared instance", load(SN_SETTINGS_SCRIPT).shared() == snSettings)
	check("settings: a save without the mod's entry has every service's switch at its default", snSettings.getValue("alert", "SERVICE_JAMESON") == sn.SETTINGS.alert.default and snSettings.getValue("alert", "ANY_SERVICE") == sn.SETTINGS.alert.default)
	var kinds = []
	for values in ROWS:
		var row = serviceRow(values)
		kinds.append(sn.kindOf(row))
		row.free()
	check("settings: watched, the services with a cooldown and the compensations; not the hotel", kinds == ["cooldown", "", "cooldown", "cooldown", "cooldown", "compensation"], kinds)
	changes = 0
	snSettings.setValue("alert", sn.SETTINGS.alert.default, "SERVICE_JAMESON")
	check("settings: an unchanged value stores nothing and signals nothing", snEntry() == null and changes == 0)
	snSettings.setValue("alert", not sn.SETTINGS.alert.default, "SERVICE_JAMESON")
	var saved = snEntry()
	var version = "%d.%d.%d" % [snManifestValue("version", "version_major"), snManifestValue("version", "version_minor"), snManifestValue("version", "version_bugfix")]
	check("settings: a change is stored under the manifest's id, with the format and mod versions and the service's value, and signalled once", saved is Dictionary and saved.formatVersion == sn.FORMAT_VERSION and saved.modVersion == version and same(saved.alert, {"SERVICE_JAMESON": not sn.SETTINGS.alert.default}) and changes == 1 and snSettings.modId() == snManifestValue("mod_information", "id"), saved)
	snSettings.setValue("alert", "yes", "SERVICE_SIMULATOR")
	check("settings: a value that isn't a bool gives the default", snSettings.getValue("alert", "SERVICE_SIMULATOR") == sn.SETTINGS.alert.default)
	snSettings.cfg.alert["SERVICE_JAMESON"] = sn.SETTINGS.alert.default
	check("settings: the stored entry is a copy", saved.alert.SERVICE_JAMESON != sn.SETTINGS.alert.default)
	snSettings.cfg.alert["SERVICE_JAMESON"] = not sn.SETTINGS.alert.default
	CurrentGame.state.ui = parse_json(to_json(CurrentGame.state.ui))
	snSettings.cfg.alert = {}
	snSettings.loadFromState()
	check("settings: read back after a JSON round trip of the save", snSettings.getValue("alert", "SERVICE_JAMESON") != sn.SETTINGS.alert.default and snSettings.getValue("alert", "SERVICE_SIMULATOR") == sn.SETTINGS.alert.default)
	CurrentGame.state.ui[snSettings.modId()] = {"alert": {"SERVICE_JAMESON": "no", "SERVICE_MINERS": false, "SERVICE_SIMULATOR": 3}}
	snSettings.loadFromState()
	check("settings: a hand-edited entry read safely (only bool values kept)", same(snSettings.cfg.alert, {"SERVICE_MINERS": false}), snSettings.cfg.alert)
	CurrentGame.state.ui[snSettings.modId()] = "garbage"
	snSettings.loadFromState()
	check("settings: an entry that isn't a dictionary gives the defaults", snSettings.cfg.alert.empty())

# The Services entry's alert mark, for each kind of row, and its tooltip.
func serviceMark():
	loadSave(gameStart() + 500 * DAY)
	snSettings.loadFromState()
	var s = station(false, ROWS)
	yield(frames(5), "completed")
	var menuKeys = s.menu
	check("menu: the mod's texts are loaded (i18n/en.po)", tr(menuKeys._SN_SETTINGS_TOOLTIP) != menuKeys._SN_SETTINGS_TOOLTIP and tr(menuKeys._SN_ALERT) != menuKeys._SN_ALERT)
	check("menu: the Services entry's Shift badge has the tooltip, which tells about Shift+Click; the entry has none of its own", badgeTip(s.servicesEntry) == tr(menuKeys._SN_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), snManifestValue("mod_information", "name")] and s.servicesEntry.hint_tooltip == "", [badgeTip(s.servicesEntry), s.servicesEntry.hint_tooltip])
	check("menu: no alert mark with no money", s.servicesEntry.text == SERVICES_KEY, s.servicesEntry.text)
	CurrentGame.setUiValue("cooldown.SERVICE_BAR_TWINS", CurrentGame.getInGameTimestamp() + 10 * DAY)
	CurrentGame.changeMoney(1000.0)
	yield(frames(3), "completed")
	check("menu: none for a hotel, which can be bought again at once, nor for The Twins in their cooldown", s.servicesEntry.text == SERVICES_KEY and not s.services.SERVICE_HOTEL_CAPSULES_MOON.buyButton.disabled and s.services.SERVICE_BAR_TWINS.buyButton.disabled, s.servicesEntry.text)
	CurrentGame.setUiValue("cooldown.SERVICE_BAR_TWINS", 0)
	yield(advance(HOUR), "completed")
	check("menu: the alert mark once The Twins' cooldown is over", snMarked(s), s.servicesEntry.text)
	TranslationServer.set_locale("de")
	yield(frames(2), "completed")
	check("menu: the alert mark follows a language change", s.servicesEntry.text == tr(menuKeys._SN_ALERT) % ENTRY_TEXTS.de[SERVICES_KEY], s.servicesEntry.text)
	TranslationServer.set_locale("en")
	yield(frames(2), "completed")
	snSettings.setValue("alert", false, "SERVICE_BAR_TWINS")
	yield(frames(3), "completed")
	check("menu: none with The Twins' switch off", s.servicesEntry.text == SERVICES_KEY, s.servicesEntry.text)
	CurrentGame.changeMoney(60000.0)
	yield(frames(3), "completed")
	check("menu: the alert mark while Jameson's Insurance and the simulator can be bought, their switches on at first", snMarked(s), s.servicesEntry.text)
	snSettings.setValue("alert", false, "SERVICE_JAMESON")
	snSettings.setValue("alert", false, "SERVICE_SIMULATOR")
	yield(frames(3), "completed")
	check("menu: none with their switches off, though both can be bought", s.servicesEntry.text == SERVICES_KEY and not s.services.SERVICE_JAMESON.buyButton.disabled and not s.services.SERVICE_SIMULATOR.buyButton.disabled, s.servicesEntry.text)
	CurrentGame.changeMoney(300000.0)
	yield(frames(3), "completed")
	check("menu: the alert mark while Scrapwright Recovery Operations can be bought", snMarked(s), s.servicesEntry.text)
	CurrentGame.setUiValue("cooldown.SERVICE_SALVAGE_LICENCE", CurrentGame.getInGameTimestamp() + DAY)
	yield(advance(HOUR), "completed")
	check("menu: none while it is paid for (the game's cooldown)", s.servicesEntry.text == SERVICES_KEY, s.servicesEntry.text)
	Factions.adjustFactionDisposition("civilian", "player", "hostility", 0.1)
	yield(advance(HOUR), "completed")
	var miners = s.services.SERVICE_MINERS
	check("menu: the alert mark while the miners hold a grudge: a compensation to pay", snMarked(s) and miners.getPrice() > 0, [s.servicesEntry.text, miners.getPrice()])
	# What buying it does (ServiceUIFactionChange.gd buy): the hostility and fear towards the player back to 0.
	Factions.adjustFactionDisposition("civilian", "player", "hostility", -0.1)
	yield(advance(HOUR), "completed")
	check("menu: none once it is paid: it costs nothing", s.servicesEntry.text == SERVICES_KEY and miners.getPrice() == 0 and miners.buyButton.disabled, [s.servicesEntry.text, miners.getPrice()])
	snSettings.setValue("alert", true, "SERVICE_JAMESON")
	yield(frames(3), "completed")
	check("menu: back with Jameson's Insurance's switch on", snMarked(s), s.servicesEntry.text)
	CurrentGame.changeMoney(-CurrentGame.getMoney())
	yield(frames(3), "completed")
	check("menu: none once the money is below every price", s.servicesEntry.text == SERVICES_KEY, s.servicesEntry.text)
	yield(freeStation(s), "completed")
	# A menu without the station's screens: no tooltip, no mark, and Shift+Click is a plain click.
	var bare = Control.new()
	var menu = VBoxContainer.new(); menu.name = "Options"
	menu.set_script(load(MENU_SCRIPT))
	var entry = Button.new(); entry.name = "Services"; entry.text = SERVICES_KEY
	menu.add_child(entry)
	bare.add_child(menu)
	add_child(bare)
	CurrentGame.changeMoney(60000.0)
	yield(frames(3), "completed")
	check("menu: without the station's screens, no tooltip and no mark", entry.hint_tooltip == "" and entry.text == SERVICES_KEY, [entry.hint_tooltip, entry.text])
	bare.queue_free()
	yield(frames(2), "completed")
	CurrentGame.changeMoney(-CurrentGame.getMoney())
	snSettings.cfg.alert = {}

# The settings screen, opened with Shift+Click on the Services entry.
func serviceScreen():
	loadSave(gameStart() + 600 * DAY)
	snSettings.loadFromState()
	snSettings.setValue("alert", false, "SERVICE_SIMULATOR")
	var s = station(false, ROWS)
	yield(frames(5), "completed")
	var ui = load(SN_UI_SCRIPT).get_script_constant_map()
	s.servicesEntry.disabled = true
	click(s.servicesEntry, true)
	yield(frames(5), "completed")
	check("screen: Shift+Click on a disabled entry does nothing", s.screens.get_node_or_null(SN_SCREEN) == null)
	s.servicesEntry.disabled = false
	var stored = to_json(CurrentGame.state.ui)
	click(s.servicesEntry, true)
	yield(frames(40), "completed")
	var screen = s.screens.get_node_or_null(SN_SCREEN)
	check("screen: Shift+Click on the Services entry opens the settings, not the Services screen", screen != null and screen.visible and not s.servicesScreen.visible)
	if screen == null:
		yield(freeStation(s), "completed")
		return
	check("screen: opening it stores nothing", to_json(CurrentGame.state.ui) == stored)
	check("screen: the Services screen's frame: panel, width and place", screen.get_stylebox("panel") == s.servicesScreen.get_stylebox("panel") and screen.rect_min_size == s.servicesScreen.rect_min_size and screen.size_flags_horizontal == s.servicesScreen.size_flags_horizontal)
	var order = []
	for child in screen.get_node("VB").get_children():
		order.append(child.name)
	check("screen: titled by the Services entry; under the header, the description's window, then the groups", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == SERVICES_KEY and order == ["HeaderWithMoney", "WindowMargin", "ScrollContainer"], order)
	var windowMargin = screen.get_node("VB/WindowMargin")
	var inside = screen.get_node("VB/WindowMargin/Window/MarginContainer")
	var gameMargin = s.tuning.get_node("VB/WindowMargin")
	var gameInside = s.tuning.get_node("VB/WindowMargin/Window/VBoxContainer/MarginContainer")
	var copied = windowMargin.theme == gameMargin.theme and inside.get_parent().get_stylebox("panel") == s.tuning.get_node("VB/WindowMargin/Window").get_stylebox("panel")
	for side in ["left", "top", "right", "bottom"]:
		copied = copied and windowMargin.get_constant("margin_" + side) == gameMargin.get_constant("margin_" + side) and inside.get_constant("margin_" + side) == gameInside.get_constant("margin_" + side)
	check("screen: the description's window copies the Tuning screen's: theme, margins around and inside, panel", copied)
	var groups = []
	var rows = {}
	for g in screen.get_node("VB/ScrollContainer/Items").get_children():
		var items = []
		for r in g.get_children():
			if "tuningItem" in r:
				items.append(r.tuningItem)
				rows[r.tuningItem] = r
		groups.append([g.system, items])
	var expected = [[sn.KINDS.cooldown.title, ["SERVICE_BAR_TWINS", "SERVICE_JAMESON", "SERVICE_SALVAGE_LICENCE", "SERVICE_SIMULATOR"]], [sn.KINDS.compensation.title, ["SERVICE_MINERS"]]]
	check("screen: a group per kind, in KINDS order, titled by it, with a row per service of that kind in the Services screen's order, named by its key (the game translates it); no hotel", same(groups, expected), groups)
	var switches = true
	for service in rows:
		var toggle = rows[service].get_node(SN_ROW_SWITCH)
		switches = switches and toggle.pressed == snSettings.getValue("alert", service) and toggle.hint_tooltip == sn.SETTINGS.alert.label
	check("screen: each switch shows its service's setting, the simulator's off, the others on at first; each with the setting's label as its tooltip", switches and not rows.SERVICE_SIMULATOR.get_node(SN_ROW_SWITCH).pressed)
	var description = screen.get_node("VB/WindowMargin/Window/MarginContainer/Description")
	yield(frames(3), "completed")
	var twins = s.services.SERVICE_BAR_TWINS
	var cooldownText = tr(sn.KINDS.cooldown.description) % [tr(twins.serviceName), Tool.readableTimeSpan(twins.cooldownHours * 3600, true), ""]
	check("screen: the first row selected, with its description: its kind's, with its name and cooldown as the game writes a time", description.text == cooldownText.strip_edges(), description.text)
	rows.SERVICE_JAMESON.focus()
	yield(frames(2), "completed")
	var jameson = s.services.SERVICE_JAMESON
	check("screen: another service's description, with its own cooldown", description.text == (tr(sn.KINDS.cooldown.description) % [tr(jameson.serviceName), Tool.readableTimeSpan(jameson.cooldownHours * 3600, true), ""]).strip_edges(), description.text)
	rows.SERVICE_MINERS.focus()
	yield(frames(2), "completed")
	check("screen: a compensation's description", description.text == (tr(sn.KINDS.compensation.description) % [tr("SERVICE_MINERS"), ""]).strip_edges(), description.text)
	check("screen: focusing stores nothing", to_json(CurrentGame.state.ui) == stored)
	rows.SERVICE_SIMULATOR.get_node(SN_ROW_SWITCH).pressed = true
	yield(frames(3), "completed")
	check("screen: a switch stores what it shows", snSettings.getValue("alert", "SERVICE_SIMULATOR") == true and snEntry().alert.SERVICE_SIMULATOR == true, snEntry())
	rows.SERVICE_SIMULATOR.focus()
	yield(frames(2), "completed")
	check("screen: focusing it again doesn't switch it back", snSettings.getValue("alert", "SERVICE_SIMULATOR") == true and rows.SERVICE_SIMULATOR.get_node(SN_ROW_SWITCH).pressed)
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("screen: Esc closes it after the game's fade", not screen.visible)
	click(s.servicesEntry, true)
	yield(frames(40), "completed")
	var reopened = screen.visible
	click(s.logs, false)
	yield(frames(40), "completed")
	check("screen: focusing another entry of the menu closes it", reopened and not screen.visible)
	# With a gamepad: the Shift badge reads the gamepad twin while the game is played with one, and X pressed on the
	# highlighted entry while LT is held opens the settings, as Shift+Click does (Badge.gd).
	var shiftBadge = s.menu._snShiftBadge
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
	var modName = snManifestValue("mod_information", "name")
	var padKey = s.menu._SN_SETTINGS_TOOLTIP_PAD
	var padExpected = tr(padKey) % [shiftBadge.PAD_BUTTON_NAME, shiftBadge.PAD_MODIFIER_NAME, modName]
	check("gamepad: its tooltip tells about the gamepad twin with a gamepad, and about Shift+Click again with keyboard and mouse", padTip == padExpected and keyTip == tr(s.menu._SN_SETTINGS_TOOLTIP) % [keyText, modName] and tr(padKey) != padKey, [padTip, keyTip])
	Settings.controlScheme = Settings.control.gamepad
	s.servicesEntry.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: X alone on the highlighted entry does nothing", not screen.visible and not s.servicesScreen.visible)
	yield(holdJoy(padModifier, true), "completed")
	s.servicesEntry.disabled = true
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: LT+X on a disabled entry does nothing", not screen.visible and not s.servicesScreen.visible)
	s.servicesEntry.disabled = false
	s.logs.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: LT+X with another entry highlighted doesn't open these settings", not screen.visible and not s.servicesScreen.visible)
	s.servicesEntry.grab_focus()
	yield(tapJoy(padButton), "completed")
	yield(frames(5), "completed")
	check("gamepad: LT+X on the highlighted Services entry opens the settings, not the Services screen", screen.visible and not s.servicesScreen.visible)
	yield(holdJoy(padModifier, false), "completed")
	yield(tap(escKey()), "completed")
	yield(frames(40), "completed")
	check("gamepad: closing them highlights the entry again", not screen.visible and s.servicesEntry.has_focus())
	Settings.controlScheme = Settings.control.keyMouse
	snSettings.cfg.alert = {}
	yield(freeStation(s), "completed")

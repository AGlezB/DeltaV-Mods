extends "res://harness/suite.gd"

# CrewCheapHireNotifier: the station menu's Crew entry (the `Crew` Button of the game's enceladus/EnceladusMenu.tscn,
# with no script and the translation key ENCELADUS_CREW as its text) shows the mod's ALERT_FORMAT while someone for
# hire earns at most the higher of the salary threshold and the best-paid hired member with the same job, plus the
# salary tolerance of it. Those are settings (the mod's Settings.gd): their defaults, ranges and steps are read from its
# SETTINGS, and every salary and slider value is built from them, so any value of them passes. The hire list, the crew
# and the save game's UI store are the CurrentGame stub's. The control checks run on the game's own script: with the
# mod loaded, that is the base of the extension.
#
# The settings screen opens on Shift+Click in a station tree built as enceladus/Enceladus.tscn nests it: the menu, and
# the right-hand screens' container (the game's HidingMarginContainer.gd) with stubs of the Crew and Tuning screens.
# Clicks go through the scene tree's input, as the game's do.

const KEY = "ENCELADUS_CREW"
const LOGS_KEY = "ENCELADUS_LOGS"
const PILOT = "CREW_OCCUPATION_PILOT"
const MECHANIC = "CREW_OCCUPATION_MECHANIC"
const TEXT_EN = "Crew"
const TEXT_DE = "Besatzung"

const SETTINGS_SCRIPT = "res://CrewCheapHireNotifier/Settings.gd"
const MANIFEST = "res://CrewCheapHireNotifier/Mod.manifest"

var tol = 0.0 # the salary tolerance's default
var changes = 0 # settingsChanged signals counted

func _countChange():
	changes += 1

# A limit with the tolerance on top, worked out as the mod does, so a salary right at it compares equal.
func capped(limit):
	return limit * (1.0 + tol)

# The menu as enceladus/EnceladusMenu.tscn nests it (two of its ten Buttons), added in one go, as instance() does,
# so the buttons are ready before the menu.
func make(script = null, withCrew = true):
	var menu = VBoxContainer.new()
	menu.name = "Options"
	menu.set_script(script if script != null else load("res://enceladus/EnceladusMenu.gd"))
	if withCrew:
		var crew = Button.new(); crew.name = "Crew"; crew.text = KEY
		menu.add_child(crew)
	var logs = Button.new(); logs.name = "Logs"; logs.text = LOGS_KEY
	menu.add_child(logs)
	add_child(menu)
	return menu

func member(fullName, occupation, salary):
	return {"fullName": fullName, "occupation": occupation, "salary": salary}

func setCrew(forHire, hired):
	CurrentGame.availableCrew = forHire
	CurrentGame.state.crew = {}
	for m in hired:
		CurrentGame.state.crew[m.fullName] = m

# A new day: a new hire list, as CurrentGame.advanceTimeBySeconds announces it.
func day(forHire, hired = []):
	setCrew(forHire, hired)
	CurrentGame.emit_signal("dayPassed")

func entry(menu) -> String:
	return menu.get_node("Crew").text

func addTranslation(locale, text):
	var t = Translation.new()
	t.locale = locale
	t.add_message(KEY, text)
	TranslationServer.add_translation(t)

# The station as enceladus/Enceladus.tscn nests the menu and the right-hand screens: MarginContainer > HBoxContainer >
# Options (the menu), and MarginContainer > CanvasLayer > MarginContainer (HidingMarginContainer.gd, hiding its screens
# when a menu entry takes focus) > the Crew screen (wired to the entry's `pressed` as the scene does) and the Tuning
# screen, hidden, with a frame of its own for the settings screen to copy.
func station(withTuning = true):
	var root = MarginContainer.new()
	root.name = "MarginContainer"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	var hbox = HBoxContainer.new(); hbox.name = "HBoxContainer"
	root.add_child(hbox)
	var menu = VBoxContainer.new(); menu.name = "Options"
	menu.set_script(load("res://enceladus/EnceladusMenu.gd"))
	var crew = Button.new(); crew.name = "Crew"; crew.text = KEY
	menu.add_child(crew)
	var logs = Button.new(); logs.name = "Logs"; logs.text = LOGS_KEY
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
	var crewScreen = Control.new(); crewScreen.name = "Crew"; crewScreen.visible = false
	crewScreen.set_script(load("res://harness/crew_screen.gd"))
	screens.add_child(crewScreen)
	crew.connect("pressed", crewScreen, "_on_Crew_pressed")
	var tuning = null
	if withTuning:
		tuning = PanelContainer.new(); tuning.name = "Tuning"; tuning.visible = false
		tuning.theme = Theme.new()
		tuning.add_stylebox_override("panel", StyleBoxFlat.new())
		tuning.rect_min_size = Vector2(600, 0)
		tuning.size_flags_horizontal = Control.SIZE_SHRINK_END
		screens.add_child(tuning)
	add_child(root)
	return {"root": root, "menu": menu, "crew": crew, "logs": logs, "screens": screens, "crewScreen": crewScreen, "tuning": tuning}

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

# A press and release of a key or button, as Input delivers a player's: it updates the actions the key is bound to
# (Input.is_action_just_pressed), then passes the event on. A bare InputEventAction would not update them. The game
# takes input in the idle part of a frame, not during physics, where is_action_just_pressed counts physics frames.
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

# The game's bindings (its project.godot): ui_cancel is Esc, B (button 1) and Start (button 11); pause is Esc and Start.
func bindGameKeys():
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	for binding in [["ui_cancel", escKey()], ["ui_cancel", joyButton(JOY_BUTTON_1)], ["ui_cancel", joyButton(JOY_START)], ["pause", escKey()], ["pause", joyButton(JOY_START)]]:
		if not InputMap.action_has_event(binding[0], binding[1]):
			InputMap.action_add_event(binding[0], binding[1])

func settingsScreen(s):
	return s.screens.get_node_or_null("CrewCheapHireNotifierSettings")

# The settings screen's rows (the game's TuningFloatValue), in order.
func rows(screen):
	var out = []
	for items in screen.get_node("VB/ScrollContainer").get_children():
		if items.is_queued_for_deletion():
			continue
		for row in items.get_children():
			if "tune" in row:
				out.append(row)
	return out

func manifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return manifest.get_value(section, key)

func freeStation(s):
	s.root.queue_free()

func run():
	var mod = hasMod("CrewCheapHireNotifier")
	var game = load("res://enceladus/EnceladusMenu.gd")
	if mod:
		game = game.get_base_script()
	addTranslation("en", TEXT_EN)
	addTranslation("de", TEXT_DE)
	TranslationServer.set_locale("en")

	var t = 0 # the salary threshold's default; without the mod any salary will do
	if mod:
		var settings = load(SETTINGS_SCRIPT).SETTINGS
		t = settings.salaryThreshold.default
		tol = settings.salaryTolerance.default
	var top = capped(t) # the limit with nobody in that job
	var h = t + 1000 # a hired pilot's salary, above the threshold, so it sets the pilots' limit
	setCrew([member("Cheap Pilot", PILOT, top - 100)], [])
	var control = make(game)
	yield(get_tree(), "physics_frame")
	check("control: without the mod a cheap hire leaves the entry as the game's key", entry(control) == KEY, entry(control))
	CurrentGame.emit_signal("dayPassed")
	check("control: without the mod a new day leaves it too", entry(control) == KEY, entry(control))
	if not mod:
		return

	var menu = make()
	yield(get_tree(), "physics_frame")
	var marked = menu.ALERT_FORMAT % TEXT_EN
	check("a cheap hire marks the entry as soon as the menu is ready, with the translated text", entry(menu) == marked, entry(menu))

	day([])
	check("nobody for hire: the entry keeps the game's key", entry(menu) == KEY, entry(menu))
	# Nobody in that job: the threshold plus the tolerance.
	day([member("Pilot", PILOT, t)])
	check("a hire at the threshold, nobody in that job: marked", entry(menu) == marked, entry(menu))
	if tol > 0:
		day([member("Pilot", PILOT, (t + top) / 2.0)])
		check("a hire above the threshold but within the tolerance: marked", entry(menu) == marked, entry(menu))
	else:
		note("the tolerance's default is 0: no salary lies within it")
	day([member("Pilot", PILOT, top)])
	check("a hire at exactly the threshold plus the tolerance: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, top + 100)])
	check("a hire above the threshold plus the tolerance: not marked", entry(menu) == KEY, entry(menu))

	# My best-paid pilot sets the limit: that salary plus the tolerance.
	var hired = [member("Hired Pilot", PILOT, h)]
	day([member("Pilot", PILOT, h)], hired)
	check("a hire at my best-paid in that job: marked", entry(menu) == marked, entry(menu))
	if tol > 0:
		day([member("Pilot", PILOT, (h + capped(h)) / 2.0)], hired)
		check("a hire above my best-paid in that job but within the tolerance: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h))], hired)
	check("a hire at exactly my best-paid in that job plus the tolerance: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h) + 100)], hired)
	check("a hire above my best-paid in that job plus the tolerance: not marked", entry(menu) == KEY, entry(menu))

	day([member("Pilot", PILOT, top + 100)], [member("Hired Mechanic", MECHANIC, h)])
	check("only another job pays more: not marked", entry(menu) == KEY, entry(menu))
	day([member("Pilot", PILOT, top)], [member("Hired Pilot", PILOT, t - 200)])
	check("my best-paid in that job earns less than the threshold: the threshold applies", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h))], [member("Low Pilot", PILOT, h - 300), member("High Pilot", PILOT, h), member("Mid Pilot", PILOT, h - 100)])
	check("the best-paid in that job counts, whatever the order", entry(menu) == marked, entry(menu))
	day([member("Pilot A", PILOT, top + 300), member("Mechanic", MECHANIC, top - 100), member("Pilot B", PILOT, top + 500)])
	check("one cheap hire among several: marked", entry(menu) == marked, entry(menu))

	# Hiring and firing, as CurrentGame.hireCrewmember and fireCrewmember announce them.
	var cheap = member("Pilot", PILOT, top + 100)
	var dear = member("Dear Pilot", PILOT, top + 200)
	day([cheap, dear])
	check("two pilots for hire, both above the threshold plus the tolerance: not marked", entry(menu) == KEY, entry(menu))
	setCrew([cheap], [dear])
	CurrentGame.emit_signal("employmentChanged")
	check("hiring the better-paid one marks the other (employmentChanged)", entry(menu) == marked, entry(menu))
	setCrew([cheap, dear], [])
	CurrentGame.emit_signal("employmentChanged")
	check("firing it clears the mark again", entry(menu) == KEY, entry(menu))

	day([member("Pilot", PILOT, top - 100)])
	TranslationServer.set_locale("de")
	check("after a language change a marked entry is in the new language", entry(menu) == menu.ALERT_FORMAT % TEXT_DE, entry(menu))
	day([])
	check("and an unmarked one is the game's key again, which the button translates", entry(menu) == KEY, entry(menu))
	TranslationServer.set_locale("en")

	day([member("Pilot", PILOT, top - 100)])
	check("the other entries keep their text", menu.get_node("Logs").text == LOGS_KEY, menu.get_node("Logs").text)
	var bare = make(null, false)
	yield(get_tree(), "physics_frame")
	CurrentGame.emit_signal("dayPassed")
	check("a menu without a Crew entry is left alone", bare._crewButton == null and bare.get_node("Logs").text == LOGS_KEY)
	menu.disable(true)
	check("the game's disable() still disables every entry", menu.get_node("Crew").disabled and menu.get_node("Logs").disabled)
	for m in [control, menu, bare]:
		m.queue_free()

	# The settings model (Settings.gd), kept per save game in CurrentGame.state.ui under the mod's id.
	var model = load(SETTINGS_SCRIPT)
	var settings = model.shared()
	var th = model.SETTINGS.salaryThreshold
	var to = model.SETTINGS.salaryTolerance
	var id = manifestValue("mod_information", "id")
	var version = "%d.%d.%d" % [manifestValue("version", "version_major"), manifestValue("version", "version_minor"), manifestValue("version", "version_bugfix")]
	check("there is one shared settings instance, and the menu uses it", model.shared() == settings and menu._settings == settings)
	check("the mod's id and name come from its manifest", settings.modId() == id and settings.modName() == manifestValue("mod_information", "name"), "%s, %s" % [settings.modId(), settings.modName()])
	CurrentGame.state.ui = {"unrelated": 1}
	settings.loadFromState()
	check("a save game without the mod's settings gives the defaults", settings.getValue("salaryThreshold") == th.default and settings.getValue("salaryTolerance") == to.default)
	CurrentGame.state.ui[id] = {"salaryThreshold": th.max + th.step, "salaryTolerance": "much"}
	settings.loadFromState()
	check("a saved value above its range is clamped to the maximum", settings.getValue("salaryThreshold") == th.max, settings.getValue("salaryThreshold"))
	check("a saved value that is not a number gives the default", settings.getValue("salaryTolerance") == to.default, settings.getValue("salaryTolerance"))
	CurrentGame.state.ui[id] = {"salaryThreshold": th.min - th.step}
	settings.loadFromState()
	check("a saved value below its range is clamped to the minimum", settings.getValue("salaryThreshold") == th.min, settings.getValue("salaryThreshold"))
	CurrentGame.state.ui = {}
	settings.loadFromState()
	settings.connect("settingsChanged", self, "_countChange")
	changes = 0
	settings.setValue("salaryThreshold", th.default)
	check("setting the value a setting already has stores and signals nothing", changes == 0 and not CurrentGame.state.ui.has(id))
	var newT = th.default + th.step if th.default + th.step <= th.max else th.default - th.step
	settings.setValue("salaryThreshold", newT)
	var saved = CurrentGame.state.ui.get(id, {})
	check("a changed value signals once", changes == 1, changes)
	check("and is stored in the save game's UI store under the mod's id, with every setting", saved.get("salaryThreshold") == newT and saved.get("salaryTolerance") == to.default, saved)
	check("with the format version and the manifest's version", saved.get("formatVersion") == model.FORMAT_VERSION and saved.get("modVersion") == version, saved)
	settings.setValue("salaryThreshold", th.max + th.step)
	check("a value set above the range is clamped", settings.getValue("salaryThreshold") == th.max)
	var shown = settings.toShown("salaryTolerance", to.default)
	check("the tolerance is shown multiplied by its `shown` (as %) and converted back", is_equal_approx(shown, to.default * to.shown) and is_equal_approx(settings.fromShown("salaryTolerance", shown), to.default), shown)
	settings.disconnect("settingsChanged", self, "_countChange")
	CurrentGame.state.ui = {}
	settings.loadFromState()

	# The settings screen, in a station built as Enceladus.tscn nests it.
	Input.set_use_accumulated_input(false)
	bindGameKeys()
	var probe = Node.new()
	probe.set_script(load("res://harness/unhandled_probe.gd"))
	add_child(probe)
	setCrew([], [])
	var s = station()
	yield(frames(2), "completed")
	var tooltip = s.menu.SETTINGS_TOOLTIP_FORMAT % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")]
	check("the Crew entry's tooltip tells about Shift+Click", s.crew.hint_tooltip == tooltip, s.crew.hint_tooltip)
	click(s.crew, false)
	yield(frames(2), "completed")
	check("a plain click on Crew opens the Crew screen and not the settings", s.crewScreen.opened == 1 and settingsScreen(s) == null, s.crewScreen.opened)
	s.crew.disabled = true
	click(s.crew, true)
	yield(frames(2), "completed")
	check("Shift+Click on a disabled Crew entry does nothing", s.crewScreen.opened == 1 and settingsScreen(s) == null)
	s.crew.disabled = false
	click(s.crew, true)
	yield(frames(5), "completed")
	var screen = settingsScreen(s)
	check("Shift+Click on Crew opens the settings screen", screen != null and screen.visible)
	check("and not the Crew screen", s.crewScreen.opened == 1, s.crewScreen.opened)
	if screen == null:
		return
	check("the settings screen has the Tuning screen's theme and frame", screen.theme == s.tuning.theme and screen.get_stylebox("panel") == s.tuning.get_stylebox("panel"))
	check("and its size and size flags", screen.rect_min_size == s.tuning.rect_min_size and screen.size_flags_horizontal == s.tuning.size_flags_horizontal and screen.size_flags_vertical == s.tuning.size_flags_vertical)
	check("so it opens at the right edge, where Tuning does", is_equal_approx(screen.rect_position.x + screen.rect_size.x, s.screens.rect_size.x) and is_equal_approx(screen.rect_size.x, s.tuning.rect_min_size.x), "%s of %s" % [screen.get_rect(), s.screens.rect_size])
	check("its title is the Crew entry's", screen.get_node("VB/HeaderWithMoney/MarketLabel").text == KEY)
	var r = rows(screen)
	var keys = model.SETTINGS.keys()
	var labelsOk = r.size() == keys.size()
	var rangesOk = labelsOk
	var valuesOk = labelsOk
	for i in range(min(r.size(), keys.size())):
		var key = keys[i]
		var setting = model.SETTINGS[key]
		var slider = r[i].get_node("HSlider")
		labelsOk = labelsOk and r[i].get_node("HBoxContainer/Name").text == setting.label and r[i].get_node("HBoxContainer/Unit").text == setting.unit
		rangesOk = rangesOk and is_equal_approx(slider.min_value, settings.toShown(key, setting.min)) and is_equal_approx(slider.max_value, settings.toShown(key, setting.max)) and is_equal_approx(slider.step, settings.toShown(key, setting.step))
		valuesOk = valuesOk and is_equal_approx(slider.value, settings.toShown(key, settings.getValue(key)))
	check("one Tuning row per setting, in order, with its label and unit", labelsOk, r.size())
	check("each slider has its setting's range and step, in the units shown", rangesOk)
	check("and starts from the current value", valuesOk)
	check("the first slider has the focus", r.size() > 0 and r[0].get_node("HSlider").has_focus())
	check("opening the screen stores nothing", not CurrentGame.state.ui.has(id), CurrentGame.state.ui)

	# Moving a slider applies at once: a hire between the old and the new limit flips the mark.
	day([member("Pilot", PILOT, (capped(t) + capped(newT)) / 2.0)])
	var before = entry(s.menu)
	r[0].get_node("HSlider").value = settings.toShown("salaryThreshold", newT)
	check("moving the threshold slider flips the mark at once", entry(s.menu) != before, "%s -> %s" % [before, entry(s.menu)])
	check("and stores the value in the save game", CurrentGame.state.ui.get(id, {}).get("salaryThreshold") == newT, CurrentGame.state.ui)
	var newTol = to.default + to.step if to.default + to.step <= to.max else to.default - to.step
	day([member("Pilot", PILOT, newT * (1.0 + (tol + newTol) / 2.0))])
	before = entry(s.menu)
	r[1].get_node("HSlider").value = settings.toShown("salaryTolerance", newTol)
	check("moving the tolerance slider flips the mark at once", entry(s.menu) != before, "%s -> %s" % [before, entry(s.menu)])
	check("and stores it as a fraction", is_equal_approx(CurrentGame.state.ui.get(id, {}).get("salaryTolerance", -1.0), newTol), CurrentGame.state.ui)
	r[0].get_node("HBoxContainer/Reset").emit_signal("pressed")
	check("a row's reset button brings the default back, and stores it", settings.getValue("salaryThreshold") == th.default and CurrentGame.state.ui.get(id, {}).get("salaryThreshold") == th.default, settings.getValue("salaryThreshold"))

	# Closing, as the game's screens close: Esc, or the controller's B or Start.
	var unhandled = probe.count
	yield(tap(escKey()), "completed")
	check("Esc is handled by the screen, so the pause menu doesn't get it", probe.count == unhandled, probe.count - unhandled)
	yield(frames(40), "completed")
	check("and closes it after the game's fade", not screen.visible)
	check("the focus goes back to the Crew entry", s.crew.has_focus())
	yield(tap(escKey()), "completed")
	check("control: with no screen open, Esc reaches the pause menu", probe.count == unhandled + 1, probe.count - unhandled)
	click(s.crew, true)
	yield(frames(5), "completed")
	check("Shift+Click opens it again", screen.visible and settingsScreen(s) == screen and screen.get_node("Shower").current_animation == "show")
	yield(tap(joyButton(JOY_BUTTON_1)), "completed")
	yield(frames(40), "completed")
	check("the controller's B button closes it", not screen.visible)
	click(s.crew, true)
	yield(frames(5), "completed")
	var opening = screen.visible and screen.get_node("Shower").current_animation == "show"
	yield(tap(joyButton(JOY_START)), "completed")
	yield(frames(40), "completed")
	check("and so does its Start button", opening and not screen.visible)
	click(s.crew, true)
	yield(frames(5), "completed")
	opening = screen.visible and screen.get_node("Shower").current_animation == "show"
	s.logs.grab_focus()
	yield(frames(40), "completed")
	check("focusing another menu entry hides it, as it hides the game's screens", opening and not screen.visible)

	# After a save and a load (CurrentGame writes the state as JSON and reads it back), a new station has the values.
	settings.setValue("salaryThreshold", newT)
	CurrentGame.state = parse_json(to_json(CurrentGame.state))
	settings.cfg.salaryThreshold = th.default # what another save game would leave in the shared instance
	freeStation(s)
	yield(frames(1), "completed")
	s = station()
	yield(frames(2), "completed")
	check("after a save and a load, a new station uses the saved value", settings.getValue("salaryThreshold") == newT, settings.getValue("salaryThreshold"))
	click(s.crew, true)
	yield(frames(5), "completed")
	screen = settingsScreen(s)
	r = rows(screen) if screen != null else []
	check("and the settings screen opens on it", r.size() > 0 and is_equal_approx(r[0].get_node("HSlider").value, settings.toShown("salaryThreshold", newT)))
	freeStation(s)
	yield(frames(1), "completed")

	s = station(false)
	yield(frames(2), "completed")
	check("without a Tuning screen there is no tooltip", s.crew.hint_tooltip == "", s.crew.hint_tooltip)
	click(s.crew, true)
	yield(frames(2), "completed")
	check("and Shift+Click is a plain click", s.crewScreen.opened == 1 and settingsScreen(s) == null, s.crewScreen.opened)

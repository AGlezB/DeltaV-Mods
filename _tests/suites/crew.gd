extends "res://harness/suite.gd"

# CrewCheapHireNotifier: the station menu's Crew entry (the `Crew` Button of the game's enceladus/EnceladusMenu.tscn,
# with no script and the translation key ENCELADUS_CREW as its text) shows the mod's alert text while someone for
# hire earns at most the higher of the salary threshold and the salary of the best-paid hired member with the same job
# changed by the salary tolerance, which never touches the threshold; in a job whose hired crew has reached its crew
# limit, only while they earn less than that best-paid member. Those are settings (the mod's Settings.gd): their
# defaults, ranges and steps are read from its SETTINGS, the jobs from CurrentGame.occupations, and every salary and
# slider value is built from them, so any value of them passes. The mod's texts are its i18n/en.po, and every expected
# text is built with tr() from the mod's keys, so any wording passes. The hire list, the crew and the save game's UI
# store are the CurrentGame stub's. The control checks run on the game's own script: with the mod loaded, that is the
# base of the extension.
#
# The Hire screen: the Crew screen's Hire tab built as enceladus/Crew.tscn nests it, around the game's HireableCrew.gd,
# whose entries are the game's CrewBio.gd in a stub of its scene (run.ps1). Everyone the same rule counts gets a badge
# above the values of their details, with the limit for their job (or, in a full job, the best-paid salary) in the
# game's tooltip (the entry's PlaySoundsOnTheseButtons), which a mouse moved through the scene tree's input shows. The
# tab's theme has a Button font color and a flat frame with an overbright border, as the game's has, for the badge to
# be built from.
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
const PILOT_EN = "Pilot"
const PILOT_DE = "Pilotin"
const GEOLOGIST = "CREW_OCCUPATION_GEOLOGIST"
const ASTROGATOR = "CREW_OCCUPATION_ASTROGATOR"
# The jobs' names in the two test languages, in a different alphabetical order in each, and neither the game's
# (CurrentGame.occupations); the German one isn't the keys' either. One English name is lowercase: sorted by case
# (uppercase first), it would come last.
const JOBS_EN = {PILOT: PILOT_EN, MECHANIC: "Mechanic", GEOLOGIST: "Geologist", ASTROGATOR: "astrogator"}
const JOBS_DE = {PILOT: PILOT_DE, MECHANIC: "Technikerin", GEOLOGIST: "Geologin", ASTROGATOR: "Navigatorin"}
# A German text for the mod's settings tooltip, which its en.po has only in English.
const SETTINGS_TOOLTIP_DE = "Mit %s klicken: Einstellungen von %s"

# The Hire screen theme's Button font color and frame border.
const HIRE_FONT_COLOR = Color(0.8, 0.7, 0.6, 1.0)
const HIRE_FRAME_BORDER = Color(2, 2, 2, 1)

const SETTINGS_SCRIPT = "res://CrewCheapHireNotifier/Settings.gd"
# The scripts the mod extends: once installed, its extensions load by these paths (take_over_path), and loading them by
# their own path would parse them again on top of themselves.
const MENU_SCRIPT = "res://enceladus/EnceladusMenu.gd"
const HIRE_TAB_SCRIPT = "res://enceladus/HireableCrew.gd"
const UI_SCRIPT = "res://CrewCheapHireNotifier/SettingsUI.gd"
const MANIFEST = "res://CrewCheapHireNotifier/Mod.manifest"
const TOLERANCE = "salaryTolerance"
const CREW_LIMIT = "crewLimit"

var tol = 0.0 # the salary tolerance's default
var changes = 0 # settingsChanged signals counted

func _countChange():
	changes += 1

# A best-paid salary changed by the tolerance's default, worked out as the mod does, so a salary right at it compares
# equal.
func capped(salary):
	return salary * (1.0 + tol)

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

# A hire list member as CurrentGame.randomizeAvailableCrewMember makes one: the Hire screen names its entry after the
# first two `details`.
func member(fullName, occupation, salary):
	var names = fullName.split(" ", true, 1)
	var details = [names[0], names[1] if names.size() > 1 else "", 0]
	return {"fullName": fullName, "details": details, "occupation": occupation, "salary": salary, "talent": 0.5, "experience": 0.5}

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

func addTranslation(locale, text, jobs):
	var t = Translation.new()
	t.locale = locale
	t.add_message(KEY, text)
	for job in jobs:
		t.add_message(job, jobs[job])
	TranslationServer.add_translation(t)

# The Crew screen's Hire tab as enceladus/Crew.tscn nests it: the HireableCrew MarginContainer (`script`, or what
# loading the game's script gives), its Scroll with the Items list the entries go in, and its visibility_changed wired
# as the scene wires it. Added hidden: showing it fills the list, as opening the tab does. It fills the viewport, so
# its scroll area shows the entries and the mouse reaches them.
func hireTab(script = null):
	var tab = MarginContainer.new()
	tab.name = "HireableCrew"
	tab.visible = false
	tab.rect_size = get_viewport().size
	var theme = Theme.new()
	theme.set_color("font_color", "Button", HIRE_FONT_COLOR)
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.9)
	frame.border_color = HIRE_FRAME_BORDER
	frame.set_border_width_all(1)
	frame.corner_radius_top_left = 20
	frame.corner_radius_bottom_right = 20
	frame.content_margin_left = 16
	frame.content_margin_right = 16
	theme.set_stylebox("normal", "Button", frame)
	tab.theme = theme
	tab.set_script(script if script != null else load("res://enceladus/HireableCrew.gd"))
	tab.hireableCrewContainterPath = NodePath("Scroll/Items")
	tab.crewDisplayResource = load("res://enceladus/CrewBio.tscn")
	var scroll = ScrollContainer.new(); scroll.name = "Scroll"
	tab.add_child(scroll)
	var items = VBoxContainer.new(); items.name = "Items"
	scroll.add_child(items)
	tab.connect("visibility_changed", tab, "_on_HireableCrew_visibility_changed")
	add_child(tab)
	return tab

# The entry of a hire list member, as HireableCrew.gd names it.
func hireEntry(tab, m):
	var fullName = "%s %s" % [m.details[0], m.details[1]]
	for e in tab.hireableCrew.get_children():
		if "fullName" in e and e.fullName == fullName and not e.is_queued_for_deletion():
			return e
	return null

# The entry's badge, by the mod's node name, on the top value of the details grid (the game's fullNameNode).
func badgeOf(tab, e):
	return e.fullNameNode.get_node_or_null(tab._CHEAP_HIRE_BADGE) if e != null else null

# A visible badge, with the limit for `job` as the tooltip the game shows for it.
func badged(tab, e, job, limit) -> bool:
	return badgedWith(tab, e, limitTip(tab, job, limit))

# A visible badge, with `text` as the first line of the tooltip the game shows for it, and hiredLine() as its second.
func badgedWith(tab, e, text) -> bool:
	var badge = badgeOf(tab, e)
	return badge != null and badge.visible and shownTip(tab, e) == text + "\n" + hiredLine(tab, e)

# The tooltip's second line for the entry's job: how many of my crew have it (counted here, everyone in
# CurrentGame.state.crew) out of its crew limit (the stored setting).
func hiredLine(tab, e) -> String:
	var count = 0
	for memberName in CurrentGame.state.crew:
		if CurrentGame.state.crew[memberName].occupation == e.occupation:
			count += 1
	var limit = load(SETTINGS_SCRIPT).shared().getValue(CREW_LIMIT, e.occupation)
	return tr(tab._CHEAP_HIRE_HIRED_TOOLTIP) % [count, limit]

# The mouse moved to `at` through the scene tree's input, as the player moves it. Controls get the mouse's enter and
# exit only once the window has had the mouse enter it (Godot 3.6, found in the harness), which the OS reports with
# NOTIFICATION_WM_MOUSE_ENTER and a window-less run never does: the Hire screen's checks send it first.
func moveMouse(at):
	var event = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_tree().input_event(event)

# The tooltip the game shows for the entry's badge: the mouse onto the badge's center, the text of the entry's
# PlaySoundsOnTheseButtons tooltip while it is shown, then the mouse off the screen, which hides it.
func shownTip(tab, e) -> String:
	var badge = badgeOf(tab, e)
	if badge == null or not badge.visible:
		return "(no badge)"
	var tooltips = e.get_node("PlaySoundsOnTheseButtons")
	moveMouse(badge.rect_global_position + badge.rect_size / 2)
	var text = tooltips.tooltipLabel.text if tooltips.tooltipPosition.visible else "(no tooltip)"
	moveMouse(Vector2(-10, -10))
	return text

# No badge, or a hidden one.
func unbadged(tab, e) -> bool:
	if e == null:
		return false
	var badge = badgeOf(tab, e)
	return badge == null or not badge.visible

# The panels anywhere in the entry but its tooltip node: the stub has no others, so any is a badge.
func panels(node) -> int:
	var count = 0
	for child in node.get_children():
		if child.name == "PlaySoundsOnTheseButtons":
			continue
		if child is PanelContainer:
			count += 1
		count += panels(child)
	return count

# The Hire button as the game leaves it: no color override, no tooltip.
func untouched(e) -> bool:
	return e != null and not e.hireButton.has_color_override("font_color") and e.hireButton.hint_tooltip == ""

func tip(tab, e) -> String:
	var badge = badgeOf(tab, e)
	if badge == null:
		return "(no badge)"
	return shownTip(tab, e) if badge.visible else "(hidden)"

# The tooltip the mod's format gives for a job's name and limit, shown as the game shows a salary.
func limitTip(tab, job, limit) -> String:
	return tr(tab._CHEAP_HIRE_LIMIT_TOOLTIP) % [job, CurrentGame.formatThousands(floor(limit)) + " E$"]

# The tooltip the mod's format gives for a full job's name and best-paid salary.
func fullTip(tab, job, best) -> String:
	return tr(tab._CHEAP_HIRE_FULL_TOOLTIP) % [job, CurrentGame.formatThousands(floor(best)) + " E$"]

# Whether every job's crew limit is `value`, in the shared settings.
func everyJob(settings, value) -> bool:
	for job in CurrentGame.occupations:
		if settings.getValue(CREW_LIMIT, job) != value:
			return false
	return true

# A hired member who is benched (not active) or on leave (CurrentGame.isCrewOnLeave: `leave`, an in-game timestamp,
# after now; here far in the future), as the game keeps them in CurrentGame.state.crew.
func benched(m):
	m["active"] = false
	return m

func onLeave(m):
	m["leave"] = 1e12
	return m

# The same for a saved per-job dictionary.
func everySavedJob(saved, value) -> bool:
	if not saved is Dictionary:
		return false
	for job in CurrentGame.occupations:
		if not (job in saved and is_equal_approx(saved[job], value)):
			return false
	return true

# The Crew entry's tooltip, in the language set now.
func settingsTip(menu) -> String:
	return tr(menu._CHEAP_HIRE_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")]

# The game's own script under a chain of extensions: the one at its root.
func rootScript(script):
	while script.get_base_script() != null:
		script = script.get_base_script()
	return script

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

# The settings screen's groups (the game's TuningItems), in order, in its Items box (as Tuning.tscn's).
func groups(screen):
	var out = []
	for items in screen.get_node("VB/ScrollContainer").get_children():
		if items.is_queued_for_deletion() or items.name != "Items":
			continue
		for group in items.get_children():
			if "tuning" in group and not group.is_queued_for_deletion():
				out.append(group)
	return out

# The settings screen's rows (the game's TuningFloatValue), in order.
func rows(screen):
	var out = []
	for group in groups(screen):
		for row in group.get_children():
			if "tune" in row:
				out.append(row)
	return out

# The rows the settings screen should have, in order: each setting that is not per job, then each per-job setting's
# jobs, in the game's order. Each is [the row's name, the setting's key, the job or null].
func expectedRows(model):
	var out = []
	for key in model.SETTINGS:
		if not model.SETTINGS[key].get("perJob", false):
			out.append([model.SETTINGS[key].label, key, null])
	for key in model.SETTINGS:
		if model.SETTINGS[key].get("perJob", false):
			for job in jobsByName():
				out.append([job, key, job])
	return out

# The game's jobs in alphabetical order of their names in the language set now, whatever the case.
func jobsByName() -> Array:
	var out = CurrentGame.occupations.duplicate()
	out.sort_custom(self, "_jobNameBefore")
	return out

func _jobNameBefore(a, b) -> bool:
	return tr(a).to_lower() < tr(b).to_lower()

# The jobs a group's rows are for (its rows' names, the jobs' keys), in order.
func rowJobs(group) -> Array:
	var out = []
	for row in group.get_children():
		if "tune" in row:
			out.append(row.get_node("HBoxContainer/Name").text)
	return out

# The index of the row of `job` for a per-job setting `key`.
func rowOf(model, key, job) -> int:
	var expected = expectedRows(model)
	for i in range(expected.size()):
		if expected[i][1] == key and expected[i][2] == job:
			return i
	return -1

func manifestValue(section, key):
	var manifest = ConfigFile.new()
	manifest.load(MANIFEST)
	return manifest.get_value(section, key)

func freeStation(s):
	s.root.queue_free()

func run():
	var mod = hasMod("CrewCheapHireNotifier")
	# The game's own menu script: at the root of the chain, which DealerNotifier, loaded too, extends as well.
	var game = rootScript(load("res://enceladus/EnceladusMenu.gd"))
	addTranslation("en", TEXT_EN, JOBS_EN)
	addTranslation("de", TEXT_DE, JOBS_DE)
	TranslationServer.set_locale("en")

	var t = 0 # the salary threshold's default; without the mod any salary will do
	if mod:
		var settings = load(SETTINGS_SCRIPT).SETTINGS
		t = settings.salaryThreshold.default
		tol = settings.salaryTolerance.default
	var top = t # the limit with nobody in that job: the threshold alone, which the tolerance never moves
	var h = t + 1000 # a hired pilot's salary, above the threshold, so it sets the pilots' limit
	setCrew([member("Cheap Pilot", PILOT, top - 100)], [])
	var control = make(game)
	yield(get_tree(), "physics_frame")
	check("control: without the mod a cheap hire leaves the entry as the game's key", entry(control) == KEY, entry(control))
	CurrentGame.emit_signal("dayPassed")
	check("control: without the mod a new day leaves it too", entry(control) == KEY, entry(control))
	var controlTab = hireTab(rootScript(load("res://enceladus/HireableCrew.gd")))
	controlTab.visible = true
	yield(frames(2), "completed")
	var controlEntry = hireEntry(controlTab, CurrentGame.availableCrew[0])
	check("control: without the mod a cheap hire's entry has no badge, and its Hire button is the game's", controlEntry != null and panels(controlEntry) == 0 and untouched(controlEntry))
	controlTab.queue_free()
	if not mod:
		return

	var menu = make()
	yield(get_tree(), "physics_frame")
	var marked = tr(menu._CHEAP_HIRE_ALERT) % TEXT_EN
	check("a cheap hire marks the entry as soon as the menu is ready, with the translated text", entry(menu) == marked, entry(menu))

	day([])
	check("nobody for hire: the entry keeps the game's key", entry(menu) == KEY, entry(menu))
	# Nobody in that job: the threshold alone; the tolerance never moves it.
	day([member("Pilot", PILOT, t)])
	check("a hire at the threshold, nobody in that job: marked", entry(menu) == marked, entry(menu))
	if tol > 0:
		day([member("Pilot", PILOT, (t + capped(t)) / 2.0)])
		check("a hire above the threshold but within the tolerance of it, nobody in that job: not marked, the tolerance doesn't raise the threshold", entry(menu) == KEY, entry(menu))
	else:
		note("the tolerance's default isn't positive: no salary lies within it above the threshold")
	day([member("Pilot", PILOT, t + 100)])
	check("a hire above the threshold, nobody in that job: not marked", entry(menu) == KEY, entry(menu))

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
	var low = t / (1.0 + tol) - 200 # a best-paid pilot whose salary, with the tolerance, stays below the threshold
	day([member("Pilot", PILOT, t)], [member("Hired Pilot", PILOT, low)])
	check("my best-paid in that job earns less than the threshold, even with the tolerance: the threshold applies", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, t + 100)], [member("Hired Pilot", PILOT, low)])
	check("and the tolerance doesn't lift the threshold: a hire above it is not marked", entry(menu) == KEY, entry(menu))
	day([member("Pilot", PILOT, capped(h))], [member("Low Pilot", PILOT, h - 300), member("High Pilot", PILOT, h), member("Mid Pilot", PILOT, h - 100)])
	check("the best-paid in that job counts, whatever the order", entry(menu) == marked, entry(menu))
	day([member("Pilot A", PILOT, top + 300), member("Mechanic", MECHANIC, top - 100), member("Pilot B", PILOT, top + 500)])
	check("one cheap hire among several: marked", entry(menu) == marked, entry(menu))

	# The tolerance at its minimum (negative, unless SETTINGS says otherwise): it changes my best-paid salary only.
	var least = load(SETTINGS_SCRIPT).SETTINGS.salaryTolerance.min
	menu._settings.setValue(TOLERANCE, least - 1.0)
	check("a tolerance set below its minimum is clamped to it", menu._settings.getValue(TOLERANCE) == least, menu._settings.getValue(TOLERANCE))
	var paid = (t + 500) / (1.0 + least) # a best-paid pilot whose salary, with the tolerance, stays above the threshold
	var paidPilot = [member("Hired Pilot", PILOT, paid)]
	day([member("Pilot", PILOT, paid * (1.0 + least))], paidPilot)
	check("at the tolerance's minimum, a hire at my best-paid in that job times it: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, paid * (1.0 + least) + 100)], paidPilot)
	check("and above that: not marked", entry(menu) == KEY, entry(menu))
	if least < 0:
		day([member("Pilot", PILOT, paid)], paidPilot)
		check("a negative tolerance: a hire at my best-paid's own salary is not marked", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, t)])
		check("and with nobody in that job a hire at the threshold still is: the tolerance never lowers it", entry(menu) == marked, entry(menu))
	else:
		note("the tolerance's minimum isn't negative")
	CurrentGame.state.ui = {}
	menu._settings.loadFromState()

	# The crew limit: a job whose hired crew has reached it is full, and there only a hire earning less than my best-paid
	# in that job counts, whatever the threshold and the tolerance say. The limits used are 0 to 3.
	var crewLimit = load(SETTINGS_SCRIPT).SETTINGS.crewLimit
	check("every job's crew limit starts at its default, the most it can be", everyJob(menu._settings, crewLimit.default) and crewLimit.default == crewLimit.max, crewLimit)
	if crewLimit.min > 0 or crewLimit.max < 3:
		note("the crew limit's range doesn't reach from 0 to 3: its checks are skipped")
	else:
		menu._settings.setValue(CREW_LIMIT, 2, PILOT)
		day([member("Pilot", PILOT, capped(h))], hired)
		check("a job below its crew limit: the usual rule, a hire at my best-paid plus the tolerance is marked", entry(menu) == marked, entry(menu))
		menu._settings.setValue(CREW_LIMIT, 1, PILOT)
		check("a limit lowered to the crew I have fills the job at once: that hire is no longer marked", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, h)], hired)
		check("in a full job, a hire at my best-paid's salary: not marked", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, h - 100)], hired)
		check("and one earning less: marked", entry(menu) == marked, entry(menu))
		var lowPilot = [member("Low Pilot", PILOT, t - 300)]
		day([member("Pilot", PILOT, t - 200)], lowPilot)
		check("in a full job the threshold doesn't apply: a hire below it but not below my best-paid is not marked", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, t - 400)], lowPilot)
		check("and one below my best-paid is", entry(menu) == marked, entry(menu))
		menu._settings.setValue(TOLERANCE, least)
		day([member("Pilot", PILOT, h - 100)], hired)
		check("nor does the tolerance: at its minimum, a hire earning less than my best-paid is still marked", entry(menu) == marked, entry(menu))
		menu._settings.setValue(TOLERANCE, tol)
		day([member("Mechanic", MECHANIC, top - 100)], hired)
		check("another job is judged as usual while the pilots are full", entry(menu) == marked, entry(menu))
		menu._settings.setValue(CREW_LIMIT, 3, PILOT)
		var away = [member("Hired Pilot", PILOT, h), benched(member("Benched Pilot", PILOT, h - 500)), onLeave(member("Away Pilot", PILOT, h - 400))]
		day([member("Pilot", PILOT, capped(h))], away)
		check("benched and on-leave crew count toward the limit: a job full with them takes no hire above my best-paid", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, h - 100)], away)
		check("and takes a cheaper one", entry(menu) == marked, entry(menu))
		menu._settings.setValue(CREW_LIMIT, 0, PILOT)
		day([member("Pilot", PILOT, t - 100)])
		check("a limit of 0 with nobody in the job: even a hire below the threshold is not marked", entry(menu) == KEY, entry(menu))
		day([member("Pilot", PILOT, h - 100)], hired)
		check("and with someone in it, a hire earning less than them is", entry(menu) == marked, entry(menu))
		# Firing frees the job and hiring fills it, as CurrentGame.fireCrewmember and hireCrewmember announce it.
		menu._settings.setValue(CREW_LIMIT, 1, PILOT)
		var atThreshold = member("Pilot", PILOT, t)
		var lowHired = member("Low Pilot", PILOT, t - 100)
		day([atThreshold], [lowHired])
		check("a full job: a hire at the threshold, above my best-paid there, is not marked", entry(menu) == KEY, entry(menu))
		setCrew([atThreshold], [])
		CurrentGame.emit_signal("employmentChanged")
		check("firing that crew member frees the job: the threshold applies again (employmentChanged)", entry(menu) == marked, entry(menu))
		setCrew([atThreshold], [lowHired])
		CurrentGame.emit_signal("employmentChanged")
		check("and hiring one fills it again", entry(menu) == KEY, entry(menu))
	CurrentGame.state.ui = {}
	menu._settings.loadFromState()
	check("a save game without the mod's settings gives every job the default crew limit again", everyJob(menu._settings, crewLimit.default))

	# Hiring and firing, as CurrentGame.hireCrewmember and fireCrewmember announce them.
	var cheap = member("Pilot", PILOT, top + 100)
	var dear = member("Dear Pilot", PILOT, top + 200)
	day([cheap, dear])
	check("two pilots for hire, both above the threshold, nobody in that job: not marked", entry(menu) == KEY, entry(menu))
	setCrew([cheap], [dear])
	CurrentGame.emit_signal("employmentChanged")
	check("hiring the better-paid one marks the other (employmentChanged)", entry(menu) == marked, entry(menu))
	setCrew([cheap, dear], [])
	CurrentGame.emit_signal("employmentChanged")
	check("firing it clears the mark again", entry(menu) == KEY, entry(menu))

	day([member("Pilot", PILOT, top - 100)])
	TranslationServer.set_locale("de")
	check("after a language change a marked entry is in the new language", entry(menu) == tr(menu._CHEAP_HIRE_ALERT) % TEXT_DE, entry(menu))
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
	var cl = model.SETTINGS.crewLimit
	var third = CurrentGame.occupations[2] # a job besides the pilots and the mechanics
	check("the crew limit is per job, for each job the game draws hires from, and the salary settings are not", settings.isPerJob(CREW_LIMIT) and not settings.isPerJob(TOLERANCE) and not settings.isPerJob("salaryThreshold") and settings.jobs() == CurrentGame.occupations, settings.jobs())
	CurrentGame.state.ui = {"unrelated": 1}
	settings.loadFromState()
	check("a save game without the mod's settings gives the defaults, the crew limit's for every job", settings.getValue("salaryThreshold") == th.default and settings.getValue(TOLERANCE) == to.default and everyJob(settings, cl.default))
	CurrentGame.state.ui[id] = {"salaryThreshold": th.max + th.step, "salaryTolerance": "much", "crewLimit": "many"}
	settings.loadFromState()
	check("a saved value above its range is clamped to the maximum", settings.getValue("salaryThreshold") == th.max, settings.getValue("salaryThreshold"))
	check("a saved value that is not a number gives the default, and so does a crew limit that is not a dictionary", settings.getValue(TOLERANCE) == to.default and everyJob(settings, cl.default))
	CurrentGame.state.ui[id] = {"salaryThreshold": th.min - th.step}
	settings.loadFromState()
	check("a saved value below its range is clamped to the minimum", settings.getValue("salaryThreshold") == th.min, settings.getValue("salaryThreshold"))
	var newTol = to.default + to.step if to.default + to.step <= to.max else to.default - to.step
	CurrentGame.state.ui[id] = {"salaryThreshold": th.default, "salaryTolerance": newTol}
	settings.loadFromState()
	check("a save from before the crew limit keeps its tolerance, and every job gets the default limit", is_equal_approx(settings.getValue(TOLERANCE), newTol) and everyJob(settings, cl.default), settings.getValue(TOLERANCE))
	CurrentGame.state.ui[id] = {"salaryThreshold": th.default, "salaryTolerance": {PILOT: newTol, MECHANIC: newTol}}
	settings.loadFromState()
	check("a tolerance saved as a dictionary by job, as the rolled-back per-job tolerance saved it, gives the default tolerance", settings.getValue(TOLERANCE) == to.default, settings.getValue(TOLERANCE))
	CurrentGame.state.ui[id] = {"crewLimit": {PILOT: cl.max + 5, MECHANIC: "many", third: cl.min + 1.6 * cl.step}}
	settings.loadFromState()
	var others = true
	for job in CurrentGame.occupations:
		if not job in [PILOT, MECHANIC, third]:
			others = others and settings.getValue(CREW_LIMIT, job) == cl.default
	check("a saved job's crew limit above its range is clamped to the maximum", settings.getValue(CREW_LIMIT, PILOT) == cl.max, settings.getValue(CREW_LIMIT, PILOT))
	check("one that is not a number gives the default, and so does a job the save has no value for", settings.getValue(CREW_LIMIT, MECHANIC) == cl.default and others)
	check("one between steps is snapped to the nearest", settings.getValue(CREW_LIMIT, third) == cl.min + 2 * cl.step, settings.getValue(CREW_LIMIT, third))
	CurrentGame.state.ui = {}
	settings.loadFromState()
	settings.connect("settingsChanged", self, "_countChange")
	changes = 0
	settings.setValue("salaryThreshold", th.default)
	settings.setValue(CREW_LIMIT, cl.default, PILOT)
	check("setting the value a setting already has stores and signals nothing", changes == 0 and not CurrentGame.state.ui.has(id))
	var newT = th.default + th.step if th.default + th.step <= th.max else th.default - th.step
	settings.setValue("salaryThreshold", newT)
	var saved = CurrentGame.state.ui.get(id, {})
	check("a changed value signals once", changes == 1, changes)
	check("and is stored in the save game's UI store under the mod's id, with every setting and every job's crew limit", saved.get("salaryThreshold") == newT and saved.get(TOLERANCE) == to.default and everySavedJob(saved.get(CREW_LIMIT), cl.default), saved)
	check("with the format version and the manifest's version", saved.get("formatVersion") == model.FORMAT_VERSION and saved.get("modVersion") == version, saved)
	var newLimit = cl.default - cl.step if cl.default - cl.step >= cl.min else cl.default + cl.step
	settings.setValue(CREW_LIMIT, newLimit, PILOT)
	var savedLimits = CurrentGame.state.ui.get(id, {}).get(CREW_LIMIT, {})
	check("a job's changed crew limit signals once and is stored for that job only", changes == 2 and savedLimits.get(PILOT) == newLimit and savedLimits.get(MECHANIC) == cl.default and settings.getValue(CREW_LIMIT, MECHANIC) == cl.default, savedLimits)
	settings.setValue(CREW_LIMIT, cl.min - cl.step, MECHANIC)
	check("a job's crew limit set below the range is clamped", settings.getValue(CREW_LIMIT, MECHANIC) == cl.min, settings.getValue(CREW_LIMIT, MECHANIC))
	check("and what was stored before is a copy, which the change left alone", savedLimits.get(MECHANIC) == cl.default, savedLimits)
	settings.setValue(CREW_LIMIT, cl.min + 1.6 * cl.step, third)
	check("a crew limit set between steps is snapped to the nearest", settings.getValue(CREW_LIMIT, third) == cl.min + 2 * cl.step, settings.getValue(CREW_LIMIT, third))
	settings.setValue("salaryThreshold", th.max + th.step)
	check("a value set above the range is clamped", settings.getValue("salaryThreshold") == th.max)
	var shown = settings.toShown(TOLERANCE, to.default)
	check("the tolerance is shown multiplied by its `shown` (as %) and converted back", is_equal_approx(shown, to.default * to.shown) and is_equal_approx(settings.fromShown(TOLERANCE, shown), to.default), shown)
	settings.disconnect("settingsChanged", self, "_countChange")
	CurrentGame.state.ui = {}
	settings.loadFromState()

	# The texts (i18n/en.po), also in a language without them (Godot's fallback, en)
	var textKeys = [load(MENU_SCRIPT)._CHEAP_HIRE_ALERT, load(MENU_SCRIPT)._CHEAP_HIRE_SETTINGS_TOOLTIP, load(HIRE_TAB_SCRIPT)._CHEAP_HIRE_LIMIT_TOOLTIP, load(HIRE_TAB_SCRIPT)._CHEAP_HIRE_FULL_TOOLTIP, load(HIRE_TAB_SCRIPT)._CHEAP_HIRE_HIRED_TOOLTIP, load(UI_SCRIPT).GROUP_LABEL]
	for key in model.SETTINGS:
		textKeys.append(model.SETTINGS[key].label)
	var translated = true
	for key in textKeys:
		translated = translated and tr(key) != key
	check("the mod's texts are translated", translated, textKeys)
	TranslationServer.set_locale("fr")
	translated = true
	for key in textKeys:
		translated = translated and tr(key) != key
	check("a language without them shows the English texts", translated)
	TranslationServer.set_locale("en")

	# The Hire screen (HireScreen.gd), with the station menu beside it.
	var cheapPilot = member("Cheap Pilot", PILOT, top - 100)
	var edgeMechanic = member("Edge Mechanic", MECHANIC, top)
	var dearPilot = member("Dear Pilot", PILOT, top + 100)
	setCrew([dearPilot, cheapPilot, edgeMechanic], []) # not in salary order, as CrewPerfectSort would sort it
	var tab = hireTab()
	var beside = make()
	get_tree().notification(MainLoop.NOTIFICATION_WM_MOUSE_ENTER)
	yield(get_tree(), "physics_frame")
	tab.visible = true
	yield(frames(2), "completed")
	var e = hireEntry(tab, cheapPilot)
	var badge = badgeOf(tab, e)
	check("a cheap hire's entry has a visible badge", badge != null and badge.visible)
	if badge != null:
		var values = e.fullNameNode
		var grid = values.get_parent()
		var bottom = badge.rect_global_position.y + badge.rect_size.y
		var right = badge.rect_global_position.x + badge.rect_size.x
		var valuesRight = values.rect_global_position.x + values.rect_size.x
		check("above the values, right-aligned with them, one grid row gap above the details, at its minimum size", is_equal_approx(right, valuesRight) and badge.rect_global_position.x >= values.rect_global_position.x and is_equal_approx(bottom, grid.rect_global_position.y - grid.get_constant("vseparation")) and badge.rect_size == badge.get_combined_minimum_size(), "%s %s, values at %s %s" % [badge.rect_global_position, badge.rect_size, values.rect_global_position, values.rect_size])
		check("inside the entry, in the empty band above the details", badge.rect_global_position.y >= e.rect_global_position.y, "%s, entry at %s" % [badge.rect_global_position, e.rect_global_position])
		var initials = ""
		for c in manifestValue("mod_information", "name"):
			if c != c.to_lower():
				initials += c
		var label = badge.get_child(0) if badge.get_child_count() > 0 else null
		check("holding the capitals of the mod's name", label is Label and label.text == initials, label.text if label is Label else "(no label)")
		check("in the Hire button's font color times the entry's colorBetter", label is Label and label.get_color("font_color").is_equal_approx(HIRE_FONT_COLOR * e.colorBetter))
		var frame = tab.theme.get_stylebox("normal", "Button")
		var copy = badge.get_stylebox("panel")
		check("its frame is a copy of the Hire button's, its border in the entry's colorBetter", copy is StyleBoxFlat and copy != frame and copy.border_color == e.colorBetter and copy.bg_color == frame.bg_color and copy.corner_radius_top_left == frame.corner_radius_top_left and copy.corner_radius_bottom_right == frame.corner_radius_bottom_right and copy.content_margin_left == frame.content_margin_left)
		check("and the theme's frame is left as it was", frame.border_color == HIRE_FRAME_BORDER)
		check("it lets the mouse through to the list (the wheel) and still gets the mouse's enter and exit", badge.mouse_filter == Control.MOUSE_FILTER_PASS)
		var hovered = shownTip(tab, e)
		check("moving the mouse over it shows the game's tooltip, giving the limit for their job, in the game's language, and how many of that job I've hired out of its crew limit", hovered == limitTip(tab, PILOT_EN, top) + "\n" + hiredLine(tab, e), hovered)
		check("the game's tooltip took over its hint_tooltip, so Godot's own (off screen in the released game) shows nothing", badge.hint_tooltip == "", badge.hint_tooltip)
		check("moving the mouse away hides the game's tooltip", not e.get_node("PlaySoundsOnTheseButtons").tooltipPosition.visible)
	check("the Hire button is the game's: no color override, no tooltip", untouched(e))
	check("and the entry is as tall as one without a badge", e != null and hireEntry(tab, dearPilot) != null and is_equal_approx(e.rect_size.y, hireEntry(tab, dearPilot).rect_size.y))
	e = hireEntry(tab, edgeMechanic)
	check("a hire at exactly the limit has a badge too, with their own job's limit", badged(tab, e, tr(MECHANIC), top), tip(tab, e))
	e = hireEntry(tab, dearPilot)
	check("a hire above the limit has none", unbadged(tab, e) and untouched(e), tip(tab, e))
	check("someone has a badge, and the menu is marked", entry(beside) != KEY, entry(beside))
	if hasMod("CrewPerfectSort"):
		var order = []
		for child in tab.hireableCrew.get_children():
			if not child.is_queued_for_deletion():
				order.append(child.salary)
		var sorted = order.duplicate()
		sorted.sort()
		check("with CrewPerfectSort the list is sorted by salary, and the badges stay", order == sorted and badged(tab, hireEntry(tab, cheapPilot), PILOT_EN, top) and unbadged(tab, hireEntry(tab, dearPilot)), order)

	# A new day: the game keeps the entries of those still for hire, and the mod judges them again.
	var hiredPilot = member("Hired Pilot", PILOT, h)
	var kept = hireEntry(tab, dearPilot)
	day([cheapPilot, dearPilot], [hiredPilot])
	e = hireEntry(tab, dearPilot)
	check("a new day judges a kept entry again: my better-paid pilot raises the pilots' limit and gives it a badge", e == kept and badged(tab, e, PILOT_EN, capped(h)), tip(tab, e))
	e = hireEntry(tab, cheapPilot)
	check("an entry with a badge kept to the next day still has exactly one, with the new limit", e != null and panels(e) == 1 and badged(tab, e, PILOT_EN, capped(h)), tip(tab, e))
	setCrew([cheapPilot, dearPilot], [])
	CurrentGame.emit_signal("employmentChanged")
	e = hireEntry(tab, dearPilot)
	check("firing that pilot (employmentChanged) hides its badge", unbadged(tab, e), tip(tab, e))

	# Hiring on the Hire screen (HireableCrew.gd hire: CurrentGame.hireCrewmember, then fillCrew).
	var pilotA = member("Pilot A", PILOT, top + 100)
	var pilotB = member("Pilot B", PILOT, top + 200)
	day([pilotA, pilotB])
	check("nobody counts: no entry has a badge, and the menu isn't marked", unbadged(tab, hireEntry(tab, pilotA)) and unbadged(tab, hireEntry(tab, pilotB)) and entry(beside) == KEY, entry(beside))
	tab.hire(pilotB)
	yield(frames(1), "completed") # Pilot A's entry is new this frame: its containers lay it out at the frame's end
	e = hireEntry(tab, pilotA)
	check("hiring the better-paid pilot there gives the other a badge, with the new limit", badged(tab, e, PILOT_EN, capped(top + 200)), tip(tab, e))

	# A setting changed (settingsChanged) applies at once: a hire between the old and the new limit flips.
	var between = member("Between Pilot", PILOT, (t + newT) / 2.0)
	day([between])
	e = hireEntry(tab, between)
	var hadBadge = not unbadged(tab, e)
	settings.setValue("salaryThreshold", newT)
	check("changing the threshold shows or hides the badge at once", unbadged(tab, e) == hadBadge, tip(tab, e))
	settings.setValue("salaryThreshold", th.default)
	check("and changing it back undoes it", unbadged(tab, e) != hadBadge, tip(tab, e))
	CurrentGame.state.ui = {}
	settings.loadFromState()

	# A full job: the badge says so, with my best-paid salary there; with room again, it gives the limit.
	if cl.min <= 1 and cl.max >= 2:
		var cheaperPilot = member("Cheaper Pilot", PILOT, h - 100)
		day([cheaperPilot], [hiredPilot])
		yield(frames(1), "completed") # a new entry, laid out at the frame's end
		settings.setValue(CREW_LIMIT, 1, PILOT)
		e = hireEntry(tab, cheaperPilot)
		check("in a full job, a cheaper hire's badge tells the job is full, with my best-paid salary there", badgedWith(tab, e, fullTip(tab, PILOT_EN, h)), tip(tab, e))
		check("and, on a second line, that I've hired 1 pilot out of 1", tip(tab, e).ends_with("\n" + tr(tab._CHEAP_HIRE_HIRED_TOOLTIP) % [1, 1]), tip(tab, e))
		settings.setValue(CREW_LIMIT, 2, PILOT)
		check("with room in the job again, the badge gives the limit", badged(tab, e, PILOT_EN, capped(h)), tip(tab, e))
		check("and that I've hired 1 out of 2", tip(tab, e).ends_with("\n" + tr(tab._CHEAP_HIRE_HIRED_TOOLTIP) % [1, 2]), tip(tab, e))
		CurrentGame.state.ui = {}
		settings.loadFromState()
		day([cheaperPilot], [hiredPilot, benched(member("Benched Pilot", PILOT, h - 500)), onLeave(member("Away Pilot", PILOT, h - 400))])
		yield(frames(1), "completed")
		e = hireEntry(tab, cheaperPilot)
		check("benched and on-leave pilots count in that line too, out of the default limit", tip(tab, e).ends_with("\n" + tr(tab._CHEAP_HIRE_HIRED_TOOLTIP) % [3, cl.default]), tip(tab, e))
	else:
		note("the crew limit's range doesn't reach from 1 to 2: the full job's badge isn't checked")

	day([cheapPilot])
	yield(frames(1), "completed") # a new entry, laid out at the frame's end
	TranslationServer.set_locale("de")
	e = hireEntry(tab, cheapPilot)
	check("after a language change the badge's tooltip names the job in the new language", badged(tab, e, PILOT_DE, top), tip(tab, e))
	TranslationServer.set_locale("en")
	yield(frames(2), "completed")
	for node in [tab, beside]:
		node.queue_free()
	setCrew([], [])
	yield(frames(2), "completed")

	# The settings screen, in a station built as Enceladus.tscn nests it.
	Input.set_use_accumulated_input(false)
	bindGameKeys()
	var probe = Node.new()
	probe.set_script(load("res://harness/unhandled_probe.gd"))
	add_child(probe)
	setCrew([], [])
	var s = station()
	yield(frames(2), "completed")
	check("the Crew entry's tooltip tells about Shift+Click", s.crew.hint_tooltip == settingsTip(s.menu), s.crew.hint_tooltip)
	var german = Translation.new()
	german.locale = "de"
	german.add_message(s.menu._CHEAP_HIRE_SETTINGS_TOOLTIP, SETTINGS_TOOLTIP_DE)
	TranslationServer.add_translation(german)
	TranslationServer.set_locale("de")
	check("after a language change the tooltip is in the new language", s.crew.hint_tooltip == SETTINGS_TOOLTIP_DE % [OS.get_scancode_string(KEY_SHIFT), manifestValue("mod_information", "name")], s.crew.hint_tooltip)
	TranslationServer.set_locale("en")
	check("and back", s.crew.hint_tooltip == settingsTip(s.menu), s.crew.hint_tooltip)
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
	var g = groups(screen)
	check("two Tuning groups: the settings that are not per job, then the crew limit, one row per job", g.size() == 2 and g[0].get_node("Label").text == load(UI_SCRIPT).GROUP_LABEL and g[1].get_node("Label").text == cl.label, g.size())
	check("in an Items box in the scroll, as the Tuning screen's", screen.get_node_or_null("VB/ScrollContainer/Items") is VBoxContainer)
	check("right below the header", screen.get_node("VB/ScrollContainer").get_index() == screen.get_node("VB/HeaderWithMoney").get_index() + 1)
	# A different crew limit for each job, so each row shows its own.
	var step = 0
	for job in CurrentGame.occupations:
		settings.setValue(CREW_LIMIT, clamp(cl.max - step * cl.step, cl.min, cl.max), job)
		step += 1
	screen.hide()
	yield(frames(40), "completed")
	click(s.crew, true)
	yield(frames(5), "completed")
	var r = rows(screen)
	var expected = expectedRows(model)
	var labelsOk = r.size() == expected.size()
	var rangesOk = labelsOk
	var valuesOk = labelsOk
	for i in range(min(r.size(), expected.size())):
		var key = expected[i][1]
		var setting = model.SETTINGS[key]
		var slider = r[i].get_node("HSlider")
		labelsOk = labelsOk and r[i].get_node("HBoxContainer/Name").text == expected[i][0] and r[i].get_node("HBoxContainer/Unit").text == setting.unit
		rangesOk = rangesOk and is_equal_approx(slider.min_value, settings.toShown(key, setting.min)) and is_equal_approx(slider.max_value, settings.toShown(key, setting.max)) and is_equal_approx(slider.step, settings.toShown(key, setting.step))
		valuesOk = valuesOk and is_equal_approx(slider.value, settings.toShown(key, settings.getValue(key, expected[i][2])))
	check("one Tuning row per setting, a crew-limit row per job, named by its key, with the setting's unit", labelsOk, r.size())
	check("each slider has its setting's range and step, in the units shown", rangesOk)
	check("and starts from the current value, its job's for a crew limit", valuesOk)
	check("the first slider has the focus", r.size() > 0 and r[0].get_node("HSlider").has_focus())
	# The crew limit's rows by the jobs' names, in the language the screen opens in.
	g = groups(screen)
	var orderEn = rowJobs(g[1]) if g.size() > 1 else []
	check("the crew limit's rows are in alphabetical order of the jobs' names, whatever the case", orderEn == jobsByName() and orderEn != CurrentGame.occupations, orderEn)
	screen.hide()
	yield(frames(40), "completed")
	TranslationServer.set_locale("de")
	click(s.crew, true)
	yield(frames(5), "completed")
	g = groups(screen)
	var orderDe = rowJobs(g[1]) if g.size() > 1 else []
	check("opened in another language, they follow its names", orderDe == jobsByName() and orderDe != orderEn, orderDe)
	TranslationServer.set_locale("en")
	CurrentGame.state.ui = {}
	settings.loadFromState()
	screen.hide()
	yield(frames(40), "completed")
	click(s.crew, true)
	yield(frames(5), "completed")
	r = rows(screen)
	check("opening the screen stores nothing", not CurrentGame.state.ui.has(id), CurrentGame.state.ui)
	var toleranceRow = rowOf(model, TOLERANCE, null)
	var pilotRow = rowOf(model, CREW_LIMIT, PILOT)

	# Moving a slider applies at once: a hire between the old and the new limit flips the mark.
	day([member("Pilot", PILOT, (t + newT) / 2.0)])
	var before = entry(s.menu)
	r[0].get_node("HSlider").value = settings.toShown("salaryThreshold", newT)
	check("moving the threshold slider flips the mark at once", entry(s.menu) != before, "%s -> %s" % [before, entry(s.menu)])
	check("and stores the value in the save game", CurrentGame.state.ui.get(id, {}).get("salaryThreshold") == newT, CurrentGame.state.ui)
	# The tolerance changes only my best-paid salary: a hired pilot, paid so that with either tolerance the limit is
	# above the threshold, and a hire between the two limits.
	var paidMore = 2 * newT + 1000
	day([member("Pilot", PILOT, paidMore * (1.0 + (tol + newTol) / 2.0))], [member("Hired Pilot", PILOT, paidMore)])
	before = entry(s.menu)
	if toleranceRow < r.size():
		r[toleranceRow].get_node("HSlider").value = settings.toShown(TOLERANCE, newTol)
	check("moving the tolerance slider flips the mark at once", entry(s.menu) != before, "%s -> %s" % [before, entry(s.menu)])
	check("and stores it as a fraction", is_equal_approx(CurrentGame.state.ui.get(id, {}).get(TOLERANCE, -1.0), newTol), CurrentGame.state.ui)
	r[0].get_node("HBoxContainer/Reset").emit_signal("pressed")
	check("a row's reset button brings the default back, and stores it", settings.getValue("salaryThreshold") == th.default and CurrentGame.state.ui.get(id, {}).get("salaryThreshold") == th.default, settings.getValue("salaryThreshold"))
	# The pilots' crew limit down to the one pilot I have: a hire below the threshold but not below my best-paid there.
	if cl.min <= 1 and cl.max >= 1:
		day([member("Pilot", PILOT, t - 200)], [member("Low Pilot", PILOT, t - 300)])
		before = entry(s.menu)
		if pilotRow < r.size():
			r[pilotRow].get_node("HSlider").value = settings.toShown(CREW_LIMIT, 1)
		check("moving the pilots' crew limit slider flips the mark at once", entry(s.menu) != before, "%s -> %s" % [before, entry(s.menu)])
		var stored = CurrentGame.state.ui.get(id, {}).get(CREW_LIMIT, {})
		check("and stores it for the pilots only", stored is Dictionary and stored.get(PILOT) == 1 and stored.get(MECHANIC) == cl.default and settings.getValue(CREW_LIMIT, MECHANIC) == cl.default, stored)
	else:
		note("the crew limit's range doesn't hold 1: its slider isn't checked")

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
	settings.setValue(CREW_LIMIT, newLimit, PILOT)
	CurrentGame.state = parse_json(to_json(CurrentGame.state))
	# What another save game would leave in the shared instance.
	settings.cfg.salaryThreshold = th.default
	settings.cfg.crewLimit[PILOT] = cl.default
	freeStation(s)
	yield(frames(1), "completed")
	s = station()
	yield(frames(2), "completed")
	check("after a save and a load, a new station uses the saved values", settings.getValue("salaryThreshold") == newT and settings.getValue(CREW_LIMIT, PILOT) == newLimit and settings.getValue(CREW_LIMIT, MECHANIC) == cl.default, [settings.getValue("salaryThreshold"), settings.getValue(CREW_LIMIT, PILOT)])
	click(s.crew, true)
	yield(frames(5), "completed")
	screen = settingsScreen(s)
	r = rows(screen) if screen != null else []
	check("and the settings screen opens on them", r.size() > pilotRow and is_equal_approx(r[0].get_node("HSlider").value, settings.toShown("salaryThreshold", newT)) and is_equal_approx(r[pilotRow].get_node("HSlider").value, settings.toShown(CREW_LIMIT, newLimit)))
	freeStation(s)
	yield(frames(1), "completed")

	s = station(false)
	yield(frames(2), "completed")
	check("without a Tuning screen there is no tooltip", s.crew.hint_tooltip == "", s.crew.hint_tooltip)
	click(s.crew, true)
	yield(frames(2), "completed")
	check("and Shift+Click is a plain click", s.crewScreen.opened == 1 and settingsScreen(s) == null, s.crewScreen.opened)

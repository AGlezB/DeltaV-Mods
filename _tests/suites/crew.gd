extends "res://harness/suite.gd"

# CrewCheapHireNotifier: the station menu's Crew entry (the `Crew` Button of the game's enceladus/EnceladusMenu.tscn,
# with no script and the translation key ENCELADUS_CREW as its text) shows the mod's ALERT_FORMAT while someone for
# hire earns at most the higher of SALARY_THRESHOLD and the best-paid hired member with the same job, plus
# SALARY_TOLERANCE of it. The constants are read from the mod and every salary is built from them, so any value of them
# passes. The hire list
# and the crew are the CurrentGame stub's. The control checks run on the game's own script: with the mod loaded, that
# is the base of the extension.

const KEY = "ENCELADUS_CREW"
const LOGS_KEY = "ENCELADUS_LOGS"
const PILOT = "CREW_OCCUPATION_PILOT"
const MECHANIC = "CREW_OCCUPATION_MECHANIC"
const TEXT_EN = "Crew"
const TEXT_DE = "Besatzung"

var tol = 0.0 # the mod's SALARY_TOLERANCE

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

func run():
	var mod = hasMod("CrewCheapHireNotifier")
	var game = load("res://enceladus/EnceladusMenu.gd")
	if mod:
		game = game.get_base_script()
	addTranslation("en", TEXT_EN)
	addTranslation("de", TEXT_DE)
	TranslationServer.set_locale("en")

	var t = 0 # SALARY_THRESHOLD; without the mod any salary will do
	if mod:
		var constants = load("res://enceladus/EnceladusMenu.gd").get_script_constant_map()
		t = constants.SALARY_THRESHOLD
		tol = constants.SALARY_TOLERANCE
	var top = capped(t) # the limit with nobody in that job
	var h = t + 1000 # a hired pilot's salary, above SALARY_THRESHOLD, so it sets the pilots' limit
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
	# Nobody in that job: SALARY_THRESHOLD plus SALARY_TOLERANCE.
	day([member("Pilot", PILOT, t)])
	check("a hire at SALARY_THRESHOLD, nobody in that job: marked", entry(menu) == marked, entry(menu))
	if tol > 0:
		day([member("Pilot", PILOT, (t + top) / 2.0)])
		check("a hire above SALARY_THRESHOLD but within SALARY_TOLERANCE: marked", entry(menu) == marked, entry(menu))
	else:
		note("SALARY_TOLERANCE is 0: no salary lies within it")
	day([member("Pilot", PILOT, top)])
	check("a hire at exactly SALARY_THRESHOLD plus SALARY_TOLERANCE: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, top + 100)])
	check("a hire above SALARY_THRESHOLD plus SALARY_TOLERANCE: not marked", entry(menu) == KEY, entry(menu))

	# My best-paid pilot sets the limit: that salary plus SALARY_TOLERANCE.
	var hired = [member("Hired Pilot", PILOT, h)]
	day([member("Pilot", PILOT, h)], hired)
	check("a hire at my best-paid in that job: marked", entry(menu) == marked, entry(menu))
	if tol > 0:
		day([member("Pilot", PILOT, (h + capped(h)) / 2.0)], hired)
		check("a hire above my best-paid in that job but within SALARY_TOLERANCE: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h))], hired)
	check("a hire at exactly my best-paid in that job plus SALARY_TOLERANCE: marked", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h) + 100)], hired)
	check("a hire above my best-paid in that job plus SALARY_TOLERANCE: not marked", entry(menu) == KEY, entry(menu))

	day([member("Pilot", PILOT, top + 100)], [member("Hired Mechanic", MECHANIC, h)])
	check("only another job pays more: not marked", entry(menu) == KEY, entry(menu))
	day([member("Pilot", PILOT, top)], [member("Hired Pilot", PILOT, t - 200)])
	check("my best-paid in that job earns less than SALARY_THRESHOLD: the threshold applies", entry(menu) == marked, entry(menu))
	day([member("Pilot", PILOT, capped(h))], [member("Low Pilot", PILOT, h - 300), member("High Pilot", PILOT, h), member("Mid Pilot", PILOT, h - 100)])
	check("the best-paid in that job counts, whatever the order", entry(menu) == marked, entry(menu))
	day([member("Pilot A", PILOT, top + 300), member("Mechanic", MECHANIC, top - 100), member("Pilot B", PILOT, top + 500)])
	check("one cheap hire among several: marked", entry(menu) == marked, entry(menu))

	# Hiring and firing, as CurrentGame.hireCrewmember and fireCrewmember announce them.
	var cheap = member("Pilot", PILOT, top + 100)
	var dear = member("Dear Pilot", PILOT, top + 200)
	day([cheap, dear])
	check("two pilots for hire, both above SALARY_THRESHOLD plus SALARY_TOLERANCE: not marked", entry(menu) == KEY, entry(menu))
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

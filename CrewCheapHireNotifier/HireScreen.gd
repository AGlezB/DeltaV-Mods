extends "res://enceladus/HireableCrew.gd"

# The Hire screen: everyone who counts (the settings model's isCheapHire, the rule that marks the station menu's Crew
# entry) gets a badge above the values of their entry's details, right-aligned with them: the capitals of the mod's
# name and how many crew members with their job you have hired out of its crew limit, in an outline, with a tooltip
# giving the limit for their job, or telling that the job is full, and those two numbers in words.

# The settings and the rule: their model, shared with the station menu and the settings screen.
const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

# The badge tooltip's first line, translation keys of i18n/en.po; the first %s is the job, in the game's language. The
# second is the limit, or, in a full job (isJobFull), the salary of your best-paid crew member in it.
const _CHEAP_HIRE_LIMIT_TOOLTIP = "CREWCHEAPHIRENOTIFIER_LIMIT_TOOLTIP"
const _CHEAP_HIRE_FULL_TOOLTIP = "CREWCHEAPHIRENOTIFIER_FULL_TOOLTIP"
# Its second line: the first %d is how many crew members with the job you have hired (crewCount), the second its crew
# limit.
const _CHEAP_HIRE_HIRED_TOOLTIP = "CREWCHEAPHIRENOTIFIER_HIRED_TOOLTIP"
# The badge's text, a translation key of i18n/en.po: the %s is the capitals of the mod's name, the first %d how many
# crew members with the job you have hired (crewCount), the second its crew limit.
const _CHEAP_HIRE_BADGE_TEXT = "CREWCHEAPHIRENOTIFIER_BADGE"
# What follows a salary, as the game writes one (enceladus/CrewBio.gd fillData).
const _CHEAP_HIRE_CURRENCY = " E$"

# The badge's node name in an entry, so that a refresh finds the badge it made.
const _CHEAP_HIRE_BADGE = "CrewCheapHireNotifierBadge"
# The badges' script: their tooltip as their only interaction.
const _CHEAP_HIRE_BADGE_SCRIPT = preload("res://CrewCheapHireNotifier/Badge.gd")

# The game calls fillCrew on every new day (dayPassed), after a hire and when the screen is first shown. A hire or
# a dismissal changes a job's limit and can fill or free the job, and so does a setting.
func _ready():
	CurrentGame.connect("employmentChanged", self, "_markCheapHires")
	CrewCheapHireNotifier.shared().connect("settingsChanged", self, "_markCheapHires")

# The tooltip holds the job's name already translated.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_markCheapHires()

func fillCrew():
	.fillCrew()
	_markCheapHires()

# Entries are told apart from other children by `fullName`, as fillCrew does. The game keeps an entry from one day to
# the next, so each is judged again; the game never touches the badge, so hiding it is enough. The badge's text holds
# counts that change, so it is set on every mark; the badge follows its size by itself, narrower as well as wider.
func _markCheapHires():
	if hireableCrew == null:
		return
	var settings = CrewCheapHireNotifier.shared()
	for entry in hireableCrew.get_children():
		if not "fullName" in entry or entry.is_queued_for_deletion() or entry.hireButton == null:
			continue
		var badge = _cheapHireAnchor(entry).get_node_or_null(_CHEAP_HIRE_BADGE)
		if settings.isCheapHire(entry):
			badge = _cheapHireBadge(entry)
			badge.get_child(0).text = _cheapHireBadgeText(settings, entry.occupation)
			badge.hint_tooltip = _cheapHireTooltip(settings, entry.occupation)
			badge.visible = true
		elif badge != null:
			badge.visible = false

# The badge's text for a job: the capitals of the mod's name, then how many crew members with the job you have hired
# out of its crew limit. The crew limit comes back from the save as a float, so it is made a whole number for %d.
func _cheapHireBadgeText(settings, occupation) -> String:
	return tr(_CHEAP_HIRE_BADGE_TEXT) % [_cheapHireInitials(), settings.crewCount(occupation), int(settings.getValue("crewLimit", occupation))]

# The badge's tooltip for a job, with the salary formatted as CrewBio.gd formats one, rounded down. Each sentence on
# its own line, as the game's own tooltips are; the tooltip's Label grows with them. The crew limit is made a whole
# number for %d, as in the badge's text.
func _cheapHireTooltip(settings, occupation) -> String:
	var text
	if settings.isJobFull(occupation):
		text = tr(_CHEAP_HIRE_FULL_TOOLTIP) % [tr(occupation), CurrentGame.formatThousands(floor(settings.bestPaid(occupation))) + _CHEAP_HIRE_CURRENCY]
	else:
		text = tr(_CHEAP_HIRE_LIMIT_TOOLTIP) % [tr(occupation), CurrentGame.formatThousands(floor(settings.limitFor(occupation))) + _CHEAP_HIRE_CURRENCY]
	return text + "\n" + tr(_CHEAP_HIRE_HIRED_TOOLTIP) % [settings.crewCount(occupation), int(settings.getValue("crewLimit", occupation))]

# What the badge hangs from: the game's fullNameNode, the top value of the entry's details grid, which spans the
# values' column to the grid's right edge, its text right-aligned (CrewBio.tscn). A Label is no container, so it
# leaves the badge where the badge puts itself.
func _cheapHireAnchor(entry):
	return entry.fullNameNode

# The entry's badge, made on first use, its text left to _markCheapHires: above the values, right-aligned with them.
# Anchored to the top value's top-right corner, its bottom edge one grid row gap (the grid's vseparation) above it, it
# grows left and up to its minimum size, so it follows the values wherever the layout puts them, in the empty band above
# the details (the portrait sets the entry's height). As a child of the details it fades with them in the game's hire
# animation. It lets the mouse through, so the wheel still scrolls the list, and still gets the mouse's enter and exit.
# The frame is a copy of the Hire button's (menu/ButtonRoundCorners.tres in the game) with its border in the entry's
# colorBetter: the game's border is overbright, and tinted it would clip to white. The letters are in the green the
# entry shows for a better stat (compareStats sets colorBetter as that stat button's modulate).
# The tooltip (Badge.gd): the entry's PlaySoundsOnTheseButtons (menu/sfx/PlaySoundsOnTheseButtons.gd) shows it below the
# badge on hover, silently, and reads it again on every hover, so _markCheapHires keeps setting it. With a gamepad, it
# shows while the entry's Hire button has the focus, which the D-pad moves from entry to entry.
func _cheapHireBadge(entry):
	var anchor = _cheapHireAnchor(entry)
	var badge = anchor.get_node_or_null(_CHEAP_HIRE_BADGE)
	if badge != null:
		return badge
	badge = _CHEAP_HIRE_BADGE_SCRIPT.new()
	badge.name = _CHEAP_HIRE_BADGE
	var gap = anchor.get_parent().get_constant("vseparation")
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.margin_left = 0
	badge.margin_right = 0
	badge.margin_top = -gap
	badge.margin_bottom = -gap
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame = entry.hireButton.get_stylebox("normal").duplicate()
	if frame is StyleBoxFlat:
		frame.border_color = entry.colorBetter
	badge.add_stylebox_override("panel", frame)
	var label = Label.new()
	label.add_color_override("font_color", entry.hireButton.get_color("font_color") * entry.colorBetter)
	badge.add_child(label)
	anchor.add_child(badge)
	badge.attachTooltip(entry.get_node_or_null("PlaySoundsOnTheseButtons"), entry.hireButton)
	return badge

# The capitals of the mod's name in Mod.manifest.
func _cheapHireInitials() -> String:
	var initials = ""
	for c in CrewCheapHireNotifier.shared().modName():
		if c != c.to_lower():
			initials += c
	return initials

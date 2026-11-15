extends "res://enceladus/HireableCrew.gd"

# The Hire screen: everyone who counts (the settings model's isCheapHire, the rule that marks the station menu's Crew
# entry) gets a badge above the values of their entry's details, right-aligned with them: the capitals of the mod's
# name in an outline, with a tooltip giving the limit for their job.

# The settings and the rule: their model, shared with the station menu and the settings screen.
const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

# The badge's tooltip; the first %s is the job, in the game's language, the second the limit.
const LIMIT_TOOLTIP_FORMAT = "Your limit for %s: %s"

# The badge's node name in an entry, so that a refresh finds the badge it made.
const _CHEAP_HIRE_BADGE = "CrewCheapHireNotifierBadge"

# The game calls fillCrew on every new day (dayPassed), after a hire and when the screen is first shown. A hire or
# a dismissal changes a job's limit, and so does a setting.
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
# the next, so each is judged again; the game never touches the badge, so hiding it is enough.
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
			badge.hint_tooltip = LIMIT_TOOLTIP_FORMAT % [tr(entry.occupation), CurrentGame.formatThousands(floor(settings.limitFor(entry.occupation))) + " E$"]
			badge.visible = true
		elif badge != null:
			badge.visible = false

# What the badge hangs from: the game's fullNameNode, the top value of the entry's details grid, which spans the
# values' column to the grid's right edge, its text right-aligned (CrewBio.tscn). A Label is no container, so it
# leaves the badge where the badge puts itself.
func _cheapHireAnchor(entry):
	return entry.fullNameNode

# The entry's badge, made on first use: above the values, right-aligned with them. Anchored to the top value's
# top-right corner, its bottom edge one grid row gap (the grid's vseparation) above it, it grows left and up to its
# minimum size, so it follows the values wherever the layout puts them, in the empty band above the details (the
# portrait sets the entry's height). As a child of the details it fades with them in the game's hire animation. It
# lets the mouse through, so the wheel still scrolls the list, and still gets the mouse's enter and exit.
# The frame is a copy of the Hire button's (menu/ButtonRoundCorners.tres in the game) with its border in the entry's
# colorBetter: the game's border is overbright, and tinted it would clip to white. The letters are in the green the
# entry shows for a better stat (compareStats sets colorBetter as that stat button's modulate).
# The tooltip: the released game puts Godot's own tooltips off screen (project.godot's
# display/mouse_cursor/tooltip_position_offset.release) and draws its own with the entry's PlaySoundsOnTheseButtons
# (menu/sfx/PlaySoundsOnTheseButtons.gd), which registers only the buttons and sliders it finds when the entry is
# made. Its connectSounds registers the badge too: it takes over the badge's hint_tooltip, shows it below the badge on
# hover (with the game's hover sound) and reads it again on every hover, so _markCheapHires keeps setting it.
func _cheapHireBadge(entry):
	var anchor = _cheapHireAnchor(entry)
	var badge = anchor.get_node_or_null(_CHEAP_HIRE_BADGE)
	if badge != null:
		return badge
	badge = PanelContainer.new()
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
	label.text = _cheapHireInitials()
	label.add_color_override("font_color", entry.hireButton.get_color("font_color") * entry.colorBetter)
	badge.add_child(label)
	anchor.add_child(badge)
	var tooltips = entry.get_node_or_null("PlaySoundsOnTheseButtons")
	if tooltips != null and tooltips.has_method("connectSounds"):
		tooltips.connectSounds(badge)
	return badge

# The capitals of the mod's name in Mod.manifest.
func _cheapHireInitials() -> String:
	var initials = ""
	for c in CrewCheapHireNotifier.shared().modName():
		if c != c.to_lower():
			initials += c
	return initials

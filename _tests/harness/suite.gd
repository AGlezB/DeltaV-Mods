extends Node

# Base of the suites: results, the loaded mods and the masses given on the command line.

const VP = preload("res://harness/vp_data.gd")
const Rig = preload("res://harness/rig.gd")

var mods = [] # folder names of the loaded mods
var shipMass = VP.SHIP_MASS
var chunkMass = VP.CHUNK_MASS
var passes = 0
var fails = 0

# Override: the suite's cases (a coroutine is fine).
func run():
	pass

func hasMod(modName) -> bool:
	return mods.has(modName)

func check(caseName, ok, details = ""):
	if ok:
		passes += 1
	else:
		fails += 1
	print(("PASS " if ok else "FAIL ") + caseName + ("" if str(details) == "" else "  [%s]" % str(details)))

func note(text):
	print("NOTE " + text)

# Deep equality, a number equal to the same number of the other type (Godot 3 compares dictionaries by reference).
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	var numbers = [TYPE_INT, TYPE_REAL]
	if typeof(a) != typeof(b):
		return numbers.has(typeof(a)) and numbers.has(typeof(b)) and a == b
	return a == b

# Waits `count` (at least 1) physics frames.
func frames(count):
	for i in max(1, count):
		yield(get_tree(), "physics_frame")

# The game's tooltip node (menu/sfx/PlaySoundsOnTheseButtons.tscn, the harness's stub of it), added to a station menu
# built in code as enceladus/EnceladusMenu.tscn has its own: the mods' Shift badges show their tooltips through it.
func addMenuTooltips(menu):
	var tooltips = load("res://menu/sfx/PlaySoundsOnTheseButtons.tscn").instance()
	tooltips.name = "PlaySoundsOnTheseButtons"
	menu.add_child(tooltips)
	return tooltips

# The Shift badge of a station menu entry or button (a mod's Badge.gd), which hangs from it, beside it or inside it; or
# null.
func shiftBadge(entry):
	for child in entry.get_children():
		if _isBadge(child):
			return child
	return null

func _isBadge(node):
	var script = node.get_script()
	return script != null and script.resource_path.ends_with("/Badge.gd")

# The tooltip of the Shift badge of `entry`, which holds it: the entry has none of its own. The game's tooltip node
# (`tooltips`, or the menu's, beside the entry) keeps the text once it has shown it, and empties the badge's own
# (PlaySoundsOnTheseButtons.gd connectSounds, showTooltip), until Badge.gd sets it again.
func badgeTip(entry, tooltips = null) -> String:
	var badge = shiftBadge(entry)
	if badge == null:
		return ""
	if badge.hint_tooltip != "":
		return badge.hint_tooltip
	if tooltips == null:
		tooltips = entry.get_parent().get_node_or_null("PlaySoundsOnTheseButtons")
	return tooltips.tooltips.get(badge, "") if tooltips != null else ""

# The Shift badge's tooltip as the game's tooltip node (`tooltips`) shows it: with keyboard and mouse on hover only, the
# keyboard wording (`keyTip`); with a gamepad, which shows no hover, while `entry` has the focus, the gamepad wording
# (`padTip`), and hidden once the focus moves on (to `other`). The checks are named after `what`. The control scheme is
# left at keyboard and mouse. The hover is checked only with `hover`: in most suites' stations a mouse moved through
# the scene tree's input shows no hover on any control, not even a plain button added to the root (cause not found);
# in the crew suite it does, and Badge.gd is the same file in every mod.
func shiftBadgeTipChecks(what, entry, other, tooltips, keyTip, padTip, hover = false):
	var badge = shiftBadge(entry)
	if badge == null or tooltips == null:
		check("%s: the Shift badge and the game's tooltip node are there" % what, false, [badge, tooltips])
		return
	Settings.controlScheme = Settings.control.keyMouse
	other.grab_focus()
	if hover:
		# From off the screen, so the mouse enters the badge whatever an earlier step left it over.
		_moveMouseTo(Vector2(-10, -10))
		_moveMouseTo(badge.rect_global_position + badge.rect_size / 2)
		var hovered = tooltips.tooltipLabel.text if tooltips.tooltipPosition.visible else "(no tooltip)"
		_moveMouseTo(Vector2(-10, -10))
		check("%s: with keyboard and mouse, hovering the Shift badge shows its tooltip, and moving away hides it" % what, hovered == keyTip and not tooltips.tooltipPosition.visible, hovered)
	entry.grab_focus()
	var keyFocus = tooltips.tooltipPosition.visible
	other.grab_focus()
	Settings.controlScheme = Settings.control.gamepad
	entry.grab_focus()
	var padShown = tooltips.tooltipLabel.text if tooltips.tooltipPosition.visible else "(no tooltip)"
	other.grab_focus()
	var padHidden = not tooltips.tooltipPosition.visible
	Settings.controlScheme = Settings.control.keyMouse
	check("%s: with keyboard and mouse, the entry getting the focus (a click, the keyboard) shows no tooltip" % what, not keyFocus)
	check("%s: with a gamepad, highlighting the entry shows the badge's tooltip, in its gamepad wording" % what, padShown == padTip, padShown)
	check("%s: and the highlight moving on hides it" % what, padHidden)

# The mouse moved to `at`, through the scene tree's input, as a player's.
func _moveMouseTo(at):
	var event = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_tree().input_event(event)
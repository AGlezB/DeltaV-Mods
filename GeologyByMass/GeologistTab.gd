extends "res://hud/SystemMineralList.gd"

# GeologyByMass: while the switch on the mod's OMS tab is on, the Geologist tab disables and dims the controls of its
# rows that the mod's switches and masses replace (Code.gd): each row's mineral switches and its Minimum value.
#
# The Geologist tab (hud/SystemMineralList.gd, the OMS's) has one row per system with mineral targeting, built by
# updateSystems: a switch per mineral (hud/components/MineralSystemToggle.tscn) and a Minimum value control
# (hud/components/PriceLabel.tscn) at the end, which the game leaves enabled for every row whose chunks the ship's rule
# judges (the HUD, the arm, the tug and haul drone plants, the NT Mining Companion) and disables for the cargo
# containers' docks (onlyMinerals without oreValueFilter), whose switches pick the processed ore they take and which the
# mod leaves alone. With the switch on, for the player's ship, the mod disables the switches and the Minimum value of
# every judged row, dimmed as the game dims a switch a row can't use (modulateDisabled), and leaves them in place with
# their values: a switch can't be toggled, and the Minimum value's button no longer opens its bar, which can't be
# dragged either (PriceLabel.gd's own `disabled` would hide them). Off, each is back as the game set it. They keep
# their focus, as the game's disabled switches do. The switch is on another tab, so the change shows as soon as this
# one does: the game processes the list only while it shows (_visibilityChanged).
#
# Stacking: the parent's _ready and _process are never called (Godot runs every level by itself); updateSystems falls
# through to the parent with `.updateSystems()`; new members start with `_`.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

# The Minimum value control's button, which opens its bar, and the bar (hud/components/PriceLabel.tscn).
const _GEOLOGY_BY_MASS_VALUE = "Box/MarginContainer/Label"
const _GEOLOGY_BY_MASS_BAR = "Box/HSlider"
# The node meta where each control the mod disables keeps the game's state of what the mod changes.
const _GEOLOGY_BY_MASS_GAME = "_geologyByMassGame"

var _geologyByMassSettings = null
var _geologyByMassOverridden = null # whether the controls are disabled now; null: not yet set on the current rows

# The game builds the rows anew (ship-ctrl.gd systemsChanged, setup).
func updateSystems(systems):
	.updateSystems(systems)
	_geologyByMassOverridden = null
	_geologyByMassOverride()

func _process(_delta):
	_geologyByMassOverride()

func _geologyByMass():
	if _geologyByMassSettings == null:
		_geologyByMassSettings = GeologyByMass.new(ship)
	return _geologyByMassSettings

# Disables or restores the judged rows' controls, only on a change; the game's own state is recorded once per control
# (the rows are built anew with every updateSystems).
func _geologyByMassOverride():
	if ship == null:
		return
	var overriding = ship.isPlayerControlled() and _geologyByMass().isEnabled()
	if overriding == _geologyByMassOverridden:
		return
	_geologyByMassOverridden = overriding
	var judged = []
	for found in _geologyByMassControls("valueChanged", "value"):
		var box = found[0]
		if box.disabled:
			continue
		judged.append(found[1])
		var button = box.get_node(_GEOLOGY_BY_MASS_VALUE)
		var bar = box.get_node(_GEOLOGY_BY_MASS_BAR)
		if not box.has_meta(_GEOLOGY_BY_MASS_GAME):
			box.set_meta(_GEOLOGY_BY_MASS_GAME, [button.disabled, bar.editable, box.modulate])
		var game = box.get_meta(_GEOLOGY_BY_MASS_GAME)
		button.disabled = true if overriding else game[0]
		bar.editable = false if overriding else game[1]
		box.modulate = modulateDisabled if overriding else game[2]
	for found in _geologyByMassControls("toggled", "toggle"):
		var toggle = found[0]
		if not found[1] in judged:
			continue
		if not toggle.has_meta(_GEOLOGY_BY_MASS_GAME):
			toggle.set_meta(_GEOLOGY_BY_MASS_GAME, [toggle.disabled, toggle.modulate])
		var game = toggle.get_meta(_GEOLOGY_BY_MASS_GAME)
		toggle.disabled = true if overriding else game[0]
		toggle.modulate = modulateDisabled if overriding else game[1]

# The rows' controls whose `signalName` reaches this list's `method` (updateSystems), each as [control, its row's
# system (the connection's first bound argument)]: the Minimum value controls (valueChanged -> value, which tells them
# from the Minimum Albedo controls, made from the same scene and reaching `albedo`) or the mineral switches (toggled ->
# toggle). The rows replaced by updateSystems are left out: they are freed at the end of the frame.
func _geologyByMassControls(signalName, method) -> Array:
	var controls = []
	for child in get_children():
		if child.is_queued_for_deletion() or not child.has_signal(signalName):
			continue
		for connection in child.get_signal_connection_list(signalName):
			if connection.target == self and connection.method == method:
				controls.append([child, connection.binds[0]])
				break
	return controls

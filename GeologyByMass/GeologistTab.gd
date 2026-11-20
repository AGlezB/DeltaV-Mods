extends "res://hud/SystemMineralList.gd"

# GeologyByMass: while the switch on the mod's OMS tab is on, the Geologist tab hides the Minimum value of its rows,
# which the mod's masses replace (Code.gd; each row's mineral switches still count), and that column's header.
#
# The Geologist tab (hud/SystemMineralList.gd, the OMS's) has one row per system with mineral targeting, built by
# updateSystems, each ending in a Minimum value control (hud/components/PriceLabel.tscn) the game leaves enabled for
# every row whose chunks the ship's rule judges (the HUD, the arm, the tug and haul drone plants, the NT Mining
# Companion) and disables for the cargo containers' docks (onlyMinerals without oreValueFilter). Disabled, the game's
# control hides its slider and its value, leaving the cell empty (PriceLabel.gd _setDisabled). With the switch on, for
# the player's ship, the mod disables every row's; off, each is back as the game set it, with its value. The column's
# header, the last cell of the header row (a hud/components/MineralLabel.tscn button titled HUD_MIN_PRICE), loses its
# text and its focus meanwhile: the list is a GridContainer, which leaves out a hidden child and would shift every cell
# after it, so the header keeps its cell, and the emptied column closes up. The switch is on another tab, so the change
# shows as soon as this one does: the game processes the list only while it shows (_visibilityChanged).
#
# Stacking: the parent's _ready and _process are never called (Godot runs every level by itself); updateSystems falls
# through to the parent with `.updateSystems()`; new members start with `_`.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")

# The node meta where each Minimum value control keeps whether the game disabled it.
const _GEOLOGY_BY_MASS_GAME_DISABLED = "_geologyByMassGameDisabled"
# The game's key titling the Minimum value column (updateSystems), and the node meta where that header keeps the game's
# [text, focus_mode].
const _GEOLOGY_BY_MASS_HEADER = "HUD_MIN_PRICE"
const _GEOLOGY_BY_MASS_GAME_HEADER = "_geologyByMassGameHeader"

var _geologyByMassSettings = null
var _geologyByMassHidden = null # whether the Minimum values are hidden now; null: not yet set on the current rows

# The game builds the rows anew (ship-ctrl.gd systemsChanged, setup); systemsChanged calls adjustFocus right after.
func updateSystems(systems):
	.updateSystems(systems)
	_geologyByMassHidden = null
	_geologyByMassPrices()

func _process(_delta):
	_geologyByMassPrices()

func _geologyByMass():
	if _geologyByMassSettings == null:
		_geologyByMassSettings = GeologyByMass.new(ship)
	return _geologyByMassSettings

# Hides or shows the Minimum values and their header, only on a change; the game's own state is recorded once per
# control (the rows are built anew with every updateSystems). The focus neighbours are worked out again, so the focus
# skips the empty cells (adjustFocus: path() passes over a hidden label); Godot passes over the header, which takes no
# focus while empty.
func _geologyByMassPrices():
	if ship == null:
		return
	var hide = ship.isPlayerControlled() and _geologyByMass().isEnabled()
	if hide == _geologyByMassHidden:
		return
	_geologyByMassHidden = hide
	for box in _geologyByMassPriceBoxes():
		if not box.has_meta(_GEOLOGY_BY_MASS_GAME_DISABLED):
			box.set_meta(_GEOLOGY_BY_MASS_GAME_DISABLED, bool(box.disabled))
		box.disabled = hide or box.get_meta(_GEOLOGY_BY_MASS_GAME_DISABLED)
	var header = _geologyByMassHeader()
	if header != null:
		if not header.has_meta(_GEOLOGY_BY_MASS_GAME_HEADER):
			header.set_meta(_GEOLOGY_BY_MASS_GAME_HEADER, [header.text, header.focus_mode])
		var game = header.get_meta(_GEOLOGY_BY_MASS_GAME_HEADER)
		header.text = "" if hide else game[0]
		header.focus_mode = Control.FOCUS_NONE if hide else game[1]
	adjustFocus()

# The Minimum value column's header: the child titled by the game's key, or, once emptied, the one holding its meta.
func _geologyByMassHeader():
	for child in get_children():
		if child.is_queued_for_deletion() or not child is Control or not "text" in child:
			continue
		if child.has_meta(_GEOLOGY_BY_MASS_GAME_HEADER) or child.text == _GEOLOGY_BY_MASS_HEADER:
			return child
	return null

# The rows' Minimum value controls: the children whose valueChanged reaches this list's `value` (updateSystems), which
# tells them from the Minimum Albedo controls, made from the same scene and reaching `albedo`. The rows replaced by
# updateSystems are left out: they are freed at the end of the frame.
func _geologyByMassPriceBoxes() -> Array:
	var boxes = []
	for child in get_children():
		if child.is_queued_for_deletion() or not child.has_signal("valueChanged"):
			continue
		for connection in child.get_signal_connection_list("valueChanged"):
			if connection.target == self and connection.method == "value":
				boxes.append(child)
				break
	return boxes

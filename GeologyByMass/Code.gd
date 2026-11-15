extends "res://hud/Hud.gd"

# GeologyByMass: judges an identified chunk by the mass of each mineral in it instead of its value, when the switch on
# the mod's OMS tab is on.
#
# Each chunk the geologist identifies gets an info box (hud/MineralMark.gd). About once a second the box asks its
# overlay (hud/AutopilotOverlay.gd isValidMineralTarget), which asks this HUD, which asks the ship with the Geologist
# tab's settings for the HUD (ships/ship-ctrl.gd isValidMineralTarget(body, mineralConfig)). A "no" plays the box's
# `diminish` animation: it shrinks, and its kg list and price are hidden. The game's rule: the chunk's estimated value
# is at least the Minimum value, and it holds a mineral switched on in that tab. Nothing else asks this HUD, so the
# mod changes only the boxes: the drones and the salvage arm ask the ship with their own settings.
#
# With the switch on, for the player's ship, an identified chunk keeps its full box when it holds, of some mineral
# switched on in the Geologist tab, at least the base mass plus that mineral's extra mass (Settings.gd getMinMass); its
# value and the Minimum value no longer count.
# The masses are the box's own (MineralMark.gd scanParent, with the geologist's error), which the box stores in the
# ship's identifiedObjects (identifyMinerals / identifyValue -> ship-ctrl.gd addIdentifiedObject). A chunk not yet
# identified, the switch off, or another ship's HUD: the game decides.
#
# Stacking: the parent's _ready etc. are never called (Godot runs every level by itself); isValidMineralTarget and
# instance fall through to the parent with `.name()`; new members start with `_`.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")
const _GEOLOGY_BY_MASS_UI = preload("res://GeologyByMass/SettingsUI.gd")

# The mod's tab: its node name, which the game's TabContainer shows translated as the tab's title (as it shows the
# OMS's own tabs, named CREW_OCCUPATION_*), and the Geologist tab it follows (hud/OMS.tscn).
const _GEOLOGY_BY_MASS_TAB = "GEOLOGYBYMASS_TAB"
const _GEOLOGIST_TAB = "CREW_OCCUPATION_GEOLOGIST"

var _geologyByMassSettings = null

func isValidMineralTarget(body: RigidBody2D) -> bool:
	var settings = _geologyByMass()
	if ship == null or not ship.isPlayerControlled() or not settings.isEnabled():
		return .isValidMineralTarget(body)
	var masses = null
	if Tool.claim(ship):
		var identified = ship.identifiedObjects.get(hash(body))
		if identified != null:
			masses = identified[0]
		Tool.release(ship)
	if not masses is Dictionary:
		return .isValidMineralTarget(body)
	for mineral in mineralConfig.minerals:
		if mineral in masses and masses[mineral] >= settings.getMinMass(mineral):
			return true
	return false

# The game builds the OMS here (the HUD's `Inventory` placeholder of hud/OMS.tscn). The tab is added once the frame
# is idle: the HUD's _ready can call this before it loads mineralConfig from the ship (a preheated ship), and the tab
# shows the values stored there.
func instance():
	.instance()
	call_deferred("_addGeologyByMassTab")

func _geologyByMass():
	if _geologyByMassSettings == null:
		_geologyByMassSettings = GeologyByMass.new(self)
	return _geologyByMassSettings

# Right after the Geologist tab, framed as it is; at most once per OMS. The TabContainer is the OMS's own `tabsPath`
# (hud/OMS.gd). Nothing in the game refers to the OMS's tabs by index.
func _addGeologyByMassTab():
	var settings = _geologyByMass()
	if not is_instance_valid(inventory) or not ("tabsPath" in inventory) or not settings.available():
		return
	var tabs = inventory.get_node_or_null(inventory.tabsPath)
	if not tabs is TabContainer or tabs.has_node(_GEOLOGY_BY_MASS_TAB):
		return
	var tab = _GEOLOGY_BY_MASS_UI.new()
	tab.name = _GEOLOGY_BY_MASS_TAB
	var geologist = tabs.get_node_or_null(_GEOLOGIST_TAB)
	if geologist is Control:
		tab.theme = geologist.theme
		tab.rect_clip_content = geologist.rect_clip_content
	tab.setup(settings)
	tabs.add_child(tab)
	if geologist != null:
		tabs.move_child(tab, geologist.get_index() + 1)

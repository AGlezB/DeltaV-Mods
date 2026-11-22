extends "res://hud/Hud.gd"

# GeologyByMass's OMS tab, added to every OMS right after the Geologist tab: the switch, and each mineral's switch and
# least mass (SettingsUI.gd), which the ship's rule reads from the ship's config (Settings.gd, Code.gd).
#
# Stacking: instance falls through to the parent with `.instance()`; new members start with `_`.

const GeologyByMass = preload("res://GeologyByMass/Settings.gd")
const _GEOLOGY_BY_MASS_UI = preload("res://GeologyByMass/SettingsUI.gd")

# The mod's tab: its node name, which the game's TabContainer shows translated as the tab's title (as it shows the
# OMS's own tabs, named CREW_OCCUPATION_*), and the Geologist tab it follows (hud/OMS.tscn).
const _GEOLOGY_BY_MASS_TAB = "GEOLOGYBYMASS_TAB"
const _GEOLOGY_BY_MASS_AFTER = "CREW_OCCUPATION_GEOLOGIST"

var _geologyByMassSettings = null

# The game builds the OMS here (the HUD's `Inventory` placeholder of hud/OMS.tscn). The tab is added once the frame
# is idle: the HUD's _ready can call this before it loads mineralConfig from the ship (a preheated ship), and the tab
# shows the values stored there.
func instance():
	.instance()
	call_deferred("_addGeologyByMassTab")

func _geologyByMass():
	if _geologyByMassSettings == null:
		_geologyByMassSettings = GeologyByMass.new(ship)
	return _geologyByMassSettings

# Right after the Geologist tab, framed as it is; at most once per OMS, and only on a HUD that keeps the Geologist
# tab's settings (mineral targeting), where the mod's go too. The TabContainer is the OMS's own `tabsPath`
# (hud/OMS.gd). Nothing in the game refers to the OMS's tabs by index.
func _addGeologyByMassTab():
	if not mineralTargetting or ship == null:
		return
	var settings = _geologyByMass()
	if not is_instance_valid(inventory) or not ("tabsPath" in inventory) or not settings.available():
		return
	var tabs = inventory.get_node_or_null(inventory.tabsPath)
	if not tabs is TabContainer or tabs.has_node(_GEOLOGY_BY_MASS_TAB):
		return
	var tab = _GEOLOGY_BY_MASS_UI.new()
	tab.name = _GEOLOGY_BY_MASS_TAB
	var geologist = tabs.get_node_or_null(_GEOLOGY_BY_MASS_AFTER)
	if geologist is Control:
		tab.theme = geologist.theme
		tab.rect_clip_content = geologist.rect_clip_content
	tab.setup(settings)
	tabs.add_child(tab)
	if geologist != null:
		tabs.move_child(tab, geologist.get_index() + 1)

extends Reference

# The code WeaponMaxPowerSwitch's scripts share, static: never instanced. The switch's key, which ModMain.gd adds and
# MechanicTab.gd (the OMS Mechanic tab's row) answers. The switch itself lives on the ship (Code.gd).

# The switch's key: an action of the mod's own, bound to KEY by scancode, as the game binds its letter keys
# (project.godot). No action or script of the game uses the key. The game's controls settings remap only their own
# actions (Settings.gd inputs, loadKeymapFromConfig), so this one is left as it is.
const KEY_ACTION = "weaponmaxpowerswitch_toggle"
const KEY = KEY_P

# Adds the key's action, once (ModMain.gd, before the game's scenes load).
static func addKey():
	if InputMap.has_action(KEY_ACTION):
		return
	InputMap.add_action(KEY_ACTION)
	var event = InputEventKey.new()
	event.scancode = KEY
	InputMap.action_add_event(KEY_ACTION, event)

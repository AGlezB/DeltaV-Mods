extends Reference

# The code TurretLockableFacing's scripts share, static: never instanced. The facing lock itself, which Code.gd (each
# turret) reads and MechanicTab.gd (the OMS Mechanic tab's row and the key) switches, the key that switches it, and the
# locked turrets' angle, which the row's slider sets.

# The facing lock, while on: a metadata of the player's ship node. The game builds that node anew for every dive (and
# for the simulator), so every dive starts unlocked, and nothing is saved.
const LOCK_META = "TurretLockableFacing"

# Every turret (ships/modules/PDT.gd, the mod's Code.gd, with no gimbal limit) joins this group, which mounts() filters
# by ship.
const MOUNTS_GROUP = "TurretLockableFacingMounts"

# The facing lock's key: an action of the mod's own, bound to KEY by scancode, as the game binds its letter keys
# (project.godot). No action or script of the game uses the key. The game's controls settings remap only their own
# actions (Settings.gd inputs, loadKeymapFromConfig), so this one is left as it is.
const KEY_ACTION = "turretlockablefacing_toggle"
const KEY = KEY_L

# The locked turrets' angle, in degrees: each turns this far from its hardpoint's direction, towards the turrets on the
# other side of the ship when positive (they converge), away from them when negative (they spread) (Code.gd). A slider
# in the facing lock's row (MechanicTab.gd), from -FACING_ANGLE_MAX to FACING_ANGLE_MAX in steps of FACING_ANGLE_STEP;
# FACING_ANGLE_DEFAULT where the ship keeps none.
const FACING_ANGLE_DEFAULT = 0.0
const FACING_ANGLE_MAX = 5.0
const FACING_ANGLE_STEP = 0.5

# The angle is kept in the ship's tuning (the game's per-ship store of its systems' settings, saved with the game and
# carried with the ship: ship-ctrl.gd getTunedValue), as one entry under the mod's id: the angle, and the turrets it
# was set for. The player's ship works on the save's own config (CurrentGame.gd createPlayerShip, Shipyard.gd
# createShipByConfig), so a change in flight is saved as the game's own are.
const FORMAT_VERSION = 1
const MANIFEST = "res://TurretLockableFacing/Mod.manifest"
const _MANIFEST_META = "TurretLockableFacingManifest"

# Adds the key's action, once (ModMain.gd, before the game's scenes load).
static func addKey():
	if InputMap.has_action(KEY_ACTION):
		return
	InputMap.add_action(KEY_ACTION)
	var event = InputEventKey.new()
	event.scancode = KEY
	InputMap.action_add_event(KEY_ACTION, event)

# The ship's turrets.
static func mounts(ship) -> Array:
	var list = []
	if not is_instance_valid(ship) or not ship.is_inside_tree():
		return list
	for node in ship.get_tree().get_nodes_in_group(MOUNTS_GROUP):
		if node.ship == ship:
			list.append(node)
	return list

static func isLocked(ship) -> bool:
	return is_instance_valid(ship) and ship.has_meta(LOCK_META)

# Switches the facing lock, and tells every turret of the ship at once: an idle turret has its physics frames off.
static func setLocked(ship, how):
	how = bool(how)
	if not is_instance_valid(ship) or how == isLocked(ship):
		return
	if how:
		ship.set_meta(LOCK_META, true)
	else:
		ship.remove_meta(LOCK_META)
	for mount in mounts(ship):
		mount._tlfRefresh()

# The ship's turrets, as the angle's entry records them: each turret's slotName, the game's own key for a weapon's
# tuning (weaponSlot.<slot>.type_<mount>_<weapon>: ships/WeaponSlot.gd loadPlaceholder, PDT.gd _setSlotName), so
# another turret on a hardpoint makes another list.
static func weapons(ship) -> Array:
	var list = []
	for mount in mounts(ship):
		list.append(str(mount.slotName))
	list.sort()
	return list

# The ship's angle: the entry's while the ship's turrets are those it was set for, else the default. A value that isn't
# a number gives the default, and the rest is snapped to the step and kept in range, so a save edited by hand can't
# break anything. Reading never writes, so putting the old turrets back brings their angle back.
static func angle(ship) -> float:
	var entry = _angleEntry(ship)
	if entry == null or not (entry.get("weapons") is Array) or entry.weapons != weapons(ship):
		return FACING_ANGLE_DEFAULT
	var value = entry.get("angle")
	if not (value is int or value is float):
		return FACING_ANGLE_DEFAULT
	return _clampAngle(value)

# Sets the ship's angle for its turrets, and tells every turret of the ship at once.
static func setAngle(ship, value):
	if not is_instance_valid(ship) or not ship.has_method("getConfig"):
		return
	var tuning = ship.getConfig("tuning")
	if not (tuning is Dictionary):
		tuning = {}
		ship.setConfig("tuning", tuning)
	tuning[modId()] = {
		"formatVersion": FORMAT_VERSION,
		"modVersion": modVersion(),
		"angle": _clampAngle(float(value)),
		"weapons": weapons(ship),
	}
	for mount in mounts(ship):
		mount._tlfRefresh()

static func _clampAngle(value) -> float:
	return clamp(stepify(value, FACING_ANGLE_STEP), - FACING_ANGLE_MAX, FACING_ANGLE_MAX)

static func _angleEntry(ship):
	if not is_instance_valid(ship) or not ship.has_method("getConfig"):
		return null
	var tuning = ship.getConfig("tuning")
	if not (tuning is Dictionary):
		return null
	var entry = tuning.get(modId())
	return entry if entry is Dictionary else null

# The mod's id and version, from Mod.manifest, as the mods' Settings.gd read them. The file is read once, and kept as
# metadata of this script (a static script has no members of its own).
static func modId() -> String:
	return str(_manifest().get_value("mod_information", "id", MANIFEST.get_base_dir().get_file()))

static func modVersion() -> String:
	var file = _manifest()
	return "%d.%d.%d" % [
		file.get_value("version", "version_major", 0),
		file.get_value("version", "version_minor", 0),
		file.get_value("version", "version_bugfix", 0)]

static func _manifest() -> ConfigFile:
	var script = load(MANIFEST.get_base_dir().plus_file("Shared.gd"))
	if not script.has_meta(_MANIFEST_META):
		var file = ConfigFile.new()
		file.load(MANIFEST)
		script.set_meta(_MANIFEST_META, file)
	return script.get_meta(_MANIFEST_META)

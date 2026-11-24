extends "res://harness/suite.gd"

# TurretLockableFacing: the turrets (the game's PDT.gd, with the mod's Code.gd on top) on stub ships, hardpoints and
# weapons (harness/turret_*.gd), the facing lock, its angle and where it is kept, the key, and the Mechanic tab's row
# (the game's SystemList.gd, with the mod's MechanicTab.gd on top, building its rows from the game's PowerToggleCheckBox
# and DamageLabel scenes). Without the mod (-Mods @()), the control checks on the game's own scripts.

const ShipScript = preload("res://harness/turret_ship.gd")
const WeaponScript = preload("res://harness/turret_weapon.gd")
const SlotScript = preload("res://harness/turret_slot.gd")
const HudScript = preload("res://harness/turret_hud.gd")
const ClickScript = preload("res://harness/turret_click.gd")
const MOUNT_SCRIPT = "res://ships/modules/PDT.gd"
const LIST_SCRIPT = "res://hud/SystemList.gd"
const SHARED = "res://TurretLockableFacing/Shared.gd"
const MANIFEST = "res://TurretLockableFacing/Mod.manifest"
const MOD = "TurretLockableFacing"

# A tooltip is one short line, as the game's own (OMS_SYSTEM_TOGGLE_TOOLTIP, "Disable or enable this system"): the game's
# tooltip Label doesn't wrap (menu/sfx/PlaySoundsOnTheseButtons.tscn).
const TOOLTIP_MAX = 40

# The game's digit actions (project.godot): the harness project has none.
const DIGITS = {
	"ship_slot_drone_toggle": KEY_9, "ship_slot_torch": KEY_0,
	"ship_slot_1": KEY_1, "ship_slot_2": KEY_2, "ship_slot_3": KEY_3, "ship_slot_4": KEY_4,
	"ship_slot_5": KEY_5, "ship_slot_6": KEY_6, "ship_slot_7": KEY_7, "ship_slot_8": KEY_8,
}

# The scenes' values (ships/modules/PDT-microwave.tscn, act-massdriver.tscn, PDT-minigun.tscn).
const ONMWG = {"gimbalLimit": -1, "autoFire": true, "fireWithNoLock": false, "returnToDefault": false, "rotationPerSecond": 3.14, "accurancy": 0.02}
const AEMD = {"gimbalLimit": 2, "autoFire": false, "fireWithNoLock": true, "returnToDefault": true, "rotationPerSecond": 0.314, "accurancy": 0.002, "massLimit": 0.0}
const MINIGUN = {"gimbalLimit": -1, "autoFire": false, "fireWithNoLock": false, "returnToDefault": true, "rotationPerSecond": 0.785, "accurancy": 0.05}

var Shared

func run():
	for action in DIGITS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var byCode = InputEventKey.new()
			byCode.scancode = DIGITS[action]
			InputMap.action_add_event(action, byCode)
			var byPlace = InputEventKey.new()
			byPlace.physical_scancode = DIGITS[action]
			InputMap.action_add_event(action, byPlace)
	if not hasMod(MOD):
		yield(controlChecks(), "completed")
		return
	Shared = load(SHARED)
	var probe = load(MOUNT_SCRIPT).new()
	check("the mod's Code.gd took over PDT.gd's path", probe.has_method("_tlfRefresh"))
	probe.free()
	var listProbe = load(LIST_SCRIPT).new()
	check("the mod's MechanicTab.gd took over SystemList.gd's path", listProbe.has_method("_tlfRow"))
	listProbe.free()
	texts()
	yield(centreTurret(), "completed")
	yield(sideTurret(), "completed")
	yield(sideBay(), "completed")
	yield(aiShip(), "completed")
	keys()
	sides()
	yield(angles(), "completed")
	yield(fixedWeapons(), "completed")
	angleKept()
	yield(mechanicRow(), "completed")

# ---- helpers ----

func makeShip(rot = 0.0):
	var ship = Node2D.new()
	ship.set_script(ShipScript)
	ship.rotation = rot
	add_child(ship)
	return ship

var slotCount = 0

func makeSlot(ship, rot = 0.0, toggle = "", pos = Vector2.ZERO):
	var slot = Node2D.new()
	slot.set_script(SlotScript)
	slot.rotation = rot
	slot.position = pos
	slot.toggleCommand = toggle
	slotCount += 1
	slot.slot = "slot%d" % slotCount
	ship.add_child(slot)
	return slot

# As ships/WeaponSlot.gd loadPlaceholder names the mount, and PDT.gd _setSlotName its weapon.
func nameMount(mount, systemName = "SYSTEM_PDMWG"):
	mount.systemName = systemName
	mount.slotName = "weaponSlot.%s.type_%s" % [mount.get_parent().slot, systemName]

# A mount of the game's PDT.gd on a hardpoint, with the scene's values `props`, as the game's scenes nest it (a Pivot
# holding the weapon).
func makeMount(ship, slotRot, nodeRot, props, pos = Vector2.ZERO):
	var slot = makeSlot(ship, slotRot, "", pos)
	var mount = Node2D.new()
	mount.set_script(load(MOUNT_SCRIPT))
	mount.rotation = nodeRot
	mount.weaponPath = NodePath("Pivot/Weapon")
	mount.aimOffset = 270.0
	for k in props:
		mount.set(k, props[k])
	var pivot = Node2D.new()
	pivot.name = "Pivot"
	mount.add_child(pivot)
	var weapon = Node2D.new()
	weapon.name = "Weapon"
	weapon.set_script(WeaponScript)
	pivot.add_child(weapon)
	slot.add_child(mount)
	nameMount(mount)
	return mount

func makeTarget(pos):
	var body = RigidBody2D.new()
	body.mode = RigidBody2D.MODE_STATIC
	body.mass = 100
	add_child(body)
	body.global_position = pos
	return body

# The pivot rotation that aims a mount at a point, as PDT.gd computes it.
func aim(mount, pos):
	return mount.pivot.global_position.angle_to_point(pos) + deg2rad(mount.aimOffset)

func off(a, b):
	return abs(wrapf(a - b, - PI, PI))

func idle(count = 2):
	for i in count:
		yield(get_tree(), "idle_frame")

# A key or a gamepad button pressed and released as real input events in the idle part of a frame.
func tapKey(code):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.scancode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

func tapJoy(button):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# A control's tooltip: its own, or the one the game's tooltip node beside it holds once it has taken the control in
# (PlaySoundsOnTheseButtons.gd connectSounds, which empties the control's own).
func tooltipOf(control) -> String:
	if control.hint_tooltip != "":
		return control.hint_tooltip
	var at = control
	while at != null:
		var tips = at.get_node_or_null("PlaySoundsOnTheseButtons")
		if tips != null and control in tips.tooltips:
			return tips.tooltips[control]
		at = at.get_parent()
	return ""

# The Mechanic tab's list (the game's SystemList.gd, as hud/OMS.tscn sets it: toggleSystem on, three damage columns,
# the key after the name) with its click, in a HUD on `ship`, showing `systems`, built.
func makeList(ship, systems):
	ship.systemsDict = systems
	var hud = Control.new()
	hud.set_script(HudScript)
	hud.ship = ship
	hud.rect_size = Vector2(1200, 600)
	var grid = GridContainer.new()
	grid.set_script(load(LIST_SCRIPT))
	grid.toggleSystem = true
	grid.detailedDamage = 3
	grid.minSize = 28
	grid.hotkeysFirst = false
	grid.columns = 2
	var click = Node.new()
	click.set_script(ClickScript)
	click.name = "Click"
	grid.add_child(click)
	hud.add_child(grid)
	ship.add_child(hud)
	grid.update()
	return grid

func systemEntry(key, ref):
	return {"key": key, "name": "SYSTEM_" + key.to_upper(), "status": 100, "power": 1.0, "enabled": true, "togleable": true, "damage": [], "ref": ref}

# ---- without the mod ----

func controlChecks():
	var ship = makeShip()
	var m = makeMount(ship, 0, 0, ONMWG)
	var t = makeTarget(m.global_position + Vector2(300, 0))
	m._on_DefendArea_body_entered(t)
	yield(frames(60), "completed")
	check("control: a centre ONMWG aims at its target and fires by itself", off(m.pivot.global_rotation, aim(m, t.global_position)) < 0.03 and m.system.last == 1, [m.pivot.global_rotation, aim(m, t.global_position), m.system.last])
	var grid = makeList(ship, {"a": systemEntry("a", makeSlot(ship, 0, "ship_slot_1"))})
	yield(idle(3), "completed")
	check("control: the Mechanic tab lists only the ship's systems: one row, no row for a facing lock", grid.get_child_count() == 1 + grid.columns and not grid.has_method("_tlfRow"), grid.get_child_count())
	t.queue_free()
	ship.queue_free()
	yield(frames(1), "completed")

# ---- the texts ----

func texts():
	check("texts: the mod's en.po is loaded", tr("TURRETLOCKABLEFACING_ROW") == "Lock facing", tr("TURRETLOCKABLEFACING_ROW"))
	for key in ["TURRETLOCKABLEFACING_TOOLTIP", "TURRETLOCKABLEFACING_ANGLE_TOOLTIP"]:
		var text = tr(key)
		check("texts: %s is one short line" % key, text != key and text.find("\n") < 0 and text.length() <= TOOLTIP_MAX, [text, text.length()])
	check("texts: the angle's text has a place for the value", tr("TURRETLOCKABLEFACING_ANGLE").find("%s") >= 0, tr("TURRETLOCKABLEFACING_ANGLE"))
	var font = load("res://hud/FontNoto.tres")
	var data = font.font_data if font else null
	check("font: the Mechanic tab's font (hud/FontNoto.tres, in hud/TNTRL-theme.tres) has the degree sign the angle's text shows", data != null and font.get_available_chars().find("°") >= 0, data.font_path if data else null)

# ---- the mounts ----

func centreTurret():
	var ship = makeShip()
	var m = makeMount(ship, 0, 0, ONMWG)
	var w = m.system
	var t = makeTarget(m.global_position + Vector2(300, 0))
	m._on_DefendArea_body_entered(t)
	yield(frames(60), "completed")
	check("unlocked: a centre ONMWG aims at its target and fires by itself, as the game's", off(m.pivot.global_rotation, aim(m, t.global_position)) < 0.03 and w.last == 1, [m.pivot.global_rotation, aim(m, t.global_position), w.last])
	Shared.setLocked(ship, true)
	check("locked: fireWithNoLock on, returnToDefault off, physics frames on", m.fireWithNoLock and not m.returnToDefault and m.is_physics_processing())
	yield(frames(60), "completed")
	check("locked: it turns to its hardpoint's forward (the nose) and doesn't fire by itself, its target still in range", off(m.pivot.global_rotation, ship.global_rotation) < 0.01 and w.last == 0 and m.queue.size() == 1, [m.pivot.global_rotation, w.last])
	var drawn = ship.energyDrawn
	yield(frames(10), "completed")
	check("locked: once there, it draws no power to turn", ship.energyDrawn == drawn, [drawn, ship.energyDrawn])
	m.fire(1.0)
	yield(frames(2), "completed")
	check("locked: it fires while the trigger is held", w.last == 1.0, w.last)
	m.fire(0.0)
	yield(frames(2), "completed")
	check("locked: it stops when the trigger is let go", w.last == 0, w.last)
	check("locked: it still faces the nose", off(m.pivot.global_rotation, ship.global_rotation) < 0.01)
	Shared.setLocked(ship, false)
	check("unlocked: the scene's fireWithNoLock and returnToDefault come back", m.fireWithNoLock == false and m.returnToDefault == false)
	yield(frames(60), "completed")
	check("unlocked: it aims at its target again and fires by itself", off(m.pivot.global_rotation, aim(m, t.global_position)) < 0.03 and w.last == 1, [m.pivot.global_rotation, w.last])
	t.queue_free()
	t = null
	m.queue.clear()
	m.pivot.rotation = 1.0
	m._on_DefendArea_body_exited(null)
	yield(frames(2), "completed")
	check("unlocked: an idle ONMWG with no target has its physics frames off, as the game's", not m.is_physics_processing())
	Shared.setLocked(ship, true)
	check("locking wakes an idle turret", m.is_physics_processing())
	yield(frames(30), "completed")
	check("and it turns to its hardpoint's forward", off(m.pivot.global_rotation, ship.global_rotation) < 0.01, m.pivot.rotation)
	Shared.setLocked(ship, false)
	check("unlocked with no target, it sleeps again, as the game's code leaves an ONMWG", not m.is_physics_processing())
	ship.queue_free()
	yield(frames(1), "completed")

func sideTurret():
	var ship = makeShip()
	var m = makeMount(ship, 0, deg2rad(60), ONMWG)
	yield(frames(2), "completed")
	check("unlocked: at rest, a -R turret points 60 degrees outward of its hardpoint", off(m.pivot.global_rotation, ship.global_rotation + deg2rad(60)) < 0.001)
	Shared.setLocked(ship, true)
	yield(frames(60), "completed")
	check("locked: the -R turret turns back to its hardpoint's forward, here the nose", off(m.pivot.global_rotation, ship.global_rotation) < 0.01, [m.pivot.rotation])
	ship.rotation = deg2rad(45)
	yield(frames(5), "completed")
	check("locked: it stays on the nose while the ship turns", off(m.pivot.global_rotation, ship.global_rotation) < 0.01)
	var mL = makeMount(ship, deg2rad(30), deg2rad(-30), MINIGUN)
	yield(frames(90), "completed")
	check("locked: a -L minigun added on a bay turned 30 degrees (the ATK225's) points along the bay", off(mL.pivot.global_rotation, ship.global_rotation + deg2rad(30)) < 0.01, [mL.pivot.rotation])
	ship.queue_free()
	yield(frames(1), "completed")

func sideBay():
	var ship = makeShip()
	var a = makeMount(ship, deg2rad(90), 0, AEMD)
	var t = makeTarget(a.global_position + Vector2(400, -10))
	a._on_DefendArea_body_entered(t)
	var m = makeMount(ship, deg2rad(90), 0, MINIGUN)
	var t2 = makeTarget(m.global_position + Vector2(0, -400))
	m._on_DefendArea_body_entered(t2)
	yield(frames(150), "completed")
	check("unlocked: on a hardpoint turned 90 degrees (the OCP-209's side bay), the AEMD aims at its target within its gimbal", abs(a.pivot.rotation) > 0.01 and abs(a.pivot.rotation) <= deg2rad(2) + 0.0001, a.pivot.rotation)
	check("unlocked: and the centre minigun turns towards the nose, at its target", off(m.pivot.global_rotation, aim(m, t2.global_position)) < 0.06, [m.pivot.global_rotation, aim(m, t2.global_position)])
	var aimed = a.pivot.rotation
	check("only turrets: the AEMD (gimbal limit) is no mount of the mod's, the minigun is", Shared.mounts(ship) == [m] and not a.is_in_group(Shared.MOUNTS_GROUP), Shared.mounts(ship))
	Shared.setLocked(ship, true)
	yield(frames(150), "completed")
	check("locked: the minigun points along its hardpoint, to starboard", off(m.pivot.global_rotation, ship.global_rotation + PI / 2) < 0.01, m.pivot.rotation)
	check("locked: the AEMD is left alone: it still aims at its target, with the scene's fireWithNoLock and returnToDefault", not a._tlfApplied and abs(a.pivot.rotation - aimed) < 0.0001 and a.fireWithNoLock and a.returnToDefault, [a._tlfApplied, a.pivot.rotation, aimed])
	a.fire(1.0)
	m.fire(1.0)
	yield(frames(2), "completed")
	check("locked: the minigun fires on the trigger, and the AEMD as the game fires it (on the trigger, its scene's autoFire off)", a.system.last == 1.0 and m.system.last == 1.0, [a.system.last, m.system.last])
	a.fire(0.0)
	m.fire(0.0)
	Shared.setLocked(ship, false)
	yield(frames(30), "completed")
	check("unlocked: the AEMD still aims at its target", abs(a.pivot.rotation - aimed) < 0.0001 and a.fireWithNoLock and a.returnToDefault, a.pivot.rotation)
	t.queue_free()
	t2.queue_free()
	ship.queue_free()
	yield(frames(1), "completed")

func aiShip():
	var ship = makeShip()
	ship.playerControlled = false
	var m = makeMount(ship, 0, 0, ONMWG)
	var t = makeTarget(m.global_position + Vector2(300, 0))
	m._on_DefendArea_body_entered(t)
	Shared.setLocked(ship, true)
	yield(frames(60), "completed")
	check("an AI ship's mount ignores the lock: it aims and fires by itself", not m._tlfApplied and off(m.pivot.global_rotation, aim(m, t.global_position)) < 0.03 and m.system.last == 1, [m._tlfApplied, m.system.last])
	t.queue_free()
	ship.queue_free()
	yield(frames(1), "completed")

func keys():
	var events = InputMap.get_action_list(Shared.KEY_ACTION) if InputMap.has_action(Shared.KEY_ACTION) else []
	check("key: the mod's action exists, bound only to KEY by scancode (as the game binds its letters)", events.size() == 1 and events[0] is InputEventKey and events[0].scancode == Shared.KEY and events[0].physical_scancode == 0, events)
	var probe = InputEventKey.new()
	probe.scancode = Shared.KEY
	probe.pressed = true
	var clash = []
	for action in DIGITS:
		if InputMap.event_is_action(probe, action):
			clash.append(action)
	check("key: KEY is none of the game's digit actions", clash.empty(), clash)

# ---- the angle ----

func sides():
	var ship = makeShip(0.7)
	var cases = [
		["forward, left of the nose line", Vector2(-68, -401), 0.0, -1],
		["forward, right of it", Vector2(68, -401), 0.0, 1],
		["forward, on it", Vector2(0, -331), 0.0, 0],
		["an ATK225 bay, left, turned 30 degrees out, far forward", Vector2(-122, -477), -0.523599, -1],
		["an ATK225 bay, right, turned 30 degrees out, far forward", Vector2(122, -478), 0.523599, 1],
		["the OCP-209's side bay, front (mainLeft), facing starboard", Vector2(192, -109), 1.5708, -1],
		["the OCP-209's side bay, back (mainRight), facing starboard", Vector2(192, 109), 1.5708, 1],
		["facing aft, port side (on the right, looking aft)", Vector2(-50, 300), PI, 1],
	]
	for c in cases:
		var m = makeMount(ship, c[2], 0, MINIGUN, c[1])
		check("side: " + c[0], m._tlfSide == c[3], m._tlfSide)
	ship.queue_free()

# Where the lines of fire of two mounts meet, in the ship's frame, and how far along the first one (negative: behind).
func meet(ship, m1, m2):
	var p1 = ship.to_local(m1.pivot.global_position)
	var p2 = ship.to_local(m2.pivot.global_position)
	var d1 = Vector2(0, -1).rotated(m1.pivot.global_rotation - ship.global_rotation)
	var d2 = Vector2(0, -1).rotated(m2.pivot.global_rotation - ship.global_rotation)
	var t1 = (p2 - p1).cross(d2) / d1.cross(d2)
	return [p1 + d1 * t1, t1]

func angles():
	var ship = makeShip(0.3)
	var left = makeMount(ship, 0, 0, ONMWG, Vector2(-68, -401))
	var right = makeMount(ship, 0, 0, ONMWG, Vector2(68, -401))
	var centre = makeMount(ship, 0, 0, ONMWG, Vector2(0, -331))
	var front = makeMount(ship, PI / 2, 0, ONMWG, Vector2(192, -109))
	var back = makeMount(ship, PI / 2, 0, ONMWG, Vector2(192, 109))
	var angle = 6 * Shared.FACING_ANGLE_STEP
	Shared.setLocked(ship, true)
	Shared.setAngle(ship, angle)
	yield(frames(60), "completed")
	var r = ship.global_rotation
	var a = deg2rad(angle)
	check("angle +: the left weapon turns right and the right one left", off(left.pivot.global_rotation, r + a) < 0.01 and off(right.pivot.global_rotation, r - a) < 0.01, [left.pivot.rotation, right.pivot.rotation])
	var m = meet(ship, left, right)
	check("angle +: their lines meet ahead, on the nose line (/\\)", m[1] > 0 and abs(m[0].x) < 1.0 and m[0].y < -401, m)
	check("angle +: a weapon on the nose line turns right", off(centre.pivot.global_rotation, r + a) < 0.01, centre.pivot.rotation)
	var s = meet(ship, front, back)
	check("angle +: the starboard pair meets to starboard, on the line across the ship", s[1] > 0 and s[0].x > 192 and abs(s[0].y) < 1.0, s)
	var drawn = ship.energyDrawn
	yield(frames(10), "completed")
	check("angle +: once there, no power is drawn to turn", ship.energyDrawn == drawn, [drawn, ship.energyDrawn])
	Shared.setAngle(ship, - angle)
	yield(frames(60), "completed")
	m = meet(ship, left, right)
	check("angle -: an aligned mount turns again; the pair's lines meet only behind (\\/)", off(left.pivot.global_rotation, r - a) < 0.01 and off(right.pivot.global_rotation, r + a) < 0.01 and m[1] < 0, [left.pivot.rotation, right.pivot.rotation, m])
	Shared.setLocked(ship, false)
	check("unlocked: the mounts forget the angle", left._tlfAngle == Shared.FACING_ANGLE_DEFAULT and right._tlfAngle == Shared.FACING_ANGLE_DEFAULT)
	ship.queue_free()
	yield(frames(1), "completed")

func fixedWeapons():
	var ship = makeShip()
	var l = makeMount(ship, 0, 0, AEMD, Vector2(-50, -200))
	var r = makeMount(ship, 0, 0, AEMD, Vector2(50, -200))
	nameMount(l, "SYSTEM_ACTEMD14")
	nameMount(r, "SYSTEM_ACL200P")
	var t = makeTarget(l.global_position + Vector2(-60, -400))
	l._on_DefendArea_body_entered(t)
	check("fixed weapons only: the ship has no turret for the mod", Shared.mounts(ship).empty() and Shared.weapons(ship).empty())
	Shared.setLocked(ship, true)
	Shared.setAngle(ship, Shared.FACING_ANGLE_MAX)
	yield(frames(120), "completed")
	check("fixed weapons only: locked at the most angle, the left AEMD still aims at its target, within its gimbal", not l._tlfApplied and abs(abs(l.pivot.rotation) - deg2rad(2)) < 0.001, rad2deg(l.pivot.rotation))
	check("fixed weapons only: and the right one, with no target, rests as the game leaves it", not r._tlfApplied and abs(r.pivot.rotation) < 0.0001 and r.fireWithNoLock and r.returnToDefault, rad2deg(r.pivot.rotation))
	t.queue_free()
	ship.queue_free()
	var mixed = makeShip()
	var aemd = makeMount(mixed, 0, 0, AEMD, Vector2(-50, -200))
	nameMount(aemd, "SYSTEM_ACTEMD14")
	var turret = makeMount(mixed, 0, 0, ONMWG, Vector2(50, -200))
	Shared.setLocked(mixed, true)
	Shared.setAngle(mixed, Shared.FACING_ANGLE_MAX)
	yield(frames(120), "completed")
	check("mixed: at the most angle, the turret turns it, and the AEMD, with no target, rests at 0", abs(turret.pivot.rotation + deg2rad(Shared.FACING_ANGLE_MAX)) < 0.01 and abs(aemd.pivot.rotation) < 0.0001, [rad2deg(aemd.pivot.rotation), rad2deg(turret.pivot.rotation)])
	check("mixed: the angle's entry records only the turret", Shared.weapons(mixed) == [turret.slotName], Shared.weapons(mixed))
	nameMount(aemd, "SYSTEM_ACL200P")
	check("mixed: another fixed weapon on the AEMD's hardpoint keeps the angle", Shared.angle(mixed) == Shared.FACING_ANGLE_MAX, Shared.angle(mixed))
	mixed.queue_free()
	yield(frames(1), "completed")

# The mod's version as it saves it (x.y.z), read from its Mod.manifest here.
func manifestVersion() -> String:
	var file = ConfigFile.new()
	file.load(MANIFEST)
	return "%d.%d.%d" % [file.get_value("version", "version_major", -1), file.get_value("version", "version_minor", -1), file.get_value("version", "version_bugfix", -1)]

func angleKept():
	var ship = makeShip()
	var l = makeMount(ship, 0, 0, ONMWG, Vector2(-68, -401))
	var r = makeMount(ship, 0, 0, ONMWG, Vector2(68, -401))
	var angle = 8 * Shared.FACING_ANGLE_STEP
	check("kept: none at first, the default", Shared.angle(ship) == Shared.FACING_ANGLE_DEFAULT)
	Shared.setAngle(ship, angle)
	var entry = ship.shipConfig.tuning.get(Shared.modId(), {})
	check("kept: an entry in the ship's tuning, under the mod's id, with the format and mod versions", Shared.modId() == "AGlezB." + MOD and entry.get("angle") == angle and entry.get("weapons") == Shared.weapons(ship) and entry.get("formatVersion") == Shared.FORMAT_VERSION and entry.get("modVersion") == manifestVersion(), entry)
	check("kept: the weapons are the mounts' slotNames", Shared.weapons(ship).size() == 2 and Shared.weapons(ship)[0].begins_with("weaponSlot."), Shared.weapons(ship))
	ship.shipConfig = parse_json(to_json(ship.shipConfig))
	check("kept: through a save's JSON", Shared.angle(ship) == angle, Shared.angle(ship))
	var next = makeShip()
	next.shipConfig = ship.shipConfig
	var l2 = makeMount(next, 0, 0, ONMWG, Vector2(-68, -401))
	var r2 = makeMount(next, 0, 0, ONMWG, Vector2(68, -401))
	l2.get_parent().slot = l.get_parent().slot
	r2.get_parent().slot = r.get_parent().slot
	nameMount(l2)
	nameMount(r2)
	Shared.setLocked(next, true)
	check("kept: the next dive's ship reads it back, and its mounts take it when locked", Shared.angle(next) == angle and l2._tlfAngle == angle, [Shared.angle(next), l2._tlfAngle])
	nameMount(r2, "SYSTEM_PDT")
	check("kept: another weapon on a hardpoint reads the default", Shared.angle(next) == Shared.FACING_ANGLE_DEFAULT, Shared.angle(next))
	nameMount(r2)
	check("kept: the old weapon back brings the angle back (reading never wrote)", Shared.angle(next) == angle, Shared.angle(next))
	var stored = next.shipConfig.tuning[Shared.modId()]
	stored.angle = "x"
	check("kept: a value that isn't a number reads the default", Shared.angle(next) == Shared.FACING_ANGLE_DEFAULT)
	stored.angle = Shared.FACING_ANGLE_MAX * 100
	check("kept: too large a value reads the range's end", Shared.angle(next) == Shared.FACING_ANGLE_MAX, Shared.angle(next))
	var offStep = 3.4 * Shared.FACING_ANGLE_STEP
	stored.angle = offStep
	check("kept: a value off the step reads the nearest step", Shared.angle(next) == stepify(offStep, Shared.FACING_ANGLE_STEP) and Shared.angle(next) != offStep, Shared.angle(next))
	ship.queue_free()
	next.queue_free()

# ---- the Mechanic tab ----

func mechanicRow():
	var ship = makeShip()
	var mount = makeMount(ship, 0, 0, ONMWG)
	var s1 = makeSlot(ship, 0, "ship_slot_1")
	var s2 = makeSlot(ship, 0, "ship_slot_2")
	var grid = makeList(ship, {"a": systemEntry("a", s1), "b": systemEntry("b", s2)})
	var click = grid.get_node("Click")
	yield(idle(3), "completed")
	var cells = grid._tlfCells
	check("row: six cells, the list's six columns", cells.size() == 6 and grid.columns == 6, [cells.size(), grid.columns])
	var last = true
	for i in cells.size():
		if grid.get_child(grid.get_child_count() - cells.size() + i) != cells[i]:
			last = false
	check("row: its cells are the list's last children, in order", last and grid.get_child_count() == 1 + 6 * 3)
	var hint = cells[2].get_child(0) if cells[2].get_child_count() > 0 else null
	check("row: the switch (the game's), the name, the key, the angle, then two blanks", cells[0] is CheckButton and cells[1] is Label and cells[1].text == "TURRETLOCKABLEFACING_ROW" and hint != null and hint.action == Shared.KEY_ACTION and cells[3].has_signal("juryRigChanged") and not cells[4].has_signal("juryRigChanged"), [cells[1].text, hint.action if hint else null])
	check("row: the switch's tooltip, held by the game's tooltip node", tooltipOf(cells[0]) == "TURRETLOCKABLEFACING_TOOLTIP", tooltipOf(cells[0]))
	var cell = cells[3]
	check("angle: the game's damage cell, named with the angle, with its tooltip, its slider spanning the range in steps", cell.label.text == "ANGLE 0°" and cell.label.visible and cell.slider.visible and tooltipOf(cell.label) == "TURRETLOCKABLEFACING_ANGLE_TOOLTIP" and cell.slider.min_value == - Shared.FACING_ANGLE_MAX and cell.slider.max_value == Shared.FACING_ANGLE_MAX and cell.slider.step == Shared.FACING_ANGLE_STEP and cell.status == 1.0, [cell.label.text, tooltipOf(cell.label), cell.slider.min_value, cell.slider.max_value, cell.slider.step])
	check("angle: nothing written just by showing it", not ship.shipConfig.has("tuning"))
	check("angle: grey while unlocked", cell.modulate == grid.colorOff, cell.modulate)
	cell.slider.value = 4 * Shared.FACING_ANGLE_STEP
	check("angle: moving the slider sets the ship's angle, and the name follows, signed, in whole degrees", Shared.angle(ship) == 4 * Shared.FACING_ANGLE_STEP and cell.label.text == "ANGLE %+d°" % int(4 * Shared.FACING_ANGLE_STEP), [Shared.angle(ship), cell.label.text])
	var odd = 5 * Shared.FACING_ANGLE_STEP
	cell.slider.value = odd
	check("angle: an angle with a fraction shows its decimals", Shared.angle(ship) == odd and cell.label.text == "ANGLE +%s°" % str(odd) and (odd == round(odd) or "." in cell.label.text), [Shared.angle(ship), cell.label.text])
	Shared.setAngle(ship, -6 * Shared.FACING_ANGLE_STEP)
	grid.update()
	check("angle: the slider follows the ship's angle", cell.slider.value == -6 * Shared.FACING_ANGLE_STEP and cell.label.text == "ANGLE %+d°" % int(-6 * Shared.FACING_ANGLE_STEP), [cell.slider.value, cell.label.text])
	check("row: it reads LOCK FACING (the list's labels are upper case)", cells[1].uppercase and tr(cells[1].text).to_upper() == "LOCK FACING", tr(cells[1].text))
	check("row: shown while the ship has a turret, unlocked and grey", cells[0].visible and not cells[0].pressed and cells[1].self_modulate == grid.colorOff)
	check("click: the list's Click is the one the list plays", grid.clickSound == click and click.plays == 0, click.plays)
	cells[0].pressed = true
	cells[0].emit_signal("pressed")
	check("row: the switch locks the mounts, and the row turns green", Shared.isLocked(ship) and mount._tlfApplied and cells[1].self_modulate == grid.colorOk)
	check("click: the switch clicks once, as the game's switches", click.plays == 1, click.plays)
	check("angle: green with the lock, as a jury-rig slider of a system in good shape", cell.modulate == cell.colorOk, cell.modulate)
	check("angle: the locked mount took the angle", mount._tlfAngle == -6 * Shared.FACING_ANGLE_STEP, mount._tlfAngle)
	yield(tapKey(Shared.KEY), "completed")
	check("key: it unlocks, and the switch follows", not Shared.isLocked(ship) and not cells[0].pressed and not mount._tlfApplied)
	check("click: none for the key unlocking (silent, as the game's hardpoint keys)", click.plays == 1, click.plays)
	yield(tapKey(Shared.KEY), "completed")
	check("key: again, it locks", Shared.isLocked(ship) and cells[0].pressed)
	check("click: none for the key locking", click.plays == 1, click.plays)
	yield(tapKey(KEY_9), "completed")
	check("key: another key (9) does nothing", Shared.isLocked(ship))
	ship.cutscene = true
	yield(tapKey(Shared.KEY), "completed")
	check("key: nothing in a cutscene", Shared.isLocked(ship))
	ship.cutscene = false
	ship.playerControlled = false
	yield(tapKey(Shared.KEY), "completed")
	check("key: nothing while the player doesn't fly the ship", Shared.isLocked(ship))
	ship.playerControlled = true
	check("click: none for another key, in a cutscene, or while the player doesn't fly the ship", click.plays == 1, click.plays)
	var s3 = makeSlot(ship, 0, "ship_slot_3")
	ship.systemsDict["c"] = systemEntry("c", s3)
	ship.systemsDict["c"].damage = [{"name": "DAMAGE_TEST", "type": "test", "current": 0, "max": 100}]
	ship.emit_signal("systemsChanged", true)
	yield(idle(3), "completed")
	last = true
	for i in cells.size():
		if grid.get_child(grid.get_child_count() - cells.size() + i) != cells[i]:
			last = false
	check("row: after a new system's row, the lock's row is last again", last and grid.get_child_count() == 1 + 6 * 4, grid.get_child_count())
	var lastSwitch = grid.objects["c"].toggler
	lastSwitch.grab_focus()
	yield(idle(2), "completed")
	yield(tapJoy(JOY_DPAD_DOWN), "completed")
	check("D-pad: down from the last system's switch reaches the lock's switch", grid.get_focus_owner() == cells[0], grid.get_focus_owner())
	yield(tapJoy(JOY_DPAD_UP), "completed")
	check("D-pad: and up goes back", grid.get_focus_owner() == lastSwitch, grid.get_focus_owner())
	var rigAbove = grid.objects["c"].damages[0]
	rigAbove.grab_focus()
	yield(idle(2), "completed")
	yield(tapJoy(JOY_DPAD_DOWN), "completed")
	check("D-pad: down from the jury-rig slider above reaches the angle's name", grid.get_focus_owner() == cell.label, grid.get_focus_owner())
	cells[0].grab_focus()
	yield(idle(2), "completed")
	yield(tapJoy(JOY_DPAD_RIGHT), "completed")
	check("D-pad: right from the lock's switch reaches it too", grid.get_focus_owner() == cell.label, grid.get_focus_owner())
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("A: moves to the slider", grid.get_focus_owner() == cell.slider, grid.get_focus_owner())
	yield(tapJoy(JOY_DPAD_RIGHT), "completed")
	var stepped = -6 * Shared.FACING_ANGLE_STEP + Shared.FACING_ANGLE_STEP
	check("D-pad: right on the slider adds a step to the angle, and the name follows", Shared.angle(ship) == stepped and cell.slider.value == stepped and cell.label.text == "ANGLE %s°" % str(stepped), [Shared.angle(ship), cell.slider.value, cell.label.text])
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("A: goes back to the name", grid.get_focus_owner() == cell.label, grid.get_focus_owner())
	mount.get_parent().free()
	grid.update()
	var hidden = true
	for c in cells:
		if c.visible:
			hidden = false
	check("row: hidden once the ship has no turret", hidden)
	Shared.setLocked(ship, false)
	var aemd = makeMount(ship, 0, 0, AEMD)
	nameMount(aemd, "SYSTEM_ACTEMD14")
	grid.update()
	hidden = true
	for c in cells:
		if c.visible:
			hidden = false
	check("row: still hidden with only a fixed gimballed weapon (an AEMD-14)", hidden)
	yield(tapKey(Shared.KEY), "completed")
	check("key: nothing without a turret, even with an AEMD-14", not Shared.isLocked(ship))
	ship.queue_free()
	yield(frames(1), "completed")

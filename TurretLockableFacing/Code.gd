extends "res://ships/modules/PDT.gd"

# TurretLockableFacing's extension of the gimballed mounts (ships/modules/PDT.gd), for the turrets only: the NDPT-4205
# and ONMWG-650, which turn all the way round (no gimbal limit). The AEMD-14 and CL-200AP, which turn only a little
# (their scenes set gimbalLimit), are left as the game has them. While the player's ship has the facing lock on
# (Shared.gd), each of its turrets points where a fixed weapon on its hardpoint points, and fires only while the trigger
# is held: the ONMWG-650 no longer fires by itself.
#
# How: while locked, the turret finds no target (getTarget), so the game's code takes its path without one, which
# fires the weapon with the trigger's power (firepower, which the ship's "w" command sets through fire) when
# fireWithNoLock is on, and turns the turret back to its rest when returnToDefault is on. The facing lock turns
# fireWithNoLock on and returnToDefault off, and turns the turret itself: to its hardpoint's direction, which is its
# rest except for the side versions (the -L and -R nodes of weapons/WeaponSlot.tscn, turned outward on their
# hardpoint), turned further by the locked turrets' angle (Shared.gd), mirrored on the other side of the ship.
#
# Stacking: getTarget falls through to the parent with `.getTarget()`; _ready and _physics_process never call the
# parent's (Godot runs them at every level); new members start with `_tlf`. CombatSimulator's Turret.gd extends the
# same script with fire and perhapsFire, and still disarms a locked turret: it zeroes firepower.

const TurretLockableFacing = preload("res://TurretLockableFacing/Shared.gd")

# How close, in radians, a locked turret must be to its hardpoint's direction to count as there: then it stops turning
# and drawing power for it.
const _TLF_ALIGNED = 0.001

# The share of its powerDraw a turret needs to turn, as the game's code asks (PDT.gd _physics_process).
const _TLF_POWER_NEEDED = 0.9

# How close, in world units, a hardpoint must be to the ship's mirror line (below) to count as on it.
const _TLF_CENTRE = 1.0

var _tlfHardpoint = null # the hardpoint holding the turret (ships/WeaponSlot.gd), whose direction the facing lock takes
var _tlfFireWithNoLock = false # the scene's fireWithNoLock and returnToDefault, given back once the facing is unlocked
var _tlfReturnToDefault = false
var _tlfApplied = false # whether the facing lock's values are in place
var _tlfSide = 0 # the side of the ship the hardpoint is on (_tlfSideOf): -1 left, 1 right, 0 on the line
var _tlfAngle = 0.0 # the locked turrets' angle (Shared.gd), in degrees, as last read

func _ready():
	if not _tlfTurret():
		return
	var parent = get_parent()
	_tlfHardpoint = parent if parent != null and "slot" in parent else null
	_tlfFireWithNoLock = fireWithNoLock
	_tlfReturnToDefault = returnToDefault
	_tlfSide = _tlfSideOf()
	add_to_group(TurretLockableFacing.MOUNTS_GROUP)
	if _tlfLocked():
		_tlfRefresh()

# No target while locked: the game's code then fires on the trigger only, and clears what the turret was aiming at.
func getTarget():
	if _tlfApplied:
		return null
	return .getTarget()

# Runs before the game's code in every physics frame.
func _physics_process(delta):
	if _tlfApplied != _tlfLocked():
		_tlfRefresh()
	if _tlfApplied and enabled:
		_tlfTurn(delta)

# Puts the facing lock's values in place, or gives the scene's back, as the ship's facing lock says, and reads the
# locked turrets' angle (Shared.gd setLocked and setAngle call it). Locked, the turret keeps its physics frames on (the
# game's code keeps them on while fireWithNoLock is). Unlocked, it keeps them as the game's code would (PDT.gd
# _on_DefendArea_body_entered and _exited), and a weapon that fires only at a target stops.
func _tlfRefresh():
	var locked = _tlfLocked()
	_tlfAngle = TurretLockableFacing.angle(ship) if locked else TurretLockableFacing.FACING_ANGLE_DEFAULT
	if locked != _tlfApplied:
		_tlfApplied = locked
		if locked:
			fireWithNoLock = true
			returnToDefault = false
		else:
			fireWithNoLock = _tlfFireWithNoLock
			returnToDefault = _tlfReturnToDefault
			if not fireWithNoLock and system != null and is_instance_valid(system):
				system.fire(0)
	set_physics_process(locked or queue.size() > 0 or fireWithNoLock or returnToDefault)

# A turret turns all the way round: the game's gimbalLimit is set only for the mounts that turn a little.
func _tlfTurret() -> bool:
	return gimbalLimit < 0

func _tlfLocked() -> bool:
	return _tlfTurret() and ship != null and is_instance_valid(ship) and ship.has_method("isPlayerControlled") \
		and ship.isPlayerControlled() and TurretLockableFacing.isLocked(ship)

# Turns the turret towards its hardpoint's direction, as the game's code turns it towards a target: the same aim
# (angle_to_point + aimOffset, here towards a point straight ahead of the hardpoint, whose angle back to the turret is
# the hardpoint's rotation + PI / 2), speed and power. The locked turrets' angle turns it further: clockwise (towards
# the line) on the left of the ship's mirror line, counter-clockwise on its right, so the turrets on both sides converge
# for a positive angle; clockwise (right) on the line itself. The game's code stops the actuation sound in every frame
# it doesn't turn the turret itself, so this turn is silent.
func _tlfTurn(delta):
	if pivot == null or not is_instance_valid(ship):
		return
	var forward = _tlfHardpoint.global_rotation if is_instance_valid(_tlfHardpoint) else global_rotation
	var towardsLine = - _tlfSide if _tlfSide != 0 else 1
	var aim = forward + PI / 2 + deg2rad(aimOffset) + deg2rad(_tlfAngle) * towardsLine
	var move = - Tool.angularDistance(pivot.global_rotation, aim)
	if abs(move) < _TLF_ALIGNED:
		return
	var pd = powerDraw * delta
	if pd > 0:
		var got = (ship.drawEnergy(delta * pd) / delta) / pd
		if got <= _TLF_POWER_NEEDED:
			return
	var dr = delta * rotationPerSecond
	pivot.rotation += clamp(move, - dr, dr)

# The side of the ship the turret's hardpoint is on, for mirroring the locked turrets' angle. The mirror line runs
# through the ship's centre along the hardpoint's direction squared to the ship's nearest axis: the nose line for
# turrets facing forward, or nearly (the ATK225's bays, turned 30 degrees outward: with their own line of fire, their
# forward position would put them on the wrong side), and the line across the ship for turrets facing a side (the
# OCP-209's side bay, whose front hardpoint the game calls mainLeft and its back one mainRight). The side is as seen
# looking along that direction. Hardpoints never move, so it is found once.
func _tlfSideOf() -> int:
	if not is_instance_valid(ship) or not (ship is Node2D):
		return 0
	var hardpoint = _tlfHardpoint if is_instance_valid(_tlfHardpoint) else self
	var quarter = PI / 2
	var along = Vector2(0, -1).rotated(round((hardpoint.global_rotation - ship.global_rotation) / quarter) * quarter)
	var across = along.cross(ship.to_local(hardpoint.global_position))
	if abs(across) < _TLF_CENTRE:
		return 0
	return -1 if across < 0 else 1

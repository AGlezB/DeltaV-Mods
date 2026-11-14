extends StaticBody2D

# Stub of the game's ship (ships/ship-ctrl.gd) with every member DockingArm.gd and the two arm mods use. It is
# not a rigid body: the suites move it by hand, applying the impulses the arm leaves here (impulses, angImpulses).

signal frozen(how)
signal juryRigChanged
signal damageChanged
signal damageImpact(power, point, delta)
signal damageThermal(power, point, delta)

var cutscene = false
var escapeCutscene = false
var dummy = false
var frozen = false
var faction = "player"
var shipName = "SHIP_PROSPECTOR_VP"
var mass = 109.29
var linear_velocity = Vector2()
var angular_velocity = 0.0

var impulses = Vector2() # linear impulses received since the suite last applied them
var angImpulses = 0.0 # and their torque about the ship's centre
var energy = 0.0 # energy drawn in total
var damage = {} # system damage by type ("wear", "bent", ...)
var systems = {} # hasSystem() results by system name
var systemTargets = []
var temporaryCargo = []
var config = {}

func getConfig(key, default = null):
	return config.get(key, default)

func setConfig(key, value):
	config[key] = value

func getTunedValue(_system, _tune, default):
	return default

func isPlayerControlled():
	return true

func isValidSystemTarget(_system, _target):
	return true

func isValidMineralTarget(_target, _mineralConfig):
	return true

# The game caps this at the ship's power balance; the stub always delivers, so the arm is never short of power.
func drawEnergy(amount):
	energy += amount
	return amount

func getSystemDamage(_key, type):
	return damage.get(type, 0.0)

func changeSystemDamage(_key, type, amount, _capacity):
	damage[type] = damage.get(type, 0.0) + amount
	return damage[type]

func getCrewAdjustedJuryRigFactorForSystem(_key, _type):
	return 1.0

func addSystemTarget(_system, target):
	if not systemTargets.has(target):
		systemTargets.append(target)

func removeSystemTarget(_system, target):
	systemTargets.erase(target)

func addTemporaryCargo(target):
	if not temporaryCargo.has(target):
		temporaryCargo.append(target)

func removeTemporaryCargo(target):
	temporaryCargo.erase(target)

func hasSystem(systemName):
	return systems.get(systemName)

func apply_impulse(offset, impulse):
	impulses += impulse
	angImpulses += offset.cross(impulse)

func apply_torque_impulse(torque):
	angImpulses += torque

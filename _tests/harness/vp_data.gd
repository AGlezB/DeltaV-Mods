extends Reference

# The Eagle-Prospector-VP with an AR-1500 salvage arm and its grinder, as the game builds it (decompiled, the
# version in CHECKED_AGAINST). Every value cites the scene line it comes from; re-check them after a game update.
# Units: 10 = 1 m.

# The decompiled game version these values were checked against; run.ps1 warns when it tests against another one.
# Update it after re-checking the values against a newer game.
const CHECKED_AGAINST = "1.93.1"

# ships/Eagle-Prospector-VP.tscn:28, the hull (`Collider`). The MineralProcessingUnit polygons depend on the cargo
# configuration and are left out, as in the claude.ai tests.
const HULL = [
	Vector2(-33, -171), Vector2(-33, 6), Vector2(-41, 6), Vector2(-49, 14), Vector2(-49, 39), Vector2(-73, 64),
	Vector2(-73, 108), Vector2(-61, 120), Vector2(-33, 120), Vector2(-37, 148), Vector2(-37, 202), Vector2(-31, 230),
	Vector2(31, 230), Vector2(38, 202), Vector2(38, 148), Vector2(34, 120), Vector2(61, 120), Vector2(73, 108),
	Vector2(73, 63), Vector2(49, 39), Vector2(49, 13), Vector2(42, 6), Vector2(33, 6), Vector2(33, -171),
	Vector2(24, -171), Vector2(24, 23), Vector2(-24, 23), Vector2(-24, -171)]

# ships/Eagle-Prospector-VP.tscn:80, the WeaponSlot holding the arm (slot "main", WeaponSlot.gd).
const WEAPON_SLOT_POSITION = Vector2(0, -235)

# ships/modules/SalvageArm.tscn:7-37 (the AR-1500), over the defaults of ships/modules/DockingArm.tscn:21-24 and
# DockingArm.gd. idleAtReady (1.0 in the game) is set to 0 by the rig so that every run starts at once.
const ARM_POSITION = Vector2(0, 130)
const ARM_SCALE = Vector2(0.75, 0.75)
const ARM_PROPERTIES = {
	"damageModel": true,
	"targetOnlyShips": false,
	"torqueMassLimit": 10,
	"massLimit": 1500,
	"response": 0.8,
	"tunePowerMin": 0.5,
	"tunePowerMax": 1.5,
	"mineralTargetting": true,
	"pickupOnlyMineralTargets": true,
	"targetAsCargo": true,
	"powerLimit": 180000,
	"targetMassThrust": 80,
	"thrust": 100,
	"fullThrust": 1000,
	"maxVelocity": 200,
	"easeDistance": 100,
	"torque": 1000.0,
	"targetRotation": 0.0,
	"autopilotRelease": false,
	"damageWearCapacity": 720000.0,
	"damageBentCapacity": 9000.0,
	"damageBentThreshold": 70.0,
	"damageOverheatCapacity": 180000.0,
	"command": "x",
	"feedVelocity": Vector2(0, -280),
	"maxDist": 350, # DockingArm.tscn:21
	"conDist": 600, # DockingArm.tscn:22
	"mass": 500, # DockingArm.tscn:23
}
# SalvageArm.tscn:41-43, the arm sections (Arm.gd; armLength 300 from Arm.gd:3).
const ARM_NODE_ROTATION = 1.5708
const ARM_NODE_MAX_VELOCITY = 800
# SalvageArm.tscn:47-56 with the shape of DockingArm.tscn:12; collision_mask SalvageArm.tscn:48.
const DOCK_AREA_POSITION = Vector2(0, -450)
const DOCK_AREA_MASK = 4673
const DOCK_AREA_SHAPE_POSITION = Vector2(0, -120)
const DOCK_AREA_EXTENTS = Vector2(633.553, 476.834)
const DOCK_SLOT_POSITION = Vector2(0, -450)
const REST_SLOT_POSITION = Vector2(64, 0) # DockingArm.tscn:78

# ships/Eagle-Prospector-VP.tscn:24 (Grinder at the nose) and ships/modules/Grinder.tscn:34-134: each rotor is a
# circle of radius 12 at (0, -28) in an arm at (-+28, -8) turned by +-0.593412.
const GRINDER_POSITION = Vector2(0, -148)
const GRINDER_ARMS = [[Vector2(-28, -8), 0.593412], [Vector2(28, -8), -0.593412]]
const ROTOR_POSITION = Vector2(0, -28)
const ROTOR_RADIUS = 12.0

# asteroids/mineral-fe-1.tscn, the chunk's collision circle (all mineral scenes share it).
const CHUNK_RADIUS = 10.4048

# Masses (t). The ship's mass is the in-game Eagle-Prospector-VP of the user's logs (109.29 t; the scene's 10.66 is
# recomputed by the game every frame); the chunk is the user's 2.8 t one. Both can be set per run.
const SHIP_MASS = 109.29
const CHUNK_MASS = 2.8
# Turning inertia Godot works out for a 109.29 t body with the hull polygon (claude.ai measurement), scaled with
# the mass.
const SHIP_INERTIA_PER_TONNE = 168887.14 / 109.29

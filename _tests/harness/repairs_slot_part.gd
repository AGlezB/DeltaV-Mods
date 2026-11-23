extends "res://harness/repairs_part.gd"

# For the repairs suite: a system the Equipment screen knows by its slot. Only the hardpoints', thrusters' and LIDAR's
# scripts have a `type`, the slot they are mounted in (ships/WeaponSlot.gd, ThrusterSlot.gd, hud/LIDAR.gd).
var type = ""

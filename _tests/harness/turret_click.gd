extends Node

# Stub of the Mechanic tab's click (the Click AudioStreamPlayer of hud/OMS.tscn, the list's clickSound) for the turret
# suite: counts its plays.

var plays = 0

func play():
	plays += 1

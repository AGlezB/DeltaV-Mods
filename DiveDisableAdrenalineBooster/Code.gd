extends "res://ships/CabinLight.gd"

# CabinLight.gd is the Adrenaline booster (its systemName). The game builds the player's ship anew at
# the start of every dive, with `enabled` true, which is the flag the Mechanic tab toggles. The mod
# switches it off then. A ship that replaces it mid-dive (teleport) copies the old ship's `enabled`
# after it is set up, so what the player chose during the dive is kept.
func _ready():
	if systemName == "SYSTEM_ADRENALINE_BOOSTER" and ship != null and ship.isPlayerControlled():
		enabled = false

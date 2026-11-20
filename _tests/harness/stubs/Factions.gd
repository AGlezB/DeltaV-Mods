extends Node

# Stub of the game's Factions autoload (Factions.gd). ships/ship-ctrl.gd names it (dispositions, hostility), which the
# skip suite doesn't reach, so it has to exist for that script to compile. The bench's game scripts (_bench\) name
# noFaction (mineral.gd, a chunk in a hold) and getFaction (projectile.gd, a hit on something with a disposition).
# CombatSimulator freezes the pirates' faction for a run (frozenFactions).

const noFaction = "noFaction"

# As the game's: the factions whose dispositions ignore the save's adjustments.
var frozenFactions = ["player", "helpless", "ai.berserk"]

func getFaction(_of):
	return noFaction

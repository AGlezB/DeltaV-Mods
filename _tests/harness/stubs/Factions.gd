extends Node

# Stub of the game's Factions autoload (Factions.gd). ships/ship-ctrl.gd names it (dispositions, hostility), which the
# skip suite doesn't reach, so it has to exist for that script to compile. CombatSimulator freezes the pirates'
# faction for a run (frozenFactions).

# As the game's: the factions whose dispositions ignore the save's adjustments.
var frozenFactions = ["player", "helpless", "ai.berserk"]

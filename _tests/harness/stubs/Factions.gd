extends Node

# Stub of the game's Factions autoload (Factions.gd). ships/ship-ctrl.gd names it (dispositions, hostility), which the
# skip suite doesn't reach, so it has to exist for that script to compile. The bench's game scripts (_bench\) name
# noFaction (mineral.gd, a chunk in a hold) and getFaction (projectile.gd, a hit on something with a disposition).
# CombatSimulator freezes the pirates' faction for a run (frozenFactions). The Services screen's compensation rows
# (enceladus/ServiceUIFactionChange.gd) price themselves by a faction's hostility and fear towards the player, and
# zero both when bought (getDispositionTowards, adjustFactionDisposition, with the game's arguments).

const noFaction = "noFaction"

# As the game's: the factions whose dispositions ignore the save's adjustments.
var frozenFactions = ["player", "helpless", "ai.berserk"]
# What each faction feels towards another, as a test sets it: dispositions[faction][to] = {"hostility": …, "fear": …};
# none set is no interest, every value 0.
var dispositions = {}

func getFaction(_of):
	return noFaction

func getDispositionTowards(faction, to):
	var d = {"fear": 0.0, "curiosity": 0.0, "hostility": 0.0, "greed": 0.0, "support": 0.0}
	for k in dispositions.get(faction, {}).get(to, {}):
		d[k] = dispositions[faction][to][k]
	return d

func adjustFactionDisposition(faction, to, which, by):
	if not faction in dispositions:
		dispositions[faction] = {}
	if not to in dispositions[faction]:
		dispositions[faction][to] = {}
	dispositions[faction][to][which] = clamp(dispositions[faction][to].get(which, 0.0) + by, -1, 1)

extends Node

# Stub of the random event story/PirateCombat.gd for the combat suite, which run.ps1 puts at that path (the game's
# preloads its loot scenes): its exports with the game's names and defaults, and makeAt building what the game's does:
# the pirate (a TRTL of the pirate faction, through the Shipyard), the civilian it hunts when hasCivilian, then
# randi() % (lootMax - lootMin) + lootMin pieces of loot (plain bodies here). Each call is recorded in the script's
# metadata `made` as [hasCivilian, lootMin, lootMax, how many things it made].

export var lootMin = 0
export var lootMax = 20
export var hasCivilian = true
export var hasPirate = true

func makeAt(_pos):
	var out = []
	if hasPirate:
		var pirate = Shipyard.createShipByConfig({"model": "TRTL", "faction": "pirate", "config": {"fuel": {"capacity": 30000.0, "initial": 10000.0}}})
		pirate.ai = true
		pirate.preheat = true
		out.append(pirate)
	if hasCivilian:
		var civilian = Shipyard.createShipBuildByName("TRTL", "civilian")
		civilian.ai = true
		civilian.preheat = true
		out.append(civilian)
	for i in range(randi() % (lootMax - lootMin) + lootMin):
		out.append(RigidBody2D.new())
	var script = get_script()
	if not script.has_meta("made"):
		script.set_meta("made", [])
	script.get_meta("made").append([hasCivilian, lootMin, lootMax, out.size()])
	return out

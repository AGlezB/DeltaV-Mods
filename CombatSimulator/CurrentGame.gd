extends "res://CurrentGame.gd"

# CombatSimulator's extension of the CurrentGame autoload (installed from ModMain.gd's _init, before the engine creates
# it). It holds the running arena, which the other extensions ask (PauseMenu.gd), and keeps what the arena's ships do
# out of the save where the game writes whatever the ship's zone. The tables CombatLayer.gd copies at Start and
# restores at the end (dispositions, encountered ships, ship names, transponders, factions) need nothing here.

# The arena (CombatLayer.gd) while a run lasts, else null. Set and cleared by the arena.
var _csArena = null

# Spotting ships and chunks (hud/ShipMark.gd, hud/MineralMark.gd) and flying (ships/ship-ctrl.gd handleExperience)
# give experience whatever the zone. During a run it is dropped; talent passes, so the crew's daily growth at the
# station (grantXpAtStation, giveXp(days, 0, true)) goes on.
func giveXp(talent: float, experience: float, includeInactive = false, roleRestriction = "") -> void :
	if _csArena != null:
		if talent > 0:
			.giveXp(talent, 0, includeInactive, roleRestriction)
		return
	.giveXp(talent, experience, includeInactive, roleRestriction)

# Reactors (the Tsukuyomi's storyFlag), conversations and the tutorial set story flags whatever the zone. At the
# station only Enceladus.gd _ready sets one, so nothing real is dropped during a run.
func setStory(story, to, onlyRise = true):
	if _csArena != null:
		return
	return .setStory(story, to, onlyRise)

# Written when a ship starts a conversation (ships/ship-ctrl.gd aiStartDialog), before it checks it has one.
func recordEncounter(ship, where: Vector2, player):
	if _csArena != null:
		return
	return .recordEncounter(ship, where, player)

# The Astrogator tab's highlights of the save's destinations.
func setDestinationHighlight(name: String, highlight: String):
	if _csArena != null:
		return
	return .setDestinationHighlight(name, highlight)

# A ship joining the fleet: what the arm holds at the end of a dive, a conversation's gift.
func addShip(s: RigidBody2D) -> bool:
	if _csArena != null:
		return false
	return .addShip(s)

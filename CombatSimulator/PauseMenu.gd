extends "res://PauseLayer.gd"

# CombatSimulator's extension of the pause menu (res://PauseLayer.gd, the station's PauseMenuEnceladus and the ring
# scene's PauseMenu). During a run, the station's would still open on focus loss (_notification, unless the game's
# streaming setting is on), a gamepad disconnect or the Steam overlay (CurrentGame's pauseGame signal), with its save
# buttons, over the arena: there, pausing opens the arena's end confirmation instead, which pauses the game itself.
# Esc never gets here during a run: the arena takes it first. The dive's pause menu never sees a run.

func pauseGame(pause):
	var arena = CurrentGame.get("_csArena")
	if arena != null and is_instance_valid(arena):
		if pause:
			arena.confirmEnd()
		return
	.pauseGame(pause)

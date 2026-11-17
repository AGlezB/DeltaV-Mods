extends "res://menu/NewGamePlus.gd"

# The New Game+ screen shows the code and name of the new game's ship, made in rerollNames (when the screen is built,
# shown, and on Reroll) with CurrentGame.getNewTransponder. That ship is CurrentGame's initialShip (newGame), so the
# code is made for its model. _atcModel is AltTransponderCodes' member of the CurrentGame autoload (Code.gd), reached
# through set and get.
func rerollNames():
	var previous = CurrentGame.get("_atcModel")
	CurrentGame.set("_atcModel", CurrentGame.get("initialShip").get("model"))
	.rerollNames()
	CurrentGame.set("_atcModel", previous)

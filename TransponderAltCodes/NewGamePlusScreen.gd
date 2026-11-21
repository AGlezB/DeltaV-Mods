extends "res://menu/NewGamePlus.gd"

# The New Game Options screen shows the code and name of the new game's ship, made in rerollNames (when the screen is
# built, shown, and on Reroll) with CurrentGame.getNewTransponder. That ship is CurrentGame's initialShip (newGame), so
# the code is made for its model. _tacModel is TransponderAltCodes' member of the CurrentGame autoload (Code.gd),
# reached through set and get.
func rerollNames():
	var previous = CurrentGame.get("_tacModel")
	CurrentGame.set("_tacModel", CurrentGame.get("initialShip").get("model"))
	.rerollNames()
	CurrentGame.set("_tacModel", previous)

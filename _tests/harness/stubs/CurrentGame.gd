extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd, Tool.gd, TuningFloatValue.gd and
# CrewCheapHireNotifier reach.

signal dayPassed()
signal employmentChanged()

var traceMinerals = []
var adrenalineSum = 0.0 # what CabinLight.gd has added through adrenaline()
var state = {"crew": {}, "ui": {}} # the game's hired crew by full name, and its per-save UI store; the crew suite fills them
var availableCrew = [] # what getAvailableCrew() returns; the crew suite fills it

func adrenaline(amount):
	adrenalineSum += amount

func getPlayerShip():
	return null

func getAgendaMember(_agenda):
	return null

func getAvailableCrew(_all = false):
	return availableCrew

# As the game's: state.ui is saved with the rest of the state.
func setUiValue(flag, value):
	state.ui[flag] = value

func getUiValue(flag, default = null):
	return state.ui.get(flag, default)

func formatThousands(nr):
	return "%d" % nr

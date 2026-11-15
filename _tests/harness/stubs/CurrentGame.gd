extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd, Tool.gd and CrewCheapHireNotifier reach.

signal dayPassed()
signal employmentChanged()

var traceMinerals = []
var adrenalineSum = 0.0 # what CabinLight.gd has added through adrenaline()
var state = {"crew": {}} # the game's hired crew, by full name; the crew suite fills it
var availableCrew = [] # what getAvailableCrew() returns; the crew suite fills it

func adrenaline(amount):
	adrenalineSum += amount

func getPlayerShip():
	return null

func getAgendaMember(_agenda):
	return null

func getAvailableCrew(_all = false):
	return availableCrew

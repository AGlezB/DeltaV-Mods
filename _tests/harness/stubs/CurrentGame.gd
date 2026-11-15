extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd, Tool.gd, TuningFloatValue.gd,
# HireableCrew.gd, CrewBio.gd and CrewCheapHireNotifier reach.

signal dayPassed()
signal employmentChanged()
signal moneyChanged(money)

# The game's crew occupations and level keys (CurrentGame.gd), for the Hire screen's entries.
var occupations = ["CREW_OCCUPATION_PILOT", "CREW_OCCUPATION_MECHANIC", "CREW_OCCUPATION_GEOLOGIST", "CREW_OCCUPATION_ASTROGATOR"]
var experienceLevels = ["CREW_EXPERIENCE_NO", "CREW_EXPERIENCE_BEGINNER", "CREW_EXPERIENCE_JOURNEYMAN", "CREW_EXPERIENCE_EXPERT"]
var talentLevels = ["CREW_EDUCATION_NO", "CREW_EDUCATION_BASIC", "CREW_EDUCATION_HIGH", "CREW_EDUCATION_MASTER"]
var money = 1000000 # what getMoney() returns

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

# As the game's, without the wages, the log and the achievements: the member joins the crew and leaves the hire list.
func hireCrewmember(member):
	if not (member.fullName in state.crew):
		state.crew[member.fullName] = member
		availableCrew.erase(member)
		emit_signal("employmentChanged")

func getMoney(_includeInsurance = false):
	return money

# As the game's: the level's key among `translation`, in equal steps from 0 to 1.
func translateLevel(lvl: float, translation):
	var step = 1.0 / translation.size()
	var nr = 0
	while lvl >= 0:
		nr += 1
		lvl -= step
	return translation[min(nr, translation.size()) - 1]

# The crew stats CrewBio.gd compares an entry's with (its showStats): nobody's, and no derived stats.
func makeEmptyStats():
	var stats = {"active": 0, "salary": 0}
	for o in occupations:
		stats[o] = {"experience": 0, "talent": 0}
	return stats

func deriveStats(stats):
	return stats

func getCrewStats(_includeInactive = false, _butNotOnLeave = false, _includeMorale = true):
	return makeEmptyStats()

func getSkillFor(occupation, type):
	return "%s_%s" % [occupation, type.to_upper()]

# As the game's: state.ui is saved with the rest of the state.
func setUiValue(flag, value):
	state.ui[flag] = value

func getUiValue(flag, default = null):
	return state.ui.get(flag, default)

func formatThousands(nr):
	return "%d" % nr

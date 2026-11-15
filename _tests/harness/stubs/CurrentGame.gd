extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd, Tool.gd, TuningFloatValue.gd,
# Hud.gd, PriceLabel.gd, HireableCrew.gd, CrewBio.gd, SystemBuyUI.gd, SystemShipUpgradeUI.gd, CrewCheapHireNotifier,
# GeologyByMass and ShipCopyPaste reach.

signal dayPassed()
signal employmentChanged()
signal moneyChanged(money)
signal broadcast(from, to, msg, replies)
signal playerShipChanged()
signal hourPassed()

# The game's crew occupations and level keys (CurrentGame.gd), for the Hire screen's entries.
var occupations = ["CREW_OCCUPATION_PILOT", "CREW_OCCUPATION_MECHANIC", "CREW_OCCUPATION_GEOLOGIST", "CREW_OCCUPATION_ASTROGATOR"]
var experienceLevels = ["CREW_EXPERIENCE_NO", "CREW_EXPERIENCE_BEGINNER", "CREW_EXPERIENCE_JOURNEYMAN", "CREW_EXPERIENCE_EXPERT"]
var talentLevels = ["CREW_EDUCATION_NO", "CREW_EDUCATION_BASIC", "CREW_EDUCATION_HIGH", "CREW_EDUCATION_MASTER"]
var money = 1000000 # what getMoney() returns

# The game's minerals (CurrentGame.gd): the market's list, the ones a HUD can target, and their colours.
var mineralPrices = {"H2O": 0.1, "Be": 20.5, "Fe": 0.9, "Pd": 2.5, "Pt": 2.7, "V": 3.0, "W": 6.5}
var traceMinerals = ["Be", "Pt", "Fe", "Pd", "V", "W"]
var specificMineralColors = {
	"H2O": Color(0.1, 0.2, 1.0),
	"Be": Color(0.0, 0.7, 1.0),
	"Pt": Color(1.0, 1.0, 1.0),
	"Fe": Color(1.0, 0.2, 0.2),
	"Pd": Color(1.0, 0.4, 0.2),
	"V": Color(1.0, 0.35, 1.0),
	"W": Color(0.4, 1.0, 0.3),
	"C": Color(0.2, 0.2, 0.2),
	"Ca": Color(1.0, 1.0, 0.8),
	"CARGO_EQUIPMENT": Color(0.0, 1.0, 0.0),
}
var stories = {} # what setStory() was given (Hud.gd instance() sets the tutorial's)
var adrenalineSum = 0.0 # what CabinLight.gd has added through adrenaline()
var state = {"crew": {}, "ui": {}} # the game's hired crew by full name, and its per-save UI store; the crew suite fills them; the fleet suite adds the ships (ship, garage)
var availableCrew = [] # what getAvailableCrew() returns; the crew suite fills it
var playerShip = null # what getPlayerShip() returns; the fleet suite sets it
var time = 0 # the in-game time (s), getInGameTimestamp()
var logs = [] # what logEvent() was given: [type, details]
var validated = [] # the current ship's crew list at each validateEmployment()
var shipSellMarkdown = 0.9 # the game's, which SystemBuyUI.gd checkPrice reads

func adrenaline(amount):
	adrenalineSum += amount

func getPlayerShip():
	return playerShip

# As the game's, without the money hash, the achievements and the insurance.
func changeMoney(by, _insurance = false):
	money += by
	emit_signal("moneyChanged", money)

func logEvent(type, details = {}):
	logs.append([type, details.duplicate(true)])

func getInGameTimestamp():
	return time

# As the game's: the current ship's maintenance ends that much later, counted from now if it had ended.
func addShipMaintanenceTime(seconds):
	state.ship.maintaineceUntil = max(state.ship.get("maintaineceUntil", 0), time) + seconds

func getInspectionLimit():
	return 50

# The game's generates and stores a name for a transponder it doesn't know; this one stores nothing.
func getShipNameByTransponder(transponder):
	return state.get("shipNames", {}).get(transponder, "Ship " + transponder)

func getStory(story):
	return stories.get(story, 0)

# The game's puts the current ship's crew list aboard; this one records the list it would put aboard.
func validateEmployment():
	validated.append(state.ship.config.get("preferredCrew"))

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

func setStory(story, to, _onlyRise = true):
	stories[story] = to

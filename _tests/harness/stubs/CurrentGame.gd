extends Node

# Stub of the game's CurrentGame autoload: what DockingArm.gd, CabinLight.gd, Tool.gd, TuningFloatValue.gd,
# Hud.gd, PriceLabel.gd, HireableCrew.gd, CrewBio.gd, SystemBuyUI.gd, SystemShipUpgradeUI.gd, Dealer.gd, Game.gd,
# Enceladus.gd, TransponderOnIntro.gd, story/body.gd, menu/NewGamePlus.gd, InGameMoney.gd, MineralMarket.gd,
# MineralSellSlider.gd, MineralPriceChart.gd, ServiceUI.gd, CrewCheapHireNotifier, GeologyByMass, ShipCopyPaste,
# DiveSkipTransit, DealerNotifier, TransponderAltCodes, CombatSimulator, MarketAdvisor, ShipSaleAdvisor and
# LidarContactCallout reach (with TheRing.gd and
# PauseLayer.gd, which connect inGameTimePassed and pauseGame), and the game scripts the bench runs (_bench\:
# asteroid.gd isInSimulatiorRange, the PDWs' weapons ageToDamageWithSeed).

signal dayPassed()
signal employmentChanged()
signal moneyChanged(money)
signal moneyOrInsuranceChanged()
signal broadcast(from, to, msg, replies)
signal playerShipChanged()
signal hourPassed()
signal gameOver()
signal plotCourseTo(to, vector)
signal pointOfNoReturn()
signal moodChange(mood, delta)
signal inventoryModeChange(state)
signal pauseGame(how)
signal inGameTimePassed(delta)
# The notices of the game's notification panel (achievement/Notifications.gd), as CurrentGame.gd declares them:
# DiveSkipTransit connects each by its count of arguments.
signal poiDiscovered(name, type, param)
signal levelUp(member, type, from, to)
signal newShip(name)
signal lostShip(name)
signal transit(name)
signal crewGone(member)
signal crewInactive(member)

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
var nextShip = null # what recreatePlayerShip() returns; the skip suite sets it
var advanced = [] # what advanceTimeBySeconds() was given, in order
var richnessAdjust = 0 # Game.gd _ready resets it
var diveTarget = Vector2(0, 0) # the dive entry point, which Game.gd _ready makes the global offset
var globalOffset = Vector2(0, 0) # setGlobalOffset(); globalCoords() adds it
var targetTimeScale = 1.0 # Game.gd _process sets it during cutscenes (BulletTimer.gd eases Engine.time_scale to it)
var inventoryMode = false # Game.gd interlunarToEnceladus resets it
var saves = 0 # how many times saveToFile() was called
var playtime = {} # what addPlaytime() added, by name
var usedShipsPool = [] # the models the dealer draws its used ships from, as the game's; the dealer suite fills it
var forSale = [] # the ships getShipsAvailableForSale() returns; the dealer suite fills it
var ownedShips = [] # the ships getOwnedShips() returns (Fleet's list); the dealer suite fills it
# What ShipSaleAdvisor's Prepare and the Repairs screen's rows (ShipRepairAdvisor's buttons) reach: the stored ships'
# instances by hash (the sale suite fills it) and the lock around them, the crew's repair limit (in %) and mechanics
# (counted by getCrewNumberWithRole besides those hired), and what giveXp() was given: [talent, experience, inactive,
# role].
var ownedShipInstances = {}
var shipMutex = Mutex.new()
var repairLimit = 99.5
var mechanics = 0
var xp = []
# The transponder suite's own CurrentGame (the game's script, with TransponderAltCodes' extension): this stub hands it
# menu/NewGamePlus.gd's transponder calls, and the members this stub doesn't have (_get, _set).
var game = null

func getNewTransponder(s):
	return game.getNewTransponder(s)

func generateShipNameFromTransponder(transponder):
	return game.generateShipNameFromTransponder(transponder)

# A null return leaves the member unknown, as without _get.
func _get(property):
	if game != null and property in game:
		return game.get(property)
	return null

func _set(property, value):
	if game != null and property in game:
		game.set(property, value)
		return true
	return false

# The game's builds the dealer's stock anew (day, week, seed, the ships sold); this one gives `forSale`.
func getShipsAvailableForSale():
	return forSale.duplicate()

func getOwnedShips(_includeCurrent = false):
	return ownedShips.duplicate()

# As the game's: the transponders of the ships sold, which state.soldShips holds with their configs.
func getSoldTransponders():
	var transponders = []
	for s in state.get("soldShips", []):
		transponders.append(s.config.transponder)
	return transponders

# As the game's.
func shipHashFromConfig(sc):
	return JSON.print(sc, "", true)

func isDemo():
	return false

# The game's writes the state to the save file; this one counts the calls.
func saveToFile():
	saves += 1

func addPlaytime(what, seconds):
	playtime[what] = playtime.get(what, 0) + seconds

func recreatePlayerShip():
	return nextShip

func freeShipInstanceCache():
	pass

func setGlobalOffset(offset):
	globalOffset = offset

# As the game's: the tanks filled (the simulator's ships start full).
func resupplyThisCfg(cfg):
	if "fuel" in cfg:
		cfg.fuel.initial = cfg.fuel.get("capacity", 0)
	if "ammo" in cfg:
		cfg.ammo.initial = cfg.ammo.get("capacity", 0)
	if "drones" in cfg:
		cfg.drones.initial = cfg.drones.get("capacity", 0)
	return cfg

func globalCoords(localPosition):
	return localPosition + globalOffset

# As the game's: the shorter way from `to` to `from` in the ring, which wraps around across it.
func getInRingVectorTowards(from: Vector2, to: Vector2) -> Vector2:
	var m = from - to
	for adj in [Vector2(0, - 30000000.0), Vector2(0, 0), Vector2(0, 30000000.0)]:
		var t = m + adj
		if m.length() > t.length():
			m = t
	return m

# As the game's, without the light lag and the hour, day and some-time signals: state.time moves on.
func advanceTimeBySeconds(seconds):
	advanced.append(seconds)
	state["time"] = state.get("time", 0.0) + seconds
	time = state.time

# The current ship's state (the fleet suite sets state.ship), or an empty one.
func getPlayerShipConfig():
	return state.get("ship", {"config": {}})

func adrenaline(amount):
	adrenalineSum += amount

func getPlayerShip():
	return playerShip

# As the game's (the insurance first, where asked, for a cost), without the money hash and the achievements, and with
# moneyChanged at once (the game's comes a frame later, from its _process).
func changeMoney(by, insurance = false):
	var asked = by
	if insurance and by < 0:
		var held = getInsurance()
		if held >= -by:
			state.insurance = held + by
			by = 0
		else:
			by += held
			state.insurance = 0
	money += by
	if asked != 0:
		emit_signal("moneyOrInsuranceChanged")
	emit_signal("moneyChanged", money)

# Recorded in `logs`; where the state has a log of its own (the market suite's), also kept there as the game's keeps
# it, since the market's prices read it: an entry per run of one type, a trade merged into the last one within a day.
func logEvent(type, details = {}):
	logs.append([type, details.duplicate(true)])
	if not state.has("logs"):
		return
	var last = state.logs.back() if not state.logs.empty() else null
	var now = getInGameTimestamp()
	var old = false
	if last != null:
		if type == "LOG_EVENT_TRADE" and now - last.from > 24 * 3600:
			old = true
		last.to = now
	if last == null or last.type != type or old:
		last = {"type": type, "details": {}, "from": now, "to": now, "money": getMoney(), "insurance": getInsurance()}
		state.logs.append(last)
	for key in details:
		last.details[String(key)] = last.details.get(String(key), 0) + details[key]

# As the game's: within 1.2 km of the player's ship, or anywhere without one (asteroid.gd: a rock farther away breaks
# into nothing).
func isInSimulatiorRange(v: Vector2):
	if Tool.claim(playerShip):
		var inside = playerShip.is_inside_tree()
		var gp = playerShip.global_position
		Tool.release(playerShip)
		return v.distance_to(gp) < 12000 if inside else true
	return true

# The game's ages a used ship's equipment; nothing the harness or the bench builds is aged.
func ageToDamageWithSeed(_years, _seed, count, _limit):
	var out = []
	for i in range(count):
		out.append(0.0)
	return out

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

# As the game's: the cash, and the insurance too where asked (SystemShipRepairUI.gd isReplaceable).
func getMoney(includeInsurance = false):
	return money + (getInsurance() if includeInsurance else 0)

# As the game's: the level's key among `translation`, in equal steps from 0 to 1.
func translateLevel(lvl: float, translation):
	var step = 1.0 / translation.size()
	var nr = 0
	while lvl >= 0:
		nr += 1
		lvl -= step
	return translation[min(nr, translation.size()) - 1]

# As the game's: nobody's crew stats, which getCrewStats fills in and CrewBio.gd fills with an entry's (its showStats).
func makeEmptyStats():
	var stats = {"active": 0, "salary": 0}
	for o in occupations:
		stats[o] = {"experience": 0, "talent": 0}
	return stats

# As the game's for the one stat a mod reads, the geologist's Price prediction accuracy (GeologyByMass's line on the
# geologist aboard, through getCrewStats); the others aren't derived.
func deriveStats(stats):
	stats.CREW_STATS_GEOLOGIST_PREDICTION = clamp(0.1 * (1 - stats.CREW_OCCUPATION_GEOLOGIST.talent) + 0.9 * (stats.CREW_OCCUPATION_GEOLOGIST.talent), 0, 1)
	return stats

# As the game's: in the dive crew (`active`), and not on leave.
func isCrewMemberActive(member: Dictionary) -> bool:
	if not member.get("active", false):
		return false
	var leave = member.get("leave", 0) - getInGameTimestamp()
	return not (leave > 0)

# As the game's.
func isCrewOnLeave(member: Dictionary) -> bool:
	return member.get("leave", 0) - getInGameTimestamp() > 0

# As the game's, without its cache: the best talent and experience per occupation among the dive crew (with
# `includeInactive` everyone, or with `butNotOnLeave` too all but those on leave), each raised or lowered by the
# member's morale, then the derived stats (deriveStats, only the one a mod reads). A member without a talent, an
# experience or a salary, as a suite may hire one, counts as 0.
func getCrewStats(includeInactive = false, butNotOnLeave = false, includeMorale = true):
	var stats = makeEmptyStats()
	for c in state.crew.values():
		var include = isCrewMemberActive(c)
		if includeInactive:
			include = not isCrewOnLeave(c) if butNotOnLeave else true
		if include:
			stats.active += 1
			var talent = c.get("talent", 0.0)
			var experience = c.get("experience", 0.0)
			if includeMorale:
				var morale = clamp(c.get("morale", 0.0), -0.5, 0.5)
				talent = pow(talent, 1 - morale)
				experience = pow(experience, 1 - morale)
			var occupation = c.get("occupation")
			if occupation in stats:
				stats[occupation].talent = clamp(max(stats[occupation].talent, talent), 0, 1)
				stats[occupation].experience = clamp(max(stats[occupation].experience, experience), 0, 1)
		stats.salary += c.get("salary", 0)
	return deriveStats(stats)

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

func getInsurance():
	return state.get("insurance", 0)
func getRepairLimit(_includeInactive = false):
	return repairLimit

# As the game's: how many of the crew have `role` (any with ""), in the dive crew, or with `includeInactive` all but
# those on leave; plus `mechanics` for the mechanics, a count a suite sets without hiring anyone.
func getCrewNumberWithRole(role, includeInactive = false):
	var count = mechanics if role in ["", "CREW_OCCUPATION_MECHANIC"] else 0
	for k in state.crew:
		var member = state.crew[k]
		var counted = not (member.get("leave", 0) - getInGameTimestamp() > 0) if includeInactive else isCrewMemberActive(member)
		if counted and (role == "" or member.get("occupation") == role):
			count += 1
	return count

# As the game's: the hired crew, by full name.
func getCrew():
	return state.crew

# As the game's: an object with a reward of its own.
func isOddity(i):
	return "specialPrice" in i and i.specialPrice > 0

func giveXp(talent, experience, includeInactive = false, role = ""):
	xp.append([talent, experience, includeInactive, role])

func removeOwnedShipByHash(key):
	ownedShipInstances.erase(key)

# As the game's for a crew with nobody on leave: everyone hired is active.
func getCrewNumbers():
	return {"active": state.crew.size(), "total": state.crew.size(), "leave": 0}

func dateToString(timestamp):
	var dt = OS.get_datetime_from_unix_time(timestamp)
	return "%04d/%02d/%02d" % [dt.year, dt.month, dt.day]

# As the game's, with "." between the whole part and the decimals, and formatThousands's whole part.
func formatThousandsWithDecimals(nr, dec = 2):
	var order = int(pow(10, dec))
	var rest = int(round(abs(nr * order))) % order
	return ("%%s.%%0%sd" % dec) % [formatThousands(round(nr * order) / order), rest]

func getShipMaintanenceTime():
	return state.get("ship", {}).get("maintaineceUntil", 0)

# The Mineral Market: the stored minerals, and the prices, as the game's code makes them (CurrentGame.gd
# initializePrices, getMineralPriceAdjustmentAt, getPlayerInfluenceMineralMarketAt): a hundred sines per mineral drawn
# from the save's seed, moved by the player's trades in the log (state.logs, which logEvent keeps where the state has
# one). Prices stand still at the base price until initializePrices draws the sines (the market suite calls it).
var priceFluctuations = {}
var priceTotals = 100
var mineralPriceFluctuationsRange = 0.99
const playerMeddlingInfluenceFactor = 1400000000.0
const mineralPriceMargin = 0.01
var playerInfluenceLookbackDays = 180
var playerInfluenceSaleDividor = 2000000000
var playerInfluenceCache = {}
# The crew's Price prediction accuracy (CREW_STATS_GEOLOGIST_PREDICTION): the game's deriveStats gives 0.1 without a
# geologist.
var predictionAccuracy = 0.1

func _ready():
	connect("dayPassed", self, "invalidateFutureCache")

func getMinerals(m):
	return state.get("storage", {}).get("minerals", {}).get(m, 0)

func changeMinerals(m, by):
	var minerals = state.storage.minerals
	minerals[m] = minerals.get(m, 0) + by

func srai(s: int, cnt: int):
	var out = []
	for i in range(cnt):
		var o = rand_seed(s + state.get("seed", 0))
		s = o[0]
		out.append(abs(o[1]))
	return out

func i2f(i: int) -> float:
	return float(i % 10000) / 10000.0

func initializePrices():
	playerInfluenceCache = {}
	var f = srai(234232 + state.get("seed", 0), priceTotals * 2 * mineralPrices.size())
	var nr = 0
	for mineral in mineralPrices.keys():
		var factors = []
		for i in range(priceTotals):
			var fo = pow(i2f(f[nr]), 3)
			factors.append({"time": (1e-06 + pow(fo, 3)) * 3600 * 24 * 365, "amp": pow(fo, 2) * i2f(f[nr + 1])})
			nr += 2
		priceFluctuations[mineral] = factors

func getMineralPriceAdjustmentAt(mineral: String, at: float):
	var factors = priceFluctuations.get(mineral, [])
	var price = 0
	if factors.size() == 0:
		return 1
	var t = getPlayerInfluenceMineralMarketAt(mineral, abs(at))
	var pia = t[0]
	var pim = t[1]
	var playerMeddlingFactor = 1 + abs(pim) * playerMeddlingInfluenceFactor
	for f in factors:
		price += sin(at / f.time) * f.amp * (1.0 + clamp(pow(playerMeddlingFactor / clamp(f.time, 3600, 36000), 1), 0, 80))
	return abs(1 + (price / factors.size()) * mineralPriceFluctuationsRange + clamp(pia, - 1, 0.1) - mineralPriceMargin) + mineralPriceMargin

func getPlayerInfluenceMineralMarketAt(mineral: String, at: float):
	var atk = floor(at / (24 * 3600))
	if atk in playerInfluenceCache:
		return playerInfluenceCache[atk][mineral]
	var age = playerInfluenceLookbackDays * 24 * 3600
	var from = at - age
	var entries = state.get("logs", [])
	var lastLog = entries.size() - 1
	var influence = {}
	for m in mineralPrices:
		influence[m] = [0.0, 0.0]
	while lastLog >= 0:
		var le = entries[lastLog]
		var t = le.from
		if t < from:
			break
		if t < at and le.type == "LOG_EVENT_TRADE":
			for m in influence:
				var sold = clamp(le.details.get(m, 0) * mineralPrices[m] / playerInfluenceSaleDividor, - 5, 5)
				var p = 1.0 - pow(clamp(abs(clamp((at - t) / age, 0, 1) - 0.5) * 2, 0, 1), 0.5)
				influence[m][0] += (sold * p)
				influence[m][1] += (abs(sold * p) / playerInfluenceLookbackDays)
		lastLog -= 1
	playerInfluenceCache[atk] = influence
	return influence[mineral]

func invalidateFutureCache(_foo = null):
	var now = getInGameTimestamp()
	for i in playerInfluenceCache.keys():
		if i < now + 24 * 3600:
			playerInfluenceCache.erase(i)

func getMineralMarketPricePerKgAt(material, at):
	if material in mineralPrices:
		return mineralPrices[material] * getMineralPriceAdjustmentAt(material, at)
	return 0

func getMineralMarketPricePerKg(material):
	return getMineralMarketPricePerKgAt(material, getInGameTimestamp())

func getMineralPricePredictionError(at: float) -> float:
	return pow(at / (3600 * 24 * 40), 2) / predictionAccuracy

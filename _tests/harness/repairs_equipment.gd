extends PanelContainer

# For the repairs suite: the station's Equipment screen (enceladus/Upgrades.gd), its items found as getItems() finds
# them, and the game's updatePricesAndAvailability and buy, copied, without the preview ships, labels and sounds. Where
# the game's buy builds the player's ship again (CurrentGame.recreatePlayerShip, then Enceladus.gd shipChanged), this
# one calls `rebuild`, which the suite sets, and records each purchase.

signal shipConfigChanged

var rebuild = null # a FuncRef
var bought = [] # [slot, value, net price] of each purchase

func _ready():
	for item in getItems():
		item.connect("buy", self, "buy")
	CurrentGame.connect("playerShipChanged", self, "updatePricesAndAvailability")

func type(of):
	match typeof(of):
		TYPE_INT:
			return TYPE_REAL
		_:
			return typeof(of)

func updatePricesAndAvailability():
	if not is_inside_tree():
		return
	var playerShip = CurrentGame.getPlayerShip()
	var items = getItems()
	if not playerShip.setup:
		yield(playerShip, "setup")
	else:
		playerShip.fillInSystems(false)
	var slotDiscount = {}
	var actualDiscount = {}
	var actualSlotTime = {}
	var money = CurrentGame.getMoney()
	for item in items:
		var slot = item.slot
		var installed = playerShip.getConfigWithDefaults(slot)
		var val = item.getVal()
		var isInstalled = type(val) == type(installed) and val == installed
		if installed == null and item.default:
			isInstalled = true
		if installed == null and val is float and val == 0:
			isInstalled = true
		item.setAvailable(not isInstalled)
		if isInstalled:
			slotDiscount[slot] = item.price
			item.setInstalled(true)
		else:
			item.setInstalled(false)
	for slot in slotDiscount:
		var actual = playerShip.getSlotValue(slot)
		if actual >= 0:
			actualDiscount[slot] = actual
			actualSlotTime[slot] = playerShip.getSlotTime(slot)
	for item in items:
		var slot = item.slot
		if slot in actualDiscount:
			item.setValuesDiscount(0, actualDiscount[slot], actualSlotTime.get(slot, 0))
		else:
			if slot in slotDiscount:
				item.setValuesDiscount(slotDiscount[slot])
		var price = item.getNetPrice()
		if price > money and price >= 0:
			item.setAvailable(false)

func getItemsFrom(where):
	var out = []
	for i in where.get_children():
		if "system" in i:
			out.append(i)
		else:
			out += getItemsFrom(i)
	return out

func getItems():
	return getItemsFrom(self)

func buy(price, slot, system, item, time = 0):
	bought.append([slot, system, price])
	for each in getItems():
		each.setAvailable(false)
	var playerShip = CurrentGame.getPlayerShip()
	playerShip.clearDamageInSlot(slot)
	playerShip.setConfig(slot, item.getVal())
	CurrentGame.changeMoney(- price)
	CurrentGame.logEvent("LOG_EVENT_UPGRADE", {"LOG_EVENT_DETAILS_COST": - price, item.system: - price})
	if time > 0:
		CurrentGame.addShipMaintanenceTime(time)
	if rebuild != null:
		rebuild.call_func()
	Tool.deferCallInPhysics(self, "emit_signal", ["shipConfigChanged"])

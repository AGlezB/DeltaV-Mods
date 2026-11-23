extends "res://enceladus/SystemBuyUI.gd"

# ShipSaleAdvisor: on the Fleet screen, Sell on a ship that would bring more cash once prepared shows a dialog of its
# own instead of the game's confirmation: Prepare, Sell (as it is) or Cancel.
#
# The Fleet screen (enceladus/Owned.tscn, an instance of Dealer.tscn) lists the owned ships as entries of this script;
# the ship market uses the same script for the ships for sale (`owned` false), which the mod leaves alone. Sell is
# disabled on the current ship and on a ship in maintenance (checkCurrentAndOwned, ship-ctrl.gd canBeSold), so the ship
# sold is always one stored in CurrentGame.state.garage, and this entry's `ship` is built from that very config
# (CurrentGame.gd getOwnedShips, Shipyard.gd createShipByConfig).
#
# - Preparing is what the player could do by hand after switching to the ship: Fix clicks at the Repairs screen
#   (enceladus/SystemShipRepairUI.gd: each halves every damage of the piece, only below the crew's repair limit and
#   while replacing would cost more than fixing; doFixSystem), and slots taken down to their cheapest item at the
#   Equipment screen (enceladus/Upgrades.gd updatePricesAndAvailability and buy). Advisor.gd picks the steps from what
#   _ssaGather reads here; the items are judged against this ship, not the flown one (SystemShipUpgradeUI.gd
#   isAvailable and UpgradeGroup.gd reexamine ask the player's ship).
# - The figures: the sale now is the game's (Dealer.gd sell: getShipValue times shipSellMarkdown), and the sale after
#   is measured on a trial ship, built from a copy of the prepared config and freed once it has a value, as the Fleet
#   screen builds its own copies for the preview (Dealer.gd showcaseDuplicate). The dialog shows only when the cash it
#   brings reaches the minimum gain set (Settings.gd minGain).
# - The dialog: a ConfirmationDialog as ShipCopyPaste's (the entry's menu theme, centered, Cancel focused as the game's
#   SellShow focuses SellCancel), with the line at its top, the rows (money coloured and signed as the Fleet screen's
#   trade-in: Dealer.gd displayShip, colorPlus and colorMinus), and a warning in the maintenance label's colour
#   (enceladus/MaintainenceLabel.tscn) when preparing takes time. Prepare plans again and applies only a plan that still
#   reads as shown; Sell sells as the game's confirmation does (_on_SellConfirm_pressed); Esc, Cancel or the Fleet
#   screen closing closes it.
# - Prepare works on a copy of the stored config, without switching ships (so the crew stays aboard as it is, and the
#   jury-rig switching would reset stays): each click as doFixSystem does it (paid by the insurance first, the
#   mechanics' XP, the log, the achievement), each slot as Upgrades.gd buy does it (its pieces' damage cleared as
#   clearDamageInSlot does, the value set, the refund, the log), the maintenance as addShipMaintanenceTime adds it, then
#   the copy replaces the stored config and the Fleet screen lists its ships again (Dealer.gd addShips), which makes a
#   new entry for the prepared ship.
# - Settings: Shift+Click on an enabled Sell button, or its gamepad twin (Badge.gd isPadShortcut), opens the mod's
#   settings screen (SettingsUI.gd). A note at the bottom of the Fleet screen says so (FleetNote.gd), in place of a
#   Shift badge.
#
# Stacking: the parent's _ready and _input are never called (Godot runs every level by itself); _on_Sell_pressed falls
# through to the parent with `._on_Sell_pressed()` where the mod has nothing to offer; new members start with `_ssa`.
# ShipCopyPaste extends the same script and touches nothing of Sell; its checkCurrentAndOwned, which Sell calls once an
# offer is worked out, calls the game's first.

const ShipSaleAdvisor = preload("res://ShipSaleAdvisor/Settings.gd")
const _SSA_ADVISOR = preload("res://ShipSaleAdvisor/Advisor.gd")
const _SSA_SETTINGS_UI = preload("res://ShipSaleAdvisor/SettingsUI.gd")
const _SSA_NOTE = preload("res://ShipSaleAdvisor/FleetNote.gd")
const _SSA_BADGE = preload("res://ShipSaleAdvisor/Badge.gd")

# The station's screens next to the Fleet screen (enceladus/Enceladus.tscn): the Equipment screen, whose items price
# the slots, and the Tuning screen, whose description window the settings screen copies.
const _SSA_EQUIPMENT = "Upgrades"
const _SSA_TUNING = "Tuning"
# The settings screen's node among the station's screens (SettingsUI.gd setup).
const _SSA_SETTINGS_NODE = "ShipSaleAdvisorSettings"
# The entry's nodes the mod reads (enceladus/SystemBuyUI.tscn): its Sell button; the node in the Fleet screen's prose
# theme (enceladus/Subwindow.theme, as the ship's description), whose Label font the dialog's rows take.
const _SSA_SELL = "HBox/Sell"
const _SSA_PROSE = "HBox/Margin"
# The Fleet screen's column the note goes at the bottom of (enceladus/Dealer.tscn).
const _SSA_FLEET_COLUMN = "VB"
# The game's key for the dialog's Cancel (the entry's sell confirmation, SellCancel).
const _SSA_CANCEL = "CANCEL"
# The crew occupation whose members make fixes faster (SystemShipRepairUI.gd getMechanicMultiplier) and get the XP.
const _SSA_MECHANIC = "CREW_OCCUPATION_MECHANIC"
# What one Fix click leaves of each damage (SystemShipRepairUI.gd repairStepAmount: it takes half away), and how far
# past its capacity a damage can be and still be fixed (maxDamageThatCanBeFixed; beyond, the piece can only be
# replaced).
const _SSA_FIX_SHARE = 0.5
const _SSA_FIXABLE_DAMAGE = 1.5
# The most Fix clicks planned on one piece: the repair limit stops them long before (each halves what is left).
const _SSA_MAX_CLICKS = 30
# How far a piece's shortfall from 100 % (as a share) may exceed its worst listed damage before the rest counts as a
# shortfall no click lowers (_ssaClicks): float error stays under it.
const _SSA_UNEXPLAINED = 0.001
# The frames the trial ship gets to set itself up (its systems load into it once it is in the tree).
const _SSA_TRIAL_FRAMES = 300
# The trial ship's place: a viewport of its own on the Fleet screen, with its own world, never drawn.
const _SSA_TRIAL_NODE = "ShipSaleAdvisorTrial"
const _SSA_TRIAL_SIZE = Vector2(2, 2)
# The Fleet screen's colours for money, and Dealer.gd's own values, used only where the screen has none.
const _SSA_COLOR_MINUS = "colorMinus"
const _SSA_COLOR_PLUS = "colorPlus"
const _SSA_COLOR_MINUS_FALLBACK = Color(1.0, 0.5, 0.5, 1)
const _SSA_COLOR_PLUS_FALLBACK = Color(0.5, 1.0, 0.5, 1)
# The game's maintenance label, whose colour the warning takes, and its value, used only where the scene can't be read.
const _SSA_WARNING_SCENE = "res://enceladus/MaintainenceLabel.tscn"
const _SSA_WARNING_FALLBACK = Color(1.0, 1.0, 0.26, 1)
# The widest the dialog's contents may be, as a share of the screen's width: they are only as wide as their texts need.
const _SSA_MAX_WIDTH_SHARE = 0.5
# The space between a row's name and its value, in heights of the rows' font.
const _SSA_COLUMN_GAP = 2.0
# The dialog's node, and the action of its Sell button.
const _SSA_DIALOG_NODE = "ShipSaleAdvisorDialog"
const _SSA_SELL_ACTION = "ShipSaleAdvisorSell"
# The texts (i18n/en.po).
const _SSA_TEXT_INTRO = "SHIPSALEADVISOR_INTRO"
const _SSA_TEXT_SALE_NOW = "SHIPSALEADVISOR_SALE_NOW"
const _SSA_TEXT_INSURANCE = "SHIPSALEADVISOR_INSURANCE_COST"
const _SSA_TEXT_CASH = "SHIPSALEADVISOR_CASH_COST"
const _SSA_TEXT_TIME = "SHIPSALEADVISOR_TIME"
const _SSA_TEXT_GAIN = "SHIPSALEADVISOR_GAIN"
const _SSA_TEXT_WARNING = "SHIPSALEADVISOR_WARNING"
const _SSA_TEXT_PREPARE = "SHIPSALEADVISOR_PREPARE"
const _SSA_TEXT_SELL = "SHIPSALEADVISOR_SELL"
const _SSA_TEXT_PLUS = "SHIPSALEADVISOR_PLUS"
const _SSA_TEXT_MINUS = "SHIPSALEADVISOR_MINUS"
const _SSA_TEXT_ZERO = "SHIPSALEADVISOR_ZERO"

var _ssaDialog = null # the dialog, made on the first offer
var _ssaIntro = null # its line at the top
var _ssaGrid = null # its rows
var _ssaWarning = null # its warning
var _ssaSellButton = null # its Sell button
var _ssaProseFont = null # the Fleet screen's prose font, which the rows and the warning take
var _ssaOffer = null # the offer it shows
var _ssaShown = "" # what it shows: Prepare applies only an offer that still reads the same
var _ssaBusy = false # while an offer is worked out
var _ssaSold = false # once its Sell has sold the ship
var _ssaClosedFrame = -1 # the frame in which Esc closed it

func _ready():
	if not owned:
		set_process_input(false)
		return
	var sell = get_node_or_null(_SSA_SELL)
	if sell is Button and not sell.is_connected("gui_input", self, "_ssaOnSellInput"):
		sell.connect("gui_input", self, "_ssaOnSellInput", [sell])
	var fleet = _ssaFleet()
	if fleet != null:
		fleet.connect("visibility_changed", self, "_ssaFleetVisibility")
		_ssaAddNote(fleet)

# Esc (or the pause button) while the dialog shows closes the dialog only, as in ShipCopyPaste: children get _input
# before their parents, so the Fleet screen (Dealer.gd _input, which closes on these) doesn't see it, and every later
# event of that frame is marked handled too, since Dealer.gd asks the action, which stays just pressed for the frame.
func _input(_event):
	if not _ssaCancelAction():
		return
	if is_instance_valid(_ssaDialog) and _ssaDialog.visible:
		_ssaDialog.hide()
		_ssaClosedFrame = Engine.get_idle_frames()
		get_tree().set_input_as_handled()
	elif _ssaClosedFrame == Engine.get_idle_frames():
		get_tree().set_input_as_handled()

func _ssaCancelAction() -> bool:
	for action in ["ui_cancel", "pause"]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

# Sell: the settings with Shift held; otherwise the offer, worked out with Sell disabled (the trial ship takes a few
# frames), and the dialog, or the game's confirmation where there is nothing worth offering.
func _on_Sell_pressed():
	if not owned or current:
		._on_Sell_pressed()
		return
	var sell = get_node_or_null(_SSA_SELL)
	if Input.is_key_pressed(KEY_SHIFT):
		_ssaOpenSettings(sell)
		return
	if _ssaBusy:
		return
	_ssaBusy = true
	if sell is Button:
		sell.disabled = true
	var offer = _ssaOfferNow()
	if offer is GDScriptFunctionState:
		offer = yield(offer, "completed")
	_ssaBusy = false
	checkCurrentAndOwned()
	# The Fleet screen closed meanwhile: nothing to show on it.
	var fleet = _ssaFleet()
	if fleet == null or not fleet.is_visible_in_tree():
		return
	if offer == null:
		._on_Sell_pressed()
		return
	_ssaShow(offer)

# Shift+Click on an enabled Sell button opens the settings instead of selling, and so does its gamepad twin on the
# highlighted button (Badge.gd isPadShortcut), as MarketAdvisor's menu entry does: the click's gui_input signal comes
# before the button's own _gui_input, and accepting the press there keeps the button from pressing.
func _ssaOnSellInput(event, sell: Button):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _SSA_BADGE.isPadShortcut(event)) and not sell.disabled:
		sell.accept_event()
		_ssaOpenSettings(sell)

# The settings screen, made on first use among the station's screens, opened from the Fleet screen.
func _ssaOpenSettings(sell):
	var fleet = _ssaFleet()
	if fleet == null or fleet.get_parent() == null or not fleet.get_parent().has_method("hidefoka"):
		return
	var screens = fleet.get_parent()
	var screen = screens.get_node_or_null(_SSA_SETTINGS_NODE)
	if screen == null:
		screen = _SSA_SETTINGS_UI.new()
		screen.setup(fleet, screens.get_node_or_null(_SSA_TUNING))
		screens.add_child(screen)
	_ssaClose()
	screen.open(fleet, sell)

# The note, once per Fleet screen, at the bottom of its column; and the save game's settings with it: the station is
# built anew after every load and new game, and its Fleet screen with it.
func _ssaAddNote(fleet: Node):
	var column = fleet.get_node_or_null(_SSA_FLEET_COLUMN)
	if column == null or column.has_node(_SSA_NOTE.NODE_NAME):
		return
	var settings = ShipSaleAdvisor.shared()
	settings.loadFromState()
	var note = _SSA_NOTE.new()
	note.setup(settings.modName())
	column.add_child(note)

# The Fleet screen: the entry's first ancestor that lists ships (Dealer.gd addShips).
func _ssaFleet():
	var node = get_parent()
	while node != null and not node.has_method("addShips"):
		node = node.get_parent()
	return node

# The Equipment screen, next to the Fleet screen.
func _ssaEquipment():
	var fleet = _ssaFleet()
	if fleet == null or fleet.get_parent() == null:
		return null
	var node = fleet.get_parent().get_node_or_null(_SSA_EQUIPMENT)
	if node != null and node.has_method("getItems"):
		return node
	return null

# The Fleet screen closed: the dialog goes with it.
func _ssaFleetVisibility():
	var fleet = _ssaFleet()
	if fleet != null and not fleet.visible:
		_ssaClose()

# The offer for this entry's ship, or null when there is none worth showing: the plan (Advisor.gd), the figures, and
# what _ssaGather read, which Prepare applies. A coroutine while the trial ship sets itself up.
func _ssaOfferNow():
	var fleet = _ssaFleet()
	var equipment = _ssaEquipment()
	if fleet == null or equipment == null or not is_instance_valid(ship) or not Tool.claim(ship):
		return null
	if not ship.setup or not ship.canBeSold():
		Tool.release(ship)
		return null
	var minGain = ShipSaleAdvisor.shared().getValue("minGain")
	var markdown = CurrentGame.shipSellMarkdown
	var gathered = _ssaGather(equipment, markdown, minGain)
	var plan = _SSA_ADVISOR.plan(gathered.data)
	if _SSA_ADVISOR.isEmpty(plan):
		Tool.release(ship)
		return null
	var config = _ssaPrepared(gathered, plan)
	var saleNow = ship.getShipValue() * markdown
	Tool.release(ship)
	var value = _ssaTrialValue(fleet, config)
	if value is GDScriptFunctionState:
		value = yield(value, "completed")
	if value == null:
		return null
	var saleAfter = value * markdown
	var gain = plan.refund - plan.cashCost + saleAfter - saleNow
	if not _SSA_ADVISOR.reaches(gain, minGain):
		return null
	return {"gathered": gathered, "plan": plan, "saleNow": saleNow, "saleAfter": saleAfter, "gain": gain}

# What Advisor.gd plans from, read from this entry's ship (claimed) and the station, and what Prepare needs to apply it.
# The systems are the list the ship made at its setup, which the Fleet screen's ships never refresh (ship-ctrl.gd
# getSystems): the one Sell prices it by, and a stored ship's condition doesn't change while it is stored.
# - data: Advisor.gd's (markdown, money, insurance, minGain, systems, slots);
# - systems, by the same ids: each system's damage key, name (the log's), damage entries (type and current, as the
#   Repairs screen reads them), fix price and fix hours;
# - slots, by the same keys: the cheapest item and the systems mounted in the slot.
func _ssaGather(equipment, markdown: float, minGain: float) -> Dictionary:
	var systems = ship.getSystems()
	var limit = CurrentGame.getRepairLimit(true)
	var mechanics = CurrentGame.getCrewNumberWithRole(_SSA_MECHANIC, true)
	var fixScale = 1.0 / ((1.0 + mechanics) / 2.0)
	var data = {
		"markdown": markdown,
		"money": CurrentGame.getMoney(),
		"insurance": CurrentGame.getInsurance(),
		"minGain": minGain,
		"systems": {},
		"slots": {},
	}
	var info = {"data": data, "systems": {}, "slots": {}}
	for id in systems:
		var system = systems[id]
		var ref = system.get("ref")
		if not is_instance_valid(ref):
			continue
		var damage = []
		for d in system.get("damage", []):
			damage.append({"type": d.get("type"), "current": float(d.get("current", 0)), "max": float(d.get("max", 0))})
		var values = [ship.getSystemPrice(system)]
		var fixPrice = ref.get("repairFixPrice") if "repairFixPrice" in ref else null
		var fixHours = ref.get("repairFixTime") if "repairFixTime" in ref else null
		var replacement = ref.get("repairReplacementPrice") if "repairReplacementPrice" in ref else null
		var fixable = _ssaNumber(fixPrice) and _ssaNumber(fixHours) and _ssaNumber(replacement) and not damage.empty()
		if fixable and not _ssaUnfixable(damage):
			_ssaClicks(system, ref, damage, values, limit, float(fixPrice), float(replacement))
		else:
			fixPrice = 0
			fixHours = 0
		var slot = ref.get("type") if "type" in ref and ref.get("type") is String else ""
		data.systems[id] = {
			"slot": slot,
			"values": values,
			"fixPrice": float(fixPrice),
			"fixTime": float(fixHours) * 3600.0 * fixScale,
		}
		info.systems[id] = {
			"key": system.get("key", id),
			"name": system.get("name", ""),
			"damage": damage,
			"fixPrice": float(fixPrice),
			"fixHours": float(fixHours),
		}
	_ssaSlots(equipment.getItems(), systems, info)
	return info

# The values after each Fix click the Repairs screen would let the player make on `system`, appended to `values` (its
# value now first): each click halves every damage, so the piece's condition, the shortfall of its worst damage from
# its capacity (the systems' getStatus), loses half its distance from 100 %; clicks stop at the repair limit, or once
# replacing would cost no more than fixing (SystemShipRepairUI.gd isFixable, shouldBeFixed, replacementPrice). The
# value is the game's own for that condition (ship-ctrl.gd getSystemPrice). A shortfall the listed damage doesn't
# explain is one no click lowers, kept as a floor: a click that wouldn't raise the condition adds nothing, and isn't
# planned. (The arm's condition reads an overheat its Repairs entry doesn't list, DockingArm.gd doComputeStatus, though
# nothing writes it under the key read: its overheat goes under the node's name, _on_energy_hit.)
func _ssaClicks(system: Dictionary, ref, damage: Array, values: Array, limit: float, fixPrice: float, replacement: float):
	var worst = 0.0
	for d in damage:
		if d.max > 0:
			worst = max(worst, d.current / d.max)
	var status = float(system.get("status", 100))
	var shortfall = 1.0 - status / 100.0
	var floorShare = shortfall if shortfall > worst + _SSA_UNEXPLAINED else 0.0
	for click in _SSA_MAX_CLICKS:
		var value = values.back()
		if status >= limit or not max(0.0, replacement - value) > fixPrice:
			break
		var share = max(worst * pow(_SSA_FIX_SHARE, click + 1), floorShare)
		status = clamp(100.0 - 100.0 * share, 0.0, 100.0)
		values.append(ship.getSystemPrice({"status": status, "ref": ref}))

# A piece the Repairs screen can only replace: one of its damages is past what a fix can take on
# (SystemShipRepairUI.gd isFubar).
func _ssaUnfixable(damage: Array) -> bool:
	for d in damage:
		if d.current > d.max * _SSA_FIXABLE_DAMAGE:
			return true
	return false

# The Equipment screen's slots this ship has, read as Upgrades.gd updatePricesAndAvailability reads the player's: the
# item fitted (a slot without one isn't priced against what is in it, so it is left out), the cheapest item available
# to this ship, and, where it is cheaper, the slot's price: against the value of the pieces mounted in it
# (ship-ctrl.gd getSlotValue, for every slot of the kind: getNumberOfSlots), with the time getSlotTime gives, or where
# none is mounted (a number, the lidar, the autopilot), against the fitted item's price.
func _ssaSlots(items: Array, systems: Dictionary, info: Dictionary):
	var groups = {}
	var order = []
	for item in items:
		if not groups.has(item.slot):
			groups[item.slot] = []
			order.append(item.slot)
		groups[item.slot].append(item)
	for slot in order:
		if slot == "" or not _ssaGroupShown(groups[slot][0]):
			continue
		var fitted = ship.getConfigWithDefaults(slot)
		var installed = null
		for item in groups[slot]:
			if _ssaInstalled(item, fitted):
				installed = item
				break
		if installed == null:
			continue
		var cheapest = null
		for item in groups[slot]:
			if item != installed and _ssaAvailable(item) and (cheapest == null or item.price < cheapest.price):
				cheapest = item
		if cheapest == null or cheapest.price >= installed.price:
			continue
		var count = ship.getNumberOfSlots(slot)
		var members = []
		var entry = {"members": members, "cost": 0.0, "refund": 0.0, "time": 0.0}
		if ship.getSlotValue(slot) >= 0:
			for id in systems:
				var ref = systems[id].get("ref")
				if is_instance_valid(ref) and "type" in ref and ref.get("type") is String and ref.get("type") == slot:
					members.append(id)
			entry.cost = float(cheapest.price * count)
			entry.time = max(0.0, ship.getSlotTime(slot))
		else:
			entry.refund = float((installed.price - cheapest.price) * count)
		info.data.slots[slot] = entry
		info.slots[slot] = {"item": cheapest, "members": members}

# Whether `item` is the one fitted, as Upgrades.gd updatePricesAndAvailability decides it: the same type (an int
# counting as a float) and value, or, where the config has nothing, the slot's default item or a number of 0.
func _ssaInstalled(item, fitted) -> bool:
	var value = item.getVal()
	if fitted == null:
		return item.default or (value is float and value == 0)
	var a = TYPE_REAL if typeof(value) == TYPE_INT else typeof(value)
	var b = TYPE_REAL if typeof(fitted) == TYPE_INT else typeof(fitted)
	return a == b and value == fitted

# Whether the Equipment screen would offer `item` to this ship (SystemShipUpgradeUI.gd isAvailable, which asks the
# player's ship): shown in the screen's scene, its story condition met, the ship able to mount it, its number within
# the ship's limits.
func _ssaAvailable(item) -> bool:
	if not item.initialVisibility:
		return false
	if item.storyFlag and item.storyFlag != "":
		var story = CurrentGame.getStory(item.storyFlag)
		if item.storyFlagMax != -1 and story > item.storyFlagMax:
			return false
		if item.storyFlagMin != -1 and story < item.storyFlagMin:
			return false
	if item.capabilityLock and not ship.queryCapability(item.slot, item.system):
		return false
	if item.numVal >= 0:
		var limit = ship.upgradeLimits.get(item.slot, null)
		if limit is Vector2 and (item.numVal < limit.x or item.numVal > limit.y):
			return false
	return true

# Whether the Equipment screen shows the group `item` is in for this ship (UpgradeGroup.gd reexamine, which asks the
# player's ship): a group of a slot shows where the ship's config has the slot or the group always shows, and a group
# of a ship type only for that type; any other keeps its scene's visibility.
func _ssaGroupShown(item) -> bool:
	var group = item.get_parent()
	while group != null and not ("restrictType" in group and "always" in group):
		group = group.get_parent()
	if group == null:
		return true
	if group.slot or group.restrictType:
		var config = ship.getConfigWithDefaults(group.slot)
		if (not config and not group.always) or (group.restrictType and ship.shipType != group.restrictType):
			return false
		return true
	return group.visible

func _ssaNumber(value) -> bool:
	return value is int or value is float

# A copy of this ship's full config with the plan applied, as the game would leave it: each Fix click as doFixSystem
# makes it (every damage entry of the piece less half of what it reads then), each slot taken down as Upgrades.gd buy
# makes it (clearDamageInSlot takes away what each damage reads then, and the slot gets the item's value), and the
# maintenance as addShipMaintanenceTime adds it.
func _ssaPrepared(gathered: Dictionary, plan: Dictionary) -> Dictionary:
	var full = ship.fullConfig.duplicate(true)
	var config = full.config
	for id in plan.clicks:
		var system = gathered.systems[id]
		for click in plan.clicks[id]:
			for d in system.damage:
				_ssaDamage(config, system.key, d.type, -_SSA_FIX_SHARE * d.current * pow(_SSA_FIX_SHARE, click))
	for slot in plan.strips:
		var entry = gathered.slots[slot]
		for id in entry.members:
			var system = gathered.systems[id]
			var done = plan.clicks.get(id, 0)
			for d in system.damage:
				_ssaDamage(config, system.key, d.type, -d.current * pow(_SSA_FIX_SHARE, done))
		_ssaPut(config, slot.split("."), entry.item.getVal())
	if plan.time > 0:
		full.maintaineceUntil = max(float(full.get("maintaineceUntil", 0)), CurrentGame.getInGameTimestamp()) + plan.time
	return full

# ship-ctrl.gd changeSystemDamage on a config: the entry made where it is missing, `delta` added.
func _ssaDamage(config: Dictionary, key, type, delta: float):
	if not config.get("damage") is Dictionary:
		config.damage = {}
	if not config.damage.get(key) is Dictionary:
		config.damage[key] = {}
	config.damage[key][type] = float(config.damage[key].get(type, 0)) + delta

# ship-ctrl.gd setConfig on a config: the dotted path made where it is missing, then the value.
func _ssaPut(dict: Dictionary, path, value):
	var node = dict
	for i in path.size() - 1:
		if not node.get(path[i]) is Dictionary:
			node[path[i]] = {}
		node = node[path[i]]
	node[path[path.size() - 1]] = value

# The value of the ship `config` makes, measured on a trial ship built from a copy of it, set up out of sight as the
# entries set up theirs (addShip: a dummy, its reactor off, in a cutscene), then freed; null when it can't be set up.
# It is read once set up, as the entry the Fleet screen makes for the prepared ship reads it (checkPrice), from the
# systems listed at setup, which Sell then prices it by. A coroutine. The tree is kept from the start: the Fleet screen
# takes its entries out of it and puts them back while it lists its ships.
func _ssaTrialValue(fleet: Node, config: Dictionary):
	var tree = get_tree()
	var host = fleet.get_node_or_null(_SSA_TRIAL_NODE)
	if host == null:
		host = Viewport.new()
		host.name = _SSA_TRIAL_NODE
		host.size = _SSA_TRIAL_SIZE
		host.own_world = true
		host.usage = Viewport.USAGE_2D
		host.render_target_update_mode = Viewport.UPDATE_DISABLED
		fleet.add_child(host)
	var trial = Shipyard.createShipByConfig(config.duplicate(true))
	if trial == null:
		return null
	trial.setDummy(true)
	trial.dummy = true
	trial.setReactorState(false)
	trial.visible = false
	host.add_child(trial)
	trial.preheat = false
	trial.cutscene = true
	for i in _SSA_TRIAL_FRAMES:
		if not is_instance_valid(trial) or trial.setup:
			break
		yield(tree, "idle_frame")
	var value = null
	if is_instance_valid(trial) and trial.setup:
		value = trial.getShipValue()
	if is_instance_valid(trial):
		if trial.get_parent() == host:
			host.remove_child(trial)
		Tool.remove(trial)
	return value

# The dialog: the line at its top in the menu font (the entry's theme, as the game's own dialogs), the rows and the
# warning in the Fleet screen's prose font, and its buttons Prepare (its OK), Sell and Cancel, in that order whatever
# the platform's order of OK and Cancel. A Popup draws on top of everything and isn't laid out by the entry.
func _ssaDialogBuild():
	if is_instance_valid(_ssaDialog):
		return
	var dialog = ConfirmationDialog.new()
	dialog.name = _SSA_DIALOG_NODE
	dialog.window_title = ""
	dialog.dialog_hide_on_ok = false
	dialog.get_ok().text = _SSA_TEXT_PREPARE
	dialog.get_cancel().text = _SSA_CANCEL
	_ssaSellButton = dialog.add_button(_SSA_TEXT_SELL, true, _SSA_SELL_ACTION)
	_ssaOrderButtons([dialog.get_ok(), _ssaSellButton, dialog.get_cancel()])
	var prose = get_node_or_null(_SSA_PROSE)
	_ssaProseFont = prose.get_font("font", "Label") if prose is Control else null
	var box = VBoxContainer.new()
	_ssaIntro = Label.new()
	_ssaIntro.autowrap = true
	_ssaIntro.align = Label.ALIGN_CENTER
	box.add_child(_ssaIntro)
	_ssaGrid = GridContainer.new()
	_ssaGrid.columns = 2
	_ssaGrid.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(_ssaGrid)
	_ssaWarning = Label.new()
	_ssaWarning.autowrap = true
	_ssaWarning.align = Label.ALIGN_CENTER
	_ssaWarning.modulate = _ssaWarningColor()
	if _ssaProseFont != null:
		_ssaWarning.add_font_override("font", _ssaProseFont)
	box.add_child(_ssaWarning)
	dialog.add_child(box)
	add_child(dialog)
	dialog.connect("confirmed", self, "_ssaPreparePressed")
	dialog.connect("custom_action", self, "_ssaDialogAction")
	dialog.connect("popup_hide", self, "_ssaDialogHidden")
	_ssaDialog = dialog

# The buttons in `buttons`' order, spaced as the dialog spaces its own (a spacer at each end and between them), and the
# D-pad's way from one to the next.
func _ssaOrderButtons(buttons: Array):
	var box = buttons[0].get_parent()
	for child in box.get_children():
		if not child in buttons:
			box.remove_child(child)
			child.queue_free()
	var order = [_ssaSpacer()]
	for button in buttons:
		order.append(button)
		order.append(_ssaSpacer())
	for i in order.size():
		if order[i].get_parent() == null:
			box.add_child(order[i])
		box.move_child(order[i], i)
	for i in buttons.size():
		var left = buttons[i - 1] if i > 0 else buttons[i]
		var right = buttons[i + 1] if i < buttons.size() - 1 else buttons[i]
		buttons[i].focus_neighbour_left = buttons[i].get_path_to(left)
		buttons[i].focus_neighbour_right = buttons[i].get_path_to(right)

func _ssaSpacer() -> Control:
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

# The game's maintenance label's colour (its scene's root), without making the label.
func _ssaWarningColor() -> Color:
	if ResourceLoader.exists(_SSA_WARNING_SCENE):
		var scene = load(_SSA_WARNING_SCENE)
		if scene is PackedScene:
			var state = scene.get_state()
			for i in state.get_node_property_count(0):
				if state.get_node_property_name(0, i) == "modulate":
					var color = state.get_node_property_value(0, i)
					if color is Color:
						return color
	return _SSA_WARNING_FALLBACK

# Fills the dialog with the offer, sized to the screen and centered on it, Cancel focused.
func _ssaShow(offer: Dictionary):
	_ssaDialogBuild()
	_ssaOffer = offer
	_ssaSold = false
	var texts = _ssaDescribe(offer)
	_ssaShown = JSON.print(texts)
	_ssaIntro.text = texts.intro
	_ssaWarning.text = texts.warning
	_ssaWarning.visible = texts.warning != ""
	_ssaFillRows(texts.rows)
	var width = _ssaContentWidth(texts)
	_ssaGrid.get_parent().rect_min_size.x = width
	# Each wrapping label's width, so it wraps its text at that width at once.
	for label in [_ssaIntro, _ssaWarning]:
		label.rect_min_size.x = width
		label.rect_size.x = width
	_ssaDialog.get_ok().disabled = false
	_ssaSellButton.disabled = false
	_ssaDialogFit()
	if not _ssaDialog.visible:
		_ssaDialog.popup_centered()
	_ssaDialogFitLater()
	_ssaDialog.get_cancel().grab_focus()

# The width of the dialog's contents: what the rows, the warning on one line and the line at the top on two lines need,
# and no more than _SSA_MAX_WIDTH_SHARE of the screen, where the texts wrap further.
func _ssaContentWidth(texts: Dictionary) -> float:
	var width = _ssaGrid.get_combined_minimum_size().x
	if texts.warning != "":
		width = max(width, _ssaLineWidth(_ssaWarning, texts.warning))
	width = max(width, _ssaTwoLinesWidth(_ssaIntro, texts.intro))
	return min(width, floor(get_viewport_rect().size.x * _SSA_MAX_WIDTH_SHARE))

# The width `label` needs to show `text` on one line. A Label wraps a line that reaches its width (Label.cpp
# regenerate_word_cache), so this is a little more: a space more, which also covers the kerning its spaces lose.
func _ssaLineWidth(label: Label, text: String) -> float:
	var font = label.get_font("font")
	var margins = label.get_stylebox("normal").get_minimum_size().x
	return ceil(font.get_string_size(text).x + font.get_string_size(" ").x + margins)

# The least width at which `label` shows `text` on two lines at most: the split between words whose longer line is the
# shortest.
func _ssaTwoLinesWidth(label: Label, text: String) -> float:
	var words = Array(text.split(" ", false))
	var best = _ssaLineWidth(label, text)
	for i in range(1, words.size()):
		var first = PoolStringArray(words.slice(0, i - 1)).join(" ")
		var second = PoolStringArray(words.slice(i, words.size() - 1)).join(" ")
		best = min(best, max(_ssaLineWidth(label, first), _ssaLineWidth(label, second)))
	return best

# The rows: each one's name on the left and its value on the right, a gap of _SSA_COLUMN_GAP between them, money coming
# in in the Fleet screen's colorPlus, money going out in its colorMinus.
func _ssaFillRows(rows: Array):
	for child in _ssaGrid.get_children():
		_ssaGrid.remove_child(child)
		child.queue_free()
	var font = _ssaProseFont if _ssaProseFont != null else _ssaGrid.get_font("font", "Label")
	_ssaGrid.add_constant_override("hseparation", int(ceil(font.get_height() * _SSA_COLUMN_GAP)))
	for row in rows:
		var left = Label.new()
		left.text = row.name
		var value = Label.new()
		value.text = row.value
		value.align = Label.ALIGN_RIGHT
		if row.sign != 0:
			value.modulate = _ssaColor(row.sign < 0)
		for label in [left, value]:
			if _ssaProseFont != null:
				label.add_font_override("font", _ssaProseFont)
			_ssaGrid.add_child(label)

# The Fleet screen's colour for money going out (`minus`) or coming in.
func _ssaColor(minus: bool) -> Color:
	var fleet = _ssaFleet()
	var property = _SSA_COLOR_MINUS if minus else _SSA_COLOR_PLUS
	if fleet != null and property in fleet and fleet.get(property) is Color:
		return fleet.get(property)
	return _SSA_COLOR_MINUS_FALLBACK if minus else _SSA_COLOR_PLUS_FALLBACK

# The dialog's texts for an offer, translated: the line at the top; the rows (name, value, and sign: 1 money coming
# in, -1 going out, 0 neither); the warning, "" when preparing takes no time.
func _ssaDescribe(offer: Dictionary) -> Dictionary:
	var plan = offer.plan
	return {
		"intro": tr(_SSA_TEXT_INTRO),
		"rows": [
			_ssaMoney(tr(_SSA_TEXT_SALE_NOW), offer.saleNow),
			_ssaMoney(tr(_SSA_TEXT_INSURANCE), -plan.insuranceCost),
			_ssaMoney(tr(_SSA_TEXT_CASH), -plan.cashCost),
			{"name": tr(_SSA_TEXT_TIME), "value": Tool.readableTimeSpan(plan.time), "sign": 0},
			_ssaMoney(tr(_SSA_TEXT_GAIN), offer.gain),
		],
		"warning": tr(_SSA_TEXT_WARNING) if plan.time > 0 else "",
	}

# A row of money, written as the Fleet screen writes a trade-in (Dealer.gd displayShip): coming in with +, going out
# with -, each in its colour; none (less than the whole E$ formatThousands writes) without either.
func _ssaMoney(label: String, amount: float) -> Dictionary:
	if int(abs(amount)) == 0:
		return {"name": label, "value": tr(_SSA_TEXT_ZERO) % CurrentGame.formatThousands(0), "sign": 0}
	var text = _SSA_TEXT_PLUS if amount > 0 else _SSA_TEXT_MINUS
	return {"name": label, "value": tr(text) % CurrentGame.formatThousands(abs(amount)), "sign": 1 if amount > 0 else -1}

# The dialog at its least size, centered on the screen.
func _ssaDialogFit():
	if not is_instance_valid(_ssaDialog):
		return
	_ssaDialog.rect_size = Vector2.ZERO
	_ssaDialog.rect_global_position = ((get_viewport_rect().size - _ssaDialog.rect_size) / 2).floor()

# Again once the containers have laid the labels out, which settles their wrapped heights.
func _ssaDialogFitLater():
	var tree = get_tree()
	for i in 2:
		yield(tree, "idle_frame")
	if is_instance_valid(_ssaDialog) and _ssaDialog.visible:
		_ssaDialogFit()

# Closed by Cancel, Prepare, Esc or a click outside: the focus goes back to Sell.
func _ssaDialogHidden():
	var sell = get_node_or_null(_SSA_SELL)
	if sell is Button and sell.is_visible_in_tree() and not sell.disabled:
		sell.grab_focus()

func _ssaClose():
	if is_instance_valid(_ssaDialog) and _ssaDialog.visible:
		_ssaDialog.hide()

# Sell sells the ship as it is, as the game's confirmation does.
func _ssaDialogAction(action):
	if action != _SSA_SELL_ACTION or _ssaSold:
		return
	_ssaSold = true
	_ssaClose()
	emit_signal("sell", ship)

# Prepare applies the offer as it is now, if it still reads as shown; otherwise shows the new one, or closes where
# there is none any more. The Fleet screen then lists its ships again: the prepared ship's entry is a new one.
func _ssaPreparePressed():
	var ok = _ssaDialog.get_ok()
	if ok.disabled:
		return
	ok.disabled = true
	_ssaSellButton.disabled = true
	var offer = _ssaOfferNow()
	if offer is GDScriptFunctionState:
		offer = yield(offer, "completed")
	# Closed meanwhile (Esc, or the Fleet screen closing): nothing is applied.
	if not is_instance_valid(_ssaDialog) or not _ssaDialog.visible:
		return
	if offer == null:
		_ssaClose()
		return
	if JSON.print(_ssaDescribe(offer)) != _ssaShown:
		_ssaShow(offer)
		return
	var applied = _ssaApply(offer)
	_ssaClose()
	var fleet = _ssaFleet()
	if applied and fleet != null:
		fleet.addShips()

# Applies the offer: the prepared config in place of the stored one (the instance built from it dropped, as
# CurrentGame.gd switchShipTo drops one), then the clicks paid and logged as doFixSystem does, the slots' refunds as
# Upgrades.gd buy does. False when the ship is no longer stored.
func _ssaApply(offer: Dictionary) -> bool:
	var gathered = offer.gathered
	var plan = offer.plan
	if not is_instance_valid(ship) or not Tool.claim(ship):
		return false
	var config = _ssaPrepared(gathered, plan)
	var transponder = ship.transponder
	var garage = CurrentGame.state.get("garage", [])
	var applied = false
	CurrentGame.shipMutex.lock()
	for i in garage.size():
		if garage[i] is Dictionary and garage[i].get("transponder") == transponder:
			for key in CurrentGame.ownedShipInstances.keys():
				if CurrentGame.ownedShipInstances[key] == ship:
					CurrentGame.removeOwnedShipByHash(key)
			garage[i] = config
			applied = true
			break
	CurrentGame.shipMutex.unlock()
	Tool.release(ship)
	if not applied:
		return false
	for id in plan.clicks:
		var system = gathered.systems[id]
		for click in plan.clicks[id]:
			CurrentGame.changeMoney(-system.fixPrice, true)
			CurrentGame.logEvent("LOG_EVENT_REPAIR")
			CurrentGame.giveXp(0, system.fixHours / 4.0, true, _SSA_MECHANIC)
			CurrentGame.logEvent("LOG_EVENT_REPAIR", {system.name: -system.fixPrice})
			Achivements.achive("FIX_PART")
	for slot in plan.strips:
		var item = gathered.slots[slot].item
		var price = -plan.refunds[slot]
		CurrentGame.changeMoney(-price)
		CurrentGame.logEvent("LOG_EVENT_UPGRADE", {"LOG_EVENT_DETAILS_COST": -price, item.system: -price})
	return true

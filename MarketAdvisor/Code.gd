extends "res://enceladus/MineralMarket.gd"

# The Mineral Market screen (enceladus/MineralMarket.gd), with MarketAdvisor's row at its bottom: a line of advice, a
# line comparing the parking minerals with the chart's average, and a Trade button that makes exactly the trades the
# advice names. It trades through the market's own sliders (enceladus/MineralSellSlider.gd), so each trade is the
# game's: the slider's price for the day, its limits, the minerals, the money and the trade log, as a drag would make
# it. The advice is Advisor.gd's, fed only what the player can see: today's prices, and the chart's history and
# forecast with the crew's geologist (enceladus/MineralPriceChart.gd). It keeps, with the save, the tonnes it bought
# to keep cash in (parked), so it can tell them from the ore brought back from dives. The station menu shows an alert
# mark on the Mineral Market entry while the advice is to trade now (StationMenu.gd, through _maAdviceChanged).
# Shift+Click on the Trade button opens MarketAdvisor's settings instead of trading, even while the button is disabled,
# and so does its gamepad twin on the highlighted button (a Shift badge inside it says so in its tooltip); closing them
# brings the market back.

signal _maAdviceChanged(tradeNow)

const MarketAdvisor = preload("res://MarketAdvisor/Settings.gd")
const _MA_ADVISOR = preload("res://MarketAdvisor/Advisor.gd")
const _MA_SETTINGS_UI = preload("res://MarketAdvisor/SettingsUI.gd")
# The badges' script: their look, and their tooltip as their only interaction.
const _MA_BADGE_SCRIPT = preload("res://MarketAdvisor/Badge.gd")
# The Shift badge's tooltip, a translation key of i18n/en.po: %s the Shift key, %s the mod's name. And the same while
# the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold, the mod's name.
const _MA_SETTINGS_TOOLTIP = "MARKETADVISOR_SETTINGS_TOOLTIP"
const _MA_SETTINGS_TOOLTIP_PAD = "MARKETADVISOR_SETTINGS_TOOLTIP_PAD"
# The game's tooltip node (with its sounds), as each of the market's slider rows instances it.
const _MA_GAME_TOOLTIPS = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"
# The Tuning screen among the station's right-hand screens (the market's siblings), whose description window the
# settings screen copies.
const _MA_TUNING = "Tuning"

# Each slider row's price chart (enceladus/MineralSellSlider.tscn), whose day, history and forecast the advice reads.
const _MA_CHART = "VBoxContainer/MarginContainer/Chart"
# The history points a mineral's average is taken from, spread evenly over the chart's history: the chart draws one a
# day, but the average barely moves with fewer, and each costs a price computation.
const _MA_AVERAGE_SAMPLES = 60
# Translation keys of i18n/en.po. The button; a mineral's tonnes (%s the tonnes, %s the mineral); the trades to make
# now (%s their tonnes); the cash they leave (%s); a trade to wait for (%s the mineral, %s the date); a parking
# mineral sold well below its average (%s); the parking minerals full (%s them, %s the tonnes); the floor out of reach
# and the floor reached (%s the cash reserve, with its range: Settings.gd floorText); the line comparing prices with the
# chart's average (%s the minerals), and each mineral in it (%s the mineral, %s the percentage).
const _MA_TRADE = "MARKETADVISOR_TRADE"
const _MA_TONNES = "MARKETADVISOR_TONNES"
const _MA_SELL = "MARKETADVISOR_SELL"
const _MA_BUY = "MARKETADVISOR_BUY"
const _MA_LEAVES = "MARKETADVISOR_LEAVES"
const _MA_WAIT_SELL = "MARKETADVISOR_WAIT_SELL"
const _MA_WAIT_BUY = "MARKETADVISOR_WAIT_BUY"
const _MA_WARN = "MARKETADVISOR_WARN"
const _MA_CAPPED = "MARKETADVISOR_CAPPED"
const _MA_SHORT = "MARKETADVISOR_SHORT"
const _MA_AT_FLOOR = "MARKETADVISOR_AT_FLOOR"
const _MA_VS_AVERAGE = "MARKETADVISOR_VS_AVERAGE"
const _MA_LOWER = "MARKETADVISOR_LOWER"
const _MA_HIGHER = "MARKETADVISOR_HIGHER"
const _MA_SAME = "MARKETADVISOR_SAME"
# The caption of the parked row in the header, a translation key of i18n/en.po.
const _MA_PARKED = "MARKETADVISOR_PARKED"
# The market's box under its header (enceladus/MineralMarket.tscn `Details`), and in it the margins around the list of
# sliders, whose sides the mod's row keeps.
const _MA_DETAILS = "Details"
const _MA_LIST_MARGIN = "MarginContainer"
# How faint the line comparing the prices with their averages is under the advice: a share of the full opacity.
const _MA_PRICES_OPACITY = 0.6
# The header (enceladus/HeaderWithMoney.tscn): the box at its right with your cash (`Money`, enceladus/InGameMoney.gd)
# and the game's own hidden row for your insurance (`Insurence`: a caption, `InsuranceLabel`, and a value, `Insurance`,
# with its `Pinger` sound), which the parked row copies.
const _MA_HEADER_BOX = _MA_DETAILS + "/HeaderWithMoney/VBoxContainer"
const _MA_HEADER_MONEY = "Money"
const _MA_HEADER_ROW = "Insurence"
const _MA_HEADER_CAPTION = "InsuranceLabel"
const _MA_HEADER_VALUE = "Insurance"
const _MA_HEADER_SOUND = "Insurance/Pinger"
# The header's title, a translation key the label translates itself, which the settings screen's header takes.
const _MA_HEADER_TITLE = _MA_DETAILS + "/HeaderWithMoney/MarketLabel"
# How your cash is written where the header has no `Money` label to read it from (InGameMoney.gd `format`).
const _MA_MONEY_FORMAT_FALLBACK = "%s E$"

var _maSettings = null
var _maParkedValue = null # the value of the parked row in the header
var _maMoneyFormat = _MA_MONEY_FORMAT_FALLBACK
var _maAdvice = null # the advice line
var _maPrices = null # the line comparing the parking minerals with the chart's average
var _maButton = null
var _maShiftBadge = null # the Shift badge inside the Trade button
var _maSettingsScreen = null # the settings screen, made on first use
var _maPlan = null
var _maAverage = {} # the chart's average E$/kg by mineral, for the chart's day _maAverageDay
var _maAverageDay = null
var _maQueued = false

# The base _ready runs first and builds the slider rows (`minerals`). The advice follows everything that changes it:
# a new day or hour (prices, the stay), the money (any purchase), the crew (the geologist's forecast), the settings,
# and the screen showing. It is worked out once per frame, after the game's own handlers. The station is built anew
# after every load and new game, so the settings loaded here are the save game's own.
func _ready():
	_maSettings = MarketAdvisor.shared()
	_maSettings.loadFromState()
	_maSettings.connect("settingsChanged", self, "_maQueue")
	for signalName in ["dayPassed", "hourPassed", "moneyChanged", "moneyOrInsuranceChanged", "employmentChanged"]:
		if CurrentGame.has_signal(signalName):
			CurrentGame.connect(signalName, self, "_maQueue")
	connect("visibility_changed", self, "_maQueue")
	_maBuildRow()
	_maBuildParked()
	_maQueue()

# The parked row, in the header right under your cash: a copy of the game's hidden insurance row, without its scripts
# and signals (so its value isn't the game's insurance display) and without its sound, shown. Its value is written as
# the `Money` label writes your cash. Both labels expand, so the gap between the caption and the value is the row's
# separation, widened by a space of the caption's font, so the value never touches the caption's colon. The gap
# is set once the row is in the tree, so the station's theme gives both the separation and the font.
func _maBuildParked():
	var box = get_node_or_null(_MA_HEADER_BOX)
	if box == null or not box.get_node_or_null(_MA_HEADER_ROW) is Control:
		return
	var row = box.get_node(_MA_HEADER_ROW).duplicate(DUPLICATE_USE_INSTANCING)
	row.name = "MarketAdvisorParked"
	row.visible = true
	var sound = row.get_node_or_null(_MA_HEADER_SOUND)
	if sound != null:
		sound.get_parent().remove_child(sound)
		sound.free()
	var caption = row.get_node_or_null(_MA_HEADER_CAPTION)
	var value = row.get_node_or_null(_MA_HEADER_VALUE)
	if not caption is Label or not value is Label:
		row.free()
		return
	caption.text = _MA_PARKED
	var money = box.get_node_or_null(_MA_HEADER_MONEY)
	box.add_child_below_node(money if money != null else box.get_node(_MA_HEADER_ROW), row)
	var space = int(ceil(caption.get_font("font").get_string_size(" ").x))
	row.add_constant_override("separation", row.get_constant("separation") + space)
	if money != null and "format" in money:
		_maMoneyFormat = money.format
	_maParkedValue = value

# The row under the sliders, inside the same side margins as their list, its nodes named so that a path reaches the
# Trade button (Details/MarketAdvisor/Row/Trade). Its two lines are in the small prose font the Shift badge is lettered
# in (Badge.gd SMALL_FONT_THEME), so they don't compete with the market's headings and the button; only the font
# changes, not the colours.
func _maBuildRow():
	var details = get_node_or_null(_MA_DETAILS)
	if not details is VBoxContainer:
		return
	var margin = MarginContainer.new()
	margin.name = "MarketAdvisor"
	var listMargin = details.get_node_or_null(_MA_LIST_MARGIN)
	if listMargin is MarginContainer:
		for side in ["left", "right"]:
			margin.add_constant_override("margin_" + side, listMargin.get_constant("margin_" + side))
	details.add_child(margin)
	var row = HBoxContainer.new()
	row.name = "Row"
	margin.add_child(row)
	var lines = VBoxContainer.new()
	lines.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lines)
	_maAdvice = Label.new()
	_maAdvice.autowrap = true
	_maAdvice.size_flags_horizontal = SIZE_EXPAND_FILL
	lines.add_child(_maAdvice)
	_maPrices = Label.new()
	_maPrices.autowrap = true
	_maPrices.size_flags_horizontal = SIZE_EXPAND_FILL
	_maPrices.modulate.a = _MA_PRICES_OPACITY
	lines.add_child(_maPrices)
	if ResourceLoader.exists(_MA_BADGE_SCRIPT.SMALL_FONT_THEME):
		var font = load(_MA_BADGE_SCRIPT.SMALL_FONT_THEME).get_font("font", "Label")
		for label in [_maAdvice, _maPrices]:
			label.add_font_override("font", font)
	_maButton = Button.new()
	_maButton.name = "Trade"
	_maButton.text = _MA_TRADE
	_maButton.size_flags_vertical = SIZE_SHRINK_CENTER
	_maButton.connect("pressed", self, "_maTrade")
	row.add_child(_maButton)
	# The settings open in the market's place among the station's right-hand screens
	# (enceladus/HidingMarginContainer.gd); without them, there is no badge and Shift+Click is a plain click.
	if get_parent() != null and get_parent().has_signal("hidefoka"):
		_maShiftBadge = _maMakeShiftBadge()
		_maFitBadge()
		_maAttachTooltips(row)
		_maButton.connect("gui_input", self, "_maOnTradeInput")

# The Shift badge (Badge.gd), in the Trade button's own frame and font colour (read once the button is in the tree,
# where the market's theme gives them), inside the button on the left, centred on it from top to bottom, as
# CombatSimulator's on the simulator's button: as far from the button's left edge as the button keeps its text from its
# edges (_maBadgeInset). A Button doesn't lay out its children, so the badge hangs from it directly, anchored to the
# middle of its left side, and grows right, up and down to its minimum size; the button makes room for it
# (_maFitBadge). On the button, it lets the mouse through: a click on it is the button's, Shift+Click too. It keeps its
# look while the button is disabled: Shift+Click still opens the settings then.
func _maMakeShiftBadge():
	var badge = _MA_BADGE_SCRIPT.new()
	badge.name = "MarketAdvisorShiftBadge"
	badge.dress(_maButton, OS.get_scancode_string(KEY_SHIFT), _MA_BADGE_SCRIPT.PAD_TEXT)
	var inset = _maBadgeInset()
	badge.set_anchors_preset(PRESET_CENTER_LEFT)
	badge.margin_left = inset
	badge.margin_right = inset
	badge.margin_top = 0
	badge.margin_bottom = 0
	badge.grow_horizontal = GROW_DIRECTION_END
	badge.grow_vertical = GROW_DIRECTION_BOTH
	badge.mouse_filter = MOUSE_FILTER_PASS
	_maButton.add_child(badge)
	_maButton.align = Button.ALIGN_RIGHT
	badge.connect("minimum_size_changed", self, "_maFitBadge")
	_maButton.connect("minimum_size_changed", self, "_maFitBadge")
	return badge

# How far the Trade button keeps its text from its edges (its normal stylebox's left margin): the badge's distance from
# its left edge, and the gap between the badge and the text.
func _maBadgeInset() -> float:
	var style = _maButton.get_stylebox("normal")
	return style.get_margin(MARGIN_LEFT) if style != null else 0.0

# The Trade button as wide as its text needs plus the badge and the gap after it, its text against its right margin, so
# the badge never covers it: again whenever either changes size (the badge's text follows the control scheme, the
# button's the language). The button's own minimum leaves out the width set here, so setting it settles at once.
func _maFitBadge():
	if _maShiftBadge == null or not is_instance_valid(_maShiftBadge):
		return
	var width = ceil(_maButton.get_minimum_size().x + _maShiftBadge.get_combined_minimum_size().x + _maBadgeInset())
	if _maButton.rect_min_size.x != width:
		_maButton.rect_min_size.x = width

# The badge's tooltip is shown by the game's own tooltip node, one of the row's own, as each slider row has its own
# (enceladus/MineralSellSlider.tscn): on hover, and with a gamepad, which shows no hover, while the Trade button is
# highlighted. The node also takes the Trade button in, with the hover and focus sounds of the sliders above it; the
# button's hint_tooltip stays empty, so it shows none.
func _maAttachTooltips(row):
	if not ResourceLoader.exists(_MA_GAME_TOOLTIPS):
		return
	var tooltips = load(_MA_GAME_TOOLTIPS).instance()
	tooltips.name = "PlaySoundsOnTheseButtons"
	row.add_child(tooltips)
	_maShiftBadge.attachTooltip(tooltips, _maButton)
	_maShiftBadge.setShiftTooltips(_MA_SETTINGS_TOOLTIP, _MA_SETTINGS_TOOLTIP_PAD, _maSettings.modName())

# Shift+Click on the Trade button opens the settings instead of trading, and so does its gamepad twin on the highlighted
# button (Badge.gd isPadShortcut), whether the button is disabled or not. A click's gui_input signal comes before the
# button's own _gui_input, which is all a disabled button ignores, and accepting the press there keeps an enabled button
# from pressing; Badge.gd's PAD_BUTTON does nothing to a button. A disabled button keeps its focus, so the D-pad still
# reaches it (setKidsFocus).
func _maOnTradeInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if shiftClick or _MA_BADGE_SCRIPT.isPadShortcut(event):
		_maButton.accept_event()
		_maOpenSettings()

# As a menu entry opens its screen: the other screens, this one too, hide (`hidefoka`), and the settings screen shows in
# the market's place, titled as the market.
func _maOpenSettings():
	var screens = get_parent()
	if _maSettingsScreen == null:
		var title = get_node_or_null(_MA_HEADER_TITLE)
		_maSettingsScreen = _MA_SETTINGS_UI.new()
		_maSettingsScreen.setup(self, screens.get_node_or_null(_MA_TUNING), title.text if title is Label else "")
		screens.add_child(_maSettingsScreen)
		_maSettingsScreen.connect("closed", self, "_maOnSettingsClosed")
	screens.hidefoka()
	_maSettingsScreen.show()

# Esc or the controller's back button closed the settings: the market comes back, the Trade button highlighted. As
# _on_MineralMarket_pressed shows it, but keeping its lastFocus, the menu entry it was opened from, where its own Esc
# goes back to.
func _maOnSettingsClosed():
	$Shower.play("show")
	setKidsFocus()
	Tool.deferCallWhenIdle(_maButton, "grab_focus")

# The sliders' focus chain (setKidsFocus, set when the screen opens) goes on down to the Trade button.
func setKidsFocus():
	.setKidsFocus()
	if _maButton != null and not minerals.empty():
		var last = minerals[minerals.size() - 1].slider
		last.focus_neighbour_bottom = _maButton.get_path()
		_maButton.focus_neighbour_top = last.get_path()

func _maQueue(_arg = null):
	if not _maQueued:
		_maQueued = true
		call_deferred("_maRefresh")

# Where the advice comes to no trade but other parked tonnes (ore of a parking mineral that would be sold and bought
# back the same day, so it nets to nothing), those are kept at once, and the advice worked out again from them.
func _maRefresh():
	_maQueued = false
	if minerals.empty():
		return
	_maPlan = _MA_ADVISOR.plan(_maInput())
	if _maPlan.now.empty() and _maPlan.parked.hash() != _maSettings.getParked().hash():
		_maSettings.setParked(_maClampedParked(_maPlan.parked))
		_maQueue()
	if _maParkedValue != null:
		_maParkedValue.text = _maMoneyFormat % CurrentGame.formatThousands(int(round(_maParkedWorth())))
	if _maButton != null:
		_maAdvice.text = _maAdviceText(_maPlan)
		_maPrices.text = _maPricesText()
		_maButton.disabled = _maPlan.now.empty()
	emit_signal("_maAdviceChanged", not _maPlan.now.empty())

# The Trade button: the trades of the advice, worked out again now, each through its mineral's slider. Before each, the
# slider is brought up to date as the game brings it when the screen shows and when the money changes:
# updateMineralCount puts it at the tonnes held, and _onMoneyUpdated sets how far it can go. The game emits
# moneyChanged a frame after the money changes (CurrentGame.gd _process), and each trade changes what the next can
# spend. Moving it to the tonnes held trades nothing (updateMineralCount leaves it alone at 0 t); then to the
# trade's tonnes. The parked tonnes the advice ends with are kept, down to what the sliders left.
func _maTrade():
	_maRefresh()
	for trade in _maPlan.now:
		var row = _maSlider(trade.mineral)
		if row == null:
			continue
		row.updateMineralCount()
		row._onMoneyUpdated(CurrentGame.getMoney())
		row.slider.value = trade.from
		row.slider.value = trade.to
	_maSettings.setParked(_maClampedParked(_maPlan.parked))
	_maRefresh()

# What the parked tonnes would sell for today, at each slider's price for the day.
func _maParkedWorth() -> float:
	var parked = _maSettings.getParked()
	var worth = 0.0
	if parked == null:
		return worth
	for row in minerals:
		worth += parked.get(row.mineral, 0) * row.multiplier * row.price
	return worth

# `tonnes` by mineral, none above what is held: a sale with a slider by hand takes parked tonnes too.
func _maClampedParked(tonnes: Dictionary) -> Dictionary:
	var kg = minerals[0].multiplier
	var out = {}
	for m in tonnes:
		out[m] = int(min(tonnes[m], floor(CurrentGame.getMinerals(m) / kg)))
	return out

func _maSlider(mineral):
	for row in minerals:
		if row.mineral == mineral:
			return row
	return null

# What the player sees: cash, whole tonnes held (the kilograms after the dot stay, as the slider leaves them), each
# slider's price for the day, the chart's average and its forecast for the days left in the stay; and the parked
# tonnes. A save without a record of them (made before the mod, or new) takes what it holds of the parking minerals
# as parked, once, so what was bought before isn't sold as ore.
func _maInput() -> Dictionary:
	var first = minerals[0]
	var kg = first.multiplier
	var chart = first.get_node_or_null(_MA_CHART)
	var days = _maDaysLeft(chart)
	var held = {}
	var price = {}
	var future = {}
	for row in minerals:
		held[row.mineral] = int(floor(CurrentGame.getMinerals(row.mineral) / kg))
		price[row.mineral] = row.price
		future[row.mineral] = _maForecast(row, days)
	var names = _maNames()
	var parking = _maSettings.parkingMinerals(names)
	var parked = _maSettings.getParked()
	if parked == null:
		parked = {}
		for m in parking:
			parked[m] = held[m]
		_maSettings.setParked(parked)
	else:
		var clamped = _maClampedParked(parked)
		if clamped.hash() != parked.hash():
			_maSettings.setParked(clamped)
		parked = clamped
	var bounds = _maSettings.floorRange()
	return {
		"cash": CurrentGame.getMoney(),
		"floor": _maSettings.floorCash(),
		"low": bounds[0],
		"high": bounds[1],
		"parking": parking,
		"sellOre": _maSettings.getValue("sellOre"),
		"minerals": names,
		"held": held,
		"parked": parked,
		"price": price,
		"average": _maAverages(parking, chart),
		"future": future,
		"maxTonnes": first.maxOre,
		"kgPerTonne": kg,
	}

# The minerals of the market's sliders, in its order.
func _maNames() -> Array:
	var names = []
	for row in minerals:
		names.append(row.mineral)
	return names

# The days left to trade, in the chart's days: until the ship's maintenance ends (repairs and new equipment set it,
# CurrentGame.addShipMaintanenceTime, and the ship can't dive before). None: trade now.
func _maDaysLeft(chart) -> int:
	if chart == null:
		return 0
	var day = chart.time * 3600
	var now = CurrentGame.getInGameTimestamp()
	return int(max(0, floor(CurrentGame.getShipMaintanenceTime() / day) - floor(now / day)))

# The chart's forecast for the next `days` days, as MineralPriceChart.gd updateChart draws it: a point a day after the
# day the chart rounds to, the true price blended into the price at the mirrored time by the crew's prediction error.
func _maForecast(row, days: int) -> Array:
	var points = []
	var chart = row.get_node_or_null(_MA_CHART)
	if chart == null:
		return points
	var step = chart.time * 3600
	var chartTime = chart.getRoundedTime()
	for k in range(1, int(min(days, chart.lookAhead / chart.time)) + 1):
		var when = chartTime + k * step
		var error = CurrentGame.getMineralPricePredictionError(chartTime - when)
		var act = CurrentGame.getMineralMarketPricePerKgAt(row.mineral, when)
		var fake = CurrentGame.getMineralMarketPricePerKgAt(row.mineral, - when)
		points.append([when, lerp(act, fake, clamp(error, 0, 1))])
	return points

# Each parking mineral's average over the history the chart shows, worked out once per chart day.
func _maAverages(parking: Array, chart) -> Dictionary:
	if chart == null:
		return {}
	var today = chart.getRoundedTime()
	if today != _maAverageDay:
		_maAverage = {}
		_maAverageDay = today
	for m in parking:
		if not m in _maAverage:
			_maAverage[m] = _maHistoryAverage(m, chart, today)
	return _maAverage

# The chart's history: `steps` points a day apart, the last lookAhead hours of them forecast, the rest the past up to
# the chart's day (MineralPriceChart.gd updateChart).
func _maHistoryAverage(mineral: String, chart, today: float) -> float:
	var step = chart.time * 3600
	var points = int(chart.steps - chart.lookAhead / chart.time)
	var samples = int(min(_MA_AVERAGE_SAMPLES, points))
	if samples <= 0:
		return 0.0
	var sum = 0.0
	for i in range(samples):
		sum += CurrentGame.getMineralMarketPricePerKgAt(mineral, today - int(i * points / samples) * step)
	return sum / samples

func _maAdviceText(plan: Dictionary) -> String:
	var parts = []
	var sold = []
	var bought = []
	for trade in plan.now:
		var item = tr(_MA_TONNES) % [CurrentGame.formatThousands(int(abs(trade.to - trade.from))), trade.mineral]
		if trade.to < trade.from:
			sold.append(item)
		else:
			bought.append(item)
	if not sold.empty():
		parts.append(tr(_MA_SELL) % PoolStringArray(sold).join(", "))
	if not bought.empty():
		parts.append(tr(_MA_BUY) % PoolStringArray(bought).join(", "))
	if not plan.now.empty():
		parts.append(tr(_MA_LEAVES) % CurrentGame.formatThousands(int(round(plan.cashAfter))))
	for wait in plan.waits:
		var key = _MA_WAIT_SELL if wait.sell else _MA_WAIT_BUY
		parts.append(tr(key) % [wait.mineral, CurrentGame.dateToString(wait.when)])
	for mineral in plan.warnings:
		parts.append(tr(_MA_WARN) % mineral)
	if plan.capped:
		parts.append(tr(_MA_CAPPED) % [PoolStringArray(_maSettings.parkingMinerals(_maNames())).join(", "),
				CurrentGame.formatThousands(minerals[0].maxOre)])
	if plan.short:
		parts.append(tr(_MA_SHORT) % _maSettings.floorText())
	if parts.empty():
		parts.append(tr(_MA_AT_FLOOR) % _maSettings.floorText())
	return PoolStringArray(parts).join(" ")

func _maPricesText() -> String:
	var items = []
	for m in _maSettings.parkingMinerals(_maNames()):
		var row = _maSlider(m)
		var average = _maAverage.get(m, 0.0)
		if row == null or average <= 0:
			continue
		var percent = int(round(100.0 * (row.price / average - 1.0)))
		if percent < 0:
			items.append(tr(_MA_LOWER) % [m, -percent])
		elif percent > 0:
			items.append(tr(_MA_HIGHER) % [m, percent])
		else:
			items.append(tr(_MA_SAME) % m)
	if items.empty():
		return ""
	return tr(_MA_VS_AVERAGE) % PoolStringArray(items).join(", ")

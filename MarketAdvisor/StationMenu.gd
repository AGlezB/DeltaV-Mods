extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Mineral Market entry opens MarketAdvisor's settings with
# Shift+Click, the way DiveSkipTransit's dive entry opens its own (the entry's tooltip says so; a plain click still
# opens the market), and shows an alert mark (the " (*)" after its text) while the market's advice is to trade now
# (Code.gd _maAdviceChanged). Its Services entry shows an alert mark while a service whose switch is on can be bought,
# as the game's own row for that service decides.

# The settings: their model, shared with the settings screen and the market screen.
const MarketAdvisor = preload("res://MarketAdvisor/Settings.gd")
const _MA_SETTINGS_UI = preload("res://MarketAdvisor/SettingsUI.gd")
# Translation keys of i18n/en.po. An entry's text with its alert mark, whose %s is the entry's own text in the game's
# language; and the Mineral Market entry's tooltip, whose first %s is the key to hold while clicking, the second the
# mod's name.
const _MA_ALERT = "MARKETADVISOR_ALERT"
const _MA_SETTINGS_TOOLTIP = "MARKETADVISOR_SETTINGS_TOOLTIP"
# The rows of the Services screen (enceladus/Services.tscn: enceladus/ServiceUI.gd, one per service), from the screens
# container.
const _MA_SERVICE_ROWS = "Services/VB/MarginContainer/ScrollContainer/MarginContainer/Items"

var _maMarketButton = null
var _maMarketKey = ""
var _maServicesButton = null
var _maServicesKey = ""
var _maScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _maMarket = null # the station's Mineral Market screen: its advice, and the frame the settings screen copies
var _maTuning = null # the station's Tuning screen, whose description window the settings screen copies
var _maSettingsScreen = null # the settings screen, made on first use
var _maSettings = null
var _maTradeNow = false
var _maServiceDue = false
var _maQueued = false

# The menu's `MineralMarket` button has the game's FocusOnThisButton.gd, and `Services` no script; their texts are
# translation keys, which the buttons translate themselves. Enceladus.tscn: the screens container's hideOnFocusOf is
# "../../HBoxContainer/Options", this menu. The menu is ready before the screens (it comes first in the station's
# scene), so the market's advice comes by its signal and the services are checked once all is built. Without the
# container or the market screen there are no settings or alert mark on the market entry, and Shift+Click is a plain
# click.
func _ready():
	var market = get_node_or_null("MineralMarket")
	if not market is Button:
		return
	_maMarketButton = market
	_maMarketKey = market.text
	var services = get_node_or_null("Services")
	if services is Button:
		_maServicesButton = services
		_maServicesKey = services.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_maSettings = MarketAdvisor.shared()
	_maSettings.loadFromState()
	_maSettings.connect("settingsChanged", self, "_maQueueServices")
	for signalName in ["dayPassed", "hourPassed", "moneyChanged", "moneyOrInsuranceChanged", "employmentChanged"]:
		if CurrentGame.has_signal(signalName):
			CurrentGame.connect(signalName, self, "_maQueueServices")
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if screens != null and screens.has_signal("hidefoka"):
		_maScreens = screens
		var screen = screens.get_node_or_null("MineralMarket")
		if screen is Control and screen.has_signal("_maAdviceChanged"):
			_maMarket = screen
			_maMarket.connect("_maAdviceChanged", self, "_maOnAdvice")
			_maTuning = screens.get_node_or_null("Tuning")
			_maMarketButton.connect("gui_input", self, "_maOnMarketInput")
	_maQueueServices()
	_maUpdate()

# An entry with its alert mark and the tooltip hold translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _maMarketButton != null:
		_maUpdate()

func _maOnAdvice(tradeNow):
	_maTradeNow = tradeNow
	_maUpdate()

# The tooltip only where Shift+Click opens the settings. The game's tooltip node (the menu's PlaySoundsOnTheseButtons,
# menu/sfx/PlaySoundsOnTheseButtons.gd) takes it over and reads it again on every hover, so setting it again is enough.
func _maUpdate():
	_maMarketButton.text = tr(_MA_ALERT) % tr(_maMarketKey) if _maTradeNow else _maMarketKey
	if _maServicesButton != null:
		_maServicesButton.text = tr(_MA_ALERT) % tr(_maServicesKey) if _maServiceDue else _maServicesKey
	if _maMarket != null:
		_maMarketButton.hint_tooltip = tr(_MA_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), _maSettings.modName()]

func _maQueueServices(_arg = null):
	if not _maQueued:
		_maQueued = true
		call_deferred("_maCheckServices")

# The game's own rows decide (enceladus/ServiceUI.gd checkPrice: the cooldown, the price against the money, a story
# condition), each run again here so it is current; a row hidden or with its Buy button disabled can't be bought.
func _maCheckServices():
	_maQueued = false
	_maServiceDue = false
	var rows = _maScreens.get_node_or_null(_MA_SERVICE_ROWS) if _maScreens != null else null
	if rows != null:
		var wanted = []
		for key in MarketAdvisor.SETTINGS:
			var service = MarketAdvisor.SETTINGS[key].get("service", "")
			if service != "" and _maSettings.getValue(key):
				wanted.append(service)
		for row in rows.get_children():
			if not ("serviceName" in row and "buyButton" in row and row.has_method("checkPrice")):
				continue
			if not row.serviceName in wanted or row.buyButton == null:
				continue
			row.checkPrice()
			if row.visible and not row.buyButton.disabled:
				_maServiceDue = true
	_maUpdate()

# Shift+Click opens the settings instead of the market. The gui_input signal comes before the button's own _gui_input,
# and accepting the press there keeps the button from pressing.
func _maOnMarketInput(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift \
			and not _maMarketButton.disabled:
		_maMarketButton.accept_event()
		_maOpenSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus.
func _maOpenSettings():
	if _maSettingsScreen == null:
		_maSettingsScreen = _MA_SETTINGS_UI.new()
		_maSettingsScreen.setup(_maMarket, _maTuning, _maMarketKey)
		_maScreens.add_child(_maSettingsScreen)
	_maScreens.hidefoka()
	_maSettingsScreen.show()

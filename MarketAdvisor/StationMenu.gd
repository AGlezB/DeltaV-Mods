extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Mineral Market entry shows an alert mark (the " (*)" after its
# text) while the market's advice is to trade now (Code.gd _maAdviceChanged), unless the player switched the mark off
# (the alertMark setting). That text is all the mod changes in the menu: the settings open from the market's own Trade
# button (Code.gd).

# The settings: their model, shared with the settings screen and the market screen, which loads the save's values.
const MarketAdvisor = preload("res://MarketAdvisor/Settings.gd")
# The entry's text with its alert mark, a translation key of i18n/en.po, whose %s is the entry's own text in the game's
# language.
const _MA_ALERT = "MARKETADVISOR_ALERT"
# The station's Mineral Market screen, among its right-hand screens (enceladus/Enceladus.tscn: the screens container's
# hideOnFocusOf is "../../HBoxContainer/Options", this menu).
const _MA_MARKET_SCREEN = "../../CanvasLayer/MarginContainer/MineralMarket"

var _maMarketButton = null
var _maMarketKey = ""
var _maSettings = null
var _maTradeNow = false

# The menu's `MineralMarket` button has the game's FocusOnThisButton.gd; its text is a translation key, which the
# button translates itself. The menu is ready before the screens (it comes first in the station's scene), so the
# market's advice comes by its signal, and the save's settings with their change signal. Without the market screen
# there is no alert mark.
func _ready():
	var market = get_node_or_null("MineralMarket")
	if not market is Button:
		return
	_maMarketButton = market
	_maMarketKey = market.text
	_maSettings = MarketAdvisor.shared()
	_maSettings.connect("settingsChanged", self, "_maUpdate")
	var screen = get_node_or_null(_MA_MARKET_SCREEN)
	if screen is Control and screen.has_signal("_maAdviceChanged"):
		screen.connect("_maAdviceChanged", self, "_maOnAdvice")
	_maUpdate()

# The entry with its alert mark holds translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _maMarketButton != null:
		_maUpdate()

func _maOnAdvice(tradeNow):
	_maTradeNow = tradeNow
	_maUpdate()

func _maUpdate():
	var marked = _maTradeNow and _maSettings.getValue("alertMark")
	_maMarketButton.text = tr(_MA_ALERT) % tr(_maMarketKey) if marked else _maMarketKey

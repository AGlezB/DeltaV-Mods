extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Mineral Market entry opens MarketAdvisor's settings with
# Shift+Click, the way DiveSkipTransit's dive entry opens its own (the entry's tooltip says so; a plain click still
# opens the market), and shows an alert mark (the " (*)" after its text) while the market's advice is to trade now
# (Code.gd _maAdviceChanged).

# The settings: their model, shared with the settings screen and the market screen.
const MarketAdvisor = preload("res://MarketAdvisor/Settings.gd")
const _MA_SETTINGS_UI = preload("res://MarketAdvisor/SettingsUI.gd")
# Translation keys of i18n/en.po. The entry's text with its alert mark, whose %s is the entry's own text in the game's
# language; and the entry's tooltip, whose first %s is the key to hold while clicking, the second the mod's name.
const _MA_ALERT = "MARKETADVISOR_ALERT"
const _MA_SETTINGS_TOOLTIP = "MARKETADVISOR_SETTINGS_TOOLTIP"

var _maMarketButton = null
var _maMarketKey = ""
var _maScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _maMarket = null # the station's Mineral Market screen: its advice, and the frame the settings screen copies
var _maTuning = null # the station's Tuning screen, whose description window the settings screen copies
var _maSettingsScreen = null # the settings screen, made on first use
var _maSettings = null
var _maTradeNow = false

# The menu's `MineralMarket` button has the game's FocusOnThisButton.gd; its text is a translation key, which the
# button translates itself. Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options",
# this menu. The menu is ready before the screens (it comes first in the station's scene), so the market's advice comes
# by its signal. Without the container or the market screen there are no settings or alert mark, and Shift+Click is a
# plain click.
func _ready():
	var market = get_node_or_null("MineralMarket")
	if not market is Button:
		return
	_maMarketButton = market
	_maMarketKey = market.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_maSettings = MarketAdvisor.shared()
	_maSettings.loadFromState()
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if screens != null and screens.has_signal("hidefoka"):
		_maScreens = screens
		var screen = screens.get_node_or_null("MineralMarket")
		if screen is Control and screen.has_signal("_maAdviceChanged"):
			_maMarket = screen
			_maMarket.connect("_maAdviceChanged", self, "_maOnAdvice")
			_maTuning = screens.get_node_or_null("Tuning")
			_maMarketButton.connect("gui_input", self, "_maOnMarketInput")
	_maUpdate()

# The entry with its alert mark and the tooltip hold translated text, which the button can't translate again.
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
	if _maMarket != null:
		_maMarketButton.hint_tooltip = tr(_MA_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), _maSettings.modName()]

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

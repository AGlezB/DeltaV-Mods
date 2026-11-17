extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Dealer entry shows the mod's mark while the dealer has a ship the
# settings model's rule counts (newShips: a ship of a model switched on, come since the Dealer screen was last open),
# and opens the mod's settings with Shift+Click, the way CrewCheapHireNotifier's Crew entry does: the entry's tooltip
# says so, and a plain click still opens the Dealer screen.

# The settings (which ship models are watched) and the dealer's stock: their model, shared with the settings screen and
# the Dealer screen.
const DealerNotifier = preload("res://DealerNotifier/Settings.gd")
const _DN_SETTINGS_UI = preload("res://DealerNotifier/SettingsUI.gd")

# Translation keys of i18n/en.po. The Dealer entry's text while a watched ship is new, whose %s is the entry's own text
# in the game's language; and its tooltip, whose first %s is the key to hold while clicking, the second the mod's name.
const _DN_ALERT = "DEALERNOTIFIER_ALERT"
const _DN_SETTINGS_TOOLTIP = "DEALERNOTIFIER_SETTINGS_TOOLTIP"

var _dnMarketButton = null
var _dnMarketKey = ""
var _dnSettingsScreen = null # the settings screen, made on first use
var _dnScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _dnDealer = null # the station's Dealer screen, whose frame and place the settings screen copies
var _dnSettings = null

# The menu's `ShipMarket` button (Dealer) has no script of its own; its text is a translation key, which the button
# translates itself. Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options", this menu.
# Without the container or its Dealer screen there are no settings, and Shift+Click is a plain click.
func _ready():
	var button = get_node_or_null("ShipMarket")
	if not button is Button:
		return
	_dnMarketButton = button
	_dnMarketKey = button.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_dnSettings = DealerNotifier.shared()
	_dnSettings.loadFromState()
	_dnSettings.connect("settingsChanged", self, "_dnUpdate")
	_dnSettings.connect("stockChanged", self, "_dnUpdate")
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if screens != null and screens.has_signal("hidefoka") and screens.get_node_or_null("Dealer") is Control:
		_dnScreens = screens
		_dnDealer = screens.get_node("Dealer")
		_dnMarketButton.connect("gui_input", self, "_dnOnMarketInput")
	_dnUpdate()

# A marked entry and the tooltip hold translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _dnMarketButton != null:
		_dnUpdate()

# The tooltip only where Shift+Click opens the settings. The game's tooltip node (the menu's PlaySoundsOnTheseButtons,
# menu/sfx/PlaySoundsOnTheseButtons.gd) takes it over and reads it again on every hover, so setting it again is enough.
func _dnUpdate():
	if _dnSettings.newShips().empty():
		_dnMarketButton.text = _dnMarketKey
	else:
		_dnMarketButton.text = tr(_DN_ALERT) % tr(_dnMarketKey)
	if _dnScreens != null:
		_dnMarketButton.hint_tooltip = tr(_DN_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), _dnSettings.modName()]

# Shift+Click opens the settings instead of the Dealer screen. The gui_input signal comes before the button's own
# _gui_input, and accepting the press there keeps the button from pressing.
func _dnOnMarketInput(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift \
			and not _dnMarketButton.disabled:
		_dnMarketButton.accept_event()
		_dnOpenSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus.
func _dnOpenSettings():
	if _dnSettingsScreen == null:
		_dnSettingsScreen = _DN_SETTINGS_UI.new()
		_dnSettingsScreen.setup(_dnDealer, _dnMarketKey)
		_dnScreens.add_child(_dnSettingsScreen)
	_dnScreens.hidefoka()
	_dnSettingsScreen.show()

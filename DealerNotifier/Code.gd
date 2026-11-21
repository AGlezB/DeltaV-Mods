extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Dealer entry shows the mod's mark while the dealer has a ship the
# settings model's rule counts (newShips: a ship of a model switched on, come since the Dealer screen was last open),
# and opens the mod's settings with Shift+Click, the way CrewCheapHireNotifier's Crew entry does: a Shift badge beside
# the entry says so in its tooltip, and a plain click on the entry still opens the Dealer screen.

# The settings (which ship models are watched) and the dealer's stock: their model, shared with the settings screen and
# the Dealer screen.
const DealerNotifier = preload("res://DealerNotifier/Settings.gd")
const _DN_SETTINGS_UI = preload("res://DealerNotifier/SettingsUI.gd")

# Translation keys of i18n/en.po. The Dealer entry's text while a watched ship is new, whose %s is the entry's own text
# in the game's language; and the Shift badge's tooltip, whose first %s is the key to hold while clicking the entry,
# the second the mod's name.
const _DN_ALERT = "DEALERNOTIFIER_ALERT"
const _DN_SETTINGS_TOOLTIP = "DEALERNOTIFIER_SETTINGS_TOOLTIP"
# The same while the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold,
# the mod's name.
const _DN_SETTINGS_TOOLTIP_PAD = "DEALERNOTIFIER_SETTINGS_TOOLTIP_PAD"
# The station's Dealer screen among its right-hand screens (enceladus/Enceladus.tscn), whose frame and place the
# settings screen copies.
const _DN_DEALER_SCREEN = "Dealer"
# The badges' script: their look, and their tooltip as their only interaction.
const _DN_BADGE_SCRIPT = preload("res://DealerNotifier/Badge.gd")

var _dnMarketButton = null
var _dnMarketKey = ""
var _dnShiftBadge = null # the Shift badge beside the Dealer entry
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
	var dealer = screens.get_node_or_null(_DN_DEALER_SCREEN) if screens != null else null
	if screens != null and screens.has_signal("hidefoka") and dealer is Control:
		_dnScreens = screens
		_dnDealer = dealer
		_dnMarketButton.connect("gui_input", self, "_dnOnMarketInput")
		_dnShiftBadge = _dnMakeShiftBadge(_dnMarketButton)
	_dnUpdate()

# A marked entry holds translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _dnMarketButton != null:
		_dnUpdate()

func _dnUpdate():
	if _dnSettings.newShips().empty():
		_dnMarketButton.text = _dnMarketKey
	else:
		_dnMarketButton.text = tr(_DN_ALERT) % tr(_dnMarketKey)

# The Shift badge (Badge.gd), in the entry's own frame and font colour, to the right of the entry, the menu's gap
# between entries away (Badge.gd hangBeside). Its tooltip, only where Shift+Click opens the settings, is shown by the
# menu's PlaySoundsOnTheseButtons.
func _dnMakeShiftBadge(button):
	var badge = _DN_BADGE_SCRIPT.new()
	badge.dress(button, OS.get_scancode_string(KEY_SHIFT), _DN_BADGE_SCRIPT.PAD_TEXT)
	badge.hangBeside(button, get_constant("separation"))
	badge.attachTooltip(get_node_or_null("PlaySoundsOnTheseButtons"))
	badge.setShiftTooltips(_DN_SETTINGS_TOOLTIP, _DN_SETTINGS_TOOLTIP_PAD, _dnSettings.modName())
	return badge

# Shift+Click opens the settings instead of the Dealer screen, and so does its gamepad twin on the highlighted entry
# (Badge.gd isPadShortcut). A click's gui_input signal comes before the button's own _gui_input, and accepting the
# press there keeps the button from pressing; the gamepad's X does nothing to a button.
func _dnOnMarketInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _DN_BADGE_SCRIPT.isPadShortcut(event)) and not _dnMarketButton.disabled:
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

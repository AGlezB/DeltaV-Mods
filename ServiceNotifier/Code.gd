extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). Its Services entry shows an alert mark (the " (*)" after its text)
# while a service whose switch is on can be bought, as the game's own row for that service decides, and opens the mod's
# settings with Shift+Click, the way DealerNotifier's Dealer entry opens its own: a Shift badge beside the entry says
# so in its tooltip, and a plain click on the entry still opens the Services screen. The services watched are those
# that can't be bought again right after being bought (Settings.gd kindOf): those with a cooldown, and those that pay a
# faction compensation.

# The settings: their model, shared with the settings screen.
const ServiceNotifier = preload("res://ServiceNotifier/Settings.gd")
const _SN_SETTINGS_UI = preload("res://ServiceNotifier/SettingsUI.gd")
# Translation keys of i18n/en.po. The entry's text with its alert mark, whose %s is the entry's own text in the game's
# language; and the Shift badge's tooltip, whose first %s is the key to hold while clicking the entry, the second the
# mod's name.
const _SN_ALERT = "SERVICENOTIFIER_ALERT"
const _SN_SETTINGS_TOOLTIP = "SERVICENOTIFIER_SETTINGS_TOOLTIP"
# The same while the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold,
# the mod's name.
const _SN_SETTINGS_TOOLTIP_PAD = "SERVICENOTIFIER_SETTINGS_TOOLTIP_PAD"
# The Services screen (enceladus/Services.tscn) in the screens container, and the box of its rows (enceladus/ServiceUI.gd,
# one per service) in it.
const _SN_SERVICES_SCREEN = "Services"
# The menu's Services entry (enceladus/EnceladusMenu.tscn), and the Tuning screen among the station's screens, whose
# description window the settings screen copies.
const _SN_SERVICES_ENTRY = "Services"
const _SN_TUNING_SCREEN = "Tuning"
const _SN_SERVICE_ROWS = "VB/MarginContainer/ScrollContainer/MarginContainer/Items"
# The badges' script: their look, and their tooltip as their only interaction.
const _SN_BADGE_SCRIPT = preload("res://ServiceNotifier/Badge.gd")

var _snButton = null
var _snKey = ""
var _snShiftBadge = null # the Shift badge beside the Services entry
var _snScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _snServices = null # the station's Services screen: its rows, and the frame the settings screen copies
var _snTuning = null # the station's Tuning screen, whose description window the settings screen copies
var _snSettingsScreen = null # the settings screen, made on first use
var _snSettings = null
var _snDue = false
var _snQueued = false

# The menu's `Services` button has no script of its own; its text is a translation key, which the button translates
# itself. Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options", this menu. The menu is
# ready before the screens (it comes first in the station's scene), so the services are checked once all is built.
# Without the container or its Services screen there are no settings and no alert mark, and Shift+Click is a plain
# click.
func _ready():
	var button = get_node_or_null(_SN_SERVICES_ENTRY)
	if not button is Button:
		return
	_snButton = button
	_snKey = button.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_snSettings = ServiceNotifier.shared()
	_snSettings.loadFromState()
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if screens != null and screens.has_signal("hidefoka") and screens.get_node_or_null(_SN_SERVICES_SCREEN) is Control:
		_snScreens = screens
		_snServices = screens.get_node(_SN_SERVICES_SCREEN)
		_snTuning = screens.get_node_or_null(_SN_TUNING_SCREEN)
		_snButton.connect("gui_input", self, "_snOnServicesInput")
		_snShiftBadge = _snMakeShiftBadge(_snButton)
		_snSettings.connect("settingsChanged", self, "_snQueue")
		for signalName in ["dayPassed", "hourPassed", "moneyChanged", "moneyOrInsuranceChanged", "employmentChanged"]:
			if CurrentGame.has_signal(signalName):
				CurrentGame.connect(signalName, self, "_snQueue")
		_snQueue()
	_snUpdate()

# The entry with its alert mark holds translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _snButton != null:
		_snUpdate()

func _snUpdate():
	_snButton.text = tr(_SN_ALERT) % tr(_snKey) if _snDue else _snKey

# The Shift badge (Badge.gd), in the entry's own frame and font colour, to the right of the entry, the menu's gap
# between entries away (Badge.gd hangBeside). Its tooltip, only where Shift+Click opens the settings, is shown by the
# menu's PlaySoundsOnTheseButtons: on hover, and with a gamepad, which shows no hover, while the entry is highlighted.
func _snMakeShiftBadge(button):
	var badge = _SN_BADGE_SCRIPT.new()
	badge.dress(button, OS.get_scancode_string(KEY_SHIFT), _SN_BADGE_SCRIPT.PAD_TEXT)
	badge.hangBeside(button, get_constant("separation"))
	badge.attachTooltip(get_node_or_null("PlaySoundsOnTheseButtons"), button)
	badge.setShiftTooltips(_SN_SETTINGS_TOOLTIP, _SN_SETTINGS_TOOLTIP_PAD, _snSettings.modName())
	return badge

# Checked once per frame at most, after the game's own handlers of the same signals.
func _snQueue(_arg = null):
	if not _snQueued:
		_snQueued = true
		call_deferred("_snCheck")

# The rows of the Services screen the mod watches (Settings.gd kindOf), in the screen's order.
func _snRows() -> Array:
	var out = []
	var rows = _snServices.get_node_or_null(_SN_SERVICE_ROWS) if _snServices != null else null
	if rows == null:
		return out
	for row in rows.get_children():
		if "serviceName" in row and "buyButton" in row and row.has_method("checkPrice") and ServiceNotifier.kindOf(row) != "":
			out.append(row)
	return out

# The game's own rows decide (enceladus/ServiceUI.gd checkPrice: the cooldown, the price against the money, a story
# condition; a compensation costs nothing while there is none to pay), each run again here so it is current; a row
# hidden or with its Buy button disabled can't be bought.
func _snCheck():
	_snQueued = false
	_snDue = false
	for row in _snRows():
		if row.buyButton == null or not _snSettings.getValue("alert", row.serviceName):
			continue
		row.checkPrice()
		if row.visible and not row.buyButton.disabled:
			_snDue = true
	_snUpdate()

# Shift+Click opens the settings instead of the Services screen, and so does its gamepad twin on the highlighted entry
# (Badge.gd isPadShortcut). A click's gui_input signal comes before the button's own _gui_input, and accepting the
# press there keeps the button from pressing; Badge.gd's PAD_BUTTON does nothing to a button.
func _snOnServicesInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _SN_BADGE_SCRIPT.isPadShortcut(event)) and not _snButton.disabled:
		_snButton.accept_event()
		_snOpenSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus. The station's rows don't change while it stands, so
# the screen gets them once.
func _snOpenSettings():
	if _snSettingsScreen == null:
		_snSettingsScreen = _SN_SETTINGS_UI.new()
		_snSettingsScreen.setup(_snServices, _snTuning, _snKey, _snRows())
		_snScreens.add_child(_snSettingsScreen)
	_snScreens.hidefoka()
	_snSettingsScreen.show()

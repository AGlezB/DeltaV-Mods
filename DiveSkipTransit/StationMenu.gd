extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). DiveSkipTransit's settings open with Shift+Click on its dive entry: a
# Shift badge beside the entry says so in its tooltip, and a plain click on the entry still launches a dive.

# The settings (which skips are on): their model, shared with the settings screen and the skips.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
const _DST_SETTINGS_UI = preload("res://DiveSkipTransit/SettingsUI.gd")
# Translation key of i18n/en.po: the Shift badge's tooltip, whose first %s is the key to hold while clicking the entry,
# the second the mod's name.
const _DST_SETTINGS_TOOLTIP = "DIVESKIPTRANSIT_SETTINGS_TOOLTIP"
# The same while the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold,
# the mod's name.
const _DST_SETTINGS_TOOLTIP_PAD = "DIVESKIPTRANSIT_SETTINGS_TOOLTIP_PAD"
# The station's Tuning screen among its right-hand screens (enceladus/Enceladus.tscn), whose frame and place the
# settings screen copies.
const _DST_TUNING_SCREEN = "Tuning"
# The badges' script: their look, and their tooltip as their only interaction.
const _DST_BADGE_SCRIPT = preload("res://DiveSkipTransit/Badge.gd")

var _dstDiveButton = null
var _dstDiveKey = ""
var _dstShiftBadge = null # the Shift badge beside the dive entry
var _dstSettingsScreen = null # the settings screen, made on first use
var _dstScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _dstTuning = null # the station's Tuning screen, whose frame and place the settings screen copies

# The menu's `RingDive` button (Launch Ring Dive) has no script of its own; its text is a translation key, which the
# button translates itself. Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options",
# this menu. Without the container or its Tuning screen there are no settings, and Shift+Click is a plain click.
func _ready():
	var button = get_node_or_null("RingDive")
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	var tuning = screens.get_node_or_null(_DST_TUNING_SCREEN) if screens != null else null
	if not button is Button or screens == null or not screens.has_signal("hidefoka") or not tuning is Control:
		return
	_dstDiveButton = button
	_dstDiveKey = button.text
	_dstScreens = screens
	_dstTuning = tuning
	_dstDiveButton.connect("gui_input", self, "_dstOnDiveInput")
	_dstShiftBadge = _dstMakeShiftBadge(_dstDiveButton)

# The Shift badge (Badge.gd), in the entry's own frame and font colour, to the right of the entry, the menu's gap
# between entries away (Badge.gd hangBeside). Its tooltip, which follows a change of language by itself, is shown by
# the menu's PlaySoundsOnTheseButtons: on hover, and with a gamepad, which shows no hover, while the entry is
# highlighted.
func _dstMakeShiftBadge(button):
	var badge = _DST_BADGE_SCRIPT.new()
	badge.dress(button, OS.get_scancode_string(KEY_SHIFT), _DST_BADGE_SCRIPT.PAD_TEXT)
	badge.hangBeside(button, get_constant("separation"))
	badge.attachTooltip(get_node_or_null("PlaySoundsOnTheseButtons"), button)
	badge.setShiftTooltips(_DST_SETTINGS_TOOLTIP, _DST_SETTINGS_TOOLTIP_PAD, DiveSkipTransit.shared().modName())
	return badge

# Shift+Click opens the settings instead of launching, and so does its gamepad twin on the highlighted entry (Badge.gd
# isPadShortcut). A click's gui_input signal comes before the button's own _gui_input, and accepting the press there
# keeps the button from pressing; Badge.gd's PAD_BUTTON does nothing to a button.
func _dstOnDiveInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _DST_BADGE_SCRIPT.isPadShortcut(event)) and not _dstDiveButton.disabled:
		_dstDiveButton.accept_event()
		_dstOpenSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus.
func _dstOpenSettings():
	if _dstSettingsScreen == null:
		_dstSettingsScreen = _DST_SETTINGS_UI.new()
		_dstSettingsScreen.setup(_dstTuning, _dstDiveKey)
		_dstScreens.add_child(_dstSettingsScreen)
	_dstScreens.hidefoka()
	_dstSettingsScreen.show()

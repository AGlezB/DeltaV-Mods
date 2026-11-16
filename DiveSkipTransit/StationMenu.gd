extends "res://enceladus/EnceladusMenu.gd"

# The station menu (enceladus/EnceladusMenu.gd). DiveSkipTransit's settings open with Shift+Click on its dive entry,
# the way CrewCheapHireNotifier's open from the Crew entry: the entry's tooltip says so, and a plain click still
# launches a dive.

# The settings (which skips are on): their model, shared with the settings screen and the skips.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
const _DST_SETTINGS_UI = preload("res://DiveSkipTransit/SettingsUI.gd")
# Translation key of i18n/en.po: the dive entry's tooltip, whose first %s is the key to hold while clicking, the second
# the mod's name.
const _DST_SETTINGS_TOOLTIP = "DIVESKIPTRANSIT_SETTINGS_TOOLTIP"

var _dstDiveButton = null
var _dstDiveKey = ""
var _dstSettingsScreen = null # the settings screen, made on first use
var _dstScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _dstTuning = null # the station's Tuning screen, whose frame and place the settings screen copies

# The menu's `RingDive` button (Launch Ring Dive) has no script of its own; its text is a translation key, which the
# button translates itself. Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options",
# this menu. Without the container or its Tuning screen there are no settings, and Shift+Click is a plain click.
func _ready():
	var button = get_node_or_null("RingDive")
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if not button is Button or screens == null or not screens.has_signal("hidefoka") \
			or not screens.get_node_or_null("Tuning") is Control:
		return
	_dstDiveButton = button
	_dstDiveKey = button.text
	_dstScreens = screens
	_dstTuning = screens.get_node("Tuning")
	_dstDiveButton.connect("gui_input", self, "_dstOnDiveInput")
	_dstUpdateTooltip()

# The tooltip holds translated text, which the button can't translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _dstDiveButton != null:
		_dstUpdateTooltip()

# The game's tooltip node (the menu's PlaySoundsOnTheseButtons, menu/sfx/PlaySoundsOnTheseButtons.gd) takes it over and
# reads it again on every hover, so setting it again is enough.
func _dstUpdateTooltip():
	var modName = DiveSkipTransit.shared().modName()
	_dstDiveButton.hint_tooltip = tr(_DST_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), modName]

# Shift+Click opens the settings instead of launching. The gui_input signal comes before the button's own _gui_input,
# and accepting the press there keeps the button from pressing.
func _dstOnDiveInput(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift \
			and not _dstDiveButton.disabled:
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

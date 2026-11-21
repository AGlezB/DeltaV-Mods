extends "res://enceladus/EnceladusMenu.gd"

# The settings (the salary threshold and tolerance, and the crew limit for each job): their model, shared with the
# settings screen.
const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

# Translation keys of i18n/en.po. The Crew entry's text while someone cheap is for hire, whose %s is the entry's own
# text in the game's language; and the Shift badge's tooltip, whose first %s is the key to hold while clicking the
# entry, the second the mod's name.
const _CHEAP_HIRE_ALERT = "CREWCHEAPHIRENOTIFIER_ALERT"
const _CHEAP_HIRE_SETTINGS_TOOLTIP = "CREWCHEAPHIRENOTIFIER_SETTINGS_TOOLTIP"
# The same while the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold,
# the mod's name.
const _CHEAP_HIRE_SETTINGS_TOOLTIP_PAD = "CREWCHEAPHIRENOTIFIER_SETTINGS_TOOLTIP_PAD"
# The station's Tuning screen among its right-hand screens (enceladus/Enceladus.tscn), whose frame and place the
# settings screen copies.
const _CHEAP_HIRE_TUNING_SCREEN = "Tuning"

const _CHEAP_HIRE_SETTINGS_UI = preload("res://CrewCheapHireNotifier/SettingsUI.gd")
# The badges' script: their look, and their tooltip as their only interaction.
const _CHEAP_HIRE_BADGE_SCRIPT = preload("res://CrewCheapHireNotifier/Badge.gd")

var _cheapHireButton = null # the menu's Crew entry
var _cheapHireKey = "" # its text, a translation key
var _cheapHireShiftBadge = null # the Shift badge beside the Crew entry
var _cheapHireSettings = null # the settings screen, made on first use
var _cheapHireScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _cheapHireTuning = null # the station's Tuning screen, whose frame and place the settings screen copies
var _cheapHireModel = null # the settings (Settings.gd), the save game's

# The menu's `Crew` button has no script of its own; its text is a translation key that the button translates itself.
func _ready():
	var button = get_node_or_null("Crew")
	if not button is Button:
		return
	_cheapHireButton = button
	_cheapHireKey = button.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_cheapHireModel = CrewCheapHireNotifier.shared()
	_cheapHireModel.loadFromState()
	_cheapHireModel.connect("settingsChanged", self, "_updateCheapHire")
	CurrentGame.connect("dayPassed", self, "_updateCheapHire")
	CurrentGame.connect("employmentChanged", self, "_updateCheapHire")
	# Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options", this menu.
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	var tuning = screens.get_node_or_null(_CHEAP_HIRE_TUNING_SCREEN) if screens != null else null
	if screens != null and screens.has_signal("hidefoka") and tuning is Control:
		_cheapHireScreens = screens
		_cheapHireTuning = tuning
		_cheapHireButton.connect("gui_input", self, "_onCrewInput")
		_cheapHireShiftBadge = _makeCheapHireShiftBadge(_cheapHireButton)
	_updateCheapHire()

# A marked entry holds translated text, which the button cannot translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _cheapHireButton != null:
		_updateCheapHire()

func _updateCheapHire():
	if _cheapHireAvailable():
		_cheapHireButton.text = tr(_CHEAP_HIRE_ALERT) % tr(_cheapHireKey)
	else:
		_cheapHireButton.text = _cheapHireKey

# The Shift badge (Badge.gd), in the entry's own frame and font colour, to the right of the entry, the menu's gap
# between entries away (Badge.gd hangBeside). Its tooltip, only where Shift+Click opens the settings, is shown by the
# menu's PlaySoundsOnTheseButtons.
func _makeCheapHireShiftBadge(button):
	var badge = _CHEAP_HIRE_BADGE_SCRIPT.new()
	badge.dress(button, OS.get_scancode_string(KEY_SHIFT), _CHEAP_HIRE_BADGE_SCRIPT.PAD_TEXT)
	badge.hangBeside(button, get_constant("separation"))
	badge.attachTooltip(get_node_or_null("PlaySoundsOnTheseButtons"))
	badge.setShiftTooltips(_CHEAP_HIRE_SETTINGS_TOOLTIP, _CHEAP_HIRE_SETTINGS_TOOLTIP_PAD, _cheapHireModel.modName())
	return badge

# The rule is the settings model's (isCheapHire), so the Hire screen (HireScreen.gd) marks the same people.
func _cheapHireAvailable() -> bool:
	for member in CurrentGame.getAvailableCrew():
		if _cheapHireModel.isCheapHire(member):
			return true
	return false

# Shift+Click opens the settings instead of the Crew screen, and so does its gamepad twin on the highlighted entry
# (Badge.gd isPadShortcut). A click's gui_input signal comes before the button's own _gui_input, and accepting the
# press there keeps the button from pressing; the gamepad's X does nothing to a button.
func _onCrewInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if (shiftClick or _CHEAP_HIRE_BADGE_SCRIPT.isPadShortcut(event)) and not _cheapHireButton.disabled:
		_cheapHireButton.accept_event()
		_openCheapHireSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus.
func _openCheapHireSettings():
	if _cheapHireSettings == null:
		_cheapHireSettings = _CHEAP_HIRE_SETTINGS_UI.new()
		_cheapHireSettings.setup(_cheapHireTuning, _cheapHireKey)
		_cheapHireScreens.add_child(_cheapHireSettings)
	_cheapHireScreens.hidefoka()
	_cheapHireSettings.show()

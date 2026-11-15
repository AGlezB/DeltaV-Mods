extends "res://enceladus/EnceladusMenu.gd"

# The settings (the salary threshold and tolerance, and the crew limit for each job): their model, shared with the
# settings screen.
const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

# Translation keys of i18n/en.po. The Crew entry's text while someone cheap is for hire, whose %s is the entry's own
# text in the game's language; and its tooltip, whose first %s is the key to hold while clicking, the second the mod's
# name.
const _CHEAP_HIRE_ALERT = "CREWCHEAPHIRENOTIFIER_ALERT"
const _CHEAP_HIRE_SETTINGS_TOOLTIP = "CREWCHEAPHIRENOTIFIER_SETTINGS_TOOLTIP"

const _CHEAP_HIRE_SETTINGS_UI = preload("res://CrewCheapHireNotifier/SettingsUI.gd")

var _crewButton = null
var _crewKey = ""
var _cheapHireSettings = null # the settings screen, made on first use
var _cheapHireScreens = null # the station's container of right-hand screens (enceladus/HidingMarginContainer.gd)
var _cheapHireTuning = null # the station's Tuning screen, whose frame and place the settings screen copies
var _settings = null

# The menu's `Crew` button has no script of its own; its text is a translation key that the button translates itself.
func _ready():
	var button = get_node_or_null("Crew")
	if not button is Button:
		return
	_crewButton = button
	_crewKey = button.text
	# The station is built anew after every load and new game, so this is the save game's own settings.
	_settings = CrewCheapHireNotifier.shared()
	_settings.loadFromState()
	_settings.connect("settingsChanged", self, "_updateCheapHire")
	CurrentGame.connect("dayPassed", self, "_updateCheapHire")
	CurrentGame.connect("employmentChanged", self, "_updateCheapHire")
	# Enceladus.tscn: the screens container's hideOnFocusOf is "../../HBoxContainer/Options", this menu.
	var screens = get_node_or_null("../../CanvasLayer/MarginContainer")
	if screens != null and screens.has_signal("hidefoka") and screens.get_node_or_null("Tuning") is Control:
		_cheapHireScreens = screens
		_cheapHireTuning = screens.get_node("Tuning")
		_crewButton.connect("gui_input", self, "_onCrewInput")
	_updateCheapHire()

# A marked entry and the tooltip hold translated text, which the button cannot translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _crewButton != null:
		_updateCheapHire()

# The tooltip only where Shift+Click opens the settings. The game's tooltip node (the menu's PlaySoundsOnTheseButtons,
# menu/sfx/PlaySoundsOnTheseButtons.gd) takes it over and reads it again on every hover, so setting it again is enough.
func _updateCheapHire():
	if _cheapHireAvailable():
		_crewButton.text = tr(_CHEAP_HIRE_ALERT) % tr(_crewKey)
	else:
		_crewButton.text = _crewKey
	if _cheapHireScreens != null:
		_crewButton.hint_tooltip = tr(_CHEAP_HIRE_SETTINGS_TOOLTIP) % [OS.get_scancode_string(KEY_SHIFT), _settings.modName()]

# The rule is the settings model's (isCheapHire), so the Hire screen (HireScreen.gd) marks the same people.
func _cheapHireAvailable() -> bool:
	for member in CurrentGame.getAvailableCrew():
		if _settings.isCheapHire(member):
			return true
	return false

# Shift+Click opens the settings instead of the Crew screen. The gui_input signal comes before the button's own
# _gui_input, and accepting the press there keeps the button from pressing.
func _onCrewInput(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift \
			and not _crewButton.disabled:
		_crewButton.accept_event()
		_openCheapHireSettings()

# As a menu entry opens its screen: the click has focused the entry, which hides the other screens (`hidefoka`);
# hiding them here too covers an entry that already had the focus.
func _openCheapHireSettings():
	if _cheapHireSettings == null:
		_cheapHireSettings = _CHEAP_HIRE_SETTINGS_UI.new()
		_cheapHireSettings.setup(_cheapHireTuning, _crewKey)
		_cheapHireScreens.add_child(_cheapHireSettings)
	_cheapHireScreens.hidefoka()
	_cheapHireSettings.show()

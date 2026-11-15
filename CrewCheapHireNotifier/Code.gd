extends "res://enceladus/EnceladusMenu.gd"

# The settings (salary threshold and tolerance): their model, shared with the settings screen.
const CrewCheapHireNotifier = preload("res://CrewCheapHireNotifier/Settings.gd")

# The Crew entry's text while someone cheap is for hire; %s is the entry's own text, in the game's language.
const ALERT_FORMAT = "%s (*)"

# The Crew entry's tooltip; the first %s is the key to hold while clicking, the second the mod's name.
const SETTINGS_TOOLTIP_FORMAT = "Click while pressing %s to open the %s settings."

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
		_crewButton.hint_tooltip = SETTINGS_TOOLTIP_FORMAT % [OS.get_scancode_string(KEY_SHIFT), _settings.modName()]
		_crewButton.connect("gui_input", self, "_onCrewInput")
	_updateCheapHire()

# A marked entry holds translated text, which the button cannot translate again.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and _crewButton != null:
		_updateCheapHire()

func _updateCheapHire():
	if _cheapHireAvailable():
		_crewButton.text = ALERT_FORMAT % tr(_crewKey)
	else:
		_crewButton.text = _crewKey

func _cheapHireAvailable() -> bool:
	var threshold = _settings.getValue("salaryThreshold")
	var tolerance = _settings.getValue("salaryTolerance")
	var highest = {}
	for memberName in CurrentGame.state.crew:
		var member = CurrentGame.state.crew[memberName]
		highest[member.occupation] = max(highest.get(member.occupation, 0), member.salary)
	for member in CurrentGame.getAvailableCrew():
		if member.salary <= max(threshold, highest.get(member.occupation, 0)) * (1.0 + tolerance):
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

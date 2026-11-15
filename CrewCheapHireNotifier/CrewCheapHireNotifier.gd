extends "res://enceladus/EnceladusMenu.gd"

# Someone for hire is cheap when their salary is at most the higher of this and the salary of your best-paid crew
# member with the same job, plus SALARY_TOLERANCE of it.
const SALARY_THRESHOLD = 1000

# How far above that limit a salary still counts as cheap, as a fraction of the limit: 0.5 would be 50 % more; 0, none.
const SALARY_TOLERANCE = 0.10

# The Crew entry's text while someone cheap is for hire; %s is the entry's own text, in the game's language.
const ALERT_FORMAT = "%s (*)"

var _crewButton = null
var _crewKey = ""

# The menu's `Crew` button has no script of its own; its text is a translation key that the button translates itself.
func _ready():
	var button = get_node_or_null("Crew")
	if not button is Button:
		return
	_crewButton = button
	_crewKey = button.text
	CurrentGame.connect("dayPassed", self, "_updateCheapHire")
	CurrentGame.connect("employmentChanged", self, "_updateCheapHire")
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
	var highest = {}
	for memberName in CurrentGame.state.crew:
		var member = CurrentGame.state.crew[memberName]
		highest[member.occupation] = max(highest.get(member.occupation, 0), member.salary)
	for member in CurrentGame.getAvailableCrew():
		if member.salary <= max(SALARY_THRESHOLD, highest.get(member.occupation, 0)) * (1.0 + SALARY_TOLERANCE):
			return true
	return false

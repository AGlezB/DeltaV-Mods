extends Label

# ShipSaleAdvisor's note at the bottom of the Fleet screen, which says how to open its settings, in place of a Shift
# badge: every owned ship's entry has a Sell button, and one note serves them all. It is lettered in the badges' small
# font (Badge.gd SMALL_FONT_THEME), and its text follows the control scheme as the Shift badges' does (Badge.gd
# _showKeys): Shift+Click with keyboard and mouse, the gamepad twin (Badge.gd isPadShortcut) with a gamepad.

const Badge = preload("res://ShipSaleAdvisor/Badge.gd")
# Translation keys of i18n/en.po: the note with keyboard and mouse, whose %s are the Shift key and the mod's name; with a
# gamepad, whose %s are the button to hold, the one to press and the mod's name.
const TEXT_KEYS = "SHIPSALEADVISOR_NOTE"
const TEXT_PAD = "SHIPSALEADVISOR_NOTE_PAD"
# The node's name on the Fleet screen, so that one entry adds it and the others find it.
const NODE_NAME = "ShipSaleAdvisorNote"

var _modName = ""

func setup(modName: String):
	name = NODE_NAME
	_modName = modName
	align = ALIGN_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(Badge.SMALL_FONT_THEME):
		add_font_override("font", load(Badge.SMALL_FONT_THEME).get_font("font", "Label"))
	var settings = _gameSettings()
	if settings != null and settings.has_signal("controlSchemeChaged") and not settings.is_connected("controlSchemeChaged", self, "_showText"):
		settings.connect("controlSchemeChaged", self, "_showText")
	_showText()

# The game's Settings autoload, read when the note is made or shown (Badge.gd _gameSettings: the mods' scripts compile
# before the engine creates the autoloads).
func _gameSettings():
	var settings = Settings
	return settings

# The scheme the game's own control hints follow (Badge.gd _isPad).
func _isPad() -> bool:
	var settings = _gameSettings()
	return settings != null and "controlScheme" in settings and settings.controlScheme == settings.control.gamepad

func _showText():
	if _isPad():
		text = tr(TEXT_PAD) % [Badge.PAD_MODIFIER_NAME, Badge.PAD_BUTTON_NAME, _modName]
	else:
		text = tr(TEXT_KEYS) % [OS.get_scancode_string(KEY_SHIFT), _modName]

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_showText()

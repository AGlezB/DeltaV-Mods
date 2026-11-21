extends PanelContainer

# A badge: a small framed label on or beside a part of the game's screens, which tells something and does nothing else.
# It takes no focus (a PanelContainer's default) and no click: one beside a button stops the mouse, and one on a button
# lets it through, so a click there is the button's. So it makes no sound, and its tooltip, when it has one, is its only
# interaction, shown sooner than the game's own; with a gamepad, while the control it tells about has the focus.

# The theme whose Label font is the small one badges are lettered in (the Hire screen's entries have it).
const SMALL_FONT_THEME = "res://enceladus/Subwindow.theme"
# How long the badge's tooltip waits after the mouse comes onto the badge, and how long it then takes to fade in, in
# seconds. The game's tooltip node uses them in place of its own (tooltipDelayTime, tooltipFadeTime) while the badge is
# hovered.
const TOOLTIP_DELAY = 0.2
const TOOLTIP_FADE = 0.2
# How long the game's tooltip node keeps its hover sound off when the mouse crosses the edge of a badge that lets it
# through, in seconds. Godot passes the mouse's enter and exit of such a badge on to the button under it, in the same
# input event, and the button would play its hover sound again. Any time above zero mutes it, since the node counts it
# down from its next frame; this one is too short to mute anything else.
const BUTTON_HOVER_MUTE = 0.001
# The gamepad's twin of Shift+Click, which the Shift badges read while the game is played with a gamepad: X pressed on
# the highlighted entry while LT is held. At the station the game gives neither button a use (project.godot: X is
# ship_strafe_left, LT ship_excavator, both flight actions), and no player can bind them to anything else (Settings.gd
# eventToString and stringToEvent handle keys and mouse buttons only). Godot 3.6 maps the trigger to a button, JOY_L2,
# held while the trigger is past half its travel. The badge and its tooltip name them as the game's gamepad glyphs show them
# (hud/components/controls-xbox-key-sheet.png).
const PAD_MODIFIER = JOY_L2
const PAD_BUTTON = JOY_XBOX_X
const PAD_MODIFIER_NAME = "LT"
const PAD_BUTTON_NAME = "X"
const PAD_TEXT = PAD_MODIFIER_NAME + "+" + PAD_BUTTON_NAME

var _tooltips = null # the game's tooltip node that shows the badge's tooltip (menu/sfx/PlaySoundsOnTheseButtons.gd)
var _gameTimes = null # the node's own wait and fade-in, kept while the badge's are set on it
var _label = null # a Shift badge's text
var _keyText = "" # what it reads with keyboard and mouse
var _padText = "" # what it reads with a gamepad, or "" for the same
var _tipKeys = null # a Shift badge's tooltips: [the key's text key, the gamepad's, the mod's name] (setShiftTooltips)

# Whether `event` is the gamepad's twin of Shift+Click: PAD_BUTTON pressed while PAD_MODIFIER is held on the same
# gamepad. A gamepad's buttons reach the highlighted control's gui_input, as keys do.
static func isPadShortcut(event) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == PAD_BUTTON \
			and Input.is_joy_button_pressed(event.device, PAD_MODIFIER)

# The Shift badges' look: the button's own frame (menu/ButtonRoundCorners.tres in the game), shared as is since nothing
# in it changes, and the text in the button's font colour and the small font. With `padText`, it reads that instead
# while the game is played with a gamepad, and follows every change of control scheme (_showKeys).
func dress(button, text, padText = ""):
	add_stylebox_override("panel", button.get_stylebox("normal"))
	_label = Label.new()
	_keyText = text
	_padText = padText
	_label.add_color_override("font_color", button.get_color("font_color"))
	if ResourceLoader.exists(SMALL_FONT_THEME):
		_label.add_font_override("font", load(SMALL_FONT_THEME).get_font("font", "Label"))
	add_child(_label)
	_showKeys()
	if padText != "":
		_followScheme()

# Hangs the badge beside `button`, `gap` px to its right, centred on it from top to bottom. A Button doesn't lay out its
# children, so the badge hangs from it directly, anchored to the middle of its right side, and grows right, up and down
# to its minimum size; the button doesn't clip it, and a child outside its parent's rect still gets the mouse. On no
# button, it stops the mouse, so a click on it does nothing.
func hangBeside(button, gap):
	set_anchors_preset(PRESET_CENTER_RIGHT)
	margin_left = gap
	margin_right = gap
	margin_top = 0
	margin_bottom = 0
	grow_horizontal = GROW_DIRECTION_END
	grow_vertical = GROW_DIRECTION_BOTH
	mouse_filter = MOUSE_FILTER_STOP
	button.add_child(self)

# A Shift badge's tooltip for each control scheme, the one shown following every change (_showKeys): `keyKey` a text key
# whose two %s are the Shift key and `modName`, `padKey` one whose three %s are the gamepad twin's button to press, the
# one to hold, and `modName`. The texts follow a change of language by themselves (_notification). The game's tooltip
# node reads hint_tooltip again on every hover, so the next one shows them.
func setShiftTooltips(keyKey, padKey, modName):
	_tipKeys = [keyKey, padKey, modName]
	_showKeys()
	_followScheme()

func _followScheme():
	var settings = _gameSettings()
	if settings != null and settings.has_signal("controlSchemeChaged") and not settings.is_connected("controlSchemeChaged", self, "_showKeys"):
		settings.connect("controlSchemeChaged", self, "_showKeys")

# The game's tooltip node draws the released game's tooltips (Godot's own are off screen: project.godot
# display/mouse_cursor/tooltip_position_offset.release), and registers only the buttons and sliders it finds itself.
# Its connectSounds registers the badge: it takes over the badge's hint_tooltip, reads it again on every hover, and
# hides it on exit and when the badge hides. The hover then goes to _notification instead of the node's _on_hover,
# which would also play the hover sound.
# With `focusOwner`, the control the badge tells about (the one the D-pad lands on), the tooltip also shows while that
# control has the focus and the game is played with a gamepad, which shows no hover: the D-pad shows what hover shows.
func attachTooltip(tooltips, focusOwner = null):
	if tooltips == null or not tooltips.has_method("connectSounds") or not tooltips.has_method("showTooltip"):
		return
	tooltips.connectSounds(self)
	if is_connected("mouse_entered", tooltips, "_on_hover"):
		disconnect("mouse_entered", tooltips, "_on_hover")
	_tooltips = tooltips
	if focusOwner != null and not focusOwner.is_connected("focus_entered", self, "_onOwnerFocus"):
		focusOwner.connect("focus_entered", self, "_onOwnerFocus")
		focusOwner.connect("focus_exited", self, "_onOwnerBlur")

# The game's Settings autoload, read when a badge is made or shown. The mods' scripts are compiled while the game's mod
# loader starts, before the engine creates that autoload, so the name would be a null constant there, and an
# expression on it alone is folded against null when the script compiles.
func _gameSettings():
	var settings = Settings
	return settings

# The scheme the game's own control hints follow (hud/components/ContextSensitiveControlDisplay.gd): the Controls
# setting, or with Auto the device last used (menu/Mouse.gd).
func _isPad() -> bool:
	var settings = _gameSettings()
	return settings != null and "controlScheme" in settings and settings.controlScheme == settings.control.gamepad

func _showKeys():
	var pad = _isPad()
	if _label != null:
		_label.text = _padText if _padText != "" and pad else _keyText
	if _tipKeys != null:
		if pad:
			hint_tooltip = tr(_tipKeys[1]) % [PAD_BUTTON_NAME, PAD_MODIFIER_NAME, _tipKeys[2]]
		else:
			hint_tooltip = tr(_tipKeys[0]) % [OS.get_scancode_string(KEY_SHIFT), _tipKeys[2]]

# The tooltip node waits and fades in as for any focus. A hidden badge has nothing to tell.
func _onOwnerFocus():
	if _tooltips != null and is_instance_valid(_tooltips) and is_visible_in_tree() and _isPad():
		_tooltips.showTooltip(self)

func _onOwnerBlur():
	if _tooltips != null and is_instance_valid(_tooltips) and _tooltips.get("currentTooltipNode") == self:
		_tooltips.hideTooltip(self)

# Godot sends the badge the mouse's enter and exit before it passes them on to whatever is under the badge. A hovered
# badge the game hides may get no exit (the Dealer screen hides its badges on a refresh), so hiding it, or taking it out
# of the tree, also gives the node its own times back.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_showKeys()
		return
	if _tooltips == null or not is_instance_valid(_tooltips):
		return
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_setTimes()
			_tooltips.showTooltip(self)
			_muteButton()
		NOTIFICATION_MOUSE_EXIT:
			_restoreTimes()
			_muteButton()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_restoreTimes()
		NOTIFICATION_EXIT_TREE:
			_restoreTimes()

func _setTimes():
	if _gameTimes == null and "tooltipDelayTime" in _tooltips and "tooltipFadeTime" in _tooltips:
		_gameTimes = [_tooltips.tooltipDelayTime, _tooltips.tooltipFadeTime]
		_tooltips.tooltipDelayTime = TOOLTIP_DELAY
		_tooltips.tooltipFadeTime = TOOLTIP_FADE

func _restoreTimes():
	if _gameTimes != null:
		_tooltips.tooltipDelayTime = _gameTimes[0]
		_tooltips.tooltipFadeTime = _gameTimes[1]
		_gameTimes = null

# Only a badge that lets the mouse through passes its enter and exit on to the button under it.
func _muteButton():
	if mouse_filter == MOUSE_FILTER_PASS and "supressFocuses" in _tooltips:
		_tooltips.supressFocuses = max(_tooltips.supressFocuses, BUTTON_HOVER_MUTE)
		_tooltips.set_process(true)

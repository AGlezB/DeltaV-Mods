extends "res://enceladus/SystemBuyUI.gd"

# ShipCopyPaste: on the Fleet screen, Copy on another ship of the current ship's model makes the current ship like it,
# in what the player picks: the same settings, crew aboard and equipment, bought as the Equipment screen sells it.
#
# The Fleet screen (enceladus/Owned.tscn, an instance of Dealer.tscn) lists the owned ships as entries of this script;
# the ship market uses the same script for the ships for sale (`owned` false), which the mod leaves alone.
#
# - Copy on the other ships' entries, right before Use, enabled on a ship of the current ship's model (the ship configs'
#   `model`), its tooltip saying why when it isn't. The current ship's entry has nothing to copy onto itself, so it gets
#   a spacer of Copy's size instead: the ship's name stretches and the rest of the row is packed at its right end
#   (enceladus/SystemBuyUI.tscn), and a hidden control takes no space, so without it that entry's details would sit
#   further right than the others'. Copy, Use and Sell get narrower side margins (copies of the theme's button styles,
#   menu/MenuTheme.tres: 16 px each side of a 48 px icon), so their icons sit _SHIP_COPY_PASTE_ICON_GAP apart and the
#   ship's name keeps more room.
# - Copy opens a confirmation dialog, a ConfirmationDialog as the game's own (the station's pause menu,
#   enceladus/PauseLayerEnceladus.tscn: no title, popup_centered, Cancel focused), in the entry's menu theme: the
#   question, then one row per part of the setup (settings, crew aboard, equipment), each with the game's Tuning switch
#   (enceladus/Tuning/TuningBoolValue.tscn), on when the dialog opens, where the two ships differ, and a label in its
#   place where they don't or the part can't be copied. Under the equipment, the pieces bought with their prices, the
#   total and the repair time, money written and coloured as the Fleet screen's trade-in (Dealer.gd displayShip).
#   Closing the Fleet screen closes it. Nothing is saved but what OK pastes.
# - Equipment: for every slot of the Equipment screen (enceladus/Upgrades.gd getItems(), each item's `slot`) where the
#   two ships' values differ, the item with the copied ship's value is bought as Upgrades.gd buy() buys it: its
#   getNetPrice() (the price times the slots, minus the trade-in of the piece it replaces), its actualReplacementTime
#   (only when the replaced piece is damaged: ship-ctrl.gd getSlotTime), the slot's damage cleared. When a value isn't
#   sold there, or its item isn't available (isAvailable(): story, capability, the ship's limits; the screen hides
#   it), the equipment can't be copied at all, and the dialog lists what is missing.
# - Settings: the copied ship's `tuning` (with the target's own entries kept for the pieces left as they are),
#   `hud.config` and each weapon slot's `config`, whatever they hold; they read the same when the Tuning screen would
#   show the same values and the configs hold the same, in any order.
# - Crew: the copied ship's crew aboard, as `preferredCrew`, put aboard at once with CurrentGame.gd validateEmployment
#   (as the game does when the player switches ships or a day passes), which redraws the crew's portraits through
#   `employmentChanged`. The game keeps a ship's `preferredCrew` only once its crew changed while it was flown
#   (hireCrewmember, fireCrewmember, setMemberActive). A copied ship without one has no crew, so copying its crew
#   leaves nobody aboard: the author's rule, where the game, switching to such a ship, keeps whoever is aboard
#   (validateEmployment falls back to the crew active then).
# - Then, as Dealer.gd use() does after a switch: the Fleet screen's `shipChanged` (enceladus/Enceladus.gd shipChanged
#   rebuilds the docked ship from CurrentGame.state.ship, which emits playerShipChanged) and addShips().
#
# Stacking: the parent's _ready is never called (Godot runs every level by itself); checkCurrentAndOwned falls through
# to the parent with `.checkCurrentAndOwned()`; _input is the extension's own (the game's script has none); new
# members start with `_`.

# The Equipment screen: the node of that name next to the Fleet screen among the station's screens
# (enceladus/Enceladus.tscn).
const _SHIP_COPY_PASTE_EQUIPMENT = "Upgrades"
# The one slot the game gives a default when a config has none (ships/ship-ctrl.gd getConfigWithDefaults), and the
# ship's property holding it.
const _SHIP_COPY_PASTE_LIDAR_SLOT = "lidar.type"
const _SHIP_COPY_PASTE_LIDAR_DEFAULT = "defaultLidar"
# The entry's nodes the mod reads (enceladus/SystemBuyUI.tscn): the Use button it copies for Copy; the node in the
# Fleet screen's prose theme (enceladus/Subwindow.theme, as the ship's description), whose Label font the dialog's
# lists take.
const _SHIP_COPY_PASTE_USE = "HBox/Use"
const _SHIP_COPY_PASTE_PROSE = "HBox/Margin"
# The entry's Sell button, whose margins the mod narrows with Use's and Copy's.
const _SHIP_COPY_PASTE_SELL = "HBox/Sell"
# The space between two neighbouring icons of the row (Copy, Use, Sell), in pixels: the row's own separation plus the
# buttons' side margins, which the mod sets to make up the rest. A user may edit it.
const _SHIP_COPY_PASTE_ICON_GAP = 10
# The button styles given those margins: `normal` sizes a button, flat or not, and each state's style places its icon,
# so all four change together (or the icon would shift on hover or when disabled). The focus frame, drawn over the
# whole button, keeps its own.
const _SHIP_COPY_PASTE_TIGHT_STYLES = ["normal", "hover", "pressed", "disabled"]
# The game's keys for the confirmation's buttons (the entry's Buy confirmation, BuyConfirm and BuyCancel).
const _SHIP_COPY_PASTE_OK = "OK"
const _SHIP_COPY_PASTE_CANCEL = "CANCEL"
# The game's Tuning switch, one per row of the dialog, and its nodes: the row, its name (a Button), the switch and the
# reset button.
const _SHIP_COPY_PASTE_SWITCH = "res://enceladus/Tuning/TuningBoolValue.tscn"
const _SHIP_COPY_PASTE_SWITCH_ROW = "HBoxContainer"
const _SHIP_COPY_PASTE_SWITCH_NAME = "HBoxContainer/Name"
const _SHIP_COPY_PASTE_SWITCH_VALUE = "HBoxContainer/Value"
const _SHIP_COPY_PASTE_SWITCH_RESET = "HBoxContainer/Reset"
# The dialog's rows, in order, each with its name's text (i18n/en.po).
const _SHIP_COPY_PASTE_ROWS = {
	"settings": "SHIPCOPYPASTE_SETTINGS",
	"crew": "SHIPCOPYPASTE_CREW",
	"equipment": "SHIPCOPYPASTE_EQUIPMENT",
}
# The Fleet screen's colours for money (Dealer.gd displayShip: the trade-in, a gain in colorPlus, a cost in
# colorMinus), and Dealer.gd's own values, used only where the screen has none.
const _SHIP_COPY_PASTE_COLOR_MINUS = "colorMinus"
const _SHIP_COPY_PASTE_COLOR_PLUS = "colorPlus"
const _SHIP_COPY_PASTE_COLOR_MINUS_FALLBACK = Color(1.0, 0.5, 0.5, 1)
const _SHIP_COPY_PASTE_COLOR_PLUS_FALLBACK = Color(0.5, 1.0, 0.5, 1)
# The mineral targeting the game gives a system that has none (hud/Hud.gd, ships/modules/DockingArm.gd,
# weapons/drone-plant.gd _ready: CurrentGame.traceMinerals, then these), so a missing config reads as that one.
const _SHIP_COPY_PASTE_MINERALS = "minerals"
const _SHIP_COPY_PASTE_TRACE_MINERALS = "traceMinerals"
const _SHIP_COPY_PASTE_MINERALS_DEFAULT = {"minValue": 0, "albedo": 0}
# The widest the dialog's question may be on one line, as a share of the screen's width: beyond, it wraps. The rest of
# the dialog is only as wide as it needs.
const _SHIP_COPY_PASTE_MAX_WIDTH_SHARE = 0.5
# The least space between a row's name and its switch or label, and between a line of the list and its value, in
# heights of the list's font.
const _SHIP_COPY_PASTE_COLUMN_GAP = 2.0
# The mod's nodes.
const _SHIP_COPY_PASTE_COPY_NODE = "ShipCopyPasteCopy"
const _SHIP_COPY_PASTE_SPACER_NODE = "ShipCopyPasteSpacer"
const _SHIP_COPY_PASTE_DIALOG_NODE = "ShipCopyPasteDialog"
# The icon's size when the Use button has no icon to read it from.
const _SHIP_COPY_PASTE_ICON_FALLBACK = Vector2(48, 48)
# The texts (i18n/en.po).
const _SHIP_COPY_PASTE_TIP_COPY = "SHIPCOPYPASTE_COPY"
const _SHIP_COPY_PASTE_TIP_COPY_MODEL = "SHIPCOPYPASTE_COPY_MODEL"
const _SHIP_COPY_PASTE_TEXT_CONFIRM = "SHIPCOPYPASTE_CONFIRM"
const _SHIP_COPY_PASTE_TEXT_BULLET = "SHIPCOPYPASTE_BULLET"
const _SHIP_COPY_PASTE_TEXT_SAME = "SHIPCOPYPASTE_SAME"
const _SHIP_COPY_PASTE_TEXT_INCOMPATIBLE = "SHIPCOPYPASTE_INCOMPATIBLE"
const _SHIP_COPY_PASTE_TEXT_UNFIT = "SHIPCOPYPASTE_UNFIT"
const _SHIP_COPY_PASTE_TEXT_COST = "SHIPCOPYPASTE_COST"
const _SHIP_COPY_PASTE_TEXT_GAIN = "SHIPCOPYPASTE_GAIN"
const _SHIP_COPY_PASTE_TEXT_TOTAL = "SHIPCOPYPASTE_TOTAL"
const _SHIP_COPY_PASTE_TEXT_REPAIRS = "SHIPCOPYPASTE_REPAIRS"
const _SHIP_COPY_PASTE_TEXT_NO_MONEY = "SHIPCOPYPASTE_NO_MONEY"

var _shipCopyPasteCopy = null # the Copy button
var _shipCopyPasteSpacer = null # Copy's space on the current ship's entry
var _shipCopyPasteDialog = null # the confirmation dialog, made on the first Copy
var _shipCopyPasteTitle = null # its question
var _shipCopyPasteParts = null # under it, the rows and the list: only as wide as they need, centered
var _shipCopyPasteRows = {} # its rows (the game's Tuning switch), by part
var _shipCopyPasteStates = {} # each row's label, shown in place of its switch, by part
var _shipCopyPasteList = null # under the equipment's row: the pieces, the total and the repair time
var _shipCopyPasteProseFont = null # the Fleet screen's prose font, which the list takes
var _shipCopyPasteChoices = {} # each row's switch, by part: on to paste that part
var _shipCopyPastePlanShown = null # the plan it shows
var _shipCopyPasteShown = "" # what it shows: OK pastes only a plan that still reads the same
var _shipCopyPasteFilling = false # while the dialog sets its switches itself
var _shipCopyPasteClosedFrame = -1 # the frame in which Esc closed it

func _ready():
	if not owned:
		# The ship market's entries have nothing of the mod's: no _input for them (Godot turned it on for the method).
		set_process_input(false)
		return
	_shipCopyPasteBuild()
	var fleet = _shipCopyPasteFleet()
	if fleet != null:
		fleet.connect("visibility_changed", self, "_shipCopyPasteFleetVisibility")
	_shipCopyPasteRefresh()

# The game calls it when `current` is set and once the ship is set up; it can come before _ready.
func checkCurrentAndOwned():
	.checkCurrentAndOwned()
	_shipCopyPasteRefresh()

# Esc (or the pause button) while the dialog shows closes the dialog only. Children get _input before their parents, so
# the Fleet screen (Dealer.gd _input, which closes on these) doesn't see it. Dealer.gd asks the action, not the event,
# and an action stays just pressed for its whole frame: every later event of that frame (the key's release, a mouse
# move) is marked handled too.
func _input(_event):
	if not _shipCopyPasteCancelAction():
		return
	if is_instance_valid(_shipCopyPasteDialog) and _shipCopyPasteDialog.visible:
		_shipCopyPasteDialog.hide()
		_shipCopyPasteClosedFrame = Engine.get_idle_frames()
		get_tree().set_input_as_handled()
	elif _shipCopyPasteClosedFrame == Engine.get_idle_frames():
		get_tree().set_input_as_handled()

func _shipCopyPasteCancelAction() -> bool:
	for action in ["ui_cancel", "pause"]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

# Copy right before Use, as a copy of it, and the spacer that takes its place on the current ship's entry: an empty
# Control the mouse and the focus pass by, sized as Copy by _shipCopyPasteRefresh.
func _shipCopyPasteBuild():
	var use = get_node_or_null(_SHIP_COPY_PASTE_USE)
	if not use is Button or use.get_parent().has_node(_SHIP_COPY_PASTE_COPY_NODE):
		return
	var icon = _shipCopyPasteIcon(use.icon)
	_shipCopyPasteCopy = _shipCopyPasteButton(use, _SHIP_COPY_PASTE_COPY_NODE, icon, "_shipCopyPasteCopyPressed")
	var spacer = Control.new()
	spacer.name = _SHIP_COPY_PASTE_SPACER_NODE
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.focus_mode = Control.FOCUS_NONE
	spacer.visible = false
	var box = use.get_parent()
	box.add_child(spacer)
	box.move_child(spacer, use.get_index())
	_shipCopyPasteSpacer = spacer
	_shipCopyPasteTighten([_shipCopyPasteCopy, use, get_node_or_null(_SHIP_COPY_PASTE_SELL)])

# The row's buttons with side margins that put their icons _SHIP_COPY_PASTE_ICON_GAP apart, the row's separation
# counted: copies of each button's styles (the theme's are shared, never edited), one per style for the entry.
func _shipCopyPasteTighten(buttons: Array):
	var model = buttons[0]
	var rest = max(0, _SHIP_COPY_PASTE_ICON_GAP - model.get_parent().get_constant("separation"))
	var left = floor(rest / 2.0)
	var right = rest - left
	for style in _SHIP_COPY_PASTE_TIGHT_STYLES:
		var box = model.get_stylebox(style)
		if box == null:
			continue
		box = box.duplicate()
		box.content_margin_left = left
		box.content_margin_right = right
		for button in buttons:
			if button is Button:
				button.add_stylebox_override(style, box)

# A copy of the Use button (its look, size, icon size and smooth scrolling, its icon dimmed when disabled), without its
# connections. Hidden and disabled until _shipCopyPasteRefresh decides.
func _shipCopyPasteButton(model: Button, nodeName: String, icon: Texture, method: String) -> Button:
	var button = model.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANCING)
	button.name = nodeName
	button.icon = icon
	button.disabled = true
	button.visible = false
	var box = model.get_parent()
	box.add_child(button)
	box.move_child(button, model.get_index())
	button.connect("pressed", self, method)
	button.connect("focus_entered", self, "_on_Use_focus_entered")
	return button

# The confirmation dialog: the question in the menu font (the entry's theme, as the game's own dialogs), under it a row
# per part of the setup, with the equipment's list under its row, and the dialog's OK and Cancel.
# The rows and the list are only as wide as their widest name and value need, with _SHIP_COPY_PASTE_COLUMN_GAP between
# the two, so each value stays near its name however wide the question is. A Popup draws on top of everything and
# isn't laid out by the entry, so it neither widens nor clips the list.
func _shipCopyPasteDialogBuild():
	if is_instance_valid(_shipCopyPasteDialog):
		return
	var dialog = ConfirmationDialog.new()
	dialog.name = _SHIP_COPY_PASTE_DIALOG_NODE
	dialog.window_title = ""
	dialog.dialog_hide_on_ok = false
	dialog.get_ok().text = _SHIP_COPY_PASTE_OK
	dialog.get_cancel().text = _SHIP_COPY_PASTE_CANCEL
	var prose = get_node_or_null(_SHIP_COPY_PASTE_PROSE)
	var proseFont = prose.get_font("font", "Label") if prose is Control else null
	_shipCopyPasteProseFont = proseFont
	var box = VBoxContainer.new()
	_shipCopyPasteTitle = Label.new()
	_shipCopyPasteTitle.autowrap = true
	_shipCopyPasteTitle.align = Label.ALIGN_CENTER
	box.add_child(_shipCopyPasteTitle)
	var parts = VBoxContainer.new()
	parts.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(parts)
	_shipCopyPasteParts = parts
	_shipCopyPasteRows = {}
	_shipCopyPasteStates = {}
	var scene = load(_SHIP_COPY_PASTE_SWITCH)
	for part in _SHIP_COPY_PASTE_ROWS:
		parts.add_child(_shipCopyPasteRow(scene, part))
		if part == "equipment":
			_shipCopyPasteList = GridContainer.new()
			_shipCopyPasteList.columns = 2
			_shipCopyPasteList.visible = false
			parts.add_child(_shipCopyPasteList)
	dialog.add_child(box)
	add_child(dialog)
	var font = proseFont if proseFont != null else _shipCopyPasteList.get_font("font", "Label")
	var gap = int(ceil(font.get_height() * _SHIP_COPY_PASTE_COLUMN_GAP))
	_shipCopyPasteList.add_constant_override("hseparation", gap)
	for part in _shipCopyPasteRows:
		_shipCopyPasteRows[part].get_node(_SHIP_COPY_PASTE_SWITCH_ROW).add_constant_override("separation", gap)
		_shipCopyPasteRows[part].connect("value_changed", self, "_shipCopyPasteSwitched", [part])
	dialog.connect("confirmed", self, "_shipCopyPasteConfirmPressed")
	dialog.connect("popup_hide", self, "_shipCopyPasteDialogHidden")
	_shipCopyPasteDialog = dialog

# A row: the game's Tuning switch, named by the part's text, without its reset button and with its name never clipped
# (a long name widens the dialog), and a label beside the switch, shown in its place.
func _shipCopyPasteRow(scene, part: String) -> Control:
	var row = scene.instance()
	row.name = "ShipCopyPaste" + part.capitalize()
	row.tuningItem = _SHIP_COPY_PASTE_ROWS[part]
	row.tune = {"type": "bool", "default": true, "current": true, "testProtocol": ""}
	var reset = row.get_node_or_null(_SHIP_COPY_PASTE_SWITCH_RESET)
	if reset is Control:
		reset.visible = false
	var label = row.get_node_or_null(_SHIP_COPY_PASTE_SWITCH_NAME)
	if label is Button:
		label.clip_text = false
	var state = Label.new()
	state.align = Label.ALIGN_RIGHT
	state.valign = Label.VALIGN_CENTER
	state.visible = false
	row.get_node(_SHIP_COPY_PASTE_SWITCH_ROW).add_child(state)
	_shipCopyPasteRows[part] = row
	_shipCopyPasteStates[part] = state
	return row

# The Copy icon, two sheets, drawn as the Use button's icon (enceladus/Upgrades/switch.png) is: at its size and with
# its flags, light strokes with a dark edge, in its colours.
func _shipCopyPasteIcon(model) -> Texture:
	var size = _SHIP_COPY_PASTE_ICON_FALLBACK
	var inks = [Color.white, null]
	var flags = Texture.FLAG_FILTER
	if model is Texture:
		size = model.get_size()
		flags = model.flags
		var data = model.get_data()
		if data is Image:
			inks = _shipCopyPasteInks(data)
	var w = int(size.x)
	var h = int(size.y)
	var stroke = max(1, int(round(min(w, h) / 16.0)))
	var edge = max(1, int(round(min(w, h) / 48.0))) if inks[1] != null else 0
	var mask = []
	mask.resize(w * h)
	for i in mask.size():
		mask[i] = false
	# A sheet laid on another.
	var parts = [Rect2(w * 0.1, h * 0.08, w * 0.5, h * 0.6), Rect2(w * 0.4, h * 0.34, w * 0.5, h * 0.6)]
	for part in parts:
		_shipCopyPasteMark(mask, w, h, part.grow(edge + 1), false)
		_shipCopyPasteFrame(mask, w, h, part, stroke)
	var image = Image.new()
	image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(inks[0].r, inks[0].g, inks[0].b, 0.0))
	image.lock()
	for y in h:
		for x in w:
			if mask[y * w + x]:
				image.set_pixel(x, y, inks[0])
			elif edge > 0 and _shipCopyPasteNear(mask, w, h, x, y, edge):
				image.set_pixel(x, y, inks[1])
	image.unlock()
	var texture = ImageTexture.new()
	texture.create_from_image(image, flags)
	return texture

# An icon's colours: the mean of its light opaque pixels (the strokes), and of its dark ones (their edge; null when
# it has none).
func _shipCopyPasteInks(data: Image) -> Array:
	var image = data.duplicate()
	if image.is_compressed():
		image.decompress()
	var sums = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	var counts = [0, 0]
	image.lock()
	for y in image.get_height():
		for x in image.get_width():
			var c = image.get_pixel(x, y)
			if c.a >= 0.5:
				var dark = 1 if (c.r + c.g + c.b) / 3.0 < 0.5 else 0
				sums[dark].r += c.r
				sums[dark].g += c.g
				sums[dark].b += c.b
				counts[dark] += 1
	image.unlock()
	var inks = [Color.white, null]
	for i in 2:
		if counts[i] > 0:
			inks[i] = Color(sums[i].r / counts[i], sums[i].g / counts[i], sums[i].b / counts[i], 1.0)
	return inks

# Sets the pixels of `rect` in a w x h mask.
func _shipCopyPasteMark(mask: Array, w: int, h: int, rect: Rect2, value: bool):
	var x0 = int(clamp(round(rect.position.x), 0, w))
	var y0 = int(clamp(round(rect.position.y), 0, h))
	var x1 = int(clamp(round(rect.end.x), 0, w))
	var y1 = int(clamp(round(rect.end.y), 0, h))
	for y in range(y0, y1):
		for x in range(x0, x1):
			mask[y * w + x] = value

# The border of `rect`, `stroke` wide.
func _shipCopyPasteFrame(mask: Array, w: int, h: int, rect: Rect2, stroke: int):
	_shipCopyPasteMark(mask, w, h, Rect2(rect.position.x, rect.position.y, rect.size.x, stroke), true)
	_shipCopyPasteMark(mask, w, h, Rect2(rect.position.x, rect.end.y - stroke, rect.size.x, stroke), true)
	_shipCopyPasteMark(mask, w, h, Rect2(rect.position.x, rect.position.y, stroke, rect.size.y), true)
	_shipCopyPasteMark(mask, w, h, Rect2(rect.end.x - stroke, rect.position.y, stroke, rect.size.y), true)

# Whether a set pixel of the mask lies within `edge` of (x, y).
func _shipCopyPasteNear(mask: Array, w: int, h: int, x: int, y: int, edge: int) -> bool:
	for dy in range(max(0, y - edge), min(h, y + edge + 1)):
		for dx in range(max(0, x - edge), min(w, x + edge + 1)):
			if mask[dy * w + dx]:
				return true
	return false

# The Fleet screen: the entry's first ancestor that lists ships (Dealer.gd addShips).
func _shipCopyPasteFleet():
	var node = get_parent()
	while node != null and not node.has_method("addShips"):
		node = node.get_parent()
	return node

# The Equipment screen, next to the Fleet screen.
func _shipCopyPasteEquipment():
	var fleet = _shipCopyPasteFleet()
	if fleet == null or fleet.get_parent() == null:
		return null
	var node = fleet.get_parent().get_node_or_null(_SHIP_COPY_PASTE_EQUIPMENT)
	if node != null and node.has_method("getItems"):
		return node
	return null

# An owned ship's full config, not the current one's, by transponder (CurrentGame.state.garage). Only read.
func _shipCopyPasteGarage(transponder: String):
	for config in CurrentGame.state.get("garage", []):
		if config is Dictionary and config.get("transponder") == transponder:
			return config
	return null

# This entry's ship's full config when Copy can copy it onto the current ship: another owned ship of the same model.
func _shipCopyPasteSource():
	if not _shipCopyPasteCopiable():
		return null
	var source = _shipCopyPasteGarage(ship.transponder)
	if source == null or source.get("model") != CurrentGame.state.ship.get("model"):
		return null
	if not source.get("config") is Dictionary:
		return null
	return source

# Copy on the other ships' entries, enabled where it can copy, its tooltip saying why not otherwise; the spacer, as
# wide and tall as Copy, on the current ship's.
func _shipCopyPasteRefresh():
	if not is_instance_valid(_shipCopyPasteCopy) or not is_instance_valid(ship):
		return
	var can = _shipCopyPasteSource() != null and _shipCopyPasteEquipment() != null
	_shipCopyPasteCopy.visible = not current
	_shipCopyPasteCopy.disabled = not can
	_shipCopyPasteCopy.hint_tooltip = _SHIP_COPY_PASTE_TIP_COPY if _shipCopyPasteCopiable() else _SHIP_COPY_PASTE_TIP_COPY_MODEL
	_shipCopyPasteSpacer.rect_min_size = _shipCopyPasteCopy.get_combined_minimum_size()
	_shipCopyPasteSpacer.visible = current
	if not can:
		_shipCopyPasteClose()

# Whether this entry's ship is another owned ship of the current ship's model.
func _shipCopyPasteCopiable() -> bool:
	if not owned or current or not is_instance_valid(ship):
		return false
	var mine = CurrentGame.state.ship
	return ship.transponder != mine.get("transponder") and ship.model == mine.get("model")

# The Fleet screen closed: the dialog goes with it.
func _shipCopyPasteFleetVisibility():
	var fleet = _shipCopyPasteFleet()
	if fleet != null and not fleet.visible:
		_shipCopyPasteClose()
	_shipCopyPasteRefresh()

# Every switch on, then the plan, and the dialog.
func _shipCopyPasteCopyPressed():
	_shipCopyPasteChoices = {}
	for part in _SHIP_COPY_PASTE_ROWS:
		_shipCopyPasteChoices[part] = true
	var plan = _shipCopyPastePlanNow()
	if plan is GDScriptFunctionState:
		plan = yield(plan, "completed")
	if plan == null:
		_shipCopyPasteRefresh()
		return
	_shipCopyPasteDialogBuild()
	_shipCopyPasteShow(plan)
	_shipCopyPasteDialog.get_cancel().grab_focus()

# Fills the dialog with the plan, sized to its contents and centered on the screen: each row's switch where its part
# can be pasted (as the player left it), its label otherwise; OK disabled when there is nothing to paste or the player
# can't pay for the equipment, and then saying so.
func _shipCopyPasteShow(plan: Dictionary):
	_shipCopyPastePlanShown = plan
	var texts = _shipCopyPasteDescribe(plan)
	_shipCopyPasteShown = JSON.print(texts)
	_shipCopyPasteTitle.text = texts.title
	_shipCopyPasteFilling = true
	for part in _shipCopyPasteRows:
		var row = _shipCopyPasteRows[part]
		var value = row.get_node(_SHIP_COPY_PASTE_SWITCH_VALUE)
		var state = _shipCopyPasteStates[part]
		state.text = texts.states[part]
		state.visible = texts.states[part] != ""
		value.visible = not state.visible
		var on = _shipCopyPasteChoices.get(part, true)
		row.tune.current = on
		if value.pressed != on:
			value.pressed = on
	_shipCopyPasteFilling = false
	_shipCopyPasteFillList(texts.list)
	_shipCopyPasteWidths(texts.title)
	var ok = _shipCopyPasteDialog.get_ok()
	ok.text = texts.ok
	ok.disabled = not _shipCopyPasteCanPaste(plan)
	_shipCopyPasteFocusChain()
	_shipCopyPasteDialogFit()
	if not _shipCopyPasteDialog.visible:
		_shipCopyPasteDialog.popup_centered()
	_shipCopyPasteDialogFitLater()

# The equipment's list: each line's name on the left, bulleted, and its value on the right, a cost in the Fleet
# screen's colorMinus and a gain in its colorPlus; hidden when empty.
func _shipCopyPasteFillList(lines: Array):
	for child in _shipCopyPasteList.get_children():
		_shipCopyPasteList.remove_child(child)
		child.queue_free()
	for line in lines:
		var left = Label.new()
		left.text = tr(_SHIP_COPY_PASTE_TEXT_BULLET) % line.name
		left.size_flags_horizontal = SIZE_EXPAND_FILL
		var value = Label.new()
		value.text = line.value
		value.align = Label.ALIGN_RIGHT
		if line.sign != 0:
			value.modulate = _shipCopyPasteColor(line.sign < 0)
		for label in [left, value]:
			if _shipCopyPasteProseFont != null:
				label.add_font_override("font", _shipCopyPasteProseFont)
			_shipCopyPasteList.add_child(label)
	_shipCopyPasteList.visible = not lines.empty()

# The question's width, set so it wraps at it at once: as wide as it needs on one line, up to
# _SHIP_COPY_PASTE_MAX_WIDTH_SHARE of the screen, and never narrower than the rows and the list.
func _shipCopyPasteWidths(title: String):
	var parts = _shipCopyPasteParts.get_combined_minimum_size().x
	var most = floor(get_viewport_rect().size.x * _SHIP_COPY_PASTE_MAX_WIDTH_SHARE)
	var width = max(parts, min(_shipCopyPasteLineWidth(_shipCopyPasteTitle, title), most))
	_shipCopyPasteTitle.rect_min_size.x = width
	_shipCopyPasteTitle.rect_size.x = width

# The width `label` needs to show `text` on one line. A Label wraps a line that reaches its width (Label.cpp
# regenerate_word_cache), so this is a little more: a space more, which also covers the kerning its spaces lose.
func _shipCopyPasteLineWidth(label: Label, text: String) -> float:
	var font = label.get_font("font")
	var margins = label.get_stylebox("normal").get_minimum_size().x
	return ceil(font.get_string_size(text).x + font.get_string_size(" ").x + margins)

# The Fleet screen's colour for a cost (`minus`) or a gain.
func _shipCopyPasteColor(minus: bool) -> Color:
	var fleet = _shipCopyPasteFleet()
	var property = _SHIP_COPY_PASTE_COLOR_MINUS if minus else _SHIP_COPY_PASTE_COLOR_PLUS
	if fleet != null and property in fleet and fleet.get(property) is Color:
		return fleet.get(property)
	return _SHIP_COPY_PASTE_COLOR_MINUS_FALLBACK if minus else _SHIP_COPY_PASTE_COLOR_PLUS_FALLBACK

# The D-pad's way through the dialog: down the switches shown, then to the buttons, and back up.
func _shipCopyPasteFocusChain():
	var switches = []
	for part in _shipCopyPasteRows:
		var value = _shipCopyPasteRows[part].get_node(_SHIP_COPY_PASTE_SWITCH_VALUE)
		value.focus_neighbour_top = NodePath()
		value.focus_neighbour_bottom = NodePath()
		if value.visible:
			switches.append(value)
	var buttons = [_shipCopyPasteDialog.get_cancel(), _shipCopyPasteDialog.get_ok()]
	for i in switches.size():
		if i > 0:
			switches[i].focus_neighbour_top = switches[i].get_path_to(switches[i - 1])
		if i < switches.size() - 1:
			switches[i].focus_neighbour_bottom = switches[i].get_path_to(switches[i + 1])
		else:
			switches[i].focus_neighbour_bottom = switches[i].get_path_to(buttons[0])
	for button in buttons:
		button.focus_neighbour_top = button.get_path_to(switches.back()) if not switches.empty() else NodePath()

# A row's switch changed, or got the focus (TuningBoolValue.gd sends `current` then, which it never updates itself:
# setting it here keeps the switch from going back). The plan shown is chosen again with it, without pricing it again:
# the equipment decides which pieces stay, and so whether their settings differ.
func _shipCopyPasteSwitched(on, part: String):
	var row = _shipCopyPasteRows.get(part)
	if row != null:
		row.tune.current = on
	if _shipCopyPasteFilling or _shipCopyPasteChoices.get(part, true) == on:
		return
	_shipCopyPasteChoices[part] = on
	var plan = _shipCopyPastePlanShown
	var target = CurrentGame.getPlayerShip()
	if plan == null or not is_instance_valid(_shipCopyPasteDialog) or not _shipCopyPasteDialog.visible:
		return
	if not Tool.claim(target):
		return
	_shipCopyPasteChoose(plan, target, _shipCopyPasteChoices)
	Tool.release(target)
	_shipCopyPasteShow(plan)

# The dialog at its least size, centered on the screen.
func _shipCopyPasteDialogFit():
	if not is_instance_valid(_shipCopyPasteDialog):
		return
	var dialog = _shipCopyPasteDialog
	dialog.rect_size = Vector2.ZERO
	dialog.rect_global_position = ((get_viewport_rect().size - dialog.rect_size) / 2).floor()

# Again once the containers have laid the labels out, which settles their wrapped heights.
func _shipCopyPasteDialogFitLater():
	for i in 2:
		yield(get_tree(), "idle_frame")
	if is_instance_valid(_shipCopyPasteDialog) and _shipCopyPasteDialog.visible:
		_shipCopyPasteDialogFit()

# Closed by Cancel, OK, Esc or a click outside: the focus goes back to Copy.
func _shipCopyPasteDialogHidden():
	var copy = _shipCopyPasteCopy
	if is_instance_valid(copy) and copy.is_visible_in_tree() and not copy.disabled:
		copy.grab_focus()

# Pastes the plan as it is now, if it still reads as shown; otherwise shows the new one.
func _shipCopyPasteConfirmPressed():
	var ok = _shipCopyPasteDialog.get_ok()
	if ok.disabled:
		return
	ok.disabled = true
	var plan = _shipCopyPastePlanNow()
	if plan is GDScriptFunctionState:
		plan = yield(plan, "completed")
	if plan == null:
		_shipCopyPasteClose()
		return
	if JSON.print(_shipCopyPasteDescribe(plan)) != _shipCopyPasteShown or not _shipCopyPasteCanPaste(plan):
		_shipCopyPasteShow(plan)
		return
	var target = CurrentGame.getPlayerShip()
	if not Tool.claim(target):
		_shipCopyPasteClose()
		return
	_shipCopyPasteApply(plan, target)
	Tool.release(target)
	_shipCopyPasteClose()
	var fleet = _shipCopyPasteFleet()
	if fleet != null:
		fleet.emit_signal("shipChanged")
		fleet.addShips()

# Whether OK can paste the plan: a part switched on, and the money for the equipment if it is one.
func _shipCopyPasteCanPaste(plan: Dictionary) -> bool:
	if not plan.affordable:
		return false
	for part in plan.choices:
		if plan.choices[part]:
			return true
	return false

# Hides the dialog (the Fleet screen closed, Copy no longer applies, or the paste is done).
func _shipCopyPasteClose():
	if is_instance_valid(_shipCopyPasteDialog) and _shipCopyPasteDialog.visible:
		_shipCopyPasteDialog.hide()

# The plan for the current ship, with the Equipment screen's prices brought up to date first (as it does when it
# shows), chosen by the switches; null when this entry can't paste. A coroutine only while the Equipment screen prices.
func _shipCopyPastePlanNow():
	var source = _shipCopyPasteSource()
	var equipment = _shipCopyPasteEquipment()
	var target = CurrentGame.getPlayerShip()
	if source == null or equipment == null or not Tool.claim(target):
		return null
	if equipment.has_method("updatePricesAndAvailability"):
		var state = equipment.updatePricesAndAvailability()
		if state is GDScriptFunctionState:
			yield(state, "completed")
	var plan = _shipCopyPastePlan(source, target, equipment.getItems())
	_shipCopyPasteChoose(plan, target, _shipCopyPasteChoices)
	Tool.release(target)
	return plan

# What the paste could do to `target` (the player's ship) from `source` (the copied ship's full config), with the
# Equipment screen's `items`:
# - offer: the items that would make the differing slots like the copied ship's, prices: what each costs (negative: a
#   refund), offerPrice and offerTime (s): their sums;
# - differing: the slots that differ, with the target's value;
# - unfit: the names of the copied ship's pieces that can't be fitted;
# - crew: the copied ship's crew aboard, none without a crew list; mine: the target's;
# - source; name: the copied ship's; target: the current ship's name.
func _shipCopyPastePlan(source: Dictionary, target, items: Array) -> Dictionary:
	var groups = {}
	var order = []
	for item in items:
		if not groups.has(item.slot):
			groups[item.slot] = []
			order.append(item.slot)
		groups[item.slot].append(item)
	var plan = {
		"offer": [],
		"prices": [],
		"offerPrice": 0.0,
		"offerTime": 0.0,
		"differing": {},
		"unfit": [],
		"source": source,
		"name": CurrentGame.getShipNameByTransponder(source.get("transponder", "")),
		"target": CurrentGame.getShipNameByTransponder(CurrentGame.state.ship.get("transponder", "")),
	}
	for slot in order:
		if slot == "":
			continue
		var group = groups[slot]
		var numeric = false
		var fallback = null
		for item in group:
			numeric = numeric or item.numVal != -1
			if item.default and fallback == null:
				fallback = item.getVal()
		var want = _shipCopyPasteValue(target, slot, source.config, numeric, fallback)
		var have = _shipCopyPasteValue(target, slot, target.shipConfig, numeric, fallback)
		if _shipCopyPasteSame(want, have):
			continue
		plan.differing[slot] = have
		var pick = null
		for item in group:
			if _shipCopyPasteSame(item.getVal(), want) and item.isAvailable():
				pick = item
				break
		if pick == null:
			plan.unfit.append(_shipCopyPasteName(group[0], want))
		else:
			var price = pick.getNetPrice()
			plan.offer.append(pick)
			plan.prices.append(price)
			plan.offerPrice += price
			plan.offerTime += max(0.0, pick.actualReplacementTime)
	plan.crew = _shipCopyPasteCrew(source.config.get("preferredCrew"))
	plan.mine = _shipCopyPasteCrewNow(target.shipConfig)
	return plan

# Chooses what the paste does with the plan by the switches (`choices`, by part; a part not given is on), with `target`
# claimed:
# - states, by part: "switch" where it can be pasted, "same", "incompatible" (pieces that can't be fitted);
# - choices, by part: whether it is pasted;
# - buy: the items bought, prices: what each costs, price and time (s): their sums;
# - kept: the slots left as they are, with the target's value;
# - affordable: whether the player can pay for the equipment pasted.
func _shipCopyPasteChoose(plan: Dictionary, target, choices: Dictionary) -> void:
	var states = {}
	if plan.differing.empty():
		states.equipment = "same"
	elif not plan.unfit.empty():
		states.equipment = "incompatible"
	else:
		states.equipment = "switch"
	var buying = states.equipment == "switch" and choices.get("equipment", true)
	plan.buy = plan.offer.duplicate() if buying else []
	plan.price = plan.offerPrice if buying else 0.0
	plan.time = plan.offerTime if buying else 0.0
	plan.kept = {} if buying else plan.differing.duplicate()
	states.settings = "same" if _shipCopyPasteSettingsSame(plan, target) else "switch"
	states.crew = "same" if _shipCopyPasteEqual(plan.crew, plan.mine) else "switch"
	plan.states = states
	plan.choices = {}
	for part in _SHIP_COPY_PASTE_ROWS:
		plan.choices[part] = states[part] == "switch" and choices.get(part, true)
	plan.affordable = plan.price <= 0 or plan.price <= CurrentGame.getMoney()

# A ship's crew list, with those still employed only; none for a ship without one. Someone fired drops off the current
# ship's list only (CurrentGame.gd fireCrewmember), so a garage ship's list can still name them.
func _shipCopyPasteCrew(list) -> Array:
	if not list is Array:
		return []
	var employed = CurrentGame.state.get("crew")
	var crew = []
	for memberName in list:
		if employed is Dictionary and employed.has(memberName):
			crew.append(memberName)
	return crew

# The crew the current ship takes aboard: its crew list, or without one whoever is aboard (CurrentGame.gd
# validateEmployment), those still employed only.
func _shipCopyPasteCrewNow(config: Dictionary) -> Array:
	var list = config.get("preferredCrew")
	if not list is Array:
		list = CurrentGame.getCurrentlyActiveCrewNames() if CurrentGame.has_method("getCurrentlyActiveCrewNames") else []
	return _shipCopyPasteCrew(list)

# A slot's value in `config`, read as the Equipment screen reads the player's (Upgrades.gd updatePricesAndAvailability):
# the lidar's default where there is none, then the value of the slot's default item (`fallback`, null without one),
# and nothing in a numeric slot is 0.
func _shipCopyPasteValue(target, slot: String, config: Dictionary, numeric: bool, fallback):
	var value = target.getConfig(slot, null, config)
	if value == null and slot == _SHIP_COPY_PASTE_LIDAR_SLOT and _SHIP_COPY_PASTE_LIDAR_DEFAULT in target:
		value = target.get(_SHIP_COPY_PASTE_LIDAR_DEFAULT)
	if value == null and fallback != null:
		value = fallback
	if value == null and numeric:
		value = 0.0
	return value

# The Equipment screen's sameness: the same type (an int counting as a float) and value.
func _shipCopyPasteSame(a, b) -> bool:
	if a == null or b == null:
		return a == null and b == null
	var ta = TYPE_REAL if typeof(a) == TYPE_INT else typeof(a)
	var tb = TYPE_REAL if typeof(b) == TYPE_INT else typeof(b)
	return ta == tb and a == b

# Whether two values of a config hold the same: numbers by value (an int as a float: the save, JSON, gives floats
# back), dictionaries by their keys and values, arrays by their elements in any order (the game's lists of minerals and
# of crew grow in the order they were switched on).
func _shipCopyPasteEqual(a, b) -> bool:
	var na = a is int or a is float
	var nb = b is int or b is float
	if na or nb:
		return na and nb and is_equal_approx(float(a), float(b))
	if a is Dictionary or b is Dictionary:
		if not (a is Dictionary and b is Dictionary) or a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _shipCopyPasteEqual(a[key], b[key]):
				return false
		return true
	if a is Array or b is Array:
		if not (a is Array and b is Array) or a.size() != b.size():
			return false
		var left = b.duplicate()
		for x in a:
			var found = -1
			for i in left.size():
				if _shipCopyPasteEqual(x, left[i]):
					found = i
					break
			if found == -1:
				return false
			left.remove(found)
		return true
	return typeof(a) == typeof(b) and a == b

# Whether the settings the paste would write read the same as the target's: its tuning as the Tuning screen shows it, its
# mineral targeting, and each weapon slot's config but for the slots kept.
func _shipCopyPasteSettingsSame(plan: Dictionary, target) -> bool:
	var from = plan.source.config
	var to = target.shipConfig
	var tuning = _shipCopyPasteTuning(from, to, plan.kept)
	if not _shipCopyPasteTuningSame(target, to.get("tuning"), tuning, plan.buy):
		return false
	if not _shipCopyPasteEqual(_shipCopyPasteMinerals(from.get("hud")), _shipCopyPasteMinerals(to.get("hud"))):
		return false
	var fromSlots = from.weaponSlot if from.get("weaponSlot") is Dictionary else {}
	var toSlots = to.weaponSlot if to.get("weaponSlot") is Dictionary else {}
	for slotName in fromSlots.keys() + toSlots.keys():
		if plan.kept.has("weaponSlot.%s.type" % slotName):
			continue
		if not _shipCopyPasteEqual(_shipCopyPasteMinerals(fromSlots.get(slotName)), _shipCopyPasteMinerals(toSlots.get(slotName))):
			return false
	return true

# The mineral targeting a system reads from `holder` (its slot's entry, or `hud`): its config, or where it has none
# (or an empty one), the one the game gives it.
func _shipCopyPasteMinerals(holder):
	var config = holder.get("config") if holder is Dictionary else null
	if config != null and not (config is Dictionary and config.empty()):
		return config
	# get(), not `in`: the script compiles before the autoload exists, and `in` on it would be folded against null.
	var minerals = CurrentGame.get(_SHIP_COPY_PASTE_TRACE_MINERALS)
	var given = _SHIP_COPY_PASTE_MINERALS_DEFAULT.duplicate()
	given[_SHIP_COPY_PASTE_MINERALS] = minerals.duplicate() if minerals is Array else []
	return given

# Whether the tuning `after` shows on the Tuning screen what `before` does: each setting of the target's systems, listed
# as Tuning.gd fillTuneableSystems lists them (a slot-mounted system under its slotName, each key once), read as the
# screen reads it (the stored value or the default, a number snapped to its step: TuningFloatValue.gd), but for the
# systems on the slots `buy` replaces; then each piece bought, by its entries ("<slot>_<system>"). Opening the screen
# stores every value it shows, so the stored tunings alone would tell two ships apart that show the same. With no
# systems to list (a ship not set up), the stored tunings.
func _shipCopyPasteTuningSame(target, before, after: Dictionary, buy: Array) -> bool:
	if not before is Dictionary:
		before = {}
	var systems = target.getSystems() if target.has_method("getSystems") else {}
	if not systems is Dictionary or systems.empty():
		return _shipCopyPasteEqual(before, after)
	var used = {}
	for k in systems:
		var system = systems[k].get("ref") if systems[k] is Dictionary else null
		if not is_instance_valid(system) or not system.has_method("getTuneables"):
			continue
		var key = str(system.slotName if "slotName" in system else k)
		if used.has(key) or _shipCopyPasteReplaced(key, buy):
			continue
		var tuneables = system.getTuneables()
		if not tuneables is Dictionary or tuneables.empty():
			continue
		used[key] = true
		for tune in tuneables:
			var spec = tuneables[tune] if tuneables[tune] is Dictionary else {}
			var path = ("%s.%s" % [key, tune]).split(".")
			if not _shipCopyPasteEqual(_shipCopyPasteTuned(before, path, spec), _shipCopyPasteTuned(after, path, spec)):
				return false
	for item in buy:
		if item.getVal() is String:
			var path = ("%s_%s" % [item.slot, item.getVal()]).split(".")
			if not _shipCopyPasteEqual(_shipCopyPasteDig(before, path), _shipCopyPasteDig(after, path)):
				return false
	return true

# Whether a system's tuning key is a slot-mounted piece's on a slot the paste buys for.
func _shipCopyPasteReplaced(key: String, buy: Array) -> bool:
	for item in buy:
		if key.begins_with(item.slot + "_"):
			return true
	return false

# A tuning setting as the Tuning screen shows it: the stored value or the default, a number snapped to its step.
func _shipCopyPasteTuned(tuning: Dictionary, path, spec: Dictionary):
	var value = _shipCopyPasteDig(tuning, path)
	if value == null:
		value = spec.get("default")
	var step = spec.get("step")
	if (value is float or value is int) and (step is float or step is int) and step > 0:
		value = round(value / step) * step
	return value

# What the dialog calls a piece it can't fit: a system's name, or the slot's group title (UpgradeGroup.gd openButton)
# with the number.
func _shipCopyPasteName(item, value) -> String:
	if value is String:
		return tr(value)
	var title = ""
	var node = item.get_parent()
	while node != null and not ("slot" in node and node.slot):
		node = node.get_parent()
	if node != null and "openButton" in node and node.openButton is Button:
		title = tr(node.openButton.text)
	if title == "":
		title = item.slot
	if value == null:
		return title
	return "%s %s" % [title, CurrentGame.formatThousands(value)]

# The dialog's texts for a plan, translated: the question; each row's label ("" where it shows its switch); the
# equipment's list, one line each (name, value, and sign: -1 a cost, 1 a gain, 0 neither): the pieces bought, as the
# Equipment screen names them, then the total and the repair time, or the pieces that can't be fitted; OK's text.
func _shipCopyPasteDescribe(plan: Dictionary) -> Dictionary:
	var states = {}
	for part in _SHIP_COPY_PASTE_ROWS:
		match plan.states[part]:
			"same":
				states[part] = tr(_SHIP_COPY_PASTE_TEXT_SAME)
			"incompatible":
				states[part] = tr(_SHIP_COPY_PASTE_TEXT_INCOMPATIBLE)
			_:
				states[part] = ""
	var list = []
	if plan.states.equipment == "incompatible":
		for piece in plan.unfit:
			list.append({"name": piece, "value": tr(_SHIP_COPY_PASTE_TEXT_UNFIT), "sign": 0})
	elif plan.states.equipment == "switch":
		for i in plan.offer.size():
			list.append(_shipCopyPasteMoney(tr(plan.offer[i].getName()), plan.prices[i]))
		list.append(_shipCopyPasteMoney(tr(_SHIP_COPY_PASTE_TEXT_TOTAL), plan.offerPrice))
		if plan.offerTime > 0:
			var time = Tool.readableTimeSpan(plan.offerTime)
			list.append({"name": tr(_SHIP_COPY_PASTE_TEXT_REPAIRS), "value": time, "sign": 0})
	return {
		"title": tr(_SHIP_COPY_PASTE_TEXT_CONFIRM) % [plan.target, plan.name],
		"states": states,
		"list": list,
		"ok": _SHIP_COPY_PASTE_OK if plan.affordable else _SHIP_COPY_PASTE_TEXT_NO_MONEY,
	}

# A line of money, written as the Fleet screen writes a trade-in (Dealer.gd displayShip): a cost (`price` from 0 up)
# negative, a gain positive, each with its sign.
func _shipCopyPasteMoney(label: String, price: float) -> Dictionary:
	if price > 0 or is_zero_approx(price):
		return {"name": label, "value": tr(_SHIP_COPY_PASTE_TEXT_COST) % CurrentGame.formatThousands(price), "sign": -1}
	return {"name": label, "value": tr(_SHIP_COPY_PASTE_TEXT_GAIN) % CurrentGame.formatThousands(-price), "sign": 1}

# Applies the plan to `target`, the player's ship, whose shipConfig is CurrentGame.state.ship's config: each item bought
# as Upgrades.gd buy() fits it, then the settings and the crew where switched on, then the money, the log and the
# repair time, and puts the crew aboard.
func _shipCopyPasteApply(plan: Dictionary, target) -> void:
	var details = {}
	for i in plan.buy.size():
		var item = plan.buy[i]
		target.clearDamageInSlot(item.slot)
		target.setConfig(item.slot, item.getVal())
		details[item.system] = details.get(item.system, 0.0) - plan.prices[i]
	if plan.choices.settings:
		_shipCopyPasteSettings(plan.source.config, target.shipConfig, plan.kept)
	if plan.choices.crew:
		target.shipConfig.preferredCrew = plan.crew.duplicate()
	if not plan.buy.empty():
		CurrentGame.changeMoney(-plan.price)
		details["LOG_EVENT_DETAILS_COST"] = -plan.price
		CurrentGame.logEvent("LOG_EVENT_UPGRADE", details)
	if plan.time > 0:
		CurrentGame.addShipMaintanenceTime(plan.time)
	if plan.choices.crew and CurrentGame.has_method("validateEmployment"):
		CurrentGame.validateEmployment()

# The copied ship's settings into the target's config: its tuning (_shipCopyPasteTuning); its mineral targeting; each
# weapon slot's config, but for the slots kept.
func _shipCopyPasteSettings(from: Dictionary, to: Dictionary, kept: Dictionary) -> void:
	to.tuning = _shipCopyPasteTuning(from, to, kept)
	var fromHud = from.hud if from.get("hud") is Dictionary else {}
	if fromHud.has("config") or (to.get("hud") is Dictionary and to.hud.has("config")):
		if not to.get("hud") is Dictionary:
			to.hud = {}
		_shipCopyPasteEntry(fromHud, to.hud, "config")
	var fromSlots = from.weaponSlot if from.get("weaponSlot") is Dictionary else {}
	var toSlots = to.weaponSlot if to.get("weaponSlot") is Dictionary else {}
	for slotName in fromSlots.keys() + toSlots.keys():
		if kept.has("weaponSlot.%s.type" % slotName):
			continue
		var src = fromSlots.get(slotName) if fromSlots.get(slotName) is Dictionary else {}
		var dst = toSlots.get(slotName)
		if not dst is Dictionary:
			if not src.has("config"):
				continue
			if not to.get("weaponSlot") is Dictionary:
				to.weaponSlot = {}
				toSlots = to.weaponSlot
			dst = {}
			toSlots[slotName] = dst
		_shipCopyPasteEntry(src, dst, "config")

# The tuning the paste writes into `to`: the copied ship's, with the target's own entries for the pieces `kept` (a
# slot-mounted piece's are filed under "<slot>_<system>": WeaponSlot.gd, ThrusterSlot.gd loadPlaceholder), and none of
# the copied ship's for a kept piece the target has none for, so a kept piece keeps how it is tuned.
func _shipCopyPasteTuning(from: Dictionary, to: Dictionary, kept: Dictionary) -> Dictionary:
	var tuning = from.tuning.duplicate(true) if from.get("tuning") is Dictionary else {}
	var own = to.tuning if to.get("tuning") is Dictionary else {}
	for slot in kept:
		if kept[slot] is String:
			var path = ("%s_%s" % [slot, kept[slot]]).split(".")
			var entry = _shipCopyPasteDig(own, path)
			if entry != null:
				_shipCopyPastePut(tuning, path, entry)
			else:
				_shipCopyPasteErase(tuning, path)
	return tuning

# to[key] = a copy of from[key]; erased when `from` has none.
func _shipCopyPasteEntry(from: Dictionary, to: Dictionary, key: String) -> void:
	if from.has(key):
		var value = from[key]
		to[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	else:
		to.erase(key)

func _shipCopyPasteDig(dict: Dictionary, path):
	var node = dict
	for key in path:
		if not node is Dictionary or not node.has(key):
			return null
		node = node[key]
	return node

func _shipCopyPastePut(dict: Dictionary, path, value) -> void:
	var node = dict
	for i in path.size() - 1:
		if not node.get(path[i]) is Dictionary:
			node[path[i]] = {}
		node = node[path[i]]
	node[path[path.size() - 1]] = value.duplicate(true) if value is Dictionary or value is Array else value

func _shipCopyPasteErase(dict: Dictionary, path) -> void:
	var node = dict
	for i in path.size() - 1:
		if not node is Dictionary or not node.has(path[i]):
			return
		node = node[path[i]]
	if node is Dictionary:
		node.erase(path[path.size() - 1])

extends "res://enceladus/SystemBuyUI.gd"

# ShipCopyPaste: on the Fleet screen, Copy makes a ship the template and Paste makes the current ship like it, for two
# ships of the same model: the same equipment, bought as the Equipment screen sells it, and the same Tuning, mineral
# targeting and crew aboard.
#
# The Fleet screen (enceladus/Owned.tscn, an instance of Dealer.tscn) lists the owned ships as entries of this script;
# the ship market uses the same script for the ships for sale (`owned` false), which the mod leaves alone.
#
# - One button per Fleet entry, in the same spot right before Use, so the entries' buttons line up: Copy on the other
#   ships' entries, Paste on the current ship's (the only one Paste can change), never a button that can't be used.
#   Each is enabled only where it applies, and its tooltip says why when it isn't.
# - Copy, enabled on a ship of the current ship's model (the ship configs' `model`): that ship becomes the template.
#   Its transponder is kept as metadata of the Fleet screen node, and dropped when the screen closes (Dealer.gd hide():
#   its `hide` animation ends with the node invisible). Nothing is saved.
# - Paste, enabled on the current ship's entry once the template is another owned ship of its model. It opens a
#   confirmation dialog, a ConfirmationDialog as the game's own (the station's pause menu,
#   enceladus/PauseLayerEnceladus.tscn: no title, popup_centered, Cancel focused), in the entry's menu theme: what will
#   be copied and what won't, as two bulleted lists, and the price and the repair time.
# - Equipment: for every slot of the Equipment screen (enceladus/Upgrades.gd getItems(), each item's `slot`) where the
#   two ships' values differ, the item with the template's value is bought as Upgrades.gd buy() buys it: its
#   getNetPrice() (the price times the slots, minus the trade-in of the piece it replaces), its actualReplacementTime
#   (only when the replaced piece is damaged: ship-ctrl.gd getSlotTime), the slot's damage cleared. A value the screen
#   doesn't sell, or an item not available (isAvailable(): story, capability, the ship's limits), is left as it is and
#   listed.
# - Settings and crew: the template's `tuning` (with the target's own entries kept for the pieces left as they are),
#   `hud.config` (the Geologist tab's mineral targeting), each weapon slot's `config` (the arm's and drone plants'
#   mineral filters) and the crew aboard, as `preferredCrew`, put aboard at once with CurrentGame.gd
#   validateEmployment (as the game does when the player switches ships or a day passes), which redraws the crew's
#   portraits through `employmentChanged`. The game keeps a ship's `preferredCrew` only once its crew changed while it
#   was flown (hireCrewmember, fireCrewmember, setMemberActive); a ship without one has whoever was aboard when the
#   player switched to it. A template without one: its crew is unknown, the current ship's is left as it is, and the
#   dialog says so.
# - Then, as Dealer.gd use() does after a switch: the Fleet screen's `shipChanged` (enceladus/Enceladus.gd shipChanged
#   rebuilds the docked ship from CurrentGame.state.ship, which emits playerShipChanged) and addShips().
#
# Stacking: the parent's _ready is never called (Godot runs every level by itself); checkCurrentAndOwned falls through
# to the parent with `.checkCurrentAndOwned()`; _input is the extension's own (the game's script has none); new
# members start with `_`.

# The Equipment screen: the node of that name next to the Fleet screen among the station's screens
# (enceladus/Enceladus.tscn).
const _SHIP_COPY_PASTE_EQUIPMENT = "Upgrades"
# Metadata of the Fleet screen node: the template's transponder.
const _SHIP_COPY_PASTE_TEMPLATE = "shipCopyPasteTemplate"
# The one slot the game gives a default when a config has none (ships/ship-ctrl.gd getConfigWithDefaults), and the
# ship's property holding it.
const _SHIP_COPY_PASTE_LIDAR_SLOT = "lidar.type"
const _SHIP_COPY_PASTE_LIDAR_DEFAULT = "defaultLidar"
# The entry's nodes the mod reads (enceladus/SystemBuyUI.tscn): the Use button it copies for Copy and Paste; the label
# whose colour marks the template's Copy button (the game's own mark for an owned ship); the node in the Fleet screen's
# prose theme (enceladus/Subwindow.theme, as the ship's description), whose Label font the dialog's lists take.
const _SHIP_COPY_PASTE_USE = "HBox/Use"
const _SHIP_COPY_PASTE_MARK = "HBox/V/Owned"
const _SHIP_COPY_PASTE_PROSE = "HBox/Margin"
# The game's keys for the confirmation's buttons (the entry's Buy confirmation, BuyConfirm and BuyCancel).
const _SHIP_COPY_PASTE_OK = "OK"
const _SHIP_COPY_PASTE_CANCEL = "CANCEL"
# The width of each of the dialog's two lists, as a share of the screen's width; their lines wrap there.
const _SHIP_COPY_PASTE_COLUMN_SHARE = 0.25
# The mod's nodes.
const _SHIP_COPY_PASTE_COPY_NODE = "ShipCopyPasteCopy"
const _SHIP_COPY_PASTE_PASTE_NODE = "ShipCopyPastePaste"
const _SHIP_COPY_PASTE_DIALOG_NODE = "ShipCopyPasteDialog"
# The icons' size when the Use button has no icon to read it from.
const _SHIP_COPY_PASTE_ICON_FALLBACK = Vector2(48, 48)
# The texts (i18n/en.po).
const _SHIP_COPY_PASTE_TIP_COPY = "SHIPCOPYPASTE_COPY"
const _SHIP_COPY_PASTE_TIP_TEMPLATE = "SHIPCOPYPASTE_TEMPLATE"
const _SHIP_COPY_PASTE_TIP_COPY_MODEL = "SHIPCOPYPASTE_COPY_MODEL"
const _SHIP_COPY_PASTE_TIP_PASTE = "SHIPCOPYPASTE_PASTE"
const _SHIP_COPY_PASTE_TIP_PASTE_NOTHING = "SHIPCOPYPASTE_PASTE_NOTHING"
const _SHIP_COPY_PASTE_TEXT_CONFIRM = "SHIPCOPYPASTE_CONFIRM"
const _SHIP_COPY_PASTE_TEXT_COPIED = "SHIPCOPYPASTE_COPIED"
const _SHIP_COPY_PASTE_TEXT_NOT_COPIED = "SHIPCOPYPASTE_NOT_COPIED"
const _SHIP_COPY_PASTE_TEXT_BULLET = "SHIPCOPYPASTE_BULLET"
const _SHIP_COPY_PASTE_TEXT_ITEM_PRICE = "SHIPCOPYPASTE_ITEM_PRICE"
const _SHIP_COPY_PASTE_TEXT_ITEM_REFUND = "SHIPCOPYPASTE_ITEM_REFUND"
const _SHIP_COPY_PASTE_TEXT_TUNING = "SHIPCOPYPASTE_TUNING"
const _SHIP_COPY_PASTE_TEXT_TARGETING = "SHIPCOPYPASTE_TARGETING"
const _SHIP_COPY_PASTE_TEXT_FILTERS = "SHIPCOPYPASTE_FILTERS"
const _SHIP_COPY_PASTE_TEXT_CREW = "SHIPCOPYPASTE_CREW"
const _SHIP_COPY_PASTE_TEXT_CREW_NOBODY = "SHIPCOPYPASTE_CREW_NOBODY"
const _SHIP_COPY_PASTE_TEXT_UNFIT = "SHIPCOPYPASTE_UNFIT"
const _SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN = "SHIPCOPYPASTE_CREW_UNKNOWN"
const _SHIP_COPY_PASTE_TEXT_NOT_COPIED_ALWAYS = [
	"SHIPCOPYPASTE_NAME",
	"SHIPCOPYPASTE_DAMAGE",
	"SHIPCOPYPASTE_MAINTENANCE",
	"SHIPCOPYPASTE_CARGO",
	"SHIPCOPYPASTE_CONSUMABLES",
]
const _SHIP_COPY_PASTE_TEXT_PRICE = "SHIPCOPYPASTE_PRICE"
const _SHIP_COPY_PASTE_TEXT_REFUND = "SHIPCOPYPASTE_REFUND"
const _SHIP_COPY_PASTE_TEXT_SAME = "SHIPCOPYPASTE_SAME"
const _SHIP_COPY_PASTE_TEXT_REPAIRS = "SHIPCOPYPASTE_REPAIRS"
const _SHIP_COPY_PASTE_TEXT_NO_MONEY = "SHIPCOPYPASTE_NO_MONEY"

var _shipCopyPasteCopy = null # the Copy button
var _shipCopyPastePaste = null # the Paste button
var _shipCopyPasteDialog = null # the confirmation dialog, made on the first Paste
var _shipCopyPasteTitle = null # its question
var _shipCopyPasteLists = [] # its two lists: copied, not copied
var _shipCopyPasteSummary = null # its price, repair time and money
var _shipCopyPasteShown = "" # what it shows: OK pastes only a plan that still reads the same
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

# Copy and Paste right before Use, as copies of it.
func _shipCopyPasteBuild():
	var use = get_node_or_null(_SHIP_COPY_PASTE_USE)
	if not use is Button or use.get_parent().has_node(_SHIP_COPY_PASTE_COPY_NODE):
		return
	var copyIcon = _shipCopyPasteIcon(use.icon, false)
	_shipCopyPasteCopy = _shipCopyPasteButton(use, _SHIP_COPY_PASTE_COPY_NODE, copyIcon, "_shipCopyPasteCopyPressed")
	_shipCopyPasteCopy.toggle_mode = true
	var pasteIcon = _shipCopyPasteIcon(use.icon, true)
	_shipCopyPastePaste = _shipCopyPasteButton(use, _SHIP_COPY_PASTE_PASTE_NODE, pasteIcon, "_shipCopyPastePastePressed")

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

# The confirmation dialog: the question in the menu font (the entry's theme, as the game's own dialogs), the two lists
# side by side under their headings, the summary, and the dialog's OK and Cancel. A Popup draws on top of everything and
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
	var box = VBoxContainer.new()
	_shipCopyPasteTitle = Label.new()
	_shipCopyPasteTitle.autowrap = true
	_shipCopyPasteTitle.align = Label.ALIGN_CENTER
	box.add_child(_shipCopyPasteTitle)
	var columns = HBoxContainer.new()
	_shipCopyPasteLists = []
	for heading in [_SHIP_COPY_PASTE_TEXT_COPIED, _SHIP_COPY_PASTE_TEXT_NOT_COPIED]:
		var column = VBoxContainer.new()
		var title = Label.new()
		title.text = heading
		column.add_child(title)
		var list = Label.new()
		list.autowrap = true
		if proseFont != null:
			list.add_font_override("font", proseFont)
		column.add_child(list)
		columns.add_child(column)
		_shipCopyPasteLists.append(list)
	box.add_child(columns)
	_shipCopyPasteSummary = Label.new()
	_shipCopyPasteSummary.autowrap = true
	_shipCopyPasteSummary.align = Label.ALIGN_CENTER
	if proseFont != null:
		_shipCopyPasteSummary.add_font_override("font", proseFont)
	box.add_child(_shipCopyPasteSummary)
	dialog.add_child(box)
	add_child(dialog)
	dialog.connect("confirmed", self, "_shipCopyPasteConfirmPressed")
	dialog.connect("popup_hide", self, "_shipCopyPasteDialogHidden")
	_shipCopyPasteDialog = dialog

# The Copy (two sheets) and Paste (a clipboard) icons, drawn as the Use button's icon (enceladus/Upgrades/switch.png)
# is: at its size and with its flags, light strokes with a dark edge, in its colours.
func _shipCopyPasteIcon(model, paste: bool) -> Texture:
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
	# Paste: a clipboard (a board with a clip on its top edge) with a sheet laid on it; Copy: a sheet on another.
	var parts = [
		Rect2(w * 0.14, h * 0.16, w * 0.56, h * 0.76),
		Rect2(w * 0.28, h * 0.08, w * 0.28, h * 0.16),
		Rect2(w * 0.44, h * 0.42, w * 0.46, h * 0.52),
	]
	if not paste:
		parts = [Rect2(w * 0.1, h * 0.08, w * 0.5, h * 0.6), Rect2(w * 0.4, h * 0.34, w * 0.5, h * 0.6)]
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

# The template's transponder, "" when there is none; a template no longer owned (sold) is forgotten.
func _shipCopyPasteTemplate() -> String:
	var fleet = _shipCopyPasteFleet()
	if fleet == null or not fleet.has_meta(_SHIP_COPY_PASTE_TEMPLATE):
		return ""
	var template = fleet.get_meta(_SHIP_COPY_PASTE_TEMPLATE)
	if CurrentGame.state.ship.get("transponder") == template or _shipCopyPasteGarage(template) != null:
		return template
	_shipCopyPasteForget(fleet)
	return ""

func _shipCopyPasteForget(fleet: Node):
	if fleet.has_meta(_SHIP_COPY_PASTE_TEMPLATE):
		fleet.remove_meta(_SHIP_COPY_PASTE_TEMPLATE)

# An owned ship's full config, not the current one's, by transponder (CurrentGame.state.garage). Only read.
func _shipCopyPasteGarage(template: String):
	for config in CurrentGame.state.get("garage", []):
		if config is Dictionary and config.get("transponder") == template:
			return config
	return null

# The template's full config when this entry can paste it: this entry is the current ship, and the template is another
# owned ship of the same model.
func _shipCopyPasteSource():
	if not owned or not current:
		return null
	var template = _shipCopyPasteTemplate()
	if template == "":
		return null
	var source = _shipCopyPasteGarage(template)
	var mine = CurrentGame.state.ship
	if source == null or template == mine.get("transponder"):
		return null
	if source.get("model") != mine.get("model") or not source.get("config") is Dictionary:
		return null
	return source

# Copy on the other ships' entries, enabled where the ship can be the template (marked when it is); Paste on the current
# ship's, enabled once it can paste; the tooltips say why not otherwise.
func _shipCopyPasteRefresh():
	if not is_instance_valid(_shipCopyPasteCopy) or not is_instance_valid(ship):
		return
	var template = _shipCopyPasteTemplate()
	var isTemplate = template != "" and template == ship.transponder
	var copiable = _shipCopyPasteCopiable()
	_shipCopyPasteCopy.visible = not current
	_shipCopyPasteCopy.disabled = not copiable
	_shipCopyPasteCopy.pressed = isTemplate
	if isTemplate:
		_shipCopyPasteCopy.hint_tooltip = _SHIP_COPY_PASTE_TIP_TEMPLATE
	elif copiable:
		_shipCopyPasteCopy.hint_tooltip = _SHIP_COPY_PASTE_TIP_COPY
	else:
		_shipCopyPasteCopy.hint_tooltip = _SHIP_COPY_PASTE_TIP_COPY_MODEL
	var mark = get_node_or_null(_SHIP_COPY_PASTE_MARK)
	_shipCopyPasteCopy.modulate = mark.modulate if isTemplate and mark is CanvasItem else Color.white
	var can = _shipCopyPasteSource() != null and _shipCopyPasteEquipment() != null
	_shipCopyPastePaste.visible = current
	_shipCopyPastePaste.disabled = not can
	_shipCopyPastePaste.hint_tooltip = _SHIP_COPY_PASTE_TIP_PASTE if can else _SHIP_COPY_PASTE_TIP_PASTE_NOTHING
	if not can:
		_shipCopyPasteClose()

# Whether this entry's ship can be the template: another owned ship of the current ship's model.
func _shipCopyPasteCopiable() -> bool:
	if not owned or current or not is_instance_valid(ship):
		return false
	var mine = CurrentGame.state.ship
	return ship.transponder != mine.get("transponder") and ship.model == mine.get("model")

# Every entry of the list, after the template changed.
func _shipCopyPasteRefreshAll():
	var list = get_parent()
	if list == null:
		_shipCopyPasteRefresh()
		return
	for entry in list.get_children():
		if entry.has_method("_shipCopyPasteRefresh"):
			entry._shipCopyPasteRefresh()

func _shipCopyPasteCopyPressed():
	var fleet = _shipCopyPasteFleet()
	if fleet == null or not is_instance_valid(ship):
		return
	if _shipCopyPasteTemplate() == ship.transponder:
		_shipCopyPasteForget(fleet)
	elif _shipCopyPasteCopiable():
		fleet.set_meta(_SHIP_COPY_PASTE_TEMPLATE, ship.transponder)
	_shipCopyPasteRefreshAll()

# The Fleet screen closed: the template goes.
func _shipCopyPasteFleetVisibility():
	var fleet = _shipCopyPasteFleet()
	if fleet != null and not fleet.visible:
		_shipCopyPasteForget(fleet)
		_shipCopyPasteClose()
	_shipCopyPasteRefresh()

func _shipCopyPastePastePressed():
	var plan = _shipCopyPastePlanNow()
	if plan is GDScriptFunctionState:
		plan = yield(plan, "completed")
	if plan == null:
		_shipCopyPasteRefreshAll()
		return
	_shipCopyPasteDialogBuild()
	_shipCopyPasteShow(plan)
	_shipCopyPasteDialog.get_cancel().grab_focus()

# Fills the dialog with the plan, sized to the screen and centered on it, OK disabled when the player can't pay.
func _shipCopyPasteShow(plan: Dictionary):
	var texts = _shipCopyPasteDescribe(plan)
	_shipCopyPasteShown = JSON.print(texts)
	var column = get_viewport_rect().size.x * _SHIP_COPY_PASTE_COLUMN_SHARE
	var separation = _shipCopyPasteLists[0].get_parent().get_parent().get_constant("separation")
	var contents = [texts.title, PoolStringArray(texts.summary).join("\n")]
	var labels = [_shipCopyPasteTitle, _shipCopyPasteSummary]
	for i in 2:
		var lines = []
		for line in texts.lists[i]:
			lines.append(tr(_SHIP_COPY_PASTE_TEXT_BULLET) % line)
		contents.append(PoolStringArray(lines).join("\n"))
		labels.append(_shipCopyPasteLists[i])
	# Each label's width first, so it wraps its text at that width at once: the lists one column each, the question
	# and the summary both.
	for i in labels.size():
		var width = column if i >= 2 else column * 2 + separation
		labels[i].rect_min_size.x = width
		labels[i].rect_size.x = width
		labels[i].text = contents[i]
	_shipCopyPasteDialog.get_ok().disabled = not plan.affordable
	_shipCopyPasteDialogFit()
	if not _shipCopyPasteDialog.visible:
		_shipCopyPasteDialog.popup_centered()
	_shipCopyPasteDialogFitLater()

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

# Closed by Cancel, OK, Esc or a click outside: the focus goes back to Paste.
func _shipCopyPasteDialogHidden():
	var paste = _shipCopyPastePaste
	if is_instance_valid(paste) and paste.is_visible_in_tree() and not paste.disabled:
		paste.grab_focus()

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
	if JSON.print(_shipCopyPasteDescribe(plan)) != _shipCopyPasteShown or not plan.affordable:
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

# Hides the dialog (the Fleet screen closed, Paste no longer applies, or the paste is done).
func _shipCopyPasteClose():
	if is_instance_valid(_shipCopyPasteDialog) and _shipCopyPasteDialog.visible:
		_shipCopyPasteDialog.hide()

# The plan for the current ship, with the Equipment screen's prices brought up to date first (as it does when it
# shows); null when this entry can't paste. A coroutine only while the player's ship isn't set up.
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
	Tool.release(target)
	return plan

# What Paste does to `target` (the player's ship) from `source` (the template's full config), with the Equipment
# screen's `items`:
# - buy: the items to buy, and prices: what each costs (negative: a refund);
# - kept: the slots left as they are, with the target's value;
# - unfit: the names of what can't be fitted;
# - filters: whether any weapon slot's mineral filters are copied;
# - crew: the crew to put aboard, null when the template's is unknown;
# - price, time (s), affordable; source; name: the template's; target: the current ship's name.
func _shipCopyPastePlan(source: Dictionary, target, items: Array) -> Dictionary:
	var groups = {}
	var order = []
	for item in items:
		if not groups.has(item.slot):
			groups[item.slot] = []
			order.append(item.slot)
		groups[item.slot].append(item)
	var plan = {
		"buy": [],
		"prices": [],
		"kept": {},
		"unfit": [],
		"price": 0.0,
		"time": 0.0,
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
		var pick = null
		for item in group:
			if _shipCopyPasteSame(item.getVal(), want) and item.isAvailable():
				pick = item
				break
		if pick == null:
			plan.kept[slot] = have
			plan.unfit.append(_shipCopyPasteName(group[0], want))
		else:
			var price = pick.getNetPrice()
			plan.buy.append(pick)
			plan.prices.append(price)
			plan.price += price
			plan.time += max(0.0, pick.actualReplacementTime)
	plan.filters = _shipCopyPasteFilters(source.config, target.shipConfig, plan.kept)
	plan.crew = _shipCopyPasteCrew(source)
	plan.affordable = plan.price <= 0 or plan.price <= CurrentGame.getMoney()
	return plan

# Whether either ship has mineral filters in a weapon slot the paste doesn't keep.
func _shipCopyPasteFilters(from: Dictionary, to: Dictionary, kept: Dictionary) -> bool:
	for config in [from, to]:
		var slots = config.weaponSlot if config.get("weaponSlot") is Dictionary else {}
		for slotName in slots:
			if kept.has("weaponSlot.%s.type" % slotName):
				continue
			if slots[slotName] is Dictionary and slots[slotName].has("config"):
				return true
	return false

# The template's crew: those on its crew list still employed; null when it has no list (unknown). Someone fired drops
# off the current ship's list only (CurrentGame.gd fireCrewmember), so a garage ship's list can still name them.
func _shipCopyPasteCrew(source: Dictionary):
	if not source.config.get("preferredCrew") is Array:
		return null
	var employed = CurrentGame.state.get("crew")
	var crew = []
	for memberName in source.config.preferredCrew:
		if employed is Dictionary and employed.has(memberName):
			crew.append(memberName)
	return crew

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

# The dialog's texts for a plan, translated: the question; the copied and not copied lists, one entry per line (each
# piece bought as the Equipment screen names it, with its price); the summary lines.
func _shipCopyPasteDescribe(plan: Dictionary) -> Dictionary:
	var copied = []
	for i in plan.buy.size():
		var price = plan.prices[i]
		var piece = tr(plan.buy[i].getName())
		if price >= 0:
			copied.append(tr(_SHIP_COPY_PASTE_TEXT_ITEM_PRICE) % [piece, CurrentGame.formatThousands(price)])
		else:
			copied.append(tr(_SHIP_COPY_PASTE_TEXT_ITEM_REFUND) % [piece, CurrentGame.formatThousands(-price)])
	copied.append(tr(_SHIP_COPY_PASTE_TEXT_TUNING))
	copied.append(tr(_SHIP_COPY_PASTE_TEXT_TARGETING))
	if plan.filters:
		copied.append(tr(_SHIP_COPY_PASTE_TEXT_FILTERS))
	var notCopied = []
	for piece in plan.unfit:
		notCopied.append(tr(_SHIP_COPY_PASTE_TEXT_UNFIT) % piece)
	if plan.crew is Array and plan.crew.empty():
		copied.append(tr(_SHIP_COPY_PASTE_TEXT_CREW_NOBODY))
	elif plan.crew is Array:
		copied.append(tr(_SHIP_COPY_PASTE_TEXT_CREW) % PoolStringArray(plan.crew).join(", "))
	else:
		notCopied.append(tr(_SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN) % plan.name)
	for key in _SHIP_COPY_PASTE_TEXT_NOT_COPIED_ALWAYS:
		notCopied.append(tr(key))
	var summary = []
	if plan.buy.empty():
		summary.append(tr(_SHIP_COPY_PASTE_TEXT_SAME))
	elif plan.price >= 0:
		summary.append(tr(_SHIP_COPY_PASTE_TEXT_PRICE) % CurrentGame.formatThousands(plan.price))
	else:
		summary.append(tr(_SHIP_COPY_PASTE_TEXT_REFUND) % CurrentGame.formatThousands(-plan.price))
	if plan.time > 0:
		summary.append(tr(_SHIP_COPY_PASTE_TEXT_REPAIRS) % Tool.readableTimeSpan(plan.time))
	if not plan.affordable:
		summary.append(tr(_SHIP_COPY_PASTE_TEXT_NO_MONEY))
	return {
		"title": tr(_SHIP_COPY_PASTE_TEXT_CONFIRM) % [plan.target, plan.name],
		"lists": [copied, notCopied],
		"summary": summary,
	}

# Applies the plan to `target`, the player's ship, whose shipConfig is CurrentGame.state.ship's config: each item as
# Upgrades.gd buy() fits it, then the settings and the crew, then the money, the log and the repair time, and puts the
# crew aboard.
func _shipCopyPasteApply(plan: Dictionary, target) -> void:
	var details = {}
	for i in plan.buy.size():
		var item = plan.buy[i]
		target.clearDamageInSlot(item.slot)
		target.setConfig(item.slot, item.getVal())
		details[item.system] = details.get(item.system, 0.0) - plan.prices[i]
	_shipCopyPasteSettings(plan.source.config, target.shipConfig, plan.kept, plan.crew)
	if not plan.buy.empty():
		CurrentGame.changeMoney(-plan.price)
		details["LOG_EVENT_DETAILS_COST"] = -plan.price
		CurrentGame.logEvent("LOG_EVENT_UPGRADE", details)
	if plan.time > 0:
		CurrentGame.addShipMaintanenceTime(plan.time)
	if plan.crew is Array and CurrentGame.has_method("validateEmployment"):
		CurrentGame.validateEmployment()

# The template's settings and crew into the target's config: its tuning, keeping the target's own entries for the
# pieces `kept` (a slot-mounted piece's are filed under "<slot>_<system>": WeaponSlot.gd, ThrusterSlot.gd
# loadPlaceholder); its mineral targeting; each weapon slot's config, but for the slots kept; the `crew` aboard, left
# as it is when null.
func _shipCopyPasteSettings(from: Dictionary, to: Dictionary, kept: Dictionary, crew) -> void:
	var tuning = from.tuning.duplicate(true) if from.get("tuning") is Dictionary else {}
	var own = to.get("tuning")
	if own is Dictionary:
		for slot in kept:
			if kept[slot] is String:
				var path = ("%s_%s" % [slot, kept[slot]]).split(".")
				var entry = _shipCopyPasteDig(own, path)
				if entry != null:
					_shipCopyPastePut(tuning, path, entry)
	to.tuning = tuning
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
	if crew is Array:
		to.preferredCrew = crew.duplicate()

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

extends "res://enceladus/SystemBuyUI.gd"

# ShipCopyPaste: on the Fleet screen, Copy makes a ship the template and Paste makes the current ship like it, for two
# ships of the same model: the same equipment, bought as the Equipment screen sells it, and the same Tuning, mineral
# targeting and crew aboard.
#
# The Fleet screen (enceladus/Owned.tscn, an instance of Dealer.tscn) lists the owned ships as entries of this script;
# the ship market uses the same script for the ships for sale (`owned` false), which the mod leaves alone.
#
# - Copy, on every Fleet entry but the current ship's (the only one Paste can change): that ship becomes the template.
#   Its transponder is kept as metadata of the Fleet screen node, and dropped when the screen closes (Dealer.gd hide():
#   its `hide` animation ends with the node invisible). Nothing is saved.
# - Paste, on the current ship's entry only, when the template is another owned ship of the same model (the ship
#   configs' `model`). It opens a copy of the entry's Buy confirmation (ConfirmationCenter/BuyPanel, which a Fleet entry
#   never uses) with the price, the repair time and what can't be fitted, shown and hidden by copies of the entry's
#   BuyShow / BuyHide animations, retargeted to the copy and to the Paste button.
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
#   confirmation says so.
# - Then, as Dealer.gd use() does after a switch: the Fleet screen's `shipChanged` (enceladus/Enceladus.gd shipChanged
#   rebuilds the docked ship from CurrentGame.state.ship, which emits playerShipChanged) and addShips().
#
# Stacking: the parent's _ready is never called (Godot runs every level by itself); checkCurrentAndOwned falls through
# to the parent with `.checkCurrentAndOwned()`; new members start with `_`.

# The Equipment screen: the node of that name next to the Fleet screen among the station's screens
# (enceladus/Enceladus.tscn).
const _SHIP_COPY_PASTE_EQUIPMENT = "Upgrades"
# Metadata of the Fleet screen node: the template's transponder.
const _SHIP_COPY_PASTE_TEMPLATE = "shipCopyPasteTemplate"
# The one slot the game gives a default when a config has none (ships/ship-ctrl.gd getConfigWithDefaults), and the
# ship's property holding it.
const _SHIP_COPY_PASTE_LIDAR_SLOT = "lidar.type"
const _SHIP_COPY_PASTE_LIDAR_DEFAULT = "defaultLidar"
# The entry's nodes the mod copies (enceladus/SystemBuyUI.tscn): the Use button, the Buy button the Buy confirmation's
# animations show and hide, the Buy confirmation, its label and buttons, and its animations.
const _SHIP_COPY_PASTE_USE = "HBox/Use"
const _SHIP_COPY_PASTE_BUY = "HBox/Buy"
const _SHIP_COPY_PASTE_BUY_PANEL = "ConfirmationCenter/BuyPanel"
const _SHIP_COPY_PASTE_PANEL_TEXT = "MarginContainer/VBoxContainer/BuyPrice"
const _SHIP_COPY_PASTE_PANEL_OK = "MarginContainer/VBoxContainer/HBoxContainer/BuyConfirm"
const _SHIP_COPY_PASTE_PANEL_CANCEL = "MarginContainer/VBoxContainer/HBoxContainer/BuyCancel"
const _SHIP_COPY_PASTE_PLAYER = "ConfirmationPlayer"
const _SHIP_COPY_PASTE_BUY_SHOW = "BuyShow"
const _SHIP_COPY_PASTE_BUY_HIDE = "BuyHide"
# The label whose colour marks the template's Copy button: the game's own mark for an owned ship.
const _SHIP_COPY_PASTE_MARK = "HBox/V/Owned"
# The label whose font the confirmation's text takes: the entry's registration, in its small font.
const _SHIP_COPY_PASTE_SMALL_TEXT = "HBox/V/Registration"
# The share of the entry's width the confirmation's text may take; it wraps there, and the confirmation (right-aligned
# in the entry, as the game places it) never grows wider than the entry.
const _SHIP_COPY_PASTE_TEXT_SHARE = 0.5
# The mod's nodes and animations.
const _SHIP_COPY_PASTE_COPY_NODE = "ShipCopyPasteCopy"
const _SHIP_COPY_PASTE_PASTE_NODE = "ShipCopyPastePaste"
const _SHIP_COPY_PASTE_PANEL_NODE = "ShipCopyPastePanel"
const _SHIP_COPY_PASTE_SHOW = "ShipCopyPasteShow"
const _SHIP_COPY_PASTE_HIDE = "ShipCopyPasteHide"
# The icons' size when the Use button has no icon to read it from.
const _SHIP_COPY_PASTE_ICON_FALLBACK = Vector2(48, 48)
# The texts (i18n/en.po).
const _SHIP_COPY_PASTE_TIP_COPY = "SHIPCOPYPASTE_COPY"
const _SHIP_COPY_PASTE_TIP_TEMPLATE = "SHIPCOPYPASTE_TEMPLATE"
const _SHIP_COPY_PASTE_TIP_PASTE = "SHIPCOPYPASTE_PASTE"
const _SHIP_COPY_PASTE_TEXT_CONFIRM = "SHIPCOPYPASTE_CONFIRM"
const _SHIP_COPY_PASTE_TEXT_PRICE = "SHIPCOPYPASTE_PRICE"
const _SHIP_COPY_PASTE_TEXT_REFUND = "SHIPCOPYPASTE_REFUND"
const _SHIP_COPY_PASTE_TEXT_SAME = "SHIPCOPYPASTE_SAME"
const _SHIP_COPY_PASTE_TEXT_REPAIRS = "SHIPCOPYPASTE_REPAIRS"
const _SHIP_COPY_PASTE_TEXT_UNFIT = "SHIPCOPYPASTE_UNFIT"
const _SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN = "SHIPCOPYPASTE_CREW_UNKNOWN"
const _SHIP_COPY_PASTE_TEXT_NO_MONEY = "SHIPCOPYPASTE_NO_MONEY"

var _shipCopyPasteCopy = null # the Copy button
var _shipCopyPastePaste = null # the Paste button
var _shipCopyPastePanel = null # the confirmation: a copy of the Buy confirmation
var _shipCopyPasteText = null # its label
var _shipCopyPasteOk = null # its OK button
var _shipCopyPasteShown = "" # the text it shows: OK pastes only a plan that still reads the same

func _ready():
	if not owned:
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

# Copy and Paste right before Use, as copies of it; the confirmation, a copy of the Buy confirmation.
func _shipCopyPasteBuild():
	var use = get_node_or_null(_SHIP_COPY_PASTE_USE)
	var source = get_node_or_null(_SHIP_COPY_PASTE_BUY_PANEL)
	var player = get_node_or_null(_SHIP_COPY_PASTE_PLAYER)
	if not use is Button or not source is Control or not player is AnimationPlayer or use.get_parent().has_node(_SHIP_COPY_PASTE_COPY_NODE):
		return
	_shipCopyPasteCopy = _shipCopyPasteButton(use, _SHIP_COPY_PASTE_COPY_NODE, _shipCopyPasteIcon(use.icon, false), "_shipCopyPasteCopyPressed")
	_shipCopyPasteCopy.toggle_mode = true
	_shipCopyPastePaste = _shipCopyPasteButton(use, _SHIP_COPY_PASTE_PASTE_NODE, _shipCopyPasteIcon(use.icon, true), "_shipCopyPastePastePressed")
	_shipCopyPastePaste.hint_tooltip = _SHIP_COPY_PASTE_TIP_PASTE
	# Without the scene's connections, which call the entry's Buy handlers.
	_shipCopyPastePanel = source.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANCING)
	_shipCopyPastePanel.name = _SHIP_COPY_PASTE_PANEL_NODE
	_shipCopyPastePanel.visible = false
	source.get_parent().add_child(_shipCopyPastePanel)
	_shipCopyPasteText = _shipCopyPastePanel.get_node_or_null(_SHIP_COPY_PASTE_PANEL_TEXT)
	if _shipCopyPasteText is Label:
		# The game's label holds one short price in the menu font; this one holds several lines.
		_shipCopyPasteText.autowrap = true
		_shipCopyPasteText.align = Label.ALIGN_LEFT
		_shipCopyPasteText.valign = Label.VALIGN_CENTER
		var small = get_node_or_null(_SHIP_COPY_PASTE_SMALL_TEXT)
		if small is Control:
			_shipCopyPasteText.add_font_override("font", small.get_font("font"))
	_shipCopyPasteOk = _shipCopyPastePanel.get_node_or_null(_SHIP_COPY_PASTE_PANEL_OK)
	var cancel = _shipCopyPastePanel.get_node_or_null(_SHIP_COPY_PASTE_PANEL_CANCEL)
	if _shipCopyPasteOk is BaseButton:
		_shipCopyPasteOk.connect("pressed", self, "_shipCopyPasteConfirmPressed")
	if cancel is BaseButton:
		cancel.connect("pressed", self, "_shipCopyPasteCancelPressed")
	_shipCopyPasteAnimations(player, source)

# A copy of the Use button (its look, size, icon size and smooth scrolling), without its connections.
func _shipCopyPasteButton(model: Button, nodeName: String, icon: Texture, method: String) -> Button:
	var button = model.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANCING)
	button.name = nodeName
	button.icon = icon
	button.disabled = false
	button.visible = false
	var box = model.get_parent()
	box.add_child(button)
	box.move_child(button, model.get_index())
	button.connect("pressed", self, method)
	button.connect("focus_entered", self, "_on_Use_focus_entered")
	return button

# The Buy confirmation's animations, retargeted to the copy and to the Paste button: shown, the Paste button hides as
# the Buy button does; hidden, it comes back and takes the focus.
func _shipCopyPasteAnimations(player: AnimationPlayer, source: Node):
	var panel = String(get_path_to(source))
	var pairs = [[_SHIP_COPY_PASTE_BUY_SHOW, _SHIP_COPY_PASTE_SHOW], [_SHIP_COPY_PASTE_BUY_HIDE, _SHIP_COPY_PASTE_HIDE]]
	for pair in pairs:
		if not player.has_animation(pair[0]) or player.has_animation(pair[1]):
			continue
		var animation = player.get_animation(pair[0]).duplicate()
		for i in animation.get_track_count():
			var path = String(animation.track_get_path(i))
			path = _shipCopyPasteRetarget(path, panel, String(get_path_to(_shipCopyPastePanel)))
			path = _shipCopyPasteRetarget(path, _SHIP_COPY_PASTE_BUY, String(get_path_to(_shipCopyPastePaste)))
			animation.track_set_path(i, NodePath(path))
		player.add_animation(pair[1], animation)

# `path` with the node `from` (or a node below it, or a property of it) moved to `to`.
func _shipCopyPasteRetarget(path: String, from: String, to: String) -> String:
	if path == from or path.begins_with(from + "/") or path.begins_with(from + ":"):
		return to + path.substr(from.length())
	return path

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
	var parts = [[Rect2(w * 0.14, h * 0.16, w * 0.56, h * 0.76)], [Rect2(w * 0.28, h * 0.08, w * 0.28, h * 0.16)], [Rect2(w * 0.44, h * 0.42, w * 0.46, h * 0.52)]]
	if not paste:
		parts = [[Rect2(w * 0.1, h * 0.08, w * 0.5, h * 0.6)], [Rect2(w * 0.4, h * 0.34, w * 0.5, h * 0.6)]]
	for part in parts:
		_shipCopyPasteMark(mask, w, h, part[0].grow(edge + 1), false)
		_shipCopyPasteFrame(mask, w, h, part[0], stroke)
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
	if source == null or template == mine.get("transponder") or source.get("model") != mine.get("model") or not source.get("config") is Dictionary:
		return null
	return source

# Shows Copy (marked on the template) on the other ships' entries and, where it can paste, Paste.
func _shipCopyPasteRefresh():
	if not is_instance_valid(_shipCopyPasteCopy) or not is_instance_valid(ship):
		return
	var template = _shipCopyPasteTemplate()
	var isTemplate = template != "" and template == ship.transponder
	_shipCopyPasteCopy.visible = not current
	_shipCopyPasteCopy.pressed = isTemplate
	_shipCopyPasteCopy.hint_tooltip = _SHIP_COPY_PASTE_TIP_TEMPLATE if isTemplate else _SHIP_COPY_PASTE_TIP_COPY
	var mark = get_node_or_null(_SHIP_COPY_PASTE_MARK)
	_shipCopyPasteCopy.modulate = mark.modulate if isTemplate and mark is CanvasItem else Color.white
	var can = _shipCopyPasteSource() != null and _shipCopyPasteEquipment() != null
	if _shipCopyPastePanel.visible:
		if not can:
			_shipCopyPasteClose()
	else:
		_shipCopyPastePaste.visible = can

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
	else:
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
	_shipCopyPasteShow(plan)
	get_node(_SHIP_COPY_PASTE_PLAYER).queue(_SHIP_COPY_PASTE_SHOW)

func _shipCopyPasteShow(plan: Dictionary):
	_shipCopyPasteShown = _shipCopyPasteDescribe(plan)
	if _shipCopyPasteText is Label:
		_shipCopyPasteText.text = _shipCopyPasteShown
		_shipCopyPasteFit()
	if _shipCopyPasteOk is BaseButton:
		_shipCopyPasteOk.disabled = not plan.affordable

# The text's width: _SHIP_COPY_PASTE_TEXT_SHARE of the entry, and never so wide that the confirmation (the text, the
# buttons, the margins) passes the entry's width, which would widen every entry of the list.
func _shipCopyPasteFit():
	_shipCopyPasteText.rect_min_size.x = 0
	var width = rect_size.x - get_constant("margin_left") - get_constant("margin_right")
	var rest = _shipCopyPastePanel.get_combined_minimum_size().x
	_shipCopyPasteText.rect_min_size.x = max(0.0, min(width * _SHIP_COPY_PASTE_TEXT_SHARE, width - rest))

func _shipCopyPasteCancelPressed():
	get_node(_SHIP_COPY_PASTE_PLAYER).queue(_SHIP_COPY_PASTE_HIDE)

# Pastes the plan as it is now, if it still reads as shown; otherwise shows the new one.
func _shipCopyPasteConfirmPressed():
	if not _shipCopyPasteOk is BaseButton or _shipCopyPasteOk.disabled:
		return
	_shipCopyPasteOk.disabled = true
	var plan = _shipCopyPastePlanNow()
	if plan is GDScriptFunctionState:
		plan = yield(plan, "completed")
	if plan == null:
		_shipCopyPasteCancelPressed()
		return
	if _shipCopyPasteDescribe(plan) != _shipCopyPasteShown or not plan.affordable:
		_shipCopyPasteShow(plan)
		return
	var target = CurrentGame.getPlayerShip()
	if not Tool.claim(target):
		_shipCopyPasteCancelPressed()
		return
	_shipCopyPasteApply(plan, target)
	Tool.release(target)
	_shipCopyPasteCancelPressed()
	var fleet = _shipCopyPasteFleet()
	if fleet != null:
		fleet.emit_signal("shipChanged")
		fleet.addShips()

# Hides the confirmation at once (the Fleet screen closed, or Paste no longer applies).
func _shipCopyPasteClose():
	if not is_instance_valid(_shipCopyPastePanel):
		return
	var player = get_node_or_null(_SHIP_COPY_PASTE_PLAYER)
	if player is AnimationPlayer and player.is_playing() and player.current_animation in [_SHIP_COPY_PASTE_SHOW, _SHIP_COPY_PASTE_HIDE]:
		player.stop()
	_shipCopyPastePanel.visible = false

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
# - crew: the crew to put aboard, null when the template's is unknown;
# - price, time (s), affordable; source; name: the template's.
func _shipCopyPastePlan(source: Dictionary, target, items: Array) -> Dictionary:
	var groups = {}
	var order = []
	for item in items:
		if not groups.has(item.slot):
			groups[item.slot] = []
			order.append(item.slot)
		groups[item.slot].append(item)
	var plan = {"buy": [], "prices": [], "kept": {}, "unfit": [], "price": 0.0, "time": 0.0, "source": source, "name": CurrentGame.getShipNameByTransponder(source.get("transponder", ""))}
	for slot in order:
		if slot == "":
			continue
		var group = groups[slot]
		var numeric = false
		for item in group:
			numeric = numeric or item.numVal != -1
		var want = _shipCopyPasteValue(target, slot, source.config, numeric)
		var have = _shipCopyPasteValue(target, slot, target.shipConfig, numeric)
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
	plan.crew = _shipCopyPasteCrew(source)
	plan.affordable = plan.price <= 0 or plan.price <= CurrentGame.getMoney()
	return plan

# The template's crew: its crew list; null when it has none (unknown).
func _shipCopyPasteCrew(source: Dictionary):
	if source.config.get("preferredCrew") is Array:
		return source.config.preferredCrew
	return null

# A slot's value in `config`, read as the Equipment screen reads the player's (Upgrades.gd updatePricesAndAvailability):
# the lidar's default where there is none, and nothing in a numeric slot is 0.
func _shipCopyPasteValue(target, slot: String, config: Dictionary, numeric: bool):
	var value = target.getConfig(slot, null, config)
	if value == null and slot == _SHIP_COPY_PASTE_LIDAR_SLOT and _SHIP_COPY_PASTE_LIDAR_DEFAULT in target:
		value = target.get(_SHIP_COPY_PASTE_LIDAR_DEFAULT)
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

# What the confirmation calls a piece it can't fit: a system's name, or the slot's group title (UpgradeGroup.gd
# openButton) with the number.
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

func _shipCopyPasteDescribe(plan: Dictionary) -> String:
	var lines = [tr(_SHIP_COPY_PASTE_TEXT_CONFIRM) % plan.name]
	if plan.buy.empty():
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_SAME))
	elif plan.price >= 0:
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_PRICE) % CurrentGame.formatThousands(plan.price))
	else:
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_REFUND) % CurrentGame.formatThousands(-plan.price))
	if plan.time > 0:
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_REPAIRS) % Tool.readableTimeSpan(plan.time))
	if not plan.unfit.empty():
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_UNFIT) % PoolStringArray(plan.unfit).join(", "))
	if plan.crew == null:
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_CREW_UNKNOWN) % plan.name)
	if not plan.affordable:
		lines.append(tr(_SHIP_COPY_PASTE_TEXT_NO_MONEY))
	return PoolStringArray(lines).join("\n")

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

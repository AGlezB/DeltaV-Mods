extends "res://enceladus/Repairs.gd"

# The Repairs screen (enceladus/Repairs.gd), with ShipRepairAdvisor's row at its bottom: the Repair button, which brings
# every damaged system of the ship up to the target condition (Settings.gd) the cheapest way, beside it a table of that
# target, what the button will cost, from the insurance and the cash, and how long it will take, and the Park button,
# which readies the ship to hold cash: every slot of the Equipment screen on its cheapest piece, empty where it can be,
# and every system at _SRA_PARK_TARGET, after a confirmation of what that costs or brings and how long it takes
# (ParkDialog.gd).
# Both work only through the game's own buttons, and only those the game has enabled, so each step is the game's: its
# price, its maintenance time, the crew's experience, the log and the achievements, as a click would make them. Repairs
# are pressed on the screen's own rows (enceladus/SystemShipRepairUI.gd), Fix and Replace, paid by the insurance first;
# purchases on the Equipment screen's own items (enceladus/SystemShipUpgradeUI.gd), Buy, paid from the cash. The plans
# are Advisor.gd's, fed what the rows and the items show and the rules by which they enable their buttons.
# Shift+Click on the Repair button opens ShipRepairAdvisor's settings instead of repairing, even while the button is
# disabled, and so does its gamepad twin on the highlighted button (a Shift badge inside it says so in its tooltip);
# closing them brings the Repairs screen back.

const ShipRepairAdvisor = preload("res://ShipRepairAdvisor/Settings.gd")
const _SRA_ADVISOR = preload("res://ShipRepairAdvisor/Advisor.gd")
const _SRA_SETTINGS_UI = preload("res://ShipRepairAdvisor/SettingsUI.gd")
const _SRA_PARK_DIALOG = preload("res://ShipRepairAdvisor/ParkDialog.gd")
# The badges' script: their look, and their tooltip as their only interaction.
const _SRA_BADGE_SCRIPT = preload("res://ShipRepairAdvisor/Badge.gd")
# The Shift badge's tooltip, a translation key of i18n/en.po: %s the Shift key, %s the mod's name. And the same while
# the game is played with a gamepad (Badge.gd setShiftTooltips): the button to press, the one to hold, the mod's name.
const _SRA_SETTINGS_TOOLTIP = "SHIPREPAIRADVISOR_SETTINGS_TOOLTIP"
const _SRA_SETTINGS_TOOLTIP_PAD = "SHIPREPAIRADVISOR_SETTINGS_TOOLTIP_PAD"
# The game's tooltip node (with its sounds), as each of the screen's rows instances it.
const _SRA_GAME_TOOLTIPS = "res://menu/sfx/PlaySoundsOnTheseButtons.tscn"
# The station's right-hand screens (this screen's siblings, enceladus/Enceladus.tscn) the mod uses: the Tuning screen,
# whose description window the settings screen copies; the Equipment screen, where Park buys; the Fleet screen, whose
# colours for money Park's confirmation takes.
const _SRA_TUNING = "Tuning"
const _SRA_EQUIPMENT = "Upgrades"
const _SRA_FLEET = "Owned"
# The Fleet screen's colours for money (Dealer.gd displayShip: coming in in colorPlus, going out in colorMinus), and
# Dealer.gd's own values, used only where the screen has none.
const _SRA_COLOR_PLUS = "colorPlus"
const _SRA_COLOR_MINUS = "colorMinus"
const _SRA_COLOR_PLUS_FALLBACK = Color(0.5, 1.0, 0.5, 1)
const _SRA_COLOR_MINUS_FALLBACK = Color(1.0, 0.5, 0.5, 1)
# The screen's title (enceladus/Repairs.tscn), a translation key the label translates itself, which the settings
# screen's header takes; and the margins around the list of rows, which make room for the mod's row under it.
const _SRA_HEADER_TITLE = "HeaderWithMoney/VBoxContainer2/Label"
const _SRA_LIST_MARGIN = "MarginContainer"
# Translation keys of i18n/en.po. The buttons; the target's value in the table (%s the target, in %); the table's names
# under the target's, in order (what the insurance pays, what the cash pays, the two together, the maintenance time); an
# amount of money (%s). The target's name is the setting's own (Settings.gd SETTINGS.target.label).
const _SRA_REPAIR = "SHIPREPAIRADVISOR_REPAIR"
const _SRA_PARK = "SHIPREPAIRADVISOR_PARK"
const _SRA_PERCENT = "SHIPREPAIRADVISOR_PERCENT"
const _SRA_INSURANCE_COST = "SHIPREPAIRADVISOR_INSURANCE_COST"
const _SRA_CASH_COST = "SHIPREPAIRADVISOR_CASH_COST"
const _SRA_TOTAL_COST = "SHIPREPAIRADVISOR_TOTAL_COST"
const _SRA_TIME = "SHIPREPAIRADVISOR_TIME"
const _SRA_TABLE = [_SRA_INSURANCE_COST, _SRA_CASH_COST, _SRA_TOTAL_COST, _SRA_TIME]
const _SRA_MONEY = "SHIPREPAIRADVISOR_MONEY"
# Park's confirmation: the question (%s the condition); its lines' names (the time's is the table's); money coming in,
# going out and none (%s the amount); the notes: the money missing (%s), the systems nothing brings to the condition
# (%s the condition, %s the list), and each of them in the list (%s its name, %s its condition).
const _SRA_PARK_CONFIRM = "SHIPREPAIRADVISOR_PARK_CONFIRM"
const _SRA_INSURANCE = "SHIPREPAIRADVISOR_INSURANCE"
const _SRA_CASH = "SHIPREPAIRADVISOR_CASH"
const _SRA_TOTAL = "SHIPREPAIRADVISOR_TOTAL"
const _SRA_PLUS = "SHIPREPAIRADVISOR_PLUS"
const _SRA_MINUS = "SHIPREPAIRADVISOR_MINUS"
const _SRA_ZERO = "SHIPREPAIRADVISOR_ZERO"
const _SRA_PARK_NEEDED = "SHIPREPAIRADVISOR_PARK_NEEDED"
const _SRA_PARK_UNREACHABLE = "SHIPREPAIRADVISOR_PARK_UNREACHABLE"
const _SRA_PARK_SYSTEM = "SHIPREPAIRADVISOR_PARK_SYSTEM"
const _SRA_LIST_SEPARATOR = ", "
# The decimals of a condition the confirmation names, rounded down, so that one just short of the target never reads
# as the target; and how far above float error the rounding looks, so that 99.7 worked out as 99.6999… still reads
# 99.7.
const _SRA_CONDITION_DECIMALS = 1
const _SRA_CONDITION_GUARD = 0.000001
# The condition Park leaves every system at, in %.
const _SRA_PARK_TARGET = 100.0
# The cash's part shows in this colour while it would leave the cash below zero: the rows' colorBad
# (enceladus/SystemShipRepairUI.gd, the failed inspection's), read from a row; this is the game's, for a screen without
# rows.
const _SRA_WARNING_FALLBACK = Color(1.0, 0.1, 0.1, 1)
# The gap between the list of rows and the mod's row, in px.
const _SRA_ROW_GAP = 8
# The most Fix clicks a system's plan looks ahead: each one halves its damage, so past these, nothing is left to fix.
const _SRA_MAX_CLICKS = 20
# The most rounds of presses each step of the buttons makes, each one press per row at most, or one purchase, as a
# safeguard against a step that doesn't do what the plan expects.
const _SRA_MAX_ROUNDS = 60
# The physics frames a round waits after its presses before reading the systems again: thrusters and the arm work out
# their condition on the next one (Tool.deferCallInPhysics from thruster.gd and DockingArm.gd computeStatus).
const _SRA_SETTLE_FRAMES = 2
# The most physics frames Park waits, after a purchase, for the station to build the ship again (Upgrades.gd buy, then
# Enceladus.gd shipChanged, which ends in CurrentGame's playerShipChanged once the ship is set up), as a safeguard.
const _SRA_SHIP_WAIT_FRAMES = 600
# The trial ship Park's confirmation reads the repairs on (_sraParkExact): its place, a viewport of its own on this screen,
# with its own world, never drawn; and the frames it gets to set itself up (its systems load into it once it is in the
# tree).
const _SRA_TRIAL_NODE = "ShipRepairAdvisorTrial"
const _SRA_TRIAL_SIZE = Vector2(2, 2)
const _SRA_TRIAL_FRAMES = 300
# Replace is offered only below this condition (SystemShipRepairUI.gd isReplaceable).
const _SRA_REPLACE_BELOW = 99.5
# The share of a system's condition its listed damage must leave unexplained before the plan takes it as damage no
# repair clears (DockingArm.gd doComputeStatus counts an overheat its damage list doesn't show), above float error.
const _SRA_UNEXPLAINED = 0.001
# The least rise of a system's condition, in %, that counts a press as a repair.
const _SRA_PROGRESS = 0.01
# What a round of presses works towards: the Repair button's plan, Park's Fixes before trading in, Park's repairs.
const _SRA_ROUNDS_REPAIR = 0
const _SRA_ROUNDS_PARK_FIXES = 1
const _SRA_ROUNDS_PARK_REPAIRS = 2

var _sraSettings = null
var _sraRow = null # the mod's row at the bottom of the screen
var _sraTargetValue = null # the target's value, the table's first line
var _sraValues = [] # the table's values under it, in _SRA_TABLE's order
var _sraButton = null # the Repair button
var _sraParkButton = null
var _sraParkDialog = null # Park's confirmation, made on first use
var _sraShiftBadge = null # the Shift badge inside the Repair button
var _sraTooltips = null # the game's tooltip node that shows the badge's tooltip
var _sraTooltipOffset = Vector2() # that node's own offset of a tooltip from under its control (tooltipExtraOffset)
var _sraSettingsScreen = null # the settings screen, made on first use
var _sraQueued = false
var _sraRunning = false # while either button works
var _sraLeftOut = {} # the systems a press didn't repair, left out for the rest of the button's step, by system key
var _sraLeftOutSlots = {} # the slots Park couldn't buy for, left out for the rest of its purchases
var _sraShipChanges = 0 # how many times the station has set up a new player ship (playerShipChanged)
var _sraParkChecking = false # while Park's confirmation is worked out on the trial ship

# The base _ready runs first. The row follows everything that changes the plans: the money (any purchase, the repairs
# themselves), the crew and the time (the mechanic's repair limit and speed, which their morale moves), the settings,
# the rows (a repair by hand), a new ship, and the screen showing. It is worked out once per frame, after the game's own
# handlers. The station is built anew after every load and new game, so the settings loaded here are the save game's
# own.
func _ready():
	_sraSettings = ShipRepairAdvisor.shared()
	_sraSettings.loadFromState()
	_sraSettings.connect("settingsChanged", self, "_sraQueue")
	for signalName in ["dayPassed", "hourPassed", "moneyOrInsuranceChanged", "employmentChanged"]:
		if CurrentGame.has_signal(signalName):
			CurrentGame.connect(signalName, self, "_sraQueue")
	if CurrentGame.has_signal("playerShipChanged"):
		CurrentGame.connect("playerShipChanged", self, "_sraShipChanged")
	connect("visibility_changed", self, "_sraVisibilityChanged")
	set_process(false)
	_sraBuildRow()
	_sraQueue()

# The row at the bottom of the screen, across its width as the header is. The screen's panel lays each of its children
# over all of it (the header at the top, the list under the header's height), so the row asks for the bottom only, at
# its own height (SIZE_SHRINK_END), and the list's margin keeps the rows clear of it. On its right, the Repair button
# with its badge inside it and the Park button after it, at the row's bottom, and right before them, at its own width, a
# table of the target condition, what the Repair button will cost and how long it will take. The row ends as
# far above the panel's frame as Park's frame, which ends the row, ends from the frame's side (_sraBottomMargin). Its
# texts are in the small font the badge has (Badge.gd SMALL_FONT_THEME).
func _sraBuildRow():
	_sraRow = MarginContainer.new()
	_sraRow.name = "ShipRepairAdvisor"
	_sraRow.size_flags_vertical = SIZE_SHRINK_END
	_sraRow.add_constant_override("margin_top", _SRA_ROW_GAP)
	add_child(_sraRow)
	var row = HBoxContainer.new()
	row.name = "Row"
	_sraRow.add_child(row)
	var font = _sraSmallFont()
	var table = GridContainer.new()
	table.name = "Table"
	table.columns = 2
	table.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	table.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(table)
	_sraTargetValue = _sraTableLine(table, font, ShipRepairAdvisor.SETTINGS.target.label)
	_sraValues = []
	for key in _SRA_TABLE:
		_sraValues.append(_sraTableLine(table, font, key))
	var actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.size_flags_vertical = SIZE_SHRINK_END
	row.add_child(actions)
	_sraButton = _sraActionButton(actions, "Repair", _SRA_REPAIR, "_sraRepair")
	_sraParkButton = _sraActionButton(actions, "Park", _SRA_PARK, "_sraParkPressed")
	_sraRow.add_constant_override("margin_bottom", _sraBottomMargin(_sraParkButton))
	# The settings open in this screen's place among the station's right-hand screens
	# (enceladus/HidingMarginContainer.gd); without them, there is no badge and Shift+Click is a plain click.
	if get_parent() != null and get_parent().has_signal("hidefoka"):
		_sraShiftBadge = _sraMakeShiftBadge()
		_sraFitBadge()
		_sraAttachTooltips(row)
		_sraButton.connect("gui_input", self, "_sraOnRepairInput")
	_sraRow.connect("minimum_size_changed", self, "_sraFitList")
	_sraRow.connect("resized", self, "_sraFitList")
	_sraFitList()

func _sraActionButton(box, nodeName: String, text: String, method: String) -> Button:
	var button = Button.new()
	button.name = nodeName
	button.text = text
	button.disabled = true
	button.connect("pressed", self, method)
	box.add_child(button)
	return button

# The row's margin under the buttons, so that the frame of `button`, which ends the row, ends as far from the panel's
# frame at the bottom as at the right. Each frame is drawn its stylebox's expand margin outside its rect (the station's
# screens, menu/PanelWithHugeShadow.tres: at the sides only), and the panel keeps its content its stylebox's content
# margin inside the rect.
func _sraBottomMargin(button: Button) -> int:
	var panel = get_stylebox("panel")
	var frame = button.get_stylebox("normal")
	var right = _sraExpand(panel, "right") + (panel.get_margin(MARGIN_RIGHT) if panel != null else 0.0) \
			- _sraExpand(frame, "right")
	var bottom = _sraExpand(panel, "bottom") + (panel.get_margin(MARGIN_BOTTOM) if panel != null else 0.0) \
			- _sraExpand(frame, "bottom")
	return int(max(0, round(right - bottom)))

# How far `style` draws outside its control's rect on `side` (StyleBoxFlat and StyleBoxTexture expand_margin_*).
func _sraExpand(style, side: String) -> float:
	if style == null:
		return 0.0
	var value = style.get("expand_margin_" + side)
	return float(value) if value != null else 0.0

# The badge's small font (the Hire screen entries' theme), or null where the game lacks it.
func _sraSmallFont():
	if ResourceLoader.exists(_SRA_BADGE_SCRIPT.SMALL_FONT_THEME):
		return load(_SRA_BADGE_SCRIPT.SMALL_FONT_THEME).get_font("font", "Label")
	return null

func _sraLabel(font) -> Label:
	var label = Label.new()
	if font != null:
		label.add_font_override("font", font)
	return label

# A line of the table: its name, the translation key `key`, and its value, aligned right, which it returns.
func _sraTableLine(table: GridContainer, font, key: String) -> Label:
	var caption = _sraLabel(font)
	caption.text = key
	table.add_child(caption)
	var value = _sraLabel(font)
	value.align = Label.ALIGN_RIGHT
	table.add_child(value)
	return value

# The list of rows ends where the mod's row begins.
func _sraFitList():
	var list = get_node_or_null(_SRA_LIST_MARGIN)
	if not list is MarginContainer or _sraRow == null:
		return
	var height = int(ceil(_sraRow.get_combined_minimum_size().y))
	if list.get_constant("margin_bottom") != height:
		list.add_constant_override("margin_bottom", height)

# The Shift badge (Badge.gd), in the Repair button's own frame and font colour (read once the button is in the tree,
# where the screen's theme gives them), inside the button on the left, centred on it from top to bottom, as
# CombatSimulator's on the simulator's button: as far from the button's left edge as the button keeps its text from its
# edges (_sraBadgeInset). A Button doesn't lay out its children, so the badge hangs from it directly, anchored to the
# middle of its left side, and grows right, up and down to its minimum size; the button makes room for it
# (_sraFitBadge). On the button, it lets the mouse through: a click on it is the button's, Shift+Click too. It keeps its
# look while the button is disabled: Shift+Click still opens the settings then.
func _sraMakeShiftBadge():
	var badge = _SRA_BADGE_SCRIPT.new()
	badge.name = "ShipRepairAdvisorShiftBadge"
	badge.dress(_sraButton, OS.get_scancode_string(KEY_SHIFT), _SRA_BADGE_SCRIPT.PAD_TEXT)
	var inset = _sraBadgeInset()
	badge.set_anchors_preset(PRESET_CENTER_LEFT)
	badge.margin_left = inset
	badge.margin_right = inset
	badge.margin_top = 0
	badge.margin_bottom = 0
	badge.grow_horizontal = GROW_DIRECTION_END
	badge.grow_vertical = GROW_DIRECTION_BOTH
	badge.mouse_filter = MOUSE_FILTER_PASS
	_sraButton.add_child(badge)
	_sraButton.align = Button.ALIGN_RIGHT
	badge.connect("minimum_size_changed", self, "_sraFitBadge")
	_sraButton.connect("minimum_size_changed", self, "_sraFitBadge")
	return badge

# How far the Repair button keeps its text from its edges (its normal stylebox's left margin): the badge's distance from
# its left edge, and the gap between the badge and the text.
func _sraBadgeInset() -> float:
	var style = _sraButton.get_stylebox("normal")
	return style.get_margin(MARGIN_LEFT) if style != null else 0.0

# The Repair button as wide as its text needs plus the badge and the gap after it, its text against its right margin,
# so the badge never covers it: again whenever either changes size (the badge's text follows the control scheme, the
# button's the language). The button's own minimum leaves out the width set here, so setting it settles at once.
func _sraFitBadge():
	if _sraShiftBadge == null or not is_instance_valid(_sraShiftBadge):
		return
	var width = ceil(_sraButton.get_minimum_size().x + _sraShiftBadge.get_combined_minimum_size().x + _sraBadgeInset())
	if _sraButton.rect_min_size.x != width:
		_sraButton.rect_min_size.x = width

# The badge's tooltip is shown by the game's own tooltip node, one of the row's own, as each row of the screen has its
# own (enceladus/SystemShipRepairUI.tscn): on hover, and with a gamepad, which shows no hover, while the Repair button
# is highlighted. The node also takes the row's buttons in, with the hover and focus sounds of the rows' buttons; their
# hint_tooltip stays empty, so they show none. The node puts a tooltip under its control, which at the bottom of the
# screen would leave it (_sraPlaceTooltip).
func _sraAttachTooltips(row):
	if not ResourceLoader.exists(_SRA_GAME_TOOLTIPS):
		return
	var tooltips = load(_SRA_GAME_TOOLTIPS).instance()
	tooltips.name = "PlaySoundsOnTheseButtons"
	row.add_child(tooltips)
	_sraShiftBadge.attachTooltip(tooltips, _sraButton)
	_sraShiftBadge.setShiftTooltips(_SRA_SETTINGS_TOOLTIP, _SRA_SETTINGS_TOOLTIP_PAD, _sraSettings.modName())
	if "tooltipExtraOffset" in tooltips and "currentTooltipNode" in tooltips and "tooltipContainer" in tooltips:
		_sraTooltips = tooltips
		_sraTooltipOffset = tooltips.tooltipExtraOffset
		_sraShiftBadge.connect("mouse_entered", self, "set_process", [true])
		_sraButton.connect("focus_entered", self, "set_process", [true])

# While the badge's tooltip may show (the mouse on the badge, or the Repair button highlighted), it is placed each
# frame, before the tooltip node, a child of this screen, places it.
func _process(_delta):
	if _sraTooltips == null or not is_instance_valid(_sraTooltips):
		set_process(false)
		return
	if _sraTooltips.currentTooltipNode == _sraShiftBadge:
		_sraPlaceTooltip()
	elif not _sraButton.has_focus() \
			and not _sraShiftBadge.get_global_rect().has_point(_sraShiftBadge.get_global_mouse_position()):
		set_process(false)

# The tooltip node puts a tooltip under its control, its own offset (tooltipExtraOffset) further down, in the screen's
# coordinates (menu/sfx/PlaySoundsOnTheseButtons.gd _process). Where that would take it past the bottom of the screen,
# the badge's goes above the badge instead, as far from it.
func _sraPlaceTooltip():
	var badge = _sraShiftBadge
	var height = _sraTooltips.tooltipContainer.rect_size.y
	var top = badge.get_global_transform_with_canvas().origin.y
	var offset = _sraTooltipOffset
	if top + badge.rect_size.y + offset.y + height > get_viewport().get_visible_rect().size.y:
		offset = Vector2(offset.x, - (badge.rect_size.y + height + offset.y))
	_sraTooltips.tooltipExtraOffset = offset

# Shift+Click on the Repair button opens the settings instead of repairing, and so does its gamepad twin on the
# highlighted button (Badge.gd isPadShortcut), whether the button is disabled or not. A click's gui_input signal comes
# before the button's own _gui_input, which is all a disabled button ignores, and accepting the press there keeps an
# enabled button from pressing; Badge.gd's PAD_BUTTON does nothing to a button. A disabled button keeps its focus, so
# the D-pad still reaches it (createRepairMenuFor).
func _sraOnRepairInput(event):
	var shiftClick = event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT and event.shift
	if shiftClick or _SRA_BADGE_SCRIPT.isPadShortcut(event):
		_sraButton.accept_event()
		_sraOpenSettings()

# As a menu entry opens its screen: the other screens, this one too, hide (`hidefoka`), and the settings screen shows in
# this one's place, titled as it is.
func _sraOpenSettings():
	var screens = get_parent()
	if _sraSettingsScreen == null:
		var title = get_node_or_null(_SRA_HEADER_TITLE)
		_sraSettingsScreen = _SRA_SETTINGS_UI.new()
		_sraSettingsScreen.setup(self, screens.get_node_or_null(_SRA_TUNING), title.text if title is Label else "")
		screens.add_child(_sraSettingsScreen)
		_sraSettingsScreen.connect("closed", self, "_sraOnSettingsClosed")
	screens.hidefoka()
	_sraSettingsScreen.show()

# Esc or the controller's back button closed the settings: the Repairs screen comes back, as it was, the Repair button
# highlighted. Not through show, which would take the settings' focus as the one to give back on closing (lastFocus):
# the menu entry the screen was opened from stays the one its own Esc goes back to.
func _sraOnSettingsClosed():
	$Shower.play("show")
	Tool.deferCallWhenIdle(_sraButton, "grab_focus")

# The game builds a row per system of the ship each time the screen shows. A repair by hand (each row's `fixed`) changes
# the plans; and the D-pad goes on down from the last row's buttons to the Repair button, and up from either button
# back to the last row (Park beside Repair, under Replace, the row's last button).
func createRepairMenuFor(ship):
	.createRepairMenuFor(ship)
	var rows = _sraRows()
	for row in rows:
		if not row.is_connected("fixed", self, "_sraQueue"):
			row.connect("fixed", self, "_sraQueue")
	if _sraButton != null and not rows.empty():
		var last = rows[rows.size() - 1]
		for button in [last.fixButton, last.replaceButton]:
			button.focus_neighbour_bottom = _sraButton.get_path()
		_sraButton.focus_neighbour_top = last.fixButton.get_path()
		_sraParkButton.focus_neighbour_top = last.replaceButton.get_path()
	_sraQueue()

# The station set up a new player ship: after each of Park's purchases (Upgrades.gd buy rebuilds the ship from its
# config). The rows read the ship they were made for, so while the screen shows they are made again for the new one,
# as showing the screen makes them (Repairs.gd show).
func _sraShipChanged():
	_sraShipChanges += 1
	if is_visible_in_tree():
		Tool.deferCallInPhysics(self, "_sraRebuildRows")
	_sraQueue()

func _sraRebuildRows():
	var ship = _sraShip()
	if ship == null or not is_visible_in_tree():
		return
	ship.fillInSystems()
	if not ship.getSystems().empty():
		createRepairMenuFor(ship)

# The screen hides: Park's confirmation goes with it.
func _sraVisibilityChanged():
	if not visible and _sraParkDialog != null and _sraParkDialog.visible:
		_sraParkDialog.hide()
	_sraQueue()

func _sraQueue(_arg = null):
	if not _sraQueued:
		_sraQueued = true
		call_deferred("_sraRefresh")

func _sraRefresh():
	_sraQueued = false
	if _sraButton == null or not is_visible_in_tree():
		return
	var target = float(_sraSettings.getValue("target"))
	_sraTargetValue.text = _sraPercent(str(int(round(target))))
	if _sraRows().empty() or _sraShip() == null:
		for value in _sraValues:
			value.text = ""
		_sraButton.disabled = true
		_sraParkButton.disabled = true
		return
	_sraShow(_SRA_ADVISOR.plan(_sraData(target)))
	var parking = null if _sraRunning else _sraParkInfo()
	_sraParkButton.disabled = parking == null or _SRA_ADVISOR.isParkEmpty(_SRA_ADVISOR.park(parking.data))

func _sraPercent(value: String) -> String:
	return tr(_SRA_PERCENT) % value

# The table and the Repair button for `plan`: what the insurance pays, what the cash pays (in the warning colour while
# it would leave the cash below zero), both together, and the maintenance time. With nothing to repair, it all reads
# zero.
func _sraShow(plan: Dictionary):
	var texts = [
		_sraMoney(plan.insuranceCost),
		_sraMoney(plan.cashCost),
		_sraMoney(plan.insuranceCost + plan.cashCost),
		Tool.readableTimeSpan(plan.time, true),
	]
	for i in _sraValues.size():
		_sraValues[i].text = texts[i]
	var cash = _sraValues[_SRA_TABLE.find(_SRA_CASH_COST)]
	cash.modulate = _sraWarningColor() if plan.cashAfter < 0 else Color(1, 1, 1, 1)
	_sraButton.disabled = _sraRunning or plan.repaired == 0

func _sraMoney(amount: float) -> String:
	return tr(_SRA_MONEY) % CurrentGame.formatThousands(int(round(amount)))

# The rows' colour for a failed inspection (SystemShipRepairUI.gd colorBad), from the first row, or the game's.
func _sraWarningColor() -> Color:
	for row in _sraRows():
		if "colorBad" in row and row.colorBad is Color:
			return row.colorBad
	return _SRA_WARNING_FALLBACK

# The Repair button: rounds of presses on the rows' own buttons (_sraRounds), towards the target set.
func _sraRepair():
	if not _sraStart():
		return
	var rounds = _sraRounds(_SRA_ROUNDS_REPAIR)
	if rounds is GDScriptFunctionState:
		yield(rounds, "completed")
	_sraFinish()

func _sraStart() -> bool:
	if _sraRunning:
		return false
	_sraRunning = true
	_sraLeftOut = {}
	_sraLeftOutSlots = {}
	_sraButton.disabled = true
	_sraParkButton.disabled = true
	return true

func _sraFinish():
	_sraRunning = false
	_sraLeftOut = {}
	_sraLeftOutSlots = {}
	for row in _sraRows():
		row.updateStatuses()
	_sraQueue()

# Rounds of presses on the rows' own buttons, the plan (`goal`, one of _SRA_ROUNDS_*) worked out again before each from
# the systems as they are. Each round presses at most one button per row, only one the row has enabled, as a player's
# click finds it, and waits for the systems to show the repair before the next: a row's buttons work on what it last
# read (the game's own rows refresh after a repair, Repairs.gd updateStatuses), and a second Fix on that would take off
# the whole damage left, not half of it. A press that doesn't raise a system's condition leaves that system out until
# the button is done. The rounds stop when nothing is left to press, when the screen closes, or after _SRA_MAX_ROUNDS.
func _sraRounds(goal: int):
	for _round in _SRA_MAX_ROUNDS:
		if not is_visible_in_tree() or _sraShip() == null:
			break
		var presses = _sraPresses(goal)
		if presses.empty():
			break
		var rows = _sraRows()
		for row in rows:
			row.updateStatuses()
		var before = {}
		for row in rows:
			var key = row.systemKey
			if not presses.has(key) or row.system == null:
				continue
			var replace = presses[key] == "replace"
			var button = row.replaceButton if replace else row.fixButton
			if button.disabled:
				continue
			before[key] = float(row.system.status)
			if replace:
				row._on_Replace_pressed()
			else:
				row._on_Fix_pressed()
		if before.empty():
			break
		for _frame in _SRA_SETTLE_FRAMES:
			yield(get_tree(), "physics_frame")
		var ship = _sraShip()
		if ship == null:
			break
		ship.fillInSystems()
		var systems = ship.getSystems()
		for key in before:
			if not systems.has(key) or float(systems[key].status) <= before[key] + _SRA_PROGRESS:
				_sraLeftOut[key] = true

# The buttons a round presses for `goal`, by system key ("fix" or "replace").
func _sraPresses(goal: int) -> Dictionary:
	if goal == _SRA_ROUNDS_REPAIR:
		return _SRA_ADVISOR.presses(_SRA_ADVISOR.plan(_sraData(float(_sraSettings.getValue("target")))))
	var info = _sraParkInfo()
	if info == null:
		return {}
	var plan = _SRA_ADVISOR.park(info.data)
	if goal == _SRA_ROUNDS_PARK_FIXES:
		var out = {}
		for key in plan.fixes:
			out[key] = "fix"
		return out
	return _SRA_ADVISOR.presses(plan.repair)

# The Park button: its confirmation, with the plan as it is now, its repairs read on the ship as the purchases will
# leave it (_sraParkExact). Another press while that is worked out does nothing.
func _sraParkPressed():
	if _sraRunning or _sraParkChecking:
		return
	var info = _sraParkInfo()
	if info == null:
		return
	if _SRA_ADVISOR.isParkEmpty(_SRA_ADVISOR.park(info.data)):
		_sraQueue()
		return
	_sraParkChecking = true
	var exact = _sraParkExact(info)
	if exact is GDScriptFunctionState:
		yield(exact, "completed")
	_sraParkChecking = false
	if _sraRunning or not is_visible_in_tree():
		return
	var plan = _SRA_ADVISOR.park(info.data)
	if _sraParkDialog == null:
		_sraParkDialog = _SRA_PARK_DIALOG.new()
		_sraParkDialog.setFont(_sraSmallFont())
		add_child(_sraParkDialog)
		_sraParkDialog.connect("confirmed", self, "_sraPark")
		_sraParkDialog.connect("popup_hide", self, "_sraParkDialogHidden")
	var question = tr(_SRA_PARK_CONFIRM) % _sraPercent(str(int(round(_SRA_PARK_TARGET))))
	_sraParkDialog.showPlan(question, _sraParkLines(plan), _sraParkNotes(plan, info.systems),
			plan.needed <= _SRA_ADVISOR.PRECISION)

# The confirmation's lines: what the insurance and the cash pay or get, the two together, and the maintenance time.
func _sraParkLines(plan: Dictionary) -> Array:
	return [
		_sraSigned(_SRA_INSURANCE, - plan.insuranceCost),
		_sraSigned(_SRA_CASH, - plan.cashCost),
		_sraSigned(_SRA_TOTAL, - (plan.insuranceCost + plan.cashCost)),
		{"name": tr(_SRA_TIME), "value": Tool.readableTimeSpan(plan.time, true), "color": null},
	]

# A line of money, written as the Fleet screen writes a trade-in (Dealer.gd displayShip): coming in with +, going out
# with -, each in its colour; none (less than the whole E$ formatThousands writes) without either.
func _sraSigned(key: String, amount: float) -> Dictionary:
	var whole = int(round(amount))
	if whole == 0:
		return {"name": tr(key), "value": tr(_SRA_ZERO) % CurrentGame.formatThousands(0), "color": null}
	var text = _SRA_PLUS if whole > 0 else _SRA_MINUS
	return {"name": tr(key), "value": tr(text) % CurrentGame.formatThousands(abs(whole)), "color": _sraFleetColor(whole < 0)}

# The Fleet screen's colour for money going out (`minus`) or coming in.
func _sraFleetColor(minus: bool) -> Color:
	var fleet = get_parent().get_node_or_null(_SRA_FLEET) if get_parent() != null else null
	var property = _SRA_COLOR_MINUS if minus else _SRA_COLOR_PLUS
	if fleet != null and property in fleet and fleet.get(property) is Color:
		return fleet.get(property)
	return _SRA_COLOR_MINUS_FALLBACK if minus else _SRA_COLOR_PLUS_FALLBACK

# The confirmation's notes: the money missing, and the systems nothing brings to the condition, each with its condition
# (`systems`: the ship's, by key).
func _sraParkNotes(plan: Dictionary, systems: Dictionary) -> Array:
	var notes = []
	if plan.needed > _SRA_ADVISOR.PRECISION:
		notes.append(tr(_SRA_PARK_NEEDED) % (tr(_SRA_MONEY) % CurrentGame.formatThousands(int(ceil(plan.needed)))))
	if not plan.unreachable.empty():
		var names = []
		var scale = pow(10, _SRA_CONDITION_DECIMALS)
		var format = "%." + str(_SRA_CONDITION_DECIMALS) + "f"
		for key in plan.unreachable:
			var system = systems.get(key, {})
			var condition = floor(float(system.get("status", 0.0)) * scale + _SRA_CONDITION_GUARD) / scale
			names.append(tr(_SRA_PARK_SYSTEM) % [tr(str(system.get("name", key))), _sraPercent(format % condition)])
		notes.append(tr(_SRA_PARK_UNREACHABLE) % [_sraPercent(str(int(round(_SRA_PARK_TARGET)))),
				PoolStringArray(names).join(_SRA_LIST_SEPARATOR)])
	return notes

# Closed by Cancel, OK, Esc or a click outside: the focus goes back to Park.
func _sraParkDialogHidden():
	if _sraParkButton.is_visible_in_tree():
		_sraParkButton.grab_focus()

# Park, once confirmed, in three steps, each worked out again from the ship as it is before every press (Advisor.gd
# park): the Fixes before trading in (rounds on the rows), the purchases (_sraParkPurchases), the repairs of what is
# left (rounds on the rows made for the new ship). Then Park is highlighted again: making the rows again highlights
# their first.
func _sraPark():
	if not _sraStart():
		return
	var step = _sraRounds(_SRA_ROUNDS_PARK_FIXES)
	if step is GDScriptFunctionState:
		yield(step, "completed")
	step = _sraParkPurchases()
	if step is GDScriptFunctionState:
		yield(step, "completed")
	_sraLeftOut = {}
	step = _sraRounds(_SRA_ROUNDS_PARK_REPAIRS)
	if step is GDScriptFunctionState:
		yield(step, "completed")
	_sraFinish()
	if _sraParkButton.is_visible_in_tree():
		_sraParkButton.grab_focus()

# Park's purchases, one at a time, each a click on the Equipment screen's own Buy button of the piece the plan buys
# first, only while the screen has it enabled (Upgrades.gd updatePricesAndAvailability disables a piece that costs more
# than the cash). Upgrades.gd buy fits it and builds the ship again; the next purchase waits for the new ship
# (playerShipChanged, up to _SRA_SHIP_WAIT_FRAMES) and for the rows made for it. A slot whose Buy is disabled, or that
# the purchase didn't change, is left out.
func _sraParkPurchases():
	for _round in _SRA_MAX_ROUNDS:
		if not is_visible_in_tree() or _sraShip() == null:
			break
		var info = _sraParkInfo()
		if info == null:
			break
		var slot = null
		for each in _SRA_ADVISOR.park(info.data).purchases:
			if not _sraLeftOutSlots.has(each):
				slot = each
				break
		if slot == null:
			break
		var item = info.items[slot]
		if item.buttonBuy.disabled:
			_sraLeftOutSlots[slot] = true
			continue
		var seen = _sraShipChanges
		item._on_Buy_pressed()
		for _frame in _SRA_SHIP_WAIT_FRAMES:
			yield(get_tree(), "physics_frame")
			if _sraShipChanges != seen and _sraShip() != null:
				break
		for _frame in _SRA_SETTLE_FRAMES:
			yield(get_tree(), "physics_frame")
		var equipment = _sraEquipment()
		if _sraShip() == null or equipment == null:
			break
		equipment.updatePricesAndAvailability()
		if not item.installed:
			_sraLeftOutSlots[slot] = true

# Park's confirmation reads the repairs on the ship as the purchases will leave it, not as it is now. A slot's members
# come new, but the systems of a slot without members (the reactor, the turbine, …) keep their damage through a
# purchase, and the new piece prices their repair and takes that damage by its own capacity (Reactor.gd
# getDamageCapacity); and a piece bought out and back comes back worth what its systems say, not its price. So the
# data's repairs, the systems nothing brings to the target, and each out-and-back's second purchase are worked out again
# on a trial ship (_sraTrial), built from a copy of the ship's config with every slot bought for on the piece it gets
# (the other piece, for one bought out and back) and that slot's members without damage (Upgrades.gd buy:
# clearDamageInSlot), the rest as it is. The rows' rules ask their row's ship, so they are read through a copy of a
# row's script, out of the tree, told the trial ship. Without purchases, the ship as it is is the one to read. A
# coroutine; the data stays as it was where the trial ship can't be set up.
func _sraParkExact(info: Dictionary):
	var rows = _sraRows()
	if rows.empty() or info.data.slots.empty():
		return
	var full = CurrentGame.getPlayerShipConfig().duplicate(true)
	if not full.get("config") is Dictionary:
		return
	var config = full.config
	if not config.get("damage") is Dictionary:
		config.damage = {}
	for entry in info.data.slots:
		_sraPut(config, entry.slot, info.items[entry.slot].getVal())
		for key in entry.members:
			var damage = config.damage.get(key)
			if damage is Dictionary:
				for type in damage:
					damage[type] = 0.0
	var trial = _sraTrial(full)
	if trial is GDScriptFunctionState:
		trial = yield(trial, "completed")
	if trial == null:
		return
	var systems = trial.getSystems()
	var rule = rows[0].get_script().new()
	rule.ship = trial
	rule.maxDamageThatCanBeFixed = rows[0].maxDamageThatCanBeFixed
	rule.repairStepAmount = rows[0].repairStepAmount
	var repair = {}
	var unreachable = []
	for key in systems:
		if not _sraWorn(systems[key]):
			continue
		if float(systems[key].status) >= _SRA_REPLACE_BELOW:
			unreachable.append(key)
			continue
		var system = _sraSystem(rule, systems[key])
		if system != null:
			repair[key] = system
	# The second purchase of one out and back: the cheapest piece's price for every slot of the kind, less what the other
	# piece's systems are worth new (ship-ctrl.gd getSystemPrice at 100 %: their price).
	for entry in info.data.slots:
		if not entry.get("back", false):
			continue
		var worth = 0.0
		var members = _sraMembers(systems, entry.slot)
		for key in members:
			worth += float(trial.getSystemPrice(systems[key]))
		entry.backNet = float(info.finals[entry.slot].price * max(members.size(), 1)) - worth
	rule.free()
	_sraTrialDone(trial)
	info.data.repair.systems = repair
	info.data.unreachable = unreachable
	info.systems = systems

# A trial ship built from `full` (a ship's whole config), set up out of sight, as ShipSaleAdvisor's (and the Fleet
# entries') trial ships are: a dummy, its reactor off, in a cutscene, in a viewport of its own, its systems read in full
# once set up and their conditions worked out (_SRA_SETTLE_FRAMES); null when it can't be set up. A coroutine. Free it
# with _sraTrialDone.
func _sraTrial(full: Dictionary):
	var host = get_node_or_null(_SRA_TRIAL_NODE)
	if host == null:
		host = Viewport.new()
		host.name = _SRA_TRIAL_NODE
		host.size = _SRA_TRIAL_SIZE
		host.own_world = true
		host.usage = Viewport.USAGE_2D
		host.render_target_update_mode = Viewport.UPDATE_DISABLED
		add_child(host)
	var trial = Shipyard.createShipByConfig(full, false)
	if trial == null:
		return null
	trial.setDummy(true)
	trial.dummy = true
	trial.setReactorState(false)
	trial.visible = false
	host.add_child(trial)
	trial.preheat = false
	trial.cutscene = true
	var tree = get_tree()
	for _frame in _SRA_TRIAL_FRAMES:
		if not is_instance_valid(trial) or trial.setup:
			break
		yield(tree, "idle_frame")
	if not is_instance_valid(trial) or not trial.setup:
		_sraTrialDone(trial)
		return null
	for _frame in _SRA_SETTLE_FRAMES:
		yield(tree, "physics_frame")
	if not is_instance_valid(trial):
		return null
	trial.fillInSystems()
	return trial

func _sraTrialDone(trial):
	if not is_instance_valid(trial):
		return
	if trial.get_parent() != null:
		trial.get_parent().remove_child(trial)
	Tool.remove(trial)

# ship-ctrl.gd setConfig on a config: the dotted path made where it is missing, then the value.
func _sraPut(config: Dictionary, key: String, value):
	var node = config
	var path = key.split(".")
	for i in path.size() - 1:
		if not node.get(path[i]) is Dictionary:
			node[path[i]] = {}
		node = node[path[i]]
	node[path[path.size() - 1]] = value

# The screen's rows (SystemShipRepairUI), in its order: those made for the player's ship as it is now (Park's purchases
# build a new one, and the old rows go once the new ones are made).
func _sraRows() -> Array:
	var rows = []
	if systemsBox == null:
		return rows
	var ship = CurrentGame.getPlayerShip()
	for row in systemsBox.get_children():
		if is_instance_valid(row) and not row.is_queued_for_deletion() and row.has_method("shouldBeFixed") \
				and "systemKey" in row and is_instance_valid(row.ship) and row.ship == ship:
			rows.append(row)
	return rows

# The ship the screen repairs, as Repairs.gd show gives it to the rows, once it is set up.
func _sraShip():
	var ship = CurrentGame.getPlayerShip()
	if ship == null or not is_instance_valid(ship) or not ship.setup:
		return null
	return ship

# The Equipment screen beside this one, or null.
func _sraEquipment():
	if get_parent() == null:
		return null
	var node = get_parent().get_node_or_null(_SRA_EQUIPMENT)
	if node != null and node.has_method("getItems") and node.has_method("updatePricesAndAvailability"):
		return node
	return null

# What Advisor.gd plans from (its header), read after a full poll of the ship's systems (ship-ctrl.gd fillInSystems):
# the player's poll reads one system at a time (getSystems), so the conditions would lag behind the repairs.
func _sraData(target: float) -> Dictionary:
	var data = {
		"target": target,
		"money": float(CurrentGame.getMoney()),
		"insurance": float(CurrentGame.getInsurance()),
		"systems": {},
	}
	var ship = _sraShip()
	if ship == null:
		return data
	ship.fillInSystems()
	var systems = ship.getSystems()
	for row in _sraRows():
		var key = row.systemKey
		if _sraLeftOut.has(key) or not systems.has(key):
			continue
		var system = _sraSystem(row, systems[key])
		if system != null:
			data.systems[key] = system
	return data

# What Advisor.gd park plans from (its header), with `items`, the Equipment screen's piece each slot's purchase buys
# now, and `systems`, the ship's, by key; null without the Equipment screen or a ship set up. The screen prices the
# player's ship first, as it does when it shows (updatePricesAndAvailability: which piece is fitted, each one's net
# price against it, its maintenance time, and its Buy button enabled or not).
# - A slot's offers are what the screen shows for this ship (_sraOffered), and the piece fitted. A slot with no piece
#   fitted is left alone: the screen would price its purchase against nothing, and what is in it would be lost.
# - The cheapest is the piece with the lowest price; on a tie, the fitted piece, then the screen's order. Where it isn't
#   fitted, it is bought, and the slot's members (its systems, ship-ctrl.gd getSlotValue) come new; those damaged may be
#   fixed first. Where it is fitted but one of its members is worn where the Repairs screen can't take it
#   (_SRA_REPLACE_BELOW or more), the cheapest other piece is bought, then the cheapest again: the second purchase's net
#   is taken here as if the other piece's systems were worth its price (_sraParkExact reads what they are worth).
# - Every other damaged system is repaired, or, at _SRA_REPLACE_BELOW or more, is one nothing brings to the target: the
#   systems of a slot without members (the reactor, the turbine, …) keep their damage through a purchase
#   (clearDamageInSlot clears a slot's members only), and the Repairs screen offers neither Fix nor Replace up there.
#   They are read here as the ship has them now, which is what Park's steps need, one at a time; its confirmation reads
#   them as the purchases will leave them (_sraParkExact).
# `finals` holds the piece each slot ends with.
func _sraParkInfo():
	var equipment = _sraEquipment()
	var ship = _sraShip()
	if equipment == null or ship == null:
		return null
	var priced = equipment.updatePricesAndAvailability()
	if priced is GDScriptFunctionState:
		return null
	ship.fillInSystems()
	var systems = ship.getSystems()
	var rows = {}
	for row in _sraRows():
		rows[row.systemKey] = row
	var data = {
		"money": float(CurrentGame.getMoney()),
		"insurance": float(CurrentGame.getInsurance()),
		"slots": [],
		"trades": {},
		"repair": {"target": _SRA_PARK_TARGET, "money": 0.0, "insurance": 0.0, "systems": {}},
		"unreachable": [],
	}
	var info = {"data": data, "items": {}, "finals": {}, "systems": systems}
	var offers = {}
	var order = []
	for item in equipment.getItems():
		if not "slot" in item or item.slot == "" or not (item.installed or _sraOffered(equipment, item)):
			continue
		if not offers.has(item.slot):
			offers[item.slot] = []
			order.append(item.slot)
		offers[item.slot].append(item)
	var renewed = {}
	for slot in order:
		var fitted = null
		var cheapest = null
		for item in offers[slot]:
			if item.installed and fitted == null:
				fitted = item
			if cheapest == null or item.price < cheapest.price \
					or (item.price == cheapest.price and item.installed and not cheapest.installed):
				cheapest = item
		if fitted == null:
			continue
		var members = _sraMembers(systems, slot)
		var buy = null
		var entry = {"slot": slot, "members": members}
		if cheapest != fitted:
			buy = cheapest
		elif _sraWornPast(systems, members):
			for item in offers[slot]:
				if item != fitted and _sraOffered(equipment, item) and (buy == null or item.price < buy.price):
					buy = item
			if buy != null:
				entry.back = true
				entry.backNet = float((fitted.price - buy.price) * fitted.getNumber())
		if buy == null:
			continue
		entry.net = float(buy.getNetPrice())
		entry.time = float(buy.actualReplacementTime)
		data.slots.append(entry)
		info.items[slot] = buy
		info.finals[slot] = cheapest
		for key in members:
			renewed[key] = true
			if not entry.get("back", false) and rows.has(key) and not _sraLeftOut.has(key):
				var trade = _sraSystem(rows[key], systems[key])
				if trade != null:
					data.trades[key] = trade
	for key in systems:
		if renewed.has(key) or _sraLeftOut.has(key) or not rows.has(key) or not _sraWorn(systems[key]):
			continue
		if float(systems[key].status) >= _SRA_REPLACE_BELOW:
			data.unreachable.append(key)
			continue
		var repair = _sraSystem(rows[key], systems[key])
		if repair != null:
			data.repair.systems[key] = repair
	return info

# The keys of a slot's members among `systems`: the systems mounted in it, whose script names the slot as its `type`
# (WeaponSlot.gd, ThrusterSlot.gd and LIDAR.gd; ship-ctrl.gd getSlotValue prices a slot by them).
func _sraMembers(systems: Dictionary, slot: String) -> Array:
	var members = []
	for key in systems:
		var ref = systems[key].get("ref")
		if is_instance_valid(ref) and "type" in ref and ref.get("type") is String and ref.get("type") == slot:
			members.append(key)
	return members

# Whether the Equipment screen shows `item` for the player's ship: the piece available to it (SystemShipUpgradeUI.gd
# isAvailable: its story condition, the ship able to mount it, its number within the ship's limits) in groups the
# screen shows (UpgradeGroup.gd reexamine sets their visibility for the player's ship).
func _sraOffered(equipment, item) -> bool:
	if not item.has_method("isAvailable") or not item.isAvailable():
		return false
	var node = item.get_parent()
	while node != null and node != equipment:
		if "restrictType" in node and "always" in node and not node.visible:
			return false
		node = node.get_parent()
	return true

# A system with damage, which leaves it below 100 % (a condition below 100 % from something else isn't a repair's to
# raise, nor a purchase's).
func _sraWorn(system: Dictionary) -> bool:
	if float(system.get("status", 100.0)) >= 100.0:
		return false
	for d in system.get("damage", []):
		if float(d.get("current", 0)) > 0:
			return true
	return false

# Whether one of `members` is worn where the Repairs screen offers neither Fix nor Replace.
func _sraWornPast(systems: Dictionary, members: Array) -> bool:
	for key in members:
		if _sraWorn(systems[key]) and float(systems[key].status) >= _SRA_REPLACE_BELOW:
			return true
	return false

# A damaged system as Advisor.gd takes it, or null for one without damage (a condition below 100 % from something else,
# such as a spinning reaction wheel, isn't a repair's to raise). Its condition after each Fix click is predicted as the
# game makes it: every damage less the row's repairStepAmount of it (doFixSystem), the condition from the worst damage
# for what it can take (ship-ctrl.gd getSystemStatus, and each system's getStatus). What of the condition the listed
# damage doesn't explain stays. Each click is allowed by the row's own rule for its Fix button (shouldBeFixed), and
# priced by its own (fixPrice, replacementPrice), on the system as predicted, and what the piece trades in for there is
# the ship's own (getSystemPrice).
func _sraSystem(row, system: Dictionary):
	var ref = system.get("ref")
	var damage = system.get("damage", [])
	if not is_instance_valid(ref) or not damage is Array or damage.empty():
		return null
	var worst = 0.0
	for d in damage:
		if d.get("max", 0) > 0:
			worst = max(worst, d.current / float(d.max))
	if worst <= 0:
		return null
	var status = float(system.status)
	var stuck = 1.0 - status / 100.0
	if stuck <= min(worst, 1.0) + _SRA_UNEXPLAINED:
		stuck = 0.0
	var keep = 1.0 - row.repairStepAmount
	var steps = []
	for k in _SRA_MAX_CLICKS + 1:
		var predicted = system.duplicate()
		if k > 0:
			var share = pow(keep, k)
			var left = []
			for d in damage:
				var entry = d.duplicate()
				entry.current = d.current * share
				left.append(entry)
			predicted.damage = left
			predicted.status = clamp(100.0 - 100.0 * max(worst * share, stuck), 0.0, 100.0)
		var step = {
			"status": float(predicted.status),
			"fix": row.shouldBeFixed(predicted),
			"replace": _sraReplaceable(row, predicted),
			"replacePrice": float(row.replacementPrice(predicted)),
			"value": float(row.ship.getSystemPrice(predicted)),
		}
		steps.append(step)
		if not step.fix:
			break
	var fixTime = float(ref.repairFixTime) if "repairFixTime" in ref else 0.0
	var replaceTime = float(ref.repairReplacementTime) if "repairReplacementTime" in ref else 0.0
	return {
		"steps": steps,
		"fixPrice": float(row.fixPrice(system)),
		"fixTime": fixTime * row.getMechanicMultiplier() * 3600.0,
		"replaceTime": replaceTime * 3600.0,
		"unfixable": row.isFubar(system),
		"replaced": 100.0 * (1.0 - stuck),
	}

# Whether the row would enable Replace for `system`, its money check aside (SystemShipRepairUI.gd isReplaceable): the
# plan sees to the money.
func _sraReplaceable(row, system: Dictionary) -> bool:
	if float(system.status) >= _SRA_REPLACE_BELOW or not "repairReplacementPrice" in system.ref:
		return false
	return row.isFubar(system) or system.ref.repairReplacementPrice >= 0

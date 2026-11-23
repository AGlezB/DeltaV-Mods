extends ConfirmationDialog

# ShipRepairAdvisor's confirmation of Park (Code.gd), a ConfirmationDialog as the game's own (the station's pause menu,
# enceladus/PauseLayerEnceladus.tscn: no title, popup_centered, Cancel highlighted). Code.gd adds it to the Repairs
# screen, so it takes the station's menu theme. The question, in the dialog's font; under it the lines of what Park
# costs or brings and how long it takes, in the font Code.gd gives it (the badge's small font), each value aligned right
# and in the colour given; under them the notes, in the dialog's font. OK is disabled while Park can't be done.
# Esc and the pause button while it shows close it alone (_input).

# The game's keys for the buttons (the Fleet entries' Buy confirmation, BuyConfirm and BuyCancel).
const OK_TEXT = "OK"
const CANCEL_TEXT = "CANCEL"
# The widest the question and the notes may be on one line, as a share of the screen's width: beyond, they wrap.
const MAX_WIDTH_SHARE = 0.5
# The least space between a line's name and its value, in heights of the lines' font.
const COLUMN_GAP = 2.0

var _question = null
var _lines = null # the lines: a grid of names and values
var _notes = null
var _font = null # the lines' font
var _closedFrame = -1 # the frame in which Esc closed it

func _init():
	window_title = ""
	get_ok().text = OK_TEXT
	get_cancel().text = CANCEL_TEXT
	var box = VBoxContainer.new()
	_question = _wrapping()
	box.add_child(_question)
	_lines = GridContainer.new()
	_lines.columns = 2
	_lines.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(_lines)
	_notes = VBoxContainer.new()
	box.add_child(_notes)
	add_child(box)

func setFont(font):
	_font = font

# Shows `question`, the `lines` (each a name, a value, and a colour or null), the `notes` (texts), OK enabled only with
# `canConfirm`, sized to all of it, centered on the screen, Cancel highlighted.
func showPlan(question: String, lines: Array, notes: Array, canConfirm: bool):
	_question.text = question
	for child in _lines.get_children() + _notes.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var font = _font if _font != null else _lines.get_font("font", "Label")
	_lines.add_constant_override("hseparation", int(ceil(font.get_height() * COLUMN_GAP)))
	for line in lines:
		var caption = _label(line.name)
		var value = _label(line.value)
		value.align = Label.ALIGN_RIGHT
		if line.get("color") is Color:
			value.modulate = line.color
		_lines.add_child(caption)
		_lines.add_child(value)
	for text in notes:
		var note = _wrapping()
		note.text = text
		_notes.add_child(note)
	_notes.visible = not notes.empty()
	_widths()
	get_ok().disabled = not canConfirm
	_fit()
	if not visible:
		popup_centered()
	_fit()
	get_cancel().grab_focus()
	_fitLater()

func _label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	if _font != null:
		label.add_font_override("font", _font)
	return label

func _wrapping() -> Label:
	var label = Label.new()
	label.autowrap = true
	label.align = Label.ALIGN_CENTER
	return label

# The question's and the notes' width, set so they wrap at it at once: as wide as the widest needs on one line, up to
# MAX_WIDTH_SHARE of the screen, and never narrower than the lines.
func _widths():
	var texts = [_question] + _notes.get_children()
	var most = floor(get_viewport_rect().size.x * MAX_WIDTH_SHARE)
	var width = _lines.get_combined_minimum_size().x
	for label in texts:
		width = max(width, min(_lineWidth(label), most))
	for label in texts:
		label.rect_min_size.x = width
		label.rect_size.x = width

# The width `label` needs to show its text on one line. A Label wraps a line that reaches its width (Label.cpp
# regenerate_word_cache), so this is a little more: a space more, which also covers the kerning its spaces lose.
func _lineWidth(label: Label) -> float:
	var font = label.get_font("font")
	var margins = label.get_stylebox("normal").get_minimum_size().x
	return ceil(font.get_string_size(label.text).x + font.get_string_size(" ").x + margins)

# At its least size, centered on the screen.
func _fit():
	rect_size = Vector2.ZERO
	rect_global_position = ((get_viewport_rect().size - rect_size) / 2).floor()

# Again once the containers have laid the labels out, which settles their wrapped heights.
func _fitLater():
	for i in 2:
		yield(get_tree(), "idle_frame")
	if visible:
		_fit()

# Esc (or the pause button) while it shows closes it alone. It is the Repairs screen's child, and children get _input
# before their parents, so the screen (Repairs.gd _input, which closes on these) doesn't see it. Repairs.gd asks the
# action, not the event, and an action stays just pressed for its whole frame: every later event of that frame (the
# key's release, a mouse move) is marked handled too.
func _input(_event):
	if not _cancelAction():
		return
	if visible:
		hide()
		_closedFrame = Engine.get_idle_frames()
		get_tree().set_input_as_handled()
	elif _closedFrame == Engine.get_idle_frames():
		get_tree().set_input_as_handled()

func _cancelAction() -> bool:
	for action in ["ui_cancel", "pause"]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false

extends Node

# ShipHighlightTypeAndPrice - makes the type of every ship entry in the dealer and
# fleet lists easy to spot: the type in bold amber, the registration and year
# dimmed. The name and price keep their original color. The ship image stretched
# behind each row is hidden, because it makes the text harder to read.

const SHIP_SCRIPT = "res://enceladus/SystemBuyUI.gd"
const TYPE_COLOR = Color(1.0, 0.75, 0.35)
const DIM_COLOR = Color(0.6, 0.6, 0.6)

var _bold_fonts = {}


func _ready():
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node):
	var script = node.get_script()
	if script == null or script.resource_path != SHIP_SCRIPT:
		return
	# The entry finds its labels after entering the tree, so wait a moment.
	yield(get_tree().create_timer(0.3), "timeout")
	if not is_instance_valid(node):
		return
	_paint(node.shipLabel, TYPE_COLOR)
	_make_bold(node.shipLabel)
	_paint(node.transponder, DIM_COLOR)
	_paint(node.makeYearLabel, DIM_COLOR)
	# Fully transparent instead of hidden, so the game can still show and hide the row.
	if node.background is TextureRect:
		node.background.self_modulate = Color(1, 1, 1, 0)


func _paint(label, color):
	if label is Label:
		label.add_color_override("font_color", color)


# Bold by drawing a faint outline in the text color. The entries share the game's
# font, which must not be changed, so one bold copy is made per font. An entry that
# is added again (the dealer does this every hour) already has the bold copy.
func _make_bold(label):
	if not label is Label:
		return
	var font = label.get_font("font")
	if not font is DynamicFont or font in _bold_fonts.values():
		return
	if not _bold_fonts.has(font):
		var bold = font.duplicate()
		bold.outline_size = 1
		bold.outline_color = TYPE_COLOR
		bold.outline_color.a = 0.2
		_bold_fonts[font] = bold
	label.add_font_override("font", _bold_fonts[font])

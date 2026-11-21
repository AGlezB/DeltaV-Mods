extends Node

# ShipSortByTypeAndPrice - sorts the ship list on the dealer screen by type (as
# shown, e.g. "K37 TNTRL"), then by price.

const SHIP_SCRIPT = "res://enceladus/SystemBuyUI.gd"
# How long the entries added together are collected before one sort, in seconds.
const SETTLE_TIME = 0.3

var _lists = {}
var _not_digits = RegEx.new()


func _ready():
	_not_digits.compile("[^0-9]")
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node):
	var script = node.get_script()
	if script == null or script.resource_path != SHIP_SCRIPT:
		return
	# New entries fill in their type and price a little later and then emit "done"
	# (enceladus/SystemBuyUI.gd addShip), so sort again then. Entries that are added
	# again are already filled in.
	if not node.is_connected("done", self, "_queue_sort"):
		node.connect("done", self, "_queue_sort", [node])
	_queue_sort(node)


func _queue_sort(node):
	var list = node.get_parent()
	if list == null:
		return
	var first = _lists.empty()
	_lists[list] = true
	if first:
		# Collect the entries that arrive in the next moment, then sort them all.
		yield(get_tree().create_timer(SETTLE_TIME), "timeout")
		for l in _lists.keys():
			if is_instance_valid(l) and l.is_inside_tree():
				_sort(l)
		_lists.clear()


# The fleet list uses the same entries, so only entries that are not owned are
# sorted. They are placed from the first entry's position, so anything above the
# entries stays where it is. The Dealer screen highlights the entry it put first
# (enceladus/Dealer.gd doAddShips, its focus()), for the keyboard and the gamepad:
# if that one still has the focus, the highlight moves to the new first entry.
func _sort(list):
	var ships = []
	var first_index = list.get_child_count()
	for child in list.get_children():
		var script = child.get_script()
		if script != null and script.resource_path == SHIP_SCRIPT and not child.owned:
			ships.append(child)
			first_index = min(first_index, child.get_index())
	if ships.empty():
		return
	var focused = list.get_focus_owner()
	var old_first = ships[0]
	var first_had_focus = focused != null and (focused == old_first or old_first.is_a_parent_of(focused))
	ships.sort_custom(self, "_before")
	for i in range(ships.size()):
		list.move_child(ships[i], first_index + i)
	if first_had_focus and ships[0] != old_first and ships[0].has_method("focus"):
		ships[0].focus()


func _before(a, b):
	var type_a = tr(a.shipLabel.text)
	var type_b = tr(b.shipLabel.text)
	if type_a != type_b:
		return type_a < type_b
	return _price(a) < _price(b)


# The price is only available as text such as "2,554,999 E$".
func _price(ship):
	return int(_not_digits.sub(ship.stickerPriceLabel.text, "", true))

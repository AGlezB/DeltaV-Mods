extends Node

# ShipSortByTypeAndPrice - sorts the ship list on the dealer screen by type (as
# shown, e.g. "K37 TNTRL"), then by price.

const SHIP_SCRIPT = "res://enceladus/SystemBuyUI.gd"

var _lists = {}
var _not_digits = RegEx.new()


func _ready():
	_not_digits.compile("[^0-9]")
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node):
	var script = node.get_script()
	if script == null or script.resource_path != SHIP_SCRIPT:
		return
	# New entries fill in their type and price a little later and then emit "done",
	# so sort again then. Entries that are added again are already filled in.
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
		yield(get_tree().create_timer(0.3), "timeout")
		for l in _lists.keys():
			if is_instance_valid(l) and l.is_inside_tree():
				_sort(l)
		_lists.clear()


# The fleet list uses the same entries, so only entries that are not owned are
# sorted. They are placed from the first entry's position, so anything above the
# entries stays where it is.
func _sort(list):
	var ships = []
	var first_index = list.get_child_count()
	for child in list.get_children():
		var script = child.get_script()
		if script != null and script.resource_path == SHIP_SCRIPT and not child.owned:
			ships.append(child)
			first_index = min(first_index, child.get_index())
	ships.sort_custom(self, "_before")
	for i in range(ships.size()):
		list.move_child(ships[i], first_index + i)


func _before(a, b):
	var type_a = tr(a.shipLabel.text)
	var type_b = tr(b.shipLabel.text)
	if type_a != type_b:
		return type_a < type_b
	return _price(a) < _price(b)


# The price is only available as text such as "2,554,999 E$".
func _price(ship):
	return int(_not_digits.sub(ship.stickerPriceLabel.text, "", true))

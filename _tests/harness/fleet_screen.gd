extends Control

# Stub of the station's Fleet screen (enceladus/Owned.tscn, Dealer.gd) for the fleet suite: it lists ships (its
# entries go in `Items`), and records the calls Dealer.gd use() makes after a switch: the `shipChanged` it emits, which
# the station answers by rebuilding the docked ship, and addShips().

signal shipChanged()

var changed = 0
var added = 0

func _ready():
	connect("shipChanged", self, "_on_shipChanged")

func _on_shipChanged():
	changed += 1

func addShips():
	added += 1

extends Control

# Stub of the station's Fleet screen (enceladus/Owned.tscn, Dealer.gd) for the fleet suite: it lists ships (its
# entries go in `Items`), and records the calls Dealer.gd use() makes after a switch: the `shipChanged` it emits, which
# the station answers by rebuilding the docked ship, and addShips(). It counts the Esc and pause presses that reach it,
# on which Dealer.gd _input closes the screen: once per frame, as Dealer.gd hide() does nothing more while its `hide`
# animation plays (the action stays just pressed for every event of its frame).

signal shipChanged()

var changed = 0
var added = 0
var cancels = 0
var cancelFrame = -1

func _ready():
	connect("shipChanged", self, "_on_shipChanged")

func _on_shipChanged():
	changed += 1

func addShips():
	added += 1

func _input(_event):
	if visible and (Input.is_action_just_pressed("ui_cancel") or (InputMap.has_action("pause") and Input.is_action_just_pressed("pause"))):
		if cancelFrame != Engine.get_idle_frames():
			cancelFrame = Engine.get_idle_frames()
			cancels += 1

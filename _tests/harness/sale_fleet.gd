extends "res://harness/fleet_screen.gd"

# Stub of the station's Fleet screen for the sale suite: fleet_screen.gd's, with its list in a column (`VB`, where
# ShipSaleAdvisor puts its note at the bottom), hidden as Dealer.gd hides it when another screen opens (the screens
# container's `hidefoka`), and its way back to the menu (`lastFocus`).

var lastFocus = null

func _ready():
	get_parent().connect("hidefoka", self, "hide")

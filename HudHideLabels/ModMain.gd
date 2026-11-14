extends Node

# HudHideLabels - hides the titles of the dive HUD's screens: VISUAL FEED, the name of
# the installed LIDAR, REMOTE SCANNER and CARGO HOLD. Each HUD is a res://hud/Display-*.tscn
# scene, instanced by the ship's Hud (hud/Hud.gd, instance()). The titles keep their space,
# so nothing else on the screens moves.

# Translation keys of the titles to hide (the text the game's Labels hold). Remove one to keep
# that title. HUD_LIDAR is the LIDAR's title: hud/HardwareLabel.gd replaces it with the LIDAR's
# name in its _ready.
const HIDDEN_KEYS = ["HUD_VISUAL_FEED", "HUD_LIDAR", "HUD_REMOTE_SCAN", "HUD_CARGO"]
# Only labels inside these scenes: the station screens (enceladus/Upgrades.tscn, Tuning.tscn)
# reuse the HUD's cargo hold and remote scanner, and the J screen (hud/OMS.tscn) has its own.
const DISPLAY_PREFIX = "res://hud/Display-"


func _init(_modLoader = null):
	pass


func _ready():
	get_tree().connect("node_added", self, "_on_node_added")


# No wait here, unlike the other observers: node_added runs for every node of a new subtree
# before any _ready, so the LIDAR's title still holds its key and its name never shows.
func _on_node_added(node):
	if not node is Label or not node.text in HIDDEN_KEYS:
		return
	if _in_display(node):
		node.self_modulate = Color(1, 1, 1, 0)


func _in_display(node) -> bool:
	var parent = node.get_parent()
	while parent != null:
		if parent.filename.begins_with(DISPLAY_PREFIX):
			return true
		parent = parent.get_parent()
	return false

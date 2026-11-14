extends "res://harness/suite.gd"

# HudHideLabels: the titles whose keys are in the mod's HIDDEN_KEYS (read from the mod, so any list passes) are hidden
# inside the HUD's res://hud/Display-*.tscn scenes, and nowhere else; the others are drawn. The LIDAR's title is renamed
# by the game's hud/HardwareLabel.gd. The trees are built in code with the node paths and types of the OCP-209's HUD
# (hud/Display-OCP209.tscn), of the station's Upgrades screen and of the J screen (hud/OMS.tscn); `filename` marks each
# scene root, as PackedScene.instance() does. The control checks (no mod loaded): every title is drawn.

var ship
var hud

# A scene root, as instanced from `file`.
func scene(type, nodeName, file):
	var root = ClassDB.instance(type)
	root.name = nodeName
	root.filename = file
	return root

# Adds `child` (a class name, or a node) under `parent` and returns it.
func add(parent, child, nodeName = ""):
	var node = ClassDB.instance(child) if child is String else child
	if nodeName != "":
		node.name = nodeName
	parent.add_child(node)
	return node

func title(parent, text, nodeName = "Label", script = null):
	var label = Label.new()
	label.name = nodeName
	label.text = text
	if script != null:
		label.set_script(script)
		label.slot = "lidar.type"
	parent.add_child(label)
	return label

func hidden(node) -> bool:
	return node.self_modulate.a == 0.0

func drawn(node) -> bool:
	return node.self_modulate.a == 1.0 and node.visible

# Hidden when `key` is one of the mod's `keys`, drawn when not.
func follows(node, key, keys) -> bool:
	return hidden(node) if key in keys else drawn(node)

func run():
	var mod = hasMod("HudHideLabels")
	# The ship and its Hud, as hud/Hud.tscn nests them; the Hud stub is the reader HardwareLabel.gd looks for.
	ship = Node2D.new()
	ship.set_script(load("res://harness/lidar_ship.gd"))
	add(self, ship, "Ship")
	hud = Control.new()
	hud.set_script(load("res://harness/lidar_reader.gd"))
	hud.ship = ship
	add(ship, hud, "Hud")
	var huds = add(hud, "Node2D", "Huds")
	yield(get_tree(), "physics_frame")

	# The OCP-209's HUD, built off the tree and added in one go, as Hud.gd instance() does with replace_by_instance().
	var display = scene("Container", "SYSTEM_HUD_OCP209", "res://hud/Display-OCP209.tscn")
	var viewports = add(display, "Node2D", "Viewports")
	var visFeedBox = add(add(viewports, "Viewport", "VisFeedViewport"), "PanelContainer", "VisFeedBox")
	var feed = title(visFeedBox, "HUD_VISUAL_FEED")
	var feedScene = add(visFeedBox, scene("PanelContainer", "EnceladusFeed", "res://hud/components/EnceladusFeed.tscn"))
	var feedLabel2 = title(feedScene, "HUD_VISUAL_FEED", "Label2")
	var radar = add(add(add(viewports, "Viewport", "LidarViewport"), "PanelContainer", "RadarBox"), "MarginContainer", "MarginContainer")
	var lidar = title(radar, "HUD_LIDAR", "Label", load("res://hud/HardwareLabel.gd"))
	var cargoBox = add(add(add(add(viewports, "Viewport", "CargoViewport"), "MarginContainer", "MarginContainer"), "MarginContainer", "CargoHold"), "VBoxContainer", "VBoxContainer")
	var cargo = title(cargoBox, "HUD_CARGO")
	var remoteBox = add(add(viewports, "Viewport", "RemoteSpecroView"), "PanelContainer", "RemoteBox")
	var remote = title(remoteBox, "HUD_REMOTE_SCAN")
	var other = title(remoteBox, "HUD_BEARING", "Label3")
	var button = Button.new()
	button.text = "HUD_CARGO"
	add(cargoBox, button, "Button")
	huds.add_child(display)

	# The J screen (Hud's Inventory) and the station's Upgrades screen reuse these titles outside any Display-*.tscn.
	var oms = scene("Control", "Inventory", "res://hud/OMS.tscn")
	var omsCargo = title(add(add(oms, "Control", "Cargo Panel"), "VBoxContainer", "VBoxContainer"), "HUD_CARGO", "Label Scan")
	hud.add_child(oms)
	var upgrades = scene("Control", "Upgrades", "res://enceladus/Upgrades.tscn")
	var stationCargo = title(add(add(upgrades, scene("HBoxContainer", "CargoHold", "res://hud/trtl/CargoHold.tscn")), "VBoxContainer", "VBoxContainer"), "HUD_CARGO", "Label Scan")
	var stationRemote = title(add(upgrades, scene("GridContainer", "RemoteSpectrometer", "res://hud/RemoteSpectrometer.tscn")), "HUD_REMOTE_SCAN", "Label2")
	add_child(upgrades)
	yield(get_tree(), "physics_frame")

	# [title, the key it was created with (the LIDAR's is renamed in its _ready), name]
	var titles = [[feed, "HUD_VISUAL_FEED", "VISUAL FEED"], [feedLabel2, "HUD_VISUAL_FEED", "VISUAL FEED of the feed sub-scene (EnceladusFeed.tscn)"],
		[lidar, "HUD_LIDAR", "the LIDAR's title"], [cargo, "HUD_CARGO", "CARGO HOLD"], [remote, "HUD_REMOTE_SCAN", "REMOTE SCANNER"]]
	check("the LIDAR's title shows the ship's LIDAR (the game's HardwareLabel.gd)", lidar.text == ship.getLidarType(), lidar.text)
	if not mod:
		var allDrawn = true
		for t in titles:
			allDrawn = allDrawn and drawn(t[0])
		check("control: without the mod every title on the HUD is drawn", allDrawn)
		check("control: without the mod the station's titles are drawn", drawn(stationCargo) and drawn(stationRemote))
		return

	var keys = load("res://HudHideLabels/ModMain.gd").get_script_constant_map()["HIDDEN_KEYS"]
	for t in titles:
		check("%s: hidden if its key is in HIDDEN_KEYS, drawn if not" % t[2], follows(t[0], t[1], keys), "%s in HIDDEN_KEYS: %s" % [t[1], t[1] in keys])
	var keepSpace = true
	for t in titles:
		keepSpace = keepSpace and t[0].visible
	check("the titles stay visible, so the hidden ones keep their space", keepSpace)
	check("another label on the HUD is drawn", drawn(other))
	check("a button with a title's text is drawn", button.self_modulate.a == 1.0)
	check("the J screen's CARGO HOLD (OMS.tscn) is drawn", drawn(omsCargo))
	check("the station's CARGO HOLD (trtl/CargoHold.tscn) is drawn", drawn(stationCargo))
	check("the station's REMOTE SCANNER (RemoteSpectrometer.tscn) is drawn", drawn(stationRemote))

	var late = title(radar, "HUD_REMOTE_SCAN", "Late")
	yield(get_tree(), "physics_frame")
	check("a title added later to a HUD already shown follows HIDDEN_KEYS too", follows(late, "HUD_REMOTE_SCAN", keys))

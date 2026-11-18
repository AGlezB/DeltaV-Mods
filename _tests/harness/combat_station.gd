extends Node

# The combat suite's stand-ins for the station's parts around CombatSimulator and for the arena's, one inner class each
# (they are small, and made in code; the scenes' roots have files of their own: harness/combat_field.gd,
# combat_bullet_timer.gd, combat_ship.gd):
# - Simulation: the simulator's layer (enceladus/Simulator/SimulationLayer.gd), which records what startSimulation is
#   given (Enceladus.tscn wires every screen's simulateShipConfig to it) and starts nothing;
# - Screen, Tuning, Dealer: a station screen with the simulator's button (enceladus/Tuning.gd, Dealer.gd): its
#   _on_LaunchVR_pressed sends the config its simulator flies (Tuning previewedConfig, Dealer currentConfig), and it
#   closes on Esc from its _input, as the game's screens do;
# - Mouse: the cursor (menu/Mouse.gd, the station's MouseLayer/Mouse and the pause menu's), which takes its layer's
#   fadeTime once, in _ready, and has the switch the pause menu sets (enabled);
# - Hud: the HUD part the ring map (hud/Video.gd) and the gravimetric readout (hud/GravimetricReadout.gd) look for among
#   their parents (getSensorReadout); the ring map takes its parent as the ship, the readout asks getShip;
# - Probe: records the key and button events that reach its _input, standing in for what the arena's viewport holds
#   (the ship's camera opens and closes the OMS from its _input, ships/camera.gd);
# - Flagged: a node with a story flag, as the game's reactors have (ships/Reactor.gd storyFlag);
# - Weapon: a weapon that records the power it is fired with (a hardpoint's system, a turret's).

class Simulation extends CanvasLayer:
	var started = []

	func startSimulation(sim):
		started.append(sim)

class Screen extends PanelContainer:
	signal simulateShipConfig(cfg)

	func _input(_event):
		if visible and (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause")):
			get_tree().set_input_as_handled()
			hide()

class Tuning extends Screen:
	var previewedConfig = null

	func _on_LaunchVR_pressed():
		if previewedConfig:
			emit_signal("simulateShipConfig", previewedConfig)

class Dealer extends Screen:
	var currentConfig = null

	func _on_LaunchVR_pressed():
		if currentConfig:
			emit_signal("simulateShipConfig", currentConfig)

class Mouse extends Node2D:
	var enabled = true
	var fadeTime = 0

	func _ready():
		fadeTime = get_parent().fadeTime

class Hud extends Node2D:
	signal shipChanged

	func getSensorReadout():
		return {}

	func getShip():
		return get_parent()

class Probe extends Node:
	var events = []

	func _input(event):
		if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
			events.append(event)

class Flagged extends Node2D:
	var storyFlag = "vilcy.bbw.destroyed"

class Weapon extends Node2D:
	var fired = []

	func fire(p):
		fired.append(p)

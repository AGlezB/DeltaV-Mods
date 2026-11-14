extends "res://harness/suite.gd"

# DiveDisableAdrenalineBooster: the player's Adrenaline Booster (the game's ships/CabinLight.gd) starts every dive
# switched off. Ported from the claude.ai harness (DVModTestHarness 1.0.0, dive/main.gd). The control check (the game
# alone starts it enabled) runs on the game's own script: with the mod loaded, that is the base of the extension.

func make(player, sysName = "SYSTEM_ADRENALINE_BOOSTER", underShip = true, script = null):
	var parent = Node2D.new()
	var host = parent
	if underShip:
		host = Node2D.new(); host.set_script(load("res://harness/dive_ship.gd")); host.playerControlled = player
		parent.add_child(host)
	var light = Sprite.new(); light.set_script(script if script != null else load("res://ships/CabinLight.gd")); light.systemName = sysName
	host.add_child(light)
	add_child(parent)
	return light

func run():
	var mod = hasMod("DiveDisableAdrenalineBooster")
	var game = load("res://ships/CabinLight.gd")
	if mod:
		game = game.get_base_script()
	yield(get_tree(), "physics_frame")
	var p = make(true)
	var n = make(false)
	var other = make(true, "SYSTEM_OTHER")
	var bare = make(false, "SYSTEM_ADRENALINE_BOOSTER", false)
	var control = make(true, "SYSTEM_ADRENALINE_BOOSTER", true, game)
	yield(get_tree(), "physics_frame")
	check("control: without the mod the player's booster starts enabled", control.enabled == true)
	if not mod:
		return
	check("player's booster starts disabled", p.enabled == false)
	check("another ship's booster is untouched", n.enabled == true)
	check("another cabin light system is untouched", other.enabled == true)
	check("no ship (habitat) is untouched and does not fail", bare.enabled == true)
	p.enabled = true
	for i in range(3): yield(get_tree(), "physics_frame")
	check("switching it on later is kept", p.enabled == true)
	p.bootProgress = p.bootTime
	CurrentGame.adrenalineSum = 0.0
	p.fire(1.0)
	p._process(0.1)
	check("enabled: firing the booster gives adrenaline", CurrentGame.adrenalineSum > 0)
	p.enabled = false
	CurrentGame.adrenalineSum = 0.0
	p._process(0.1)
	check("disabled: no adrenaline is given", CurrentGame.adrenalineSum <= 0)

extends "res://Game.gd"

# The ring scene (Game.gd). A dive starts with the arrival cutscene: _ready spawns the player's ship at
# initialPosition, coming in at initialSpeed (both from desiredAcceleration and initialCutsceneTime), and _process
# brakes it at desiredAcceleration for totalCutsceneTime (Game.tscn sets the two times), turns it to face into the
# rings near the end and then hands it to the player, while "intro", a title card, covers the screen. The ship really
# flies: its thrusters and its reactor's turbine burn remass, and in-game time passes. The remass left carries over to
# the next dive (ships/ship-ctrl.gd _exit_tree, storeCurrentSuppliesInConfig). The mod puts the ship where the
# cutscene leaves it, lets the game's own _process end the cutscene on its first frame, jumps the title card to its
# end, and charges what the cutscene would have cost.

# The fission reactor, whose turbine burns remass every physics frame (ships/Reactor.gd _physics_process). The fusion
# reactor's (ships/modules/FusionReactor.gd) burns none.
const _DST_REACTOR_SCRIPT = "res://ships/Reactor.gd"
# The heading Game.gd _process turns the ship to before the cutscene ends: into the rings.
const _DST_RING_HEADING = PI / 2
# World units in a metre: the game shows 10 world units as 1 m.
const _DST_UNITS_PER_METRE = 10.0

# Game.gd's _ready has run first (Godot runs every level's _ready, base first): it has spawned the ship (_respawn_ship
# adds it to the tree deferred) and waits for the ship's setup.
func _ready():
	_dstSkipArrival()

func _dstSkipArrival():
	if not cutscene or si == null:
		return
	var seconds = totalCutsceneTime
	# Game.gd _process brakes the ship along dvel = initialSpeed - Vector2(1, 0) * desiredAcceleration * eclapsedTime.
	var braking = Vector2(1, 0) * desiredAcceleration
	si.position = initialPosition + initialSpeed * seconds - braking * seconds * seconds / 2
	si.linear_velocity = initialSpeed - braking * seconds
	si.rotation = _DST_RING_HEADING
	si.autopilotDesiredRotation = _DST_RING_HEADING
	# Game.gd _process ends the cutscene on its next frame, with its own code: the ship's cutscene off, the autopilot's
	# end values, the time scale.
	eclapsedTime = seconds
	var titles = $TitleAnimPlayer
	if titles.current_animation == "intro":
		titles.seek(titles.current_animation_length, true)
	var ship = si
	yield(ship, "setup")
	if Tool.claim(ship):
		_dstChargeDv(ship, (braking * seconds).length() / _DST_UNITS_PER_METRE)
		_dstChargeSeconds(ship, seconds)
		Tool.release(ship)

# The remass the ship's thrusters burn for a change of speed of `dv` m/s: the game's rocket equation
# (ships/ship-ctrl.gd getRemassRequiredForDv).
func _dstChargeDv(ship, dv):
	ship.drawReactiveMass(ship.getRemassRequiredForDv(dv))

# What `seconds` in the ring cost besides thrust: the in-game time (the asteroid field advances it every frame,
# AsteroidSpawner.gd _process), and the remass each fission reactor's turbine draws, turbineConsumption per second
# while the reactor is enabled or still at or above its coldLimit and the ship isn't frozen (ships/Reactor.gd
# _physics_process).
func _dstChargeSeconds(ship, seconds):
	CurrentGame.advanceTimeBySeconds(seconds)
	if ship.frozen:
		return
	for reactor in ship.reactors:
		var script = reactor.get_script()
		if script == null or script.resource_path != _DST_REACTOR_SCRIPT or reactor.exploding:
			continue
		if reactor.enabled or reactor.temperature >= reactor.coldLimit:
			ship.drawReactiveMass(reactor.turbineConsumption * seconds)

extends "res://Game.gd"

# The ring scene (Game.gd). Two of its cutscenes really fly the ship: its thrusters and its reactor's turbine burn
# remass, and in-game time passes. The remass left carries over to the next dive (ships/ship-ctrl.gd _exit_tree,
# storeCurrentSuppliesInConfig). While its setting is on, the mod skips each one and charges what it would have cost.
# - The arrival: _ready spawns the player's ship at initialPosition, coming in at initialSpeed (both from
#   desiredAcceleration and initialCutsceneTime), and _process brakes it at desiredAcceleration for totalCutsceneTime
#   (Game.tscn sets the two times), turns it to face into the rings near the end and then hands it to the player,
#   while "intro", a title card, covers the screen. The mod puts the ship where the cutscene leaves it, lets the game's
#   own _process end the cutscene on its first frame and jumps the title card to its end.
# - The exit, diving back or at overspeed: ships/ship-ctrl.gd escapeTheRing turns the ship to the escape heading, sets
#   the autopilot's desired velocity far out of the rings, with comfort and collisions off, and emits exitingRing;
#   _on_exitingRing plays "exit": the ship burns away from the ring (the departure) under the title card of the trip
#   to Enceladus, and the animation's method keys charge the transit (interlunarToEnceladus), clear the asteroids and
#   go to the station (goToEnceladus). The mod calls those at once, in order, charging the stretch before each.

# The settings (which skips are on), shared with the settings screen.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
# The fission reactor, whose turbine burns remass every physics frame (ships/Reactor.gd _physics_process). The fusion
# reactor's (ships/modules/FusionReactor.gd) burns none.
const _DST_REACTOR_SCRIPT = "res://ships/Reactor.gd"
# The heading Game.gd _process turns the ship to before the arrival ends: into the rings.
const _DST_RING_HEADING = PI / 2
# World units in a metre: the game shows 10 world units as 1 m.
const _DST_UNITS_PER_METRE = 10.0
# The ship's forward axis in its own frame, which the escape heading points out of the rings: a hull points up
# (ship-ctrl.gd: Vector2(0, -1).rotated(rotation)), and a thruster's push is its own up (sfx/thruster.gd
# getLocalThrustVector).
const _DST_FORWARD = Vector2(0, -1)
# Kilograms in a tonne: the game's ship masses are in t (ship-ctrl.gd computeCurrentMass).
const _DST_KG_PER_TONNE = 1000.0

# Game.gd's _ready has run first (Godot runs every level's _ready, base first): it has spawned the ship (_respawn_ship
# adds it to the tree deferred) and waits for the ship's setup.
func _ready():
	_dstSkipArrival()

func _dstSkipArrival():
	if not cutscene or si == null or not DiveSkipTransit.shared().getValue("skipArrival"):
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

# The parent plays "exit" and lets every ship and drone take its leave (handleExitToEnceladus).
func _on_exitingRing():
	._on_exitingRing()
	var titles = $TitleAnimPlayer
	if titles.current_animation == "exit" and si != null and DiveSkipTransit.shared().getValue("skipExit"):
		_dstSkipExit(titles)

# The method keys of "exit", read from the animation, called in time order (keys at the same time in track order),
# each after charging the stretch of the cutscene before it: so the transit is charged from the remass the departure
# leaves, as in the cutscene. Nothing is charged after the last key: the scene switches. A seek calls no method keys;
# it leaves the title card's last frame, black, on screen until the station is loaded.
func _dstSkipExit(titles):
	var exit = titles.get_animation("exit")
	var keys = []
	for track in exit.get_track_count():
		if exit.track_get_type(track) != Animation.TYPE_METHOD or not exit.track_is_enabled(track):
			continue
		for key in exit.track_get_key_count(track):
			keys.append([exit.track_get_key_time(track, key), keys.size(), exit.track_get_path(track),
					exit.method_track_get_name(track, key), exit.method_track_get_params(track, key)])
	keys.sort_custom(self, "_dstIsKeyBefore")
	var burn = _dstEscapeBurn(si)
	var root = titles.get_node(titles.root_node)
	var elapsed = 0.0
	for key in keys:
		if key[0] > elapsed and Tool.claim(si):
			_dstChargeEscape(si, burn, key[0] - elapsed)
			_dstChargeSeconds(si, key[0] - elapsed)
			Tool.release(si)
		elapsed = max(elapsed, key[0])
		var node = root.get_node_or_null(key[2])
		if node != null:
			node.callv(key[3], key[4])
	titles.seek(exit.length, true)

func _dstIsKeyBefore(a, b):
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

# The departure's burn, as "exit" would fly it: from the ship's velocity to the autopilot's desired velocity
# escapeTheRing set, at full throttle on the thrusters that push along the ship's forward axis. The autopilot fires each
# thruster at its alignment with the push (ship-ctrl.gd fireVector, which fires switched-off thrusters too during a
# cutscene). A thruster pushes with realThrust * cf, an impulse per second on a mass in t, and burns
# cf * realThrust * power / (specificImpulse * 10) kg/s (sfx/thruster.gd _physics_process, realThrust =
# getThrust() * 10, cf = getChoke()). Also the ship's mass then, as the game's rocket equation counts it
# (getRemassRequiredForDv), and its remass, to tell what is drawn later.
func _dstEscapeBurn(ship):
	var burn = {"dv": 0.0, "push": 0.0, "flow": 0.0, "mass": 0.0, "remass": 0.0}
	if not Tool.claim(ship):
		return burn
	burn.dv = (ship.autopilotDesiredVelocity - ship.linear_velocity).length() / _DST_UNITS_PER_METRE
	for name in ship.thrusters:
		var thruster = ship.thrusters[name]
		var node = thruster.node
		var alignment = thruster.vector.normalized().dot(_DST_FORWARD)
		if alignment <= 0 or not node.has_method("getThrust") or not node.has_method("getChoke") \
				or not "specificImpulse" in node or node.specificImpulse <= 0:
			continue
		var power = min(1.0, alignment)
		var thrust = node.getThrust() * 10 * node.getChoke()
		burn.push += thrust * power * alignment
		burn.flow += thrust * power / (node.specificImpulse * 10)
	burn.mass = ship.currentMass * _DST_KG_PER_TONNE + ship.cargoMass + ship.temporaryCargoMass()
	burn.remass = ship.reactiveMass
	Tool.release(ship)
	return burn

# The departure's remass over `seconds`: the rocket equation at the burn's exhaust velocity (its push over its flow; a
# push of 1 is 1 t speeding up 1 world unit/s every second), for the change of speed still needed or what the
# thrusters reach in `seconds`, whichever is smaller. The mass is the one at the start, less the remass drawn since.
func _dstChargeEscape(ship, burn, seconds):
	if burn.dv <= 0 or burn.flow <= 0 or burn.push <= 0:
		return
	var mass = burn.mass - (burn.remass - ship.reactiveMass)
	var exhaust = burn.push * _DST_KG_PER_TONNE / _DST_UNITS_PER_METRE / burn.flow
	var reachable = INF
	if burn.flow * seconds < mass:
		reachable = exhaust * log(mass / (mass - burn.flow * seconds))
	var dv = min(burn.dv, reachable)
	burn.dv -= dv
	ship.drawReactiveMass(mass * (1 - exp( - dv / exhaust)))

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

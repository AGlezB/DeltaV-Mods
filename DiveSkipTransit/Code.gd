extends "res://Game.gd"

# The ring scene (Game.gd), whose cutscenes the mod skips, each while its setting is on. Two of them really fly the
# ship (its thrusters and its reactor's turbine burn remass, and in-game time passes), and the mod charges what they
# would have cost: the remass left carries over to the next dive (ships/ship-ctrl.gd _exit_tree,
# storeCurrentSuppliesInConfig).
# - The arrival: _ready spawns the player's ship at initialPosition, coming in at initialSpeed (both from
#   desiredAcceleration and initialCutsceneTime), and _process brakes it at desiredAcceleration for totalCutsceneTime
#   (Game.tscn sets the two times), turns it to face into the rings near the end and then hands it to the player,
#   while "intro", a title card, covers the screen. The mod puts the ship where the cutscene leaves it, lets the game's
#   own _process end the cutscene on its first frame and jumps the title card to its end.
# - The exit, diving back or at overspeed: ships/ship-ctrl.gd escapeTheRing turns the ship to the escape heading, sets
#   the autopilot's desired velocity far out of the rings, with comfort and collisions off, and emits exitingRing;
#   _on_exitingRing plays "exit": the ship burns away from the ring (the departure) under the title card of the trip
#   to Enceladus, and the animation's method keys charge the transit (interlunarToEnceladus), clear the asteroids and
#   go to the station (goToEnceladus).
# - The rescue, out of remass: _process plays "helpless", whose method keys call the rescue ship (sendHelp) and go to
#   the station. It burns nothing (the tank is empty): only its in-game time is charged.
# - The game over, after a meltdown: _on_gameOver plays "gameover", which ends on the title screen (gameOverScreen).
# - Astrogation's title card, "fasttravel" (_onFastTravel): the trip itself is skipped by Ship.gd.
# The mod plays each through at once (DiveSkipTransit.playThrough): the method keys are called in order, each after
# charging the stretch of the cutscene before it. The arrival and the exit, the transit, share one switch; while it is
# off, the mod plays them at the transit speed instead, without Space (the pacing, below).

# The settings (which skips are on), shared with the settings screen, and the code the skips share.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
# The heading Game.gd _process turns the ship to before the arrival ends: into the rings.
const _DST_RING_HEADING = PI / 2
# The ship's forward axis in its own frame, which the escape heading points out of the rings: a hull points up
# (ship-ctrl.gd: Vector2(0, -1).rotated(rotation)), and a thruster's push is its own up (sfx/thruster.gd
# getLocalThrustVector).
const _DST_FORWARD = Vector2(0, -1)
# The game's speed while Space is held in a cutscene (Game.gd _process): above it, the transit plays muted.
const _DST_SPACE_SPEED = 3.0
# The master bus, which the game mutes while its window is out of focus (Settings.gd _notification).
const _DST_MASTER_BUS = 0

var _dstBurn = null # the departure's burn while the exit is played through (_dstEscapeBurn)
var _dstPace = 0.0 # the speed the mod plays the transit at, or 0 while it doesn't
var _dstBaseRate = 0 # the physics rate (Engine.iterations_per_second) when the pacing started

# Game.gd's _ready has run first (Godot runs every level's _ready, base first): it has spawned the ship (_respawn_ship
# adds it to the tree deferred) and waits for the ship's setup. "helpless" is played inside _process, so it is caught
# when the title card player starts it.
func _ready():
	$TitleAnimPlayer.connect("animation_started", self, "_dstOnTitleCard")
	_dstSkipArrival()

func _dstSkipArrival():
	if not cutscene or si == null or not DiveSkipTransit.shared().getValue("skipTransit"):
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
		DiveSkipTransit.chargeDv(ship, (braking * seconds).length() / DiveSkipTransit.UNITS_PER_METRE)
		DiveSkipTransit.chargeSeconds(ship, seconds)
		Tool.release(ship)

# The parent plays "exit" and lets every ship and drone take its leave (handleExitToEnceladus). The transit is charged
# from the remass the departure leaves, as in the cutscene.
func _on_exitingRing():
	._on_exitingRing()
	var titles = $TitleAnimPlayer
	if titles.current_animation == "exit" and si != null and DiveSkipTransit.shared().getValue("skipTransit"):
		_dstBurn = _dstEscapeBurn(si)
		DiveSkipTransit.playThrough(titles, "exit", funcref(self, "_dstChargeExitStretch"))

func _dstChargeExitStretch(seconds):
	if Tool.claim(si):
		_dstChargeEscape(si, _dstBurn, seconds)
		DiveSkipTransit.chargeSeconds(si, seconds)
		Tool.release(si)

# Deferred: _process starts "helpless" after setting up the rescue (the reactor off, the cargo claimed), and the
# rescue is played through once that frame's processing is done.
func _dstOnTitleCard(animName):
	if animName == "helpless" and DiveSkipTransit.shared().getValue("skipRescue"):
		call_deferred("_dstSkipRescue")

func _dstSkipRescue():
	var titles = $TitleAnimPlayer
	if titles.current_animation == "helpless":
		DiveSkipTransit.playThrough(titles, "helpless", funcref(self, "_dstChargeStretch"))

func _dstChargeStretch(seconds):
	if Tool.claim(si):
		DiveSkipTransit.chargeSeconds(si, seconds)
		Tool.release(si)

# The parent starts the game over only the first time (gamerunning); a second gameOver changes nothing.
func _on_gameOver():
	var starting = gamerunning
	._on_gameOver()
	var titles = $TitleAnimPlayer
	if starting and titles.current_animation == "gameover" and DiveSkipTransit.shared().getValue("skipGameOver"):
		DiveSkipTransit.playThrough(titles, "gameover")

# The ship emits fastTraveling when astrogation starts; while its setting is on, Ship.gd has already made the trip.
func _onFastTravel():
	._onFastTravel()
	var titles = $TitleAnimPlayer
	if titles.current_animation == "fasttravel" and DiveSkipTransit.shared().getValue("skipAstrogation"):
		DiveSkipTransit.playThrough(titles, "fasttravel")

# The pacing: while the transit skip is off, the arrival and the exit play at the transit speed, without Space. During
# a cutscene, Game.gd _process sets CurrentGame.targetTimeScale every frame (the Space speed while it is held, else
# 1), and BulletTimer.gd _physics_process eases Engine.time_scale towards it at timeSlowPerSecond, then sets it back
# to 1. The mod sets both the target and the time scale itself, in its _physics_process: that runs after the previous
# frame's Game.gd _process and before BulletTimer's (Game's child), which then finds nothing to ease. Physics steps by
# time_scale / iterations_per_second, so the mod raises the physics rate with the speed above the Space speed: every
# step keeps the size the game's own fast-forward gives it, and the frame takes more of them (Godot 3 takes at most 8
# a frame, so a slower machine just goes less fast). Above the Space speed the master bus is muted.
func _physics_process(_delta):
	var pace = _dstTransitPace()
	if pace > 0:
		_dstApplyPace(pace)
	elif _dstPace > 0:
		_dstStopPace()

# Settings.gd _process puts the physics rate back to the player's once a second; it runs before the scene's, and a
# frame counts its physics steps from the rate it starts with, so the pace's rate goes back here first.
func _process(_delta):
	if _dstPace > 0:
		_dstApplyPace(_dstPace)

func _exit_tree():
	if _dstPace > 0:
		_dstStopPace()

# The speed the transit cutscene running now plays at, or 0: none is running, the transit is skipped, or the speed
# is the game's own. On the arrival it tapers to 1x by the end, as the game's Space speed does; it is never below what
# the game asked for (holding Space).
func _dstTransitPace() -> float:
	var settings = DiveSkipTransit.shared()
	if settings.getValue("skipTransit"):
		return 0.0
	var speed = settings.getValue("transitSpeed")
	if cutscene and si != null:
		speed = lerp(speed, 1.0, clamp(eclapsedTime / totalCutsceneTime, 0.0, 1.0))
	elif not (has_node("TitleAnimPlayer") and $TitleAnimPlayer.current_animation == "exit"):
		return 0.0
	if speed <= 1.0:
		return 0.0
	return max(speed, CurrentGame.targetTimeScale)

func _dstApplyPace(pace):
	if _dstPace <= 0:
		_dstBaseRate = Engine.iterations_per_second
	_dstPace = pace
	CurrentGame.targetTimeScale = pace
	Engine.time_scale = pace
	Engine.iterations_per_second = int(ceil(_dstBaseRate * max(1.0, pace / _DST_SPACE_SPEED)))
	if pace > _DST_SPACE_SPEED:
		AudioServer.set_bus_mute(_DST_MASTER_BUS, true)
	else:
		_dstRestoreMute()

# Back to the game's: its physics rate, its mute, and normal time, which is where the game's own end of a cutscene
# leaves it (Game.gd _process; goToEnceladus).
func _dstStopPace():
	Engine.iterations_per_second = _dstBaseRate
	Engine.time_scale = 1.0
	CurrentGame.targetTimeScale = 1.0
	_dstRestoreMute()
	_dstPace = 0.0

# The master bus muted as the game mutes it: while the window is out of focus, unless streaming.
func _dstRestoreMute():
	AudioServer.set_bus_mute(_DST_MASTER_BUS, not Settings.focused and not Settings.cfg.gameplay.streaming)

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
	burn.dv = (ship.autopilotDesiredVelocity - ship.linear_velocity).length() / DiveSkipTransit.UNITS_PER_METRE
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
	burn.mass = ship.currentMass * DiveSkipTransit.KG_PER_TONNE + ship.cargoMass + ship.temporaryCargoMass()
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
	var exhaust = burn.push * DiveSkipTransit.KG_PER_TONNE / DiveSkipTransit.UNITS_PER_METRE / burn.flow
	var reachable = INF
	if burn.flow * seconds < mass:
		reachable = exhaust * log(mass / (mass - burn.flow * seconds))
	var dv = min(burn.dv, reachable)
	burn.dv -= dv
	ship.drawReactiveMass(mass * (1 - exp( - dv / exhaust)))

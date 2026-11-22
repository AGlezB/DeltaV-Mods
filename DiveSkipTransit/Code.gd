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
# off, the mod plays them at the transit speed instead, without Space (the pacing, below). What the game's notification
# panel still had to show when the ring scene goes to the station, the station's panel shows (goToEnceladus); a sped-up
# exit too short for it hides the ring's panel as it starts (_dstFitNotices).

# The settings (which skips are on), shared with the settings screen, and the code the skips share.
const DiveSkipTransit = preload("res://DiveSkipTransit/Settings.gd")
# The heading Game.gd _process turns the ship to before the arrival ends: into the rings.
const _DST_RING_HEADING = PI / 2
# The ship's forward axis in its own frame, which the escape heading points out of the rings: a hull points up
# (ship-ctrl.gd: Vector2(0, -1).rotated(rotation)), and a thruster's push is its own up (sfx/thruster.gd
# getLocalThrustVector).
const _DST_FORWARD = Vector2(0, -1)
# The game's speed while Space is held in a cutscene (Game.gd _process): above it, the transit plays without sound.
const _DST_SPACE_SPEED = 3.0
# The master bus, which the game mutes while its window is out of focus (Settings.gd _notification).
const _DST_MASTER_BUS = 0
# The game's notification panel in the ring scene (BulletTimer.tscn's Notifications, achievement/Notifications.gd): its
# `animation` plays each notice ("acquired", "lost", "inTransit", a level-up, …) and queues the next.
const _DST_NOTICES = "BulletTimer/NotificationsLayer/Notifications"

var _dstBurn = null # the departure's burn while the exit is played through (_dstEscapeBurn)
var _dstPace = 0.0 # the speed the mod plays the transit at, or 0 while it doesn't
var _dstBaseRate = 0 # the physics rate (Engine.iterations_per_second) when the pacing started
var _dstModel = null # the settings (Settings.gd), kept in _ready: _physics_process asks them every frame
var _dstTitles = null # the ring scene's title card player (Game.tscn TitleAnimPlayer), kept in _ready
var _dstNotices = [] # the notices the panel is showing or has queued, each [handler, args] (_dstNote)
var _dstHidden = false # the panel is hidden for the rest of the ring scene: every notice noted goes to the station

# Game.gd's _ready has run first (Godot runs every level's _ready, base first): it has spawned the ship (_respawn_ship
# adds it to the tree deferred) and waits for the ship's setup. "helpless" is played inside _process, so it is caught
# when the title card player starts it.
func _ready():
	_dstModel = DiveSkipTransit.shared()
	_dstTitles = $TitleAnimPlayer
	_dstTitles.connect("animation_started", self, "_dstOnTitleCard")
	_dstListenToNotices()
	_dstSkipArrival()

func _dstSkipArrival():
	if not cutscene or si == null or not _dstModel.getValue("skipTransit"):
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
	var titles = _dstTitles
	if titles.current_animation == "intro":
		titles.seek(titles.current_animation_length, true)
	var ship = si
	yield(ship, "setup")
	if Tool.claim(ship):
		DiveSkipTransit.chargeDv(ship, (braking * seconds).length() / DiveSkipTransit.UNITS_PER_METRE)
		DiveSkipTransit.chargeSeconds(ship, seconds)
		Tool.release(ship)

# The parent plays "exit" and lets every ship and drone take its leave (handleExitToEnceladus). The transit is charged
# from the remass the departure leaves, as in the cutscene. Sped up instead, the exit may end before the notification
# panel has shown what leaving brought (_dstFitNotices).
func _on_exitingRing():
	._on_exitingRing()
	var titles = _dstTitles
	if titles.current_animation == "exit" and si != null and _dstModel.getValue("skipTransit"):
		_dstBurn = _dstEscapeBurn(si)
		DiveSkipTransit.playThrough(titles, "exit", funcref(self, "_dstChargeExitStretch"))
	elif _dstTransitPace() > 0:
		_dstFitNotices()

func _dstChargeExitStretch(seconds):
	if Tool.claim(si):
		_dstChargeEscape(si, _dstBurn, seconds)
		DiveSkipTransit.chargeSeconds(si, seconds)
		Tool.release(si)

# Deferred: _process starts "helpless" after setting up the rescue (the reactor off, the cargo claimed), and the
# rescue is played through once that frame's processing is done.
func _dstOnTitleCard(animName):
	if animName == "helpless" and _dstModel.getValue("skipRescue"):
		call_deferred("_dstSkipRescue")

func _dstSkipRescue():
	var titles = _dstTitles
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
	var titles = _dstTitles
	if starting and titles.current_animation == "gameover" and _dstModel.getValue("skipGameOver"):
		DiveSkipTransit.playThrough(titles, "gameover")

# The ship emits fastTraveling when astrogation starts; while its setting is on, Ship.gd has already made the trip.
func _onFastTravel():
	._onFastTravel()
	var titles = _dstTitles
	if titles.current_animation == "fasttravel" and _dstModel.getValue("skipAstrogation"):
		DiveSkipTransit.playThrough(titles, "fasttravel")

# The way to the station: the last method key of "exit" and of "helpless". The game's notification panel announces what
# leaving brought (ships/ship-ctrl.gd handleExitToEnceladus, from escapeTheRing and from Game.gd sendHelp): the ship
# the arm held, salvaged (CurrentGame.addShip emits newShip, and Notifications.gd _newShip plays "acquired", where the
# ship's name fades in from 0.7 s), and the drones' cargo in transit (claimCargo emits transit). The game's cutscenes
# end long after the panel has finished; a skipped or sped-up one gets here at once, and the station would cut the
# panel short. So what it is still showing or has queued, or all it was given since it was hidden for a sped-up exit
# (_dstFitNotices), goes to the station's panel instead (Station.gd), and the ring's is hidden and stopped, so it
# neither flashes part of a notice nor plays its sound while the station loads. (The game over goes to the title
# screen, which has no panel.)
func goToEnceladus():
	if not _dstNotices.empty() and (_dstHidden or _dstNoticesShowing()):
		_dstModel.carriedNotices = _dstNotices.duplicate()
		_dstNotices.clear()
		_dstHideNotices()
	.goToEnceladus()

# A sped-up exit gives the panel what is left of the exit over its speed: the game plays its notices in real time
# (Notifications.gd _process: playback_speed = 1 / Engine.time_scale). Where that is shorter than what the panel has to
# show, a notice would stand on screen part shown (the ship's name fades in last), so the panel is hidden from then on,
# and all it was given goes to the station's (goToEnceladus). Checked as the exit starts, after escapeTheRing's notices
# (the salvage, a drone's cargo in transit), and at each notice during it.
func _dstFitNotices():
	if not _dstHidden and not _dstNotices.empty() and _dstNoticesShowing() \
			and _dstExitSecondsLeft() < _dstNoticeSecondsLeft():
		_dstHideNotices()

func _dstExitSecondsLeft() -> float:
	var pace = _dstTransitPace()
	if pace <= 0:
		return INF
	return (_dstTitles.current_animation_length - _dstTitles.current_animation_position) / pace

# What the panel still needs: the rest of the notice it is playing, and a whole notice for each other one it was given,
# which waits its turn; the game's notices all have one length (achievement/Notifications.tscn). One shown in full while
# a later one plays still counts, which only sends it to the station.
func _dstNoticeSecondsLeft() -> float:
	var player = _dstNoticePlayer()
	if player == null or not player.is_playing():
		return 0.0
	var length = player.current_animation_length
	return length - player.current_animation_position + length * (_dstNotices.size() - 1)

func _dstHideNotices():
	var player = _dstNoticePlayer()
	if player != null:
		get_node(_DST_NOTICES).visible = false
		player.stop()
	_dstHidden = true

# Each notice of the game's panel (DiveSkipTransit.NOTICES) is noted as the panel gets it. Godot 3 has no functions with
# any number of arguments, so each signal is connected to the _dstOnNotice function for its count of arguments, as the
# game declares them; a signal the game doesn't have is left out.
func _dstListenToNotices():
	for notice in DiveSkipTransit.NOTICES:
		var source = get_node_or_null("/root/" + notice[0])
		if source == null:
			continue
		for info in source.get_signal_list():
			var method = "_dstOnNotice%d" % info.args.size()
			if info.name == notice[1] and has_method(method) and not source.is_connected(notice[1], self, method):
				source.connect(notice[1], self, method, [notice[2]])

func _dstOnNotice1(a, handler):
	_dstNote(handler, [a])

func _dstOnNotice3(a, b, c, handler):
	_dstNote(handler, [a, b, c])

func _dstOnNotice4(a, b, c, d, handler):
	_dstNote(handler, [a, b, c, d])

func _dstNote(handler, args):
	_dstNotices.append([handler, args])
	if _dstTitles != null and _dstTitles.current_animation == "exit" and _dstTransitPace() > 0:
		_dstFitNotices()

# The panel's player, or null where the ring scene has no panel.
func _dstNoticePlayer():
	var panel = get_node_or_null(_DST_NOTICES)
	var player = panel.get("animation") if panel != null else null
	return player if player is AnimationPlayer else null

# Whether the panel is playing a notice or has one queued (the money's).
func _dstNoticesShowing() -> bool:
	var player = _dstNoticePlayer()
	return player != null and (player.is_playing() or player.get_queue().size() > 0)

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
# frame counts its physics steps from the rate it starts with, so the pace's rate goes back here first. Once the
# notification panel has nothing left to show, the notices it was given are forgotten: they were shown in full. Not
# while it is hidden: it showed them to no one.
func _process(_delta):
	if _dstPace > 0:
		_dstApplyPace(_dstPace)
	if not _dstHidden and not _dstNotices.empty() and not _dstNoticesShowing():
		_dstNotices.clear()

func _exit_tree():
	if _dstPace > 0:
		_dstStopPace()

# The speed the transit cutscene running now plays at, or 0: none is running, the transit is skipped, or the speed
# is the game's own. On the arrival it tapers to 1x by the end, as the game's Space speed does; it is never below what
# the game asked for (holding Space).
func _dstTransitPace() -> float:
	var settings = _dstModel
	if settings.getValue("skipTransit"):
		return 0.0
	var speed = settings.getValue("transitSpeed")
	if cutscene and si != null:
		speed = lerp(speed, 1.0, clamp(eclapsedTime / totalCutsceneTime, 0.0, 1.0))
	elif not (_dstTitles != null and _dstTitles.current_animation == "exit"):
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

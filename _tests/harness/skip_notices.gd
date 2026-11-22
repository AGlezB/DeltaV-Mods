extends Control

# Stub of the game's notification panel (achievement/Notifications.tscn, which the ring scene's BulletTimer.tscn and
# the station's enceladus/Enceladus.tscn both hold) for the skip suite. Its `animation`, an AnimationPlayer as the
# game's, plays a notice of `seconds` in real time whatever the time scale (Notifications.gd _process:
# playback_speed = 1 / Engine.time_scale). Its handlers have the game's names and arguments, and record each call in
# `calls` as [handler, args] instead of showing a notice; nothing connects them.

var animation = AnimationPlayer.new()
var calls = []

func _init(seconds = 1.0):
	animation.name = "AnimationPlayer"
	var notice = Animation.new()
	notice.length = seconds
	animation.add_animation("acquired", notice)
	add_child(animation)

# Shows a notice, as each handler of the game's does.
func notify():
	animation.play("acquired")

func _process(_delta):
	if animation.is_playing() and Engine.time_scale > 0:
		animation.playback_speed = 1.0 / Engine.time_scale

func _newShip(n):
	calls.append(["_newShip", [n]])

func _lostShip(n):
	calls.append(["_lostShip", [n]])

func _transit(n):
	calls.append(["_transit", [n]])

func _levelUp(who, type, from, to):
	calls.append(["_levelUp", [who, type, from, to]])

func _gone(who):
	calls.append(["_gone", [who]])

func _onPoiFound(poi, type, param):
	calls.append(["_onPoiFound", [poi, type, param]])

func _achieve(n):
	calls.append(["_achieve", [n]])

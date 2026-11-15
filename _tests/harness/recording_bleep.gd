extends "res://sfx/PitchAdjustedAudio.gd"

# The lidar suite's ping player: the game's PitchAdjustedAudio.gd, which also records every play() in `played` as
# [volume_db, pitch_scale]. `playing` can't count pings driven by hand: after stop(), a play() in the same engine
# frame did not show in it.

var played = []

func play(pos = 0.0):
	played.append([volume_db, defaultPitch])
	.play(pos)

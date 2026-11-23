extends Node

# Stub of the ship's LIDAR (hud/LIDAR.gd) for the callout suite: hasSeen, as the game's (the objects its sweep has hit,
# by hash, until they expire), here the objects the suite marks seen (see).

var seen = {}

func hasSeen(object):
	return seen.has(hash(object))

func see(object):
	seen[hash(object)] = true

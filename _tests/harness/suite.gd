extends Node

# Base of the suites: results, the loaded mods and the masses given on the command line.

const VP = preload("res://harness/vp_data.gd")
const Rig = preload("res://harness/rig.gd")

var mods = [] # folder names of the loaded mods
var shipMass = VP.SHIP_MASS
var chunkMass = VP.CHUNK_MASS
var passes = 0
var fails = 0

# Override: the suite's cases (a coroutine is fine).
func run():
	pass

func hasMod(modName) -> bool:
	return mods.has(modName)

func check(caseName, ok, details = ""):
	if ok:
		passes += 1
	else:
		fails += 1
	print(("PASS " if ok else "FAIL ") + caseName + ("" if str(details) == "" else "  [%s]" % str(details)))

func note(text):
	print("NOTE " + text)

# Deep equality, a number equal to the same number of the other type (Godot 3 compares dictionaries by reference).
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	var numbers = [TYPE_INT, TYPE_REAL]
	if typeof(a) != typeof(b):
		return numbers.has(typeof(a)) and numbers.has(typeof(b)) and a == b
	return a == b

# Waits `count` (at least 1) physics frames.
func frames(count):
	for i in max(1, count):
		yield(get_tree(), "physics_frame")

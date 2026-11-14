extends Node

# Entry point (run by run.ps1): runs the suite named by --suite=<name> (suites/<name>.gd) and quits. The mods given
# by --mod-zips=<zip>;<zip> are already loaded by then (the ModLoader autoload, harness/loader.gd). Exit code: the
# number of failures (at most 99), 100 when the harness itself fails. Optional: --ship-mass=<t>, --chunk-mass=<t>.
# The root of main.tscn, or a child of the root of harness/boot.tscn for the boot suite.

const VP = preload("res://harness/vp_data.gd")

func _ready():
	var args = {}
	for a in OS.get_cmdline_args():
		if a.begins_with("--") and "=" in a:
			var kv = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	seed(1)
	if not ModLoader.ok:
		get_tree().quit(100)
		return
	var path = "res://suites/%s.gd" % args.get("suite", "")
	if not ResourceLoader.exists(path):
		printerr("HARNESS ERROR: no suite %s" % path)
		get_tree().quit(100)
		return
	var suite = load(path).new()
	suite.name = "Suite"
	suite.mods = ModLoader.loaded
	suite.shipMass = float(args.get("ship-mass", VP.SHIP_MASS))
	suite.chunkMass = float(args.get("chunk-mass", VP.CHUNK_MASS))
	add_child(suite)
	yield(get_tree(), "physics_frame")
	var state = suite.run()
	if state is GDScriptFunctionState:
		yield(state, "completed")
	print("SUMMARY %s mods=%s ship=%s chunk=%s: %d pass, %d fail" % [args.get("suite"), PoolStringArray(suite.mods).join(","), suite.shipMass, suite.chunkMass, suite.passes, suite.fails])
	get_tree().quit(int(min(suite.fails, 99)))

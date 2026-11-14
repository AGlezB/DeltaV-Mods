extends Node

# Stub of the game's Loader autoload (Loader.gd): what Boot.gd calls. It records the calls instead of loading and
# switching scenes.

var current = null
var calls = [] # "setCurrent", "prepare <path>", "go <path>", in call order

func setCurrent(scene):
	current = scene
	calls.append("setCurrent")

func prepare(what: String, _soon = false):
	calls.append("prepare " + what)
	return what

func go(where):
	calls.append("go %s" % where)

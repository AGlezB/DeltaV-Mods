extends "res://harness/suite.gd"

# BootSkipLogos: the game's first scene (Boot.gd, the logo sequence) goes to the title screen as soon as it is
# ready, except on the first launch. run.ps1 runs this suite with harness/boot.tscn as the main scene: its root has
# the game's Boot.gd and is loaded by the engine at startup, after the autoloads (the mod loader among them) are
# created, as the game's Boot.tscn is. This suite runs under its child Main. The Loader stub records what Boot.gd
# asks for instead of switching scenes.

const TITLE = "res://TitleScreen.tscn"

# What a new Boot node with `script` asks of the loader in its _ready.
func start(script, firstBoot):
	Loader.calls.clear()
	Settings.firstBoot = firstBoot
	var boot = Node.new()
	boot.set_script(script)
	add_child(boot)
	Settings.firstBoot = false
	boot.queue_free()
	return Loader.calls.duplicate()

func run():
	var mod = hasMod("BootSkipLogos")
	var startup = get_tree().current_scene
	var startupCalls = Loader.calls.duplicate()
	check("the engine loaded harness/boot.tscn as the main scene", startup != null and startup.name == "Boot" and Loader.current == startup, startup)
	var game = load("res://Boot.gd")
	if mod:
		game = game.get_base_script()
	var gameCalls = start(game, false)
	check("control: the game alone does not leave the logos on start", gameCalls.size() > 0 and not ("go " + TITLE) in gameCalls, gameCalls)
	if not mod:
		check("control: without the mod the startup scene does not leave the logos", startupCalls == gameCalls, startupCalls)
		return
	check("the startup scene has the extension (installed before the engine loaded the scene)", startup.get_script().get_base_script() != null)
	check("the startup scene runs the game's own start-up, then goes to the title screen", startupCalls == gameCalls + ["go " + TITLE], startupCalls)
	var first = start(load("res://Boot.gd"), true)
	check("first launch: the logos play in full", first == gameCalls, first)

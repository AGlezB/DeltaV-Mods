extends "res://harness/suite.gd"

# WeaponMaxPowerSwitch: a switch, the first row of the OMS Mechanic tab, and a key of the mod's own (Shared.gd KEY) fire
# the player's weapons at their highest power until switched off: every mass driver, laser and microwave emitter reads
# its power's Tuning at the top of its range, a pulse laser its Pulse frequency at the end the mod sets for it (Code.gd
# _WMPS_FREQUENCY), and every other Tuning reads as the player set it; nothing is written to the ship's config, and a
# new ship starts with the switch off. While it is on, the ship's cabin light is red. The key plays the ship's alarm,
# more times for on than for off; the switch clicks. The ship extension runs on ships of the game's ship-ctrl.gd (with
# the mod, its extension), out of the tree (their _ready never runs), with the game's weapon scripts (massdriver.gd,
# laser.gd, emp.gd) held by the game's hardpoint and turret scripts (WeaponSlot.gd, PDT.gd), and the game's cabin light
# (CabinLight.gd). The tab is the game's hud/SystemList.gd (with the mod, its extension), with the Mechanic tab's values
# in hud/OMS.tscn and the game's row parts (PowerToggleCheckBox.tscn, DamageLabel.tscn; the key hint is the harness's
# stub), in the tree under a stand-in of the HUD it reads the ship through (harness/power_reader.gd). The ship's alarm
# and the tab's click are the game's PitchAdjustedAudio.gd under harness/power_sound.gd, which counts plays without
# sound, so the suite sends `finished` itself. The weapons keep their scripts' own values: the checks read each end
# from the weapon's Tuning entries, and the mod's constants from the mod, so any values pass. The control checks run on
# the game's own ship-ctrl.gd and SystemList.gd.

const MOD = "WeaponMaxPowerSwitch"
const SHARED = "res://WeaponMaxPowerSwitch/Shared.gd"
const SHIP = "res://ships/ship-ctrl.gd"
const LIST = "res://hud/SystemList.gd"
const CABIN = "res://ships/CabinLight.gd"
const HARDPOINT = "res://ships/WeaponSlot.gd"
const TURRET = "res://ships/modules/PDT.gd"
const MASS_DRIVER = "res://weapons/massdriver.gd"
const LASER = "res://weapons/laser.gd"
const EMITTER = "res://weapons/emp.gd"
const DAMAGE_LABEL = "res://hud/components/DamageLabel.gd"
const SOUND = "res://harness/power_sound.gd"
const READER = "res://harness/power_reader.gd"
const SYSTEM = "res://harness/power_system.gd"
# The Mechanic tab's list as hud/OMS.tscn sets it (its OMS node, the only SystemList.gd with toggleSystem on).
const LIST_VALUES = {"toggleSystem": true, "detailedDamage": 3, "minSize": 28, "hotkeysFirst": false}
# A cabin light's colours as a ship's scene could set them (any but the mod's), so that their return shows.
const SCENE_MODULATE = Color(0.9, 0.95, 1, 1)
const SCENE_LIGHT = Color(1, 0.9, 0.8, 1)

# The ship SystemList.gd _ready takes, the parent of what it reads through: this suite, whose signal it connects. The
# list is then pointed at the ship under test.
signal systemsChanged(to)

var _ships = [] # out of the tree: freed at the end
var _red # the mod's cabin light colour (Code.gd)

func near(a, b) -> bool:
	return a != null and b != null and abs(float(a) - float(b)) < 0.0001

# The bottom of a script's chain: the game's own, however many mods extend it.
func gameScriptOf(path):
	var script = load(path)
	while script.get_base_script() != null:
		script = script.get_base_script()
	return script

# A ship of `script` (the game's ship-ctrl.gd, or with the mod its extension), out of the tree, set up.
func makeShip(script, player = true):
	var ship = RigidBody2D.new()
	ship.set_script(script)
	ship.playerControlled = player
	ship.setup = true
	_ships.append(ship)
	return ship

# A weapon of the game's `script` under `parent`, with the slot name its mount gives it (ships/WeaponSlot.gd
# loadPlaceholder, ships/modules/PDT.gd _setSlotName) and the ship its getShip finds in _ready.
func weapon(parent, ship, script, slot, values = {}):
	var node = Sprite.new()
	node.set_script(load(script))
	for key in values:
		node.set(key, values[key])
	node.ship = ship
	node.slotName = slot
	parent.add_child(node)
	return node

# A weapon held by a mount of the game's `mountScript` (a hardpoint or a turret) on `ship`, as its `system`.
func mounted(ship, mountScript, weaponScript, slot, values = {}):
	var mount = Node2D.new()
	mount.set_script(load(mountScript))
	ship.add_child(mount)
	var held = weapon(mount, ship, weaponScript, slot, values)
	mount.system = held
	return held

func system(ship, slot, tuneables):
	var node = Node2D.new()
	node.set_script(load(SYSTEM))
	node.slotName = slot
	node.tuneables = tuneables
	ship.add_child(node)
	return node

# The game's cabin light on `ship`, in the scene's colours, with its spotlight (its Light child, which its lightNode
# finds once in the tree: set here, out of it), or without one.
func cabin(ship, withLight = true):
	var node = Sprite.new()
	node.set_script(load(CABIN))
	node.modulate = SCENE_MODULATE
	if withLight:
		var light = Light2D.new()
		light.name = "Light"
		light.color = SCENE_LIGHT
		node.add_child(light)
		node.lightNode = light
	ship.add_child(node)
	return node

func red(light) -> bool:
	return light.modulate == _red and (light.lightNode == null or light.lightNode.color == _red)

func asScene(light) -> bool:
	return light.modulate == SCENE_MODULATE and (light.lightNode == null or light.lightNode.color == SCENE_LIGHT)

func sound(nodeName):
	var player = AudioStreamPlayer.new()
	player.set_script(load(SOUND))
	player.name = nodeName
	return player

# The Mechanic tab's list (`script`: the game's SystemList.gd, or with the mod its extension), with OMS.tscn's values
# and its click, in the tree under a reader, pointed at `ship`.
func makeList(ship, script = null):
	var reader = Node.new()
	reader.set_script(load(READER))
	var list = GridContainer.new()
	list.set_script(script if script != null else load(LIST))
	for key in LIST_VALUES:
		list.set(key, LIST_VALUES[key])
	list.add_child(sound("Click"))
	reader.add_child(list)
	add_child(reader)
	list.ship = ship
	reader.ship = ship
	return list

func freeList(list):
	var reader = list.get_parent()
	remove_child(reader)
	reader.free()

# The grid's cells: its Controls, in order (its click is no cell).
func cells(list) -> Array:
	var out = []
	for child in list.get_children():
		if child is Control:
			out.append(child)
	return out

# Whether `row` takes the grid's first cells, in its order.
func rowFirst(list, row) -> bool:
	var grid = cells(list)
	if grid.size() < row.size():
		return false
	for i in range(row.size()):
		if grid[i] != row[i]:
			return false
	return true

# A click on a switch: the button turns, then says it was pressed (BaseButton).
func click(button):
	button.pressed = not button.pressed
	button.emit_signal("pressed")

# A press and release of a key, as Input delivers a player's, to every node's _input (with the OMS closed too).
func tapKey(scancode):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.scancode = scancode
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# A press and release of a gamepad button (JOY_*), as Input delivers a player's: the actions it is bound to follow
# (Godot's defaults: button 0 is ui_accept), then the focused control gets it.
func tapJoy(button):
	yield(get_tree(), "idle_frame")
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	yield(get_tree(), "idle_frame")

# The end of each play of `player`, as the engine signals it.
func finish(player, times):
	for i in range(times):
		player.emit_signal("finished")

func freeAll():
	for ship in _ships:
		if is_instance_valid(ship):
			ship.free()
	_ships = []

func run():
	var mod = hasMod(MOD)
	yield(get_tree(), "idle_frame")

	var control = makeShip(gameScriptOf(SHIP))
	var controlGun = weapon(control, control, MASS_DRIVER, "weaponSlot.main.type_SYSTEM_EMD14")
	var controlPower = controlGun.getTuneables().TUNE_MASSDRIVER_POWER
	check("control: a mass driver fires at its power's Tuning as set (its default here)", near(controlGun.getPowerDraw(), controlPower.default), controlGun.getPowerDraw())
	var controlList = makeList(control, gameScriptOf(LIST))
	controlList.update()
	check("control: the game's Mechanic tab has a row only for each of the ship's systems (none here)", cells(controlList).empty(), cells(controlList))
	freeList(controlList)
	if not mod:
		freeAll()
		return

	# The mod's constants, from its extensions: installed, each holds its game script's path (a load by its own path
	# would compile it again, over itself).
	var Ship = load(SHIP)
	var Tab = load(LIST)
	var Shared = load(SHARED)
	_red = Ship._WMPS_LIGHT_COLOR

	# The key's input action, added at load (ModMain.gd).
	var events = InputMap.get_action_list(Shared.KEY_ACTION)
	check("the key: an input action of the mod's own, bound to its key", events.size() == 1 and events[0] is InputEventKey and events[0].scancode == Shared.KEY, events)
	Shared.addKey()
	check("the key: added once", InputMap.get_action_list(Shared.KEY_ACTION).size() == 1)

	# The weapons: the NDPT-4205's minigun on its turret, a CL-600P, a CL-150 and an MWG on hardpoints, the CL-200AP's
	# laser on its mount (ships/modules/act-laser.tscn, PDT.gd); and systems that aren't weapons: a drone plant's range
	# on a hardpoint, a mass driver power entry outside the hardpoints.
	var ship = makeShip(load(SHIP))
	var minigun = mounted(ship, TURRET, MASS_DRIVER, "weaponSlot.left.type_SYSTEM_PDT-L_SYSTEM_MINIGUN", {"systemName": "SYSTEM_MINIGUN"})
	var cl600 = mounted(ship, HARDPOINT, LASER, "weaponSlot.main.type_SYSTEM_CL600P", {"pulse": true, "systemName": "SYSTEM_CL600P"})
	var cl200 = mounted(ship, TURRET, LASER, "weaponSlot.right.type_SYSTEM_ACL200P_SYSTEM_CL200P", {"pulse": true, "systemName": "SYSTEM_CL200P"})
	var cl150 = mounted(ship, HARDPOINT, LASER, "weaponSlot.mainLeft.type_SYSTEM_CL150", {"systemName": "SYSTEM_CL150"})
	var mwg = mounted(ship, HARDPOINT, EMITTER, "weaponSlot.mainRight.type_SYSTEM_MWG", {"systemName": "SYSTEM_MWG"})
	var plant = system(ship, "weaponSlot.leftDrone.type_SYSTEM_DND_FIX", {"TUNE_RANGE_MAX": {"min": 10, "max": 200, "default": 100}})
	var outside = system(ship, "propulsion.main_SYSTEM_X", {"TUNE_MASSDRIVER_POWER": {"min": 1, "max": 9, "default": 5}})
	var light = cabin(ship)
	var bare = cabin(ship, false)
	var tm = minigun.getTuneables().TUNE_MASSDRIVER_POWER
	var t6 = cl600.getTuneables()
	var t2 = cl200.getTuneables()
	var te = mwg.getTuneables()

	check("off: the minigun at its power's Tuning (its default here)", near(minigun.getPowerDraw(), tm.default), minigun.getPowerDraw())
	check("off: the cabin lights in the scene's colours", asScene(light) and asScene(bare))
	ship._wmpsSetOn(true)
	check("on", ship._wmpsIsOn())
	var ends = ship._wmpsWeapons()
	check("on: the five weapons changed, found through their mounts; the other systems not", ends.size() == 5 and ends.has(minigun.slotName) and ends.has(cl600.slotName) and ends.has(cl200.slotName) and ends.has(cl150.slotName) and ends.has(mwg.slotName), ends.keys())
	check("on: the minigun at its highest power", near(minigun.getPowerDraw(), tm.max), [minigun.getPowerDraw(), tm.max])
	check("on: the minigun's highest read through the ship, as every system reads its Tuning", near(ship.getTunedValue(minigun.slotName, "TUNE_MASSDRIVER_POWER", tm.default), tm.max))
	check("on: the CL-600P at its highest power", near(cl600.getPowerDraw(), cl600.powerDraw * 1.5 / 1000), cl600.getPowerDraw())
	check("on: the CL-600P at its lowest Pulse frequency", near(cl600.getFrequency(), t6.TUNE_LASER_FREQUENCY.min), cl600.getFrequency())
	check("on: the CL-200AP at its highest power", near(cl200.getPowerDraw(), cl200.powerDraw * 1.5 / 1000), cl200.getPowerDraw())
	check("on: the CL-200AP at its highest Pulse frequency", near(cl200.getFrequency(), t2.TUNE_LASER_FREQUENCY.max), cl200.getFrequency())
	check("on: the CL-150 at its highest power, with no frequency set", near(cl150.getPowerDraw(), cl150.powerDraw * 1.5 / 1000) and not ends[cl150.slotName].has("TUNE_LASER_FREQUENCY"), cl150.getPowerDraw())
	check("on: the MWG at its highest power", near(mwg.getPowerDraw(), te.TUNE_EMP_POWER.max), mwg.getPowerDraw())
	check("on: the MWG's Water Resonance as tuned (its default here)", near(mwg.getResonance(), te.TUNE_EMP_RESONANCE.default), mwg.getResonance())
	check("on: the drone plant's range as tuned", near(ship.getTunedValue(plant.slotName, "TUNE_RANGE_MAX", 100), 100))
	check("on: a power entry outside the hardpoints as tuned", near(ship.getTunedValue(outside.slotName, "TUNE_MASSDRIVER_POWER", 5), 5))
	check("on: the cabin lights red, the spotlight too", red(light) and red(bare), [light.modulate, light.lightNode.color])
	# The cabin light's own update (CabinLight.gd _process, which its ship's power feeds) sets its glow's alpha and its
	# spotlight's energy, never their colour.
	light.ship = ship
	ship.powerBalance = 1e9
	for i in range(3):
		light._process(1.0)
	check("on: the cabin light's own update lights it and keeps the red", red(light) and light.self_modulate.a > 0 and light.lightNode.energy > 0, [light.modulate, light.self_modulate, light.lightNode.energy])

	# A Tuning the player stored: overridden while on, read again when off, never written.
	var stored = {"TUNE_MASSDRIVER_POWER": tm.min}
	ship.shipConfig = {"tuning": {"weaponSlot": {"left": {"type_SYSTEM_PDT-L_SYSTEM_MINIGUN": stored}}}}
	check("on: a power the player stored at its lowest reads as the highest", near(minigun.getPowerDraw(), tm.max), minigun.getPowerDraw())
	ship._wmpsSetOn(true)
	check("on again: still red", red(light))
	ship._wmpsSetOn(false)
	check("off", not ship._wmpsIsOn())
	check("off: the cabin lights back in the scene's colours (switching on twice kept them)", asScene(light) and asScene(bare), [light.modulate, light.lightNode.color])
	ship._wmpsSetOn(false)
	check("off again: the cabin lights unchanged", asScene(light) and asScene(bare))
	check("off: the stored power again", near(minigun.getPowerDraw(), tm.min), minigun.getPowerDraw())
	check("off: the CL-600P's Pulse frequency as tuned (its default here)", near(cl600.getFrequency(), t6.TUNE_LASER_FREQUENCY.default), cl600.getFrequency())
	check("nothing written to the ship's config", stored.size() == 1 and near(stored.TUNE_MASSDRIVER_POWER, tm.min) and ship.shipConfig.tuning.size() == 1)

	var other = makeShip(load(SHIP), false)
	var otherLight = cabin(other)
	other._wmpsSetOn(true)
	check("a ship not the player's stays off, its cabin light untouched", not other._wmpsIsOn() and asScene(otherLight))
	var fresh = makeShip(load(SHIP))
	check("a new ship starts off, with nothing worked out", not fresh._wmpsIsOn() and fresh._wmpsEnds == null)

	# The weapons are worked out again when the ship's systems change (ship-ctrl.gd fillInSystems).
	ship._wmpsSetOn(true)
	var cl150Mount = cl150.get_parent()
	ship.remove_child(cl150Mount)
	cl150Mount.free()
	ship.emit_signal("systemsChanged", {})
	check("systems changed: the four weapons left", ship._wmpsWeapons().size() == 4, ship._wmpsWeapons().keys())

	# The tab, on a ship with an alarm and, at first, no weapon.
	var onTimes = Tab._WMPS_ALARM_ON
	var offTimes = Tab._WMPS_ALARM_OFF
	check("the key's cues: the on cue plays more times than the off cue", onTimes > offTimes and offTimes >= 1, [onTimes, offTimes])
	var tabShip = makeShip(load(SHIP))
	var tabLight = cabin(tabShip)
	# The ship's alarm (ship-ctrl.gd playerAlert, its Noises/Alert), in the tree beside the ship, which is out of it.
	var noises = Node.new()
	noises.name = "Noises"
	add_child(noises)
	var alarm = sound("Alert")
	alarm.stream = AudioStreamSample.new()
	alarm.volume_db = -5.0
	alarm.bus = "SFX"
	noises.add_child(alarm)
	tabShip.playerAlert = alarm
	var list = makeList(tabShip)
	list.update()
	var row = list._wmpsCells
	check("the row: built from the list's parts, one cell per column", row.size() == list.columns and list.columns == 6, [row.size(), list.columns])
	check("the row: first in the list", rowFirst(list, row))
	if row.size() != 6:
		freeList(list)
		freeAll()
		return
	var keys = row[2].get_children()
	check("the row: the game's switch, the name, the key, the damage columns left empty", row[0] is CheckButton and row[1] is Label and row[1].text == Tab._WMPS_ROW and row[1].uppercase and keys.size() == 1 and keys[0].action == Shared.KEY_ACTION and row[3].get_script().resource_path == DAMAGE_LABEL and row[5].get_script().resource_path == DAMAGE_LABEL, [row[1].text, keys])
	var hidden = true
	for cell in row:
		hidden = hidden and not cell.visible
	check("the row: hidden while the ship has no weapon the switch changes", hidden)
	var gun = mounted(tabShip, TURRET, MASS_DRIVER, "weaponSlot.left.type_SYSTEM_PDT-L_SYSTEM_MINIGUN")
	var gunPower = gun.getTuneables().TUNE_MASSDRIVER_POWER
	tabShip.emit_signal("systemsChanged", {})
	list.update()
	var shown = true
	for cell in row:
		shown = shown and cell.visible
	check("the row: shown once the ship has one", shown)
	var later = Label.new()
	list.add_child(later)
	list.update()
	# TurretLockableFacing, when loaded, keeps its own row last (its MechanicTab.gd): the game's row comes right before.
	var tail = cells(list)
	if "_tlfCells" in list:
		for cell in list._tlfCells:
			tail.erase(cell)
	check("the row: still first after a row the game adds at the end", rowFirst(list, row) and tail.back() == later)
	list.remove_child(later)
	later.free()
	var switch = row[0]
	check("off: the row coloured as a system switched off", row[1].self_modulate == list.colorOff and switch.modulate == list.colorOff and not switch.pressed)

	# The switch: its click both ways, never the alarm; the cabin light follows it.
	var clickSound = list.clickSound
	click(switch)
	check("the switch on: the weapons at their highest", tabShip._wmpsIsOn() and near(gun.getPowerDraw(), gunPower.max), gun.getPowerDraw())
	check("the switch on: the cabin light red", red(tabLight))
	check("the switch on: the list's click, not the alarm", clickSound.plays == 1 and list._wmpsAlarmPlayer == null and alarm.plays == 0)
	check("the switch on: the row coloured as a system switched on", row[1].self_modulate == list.colorOk and switch.modulate == list.colorOk)
	click(switch)
	check("the switch off: off, the cabin light back", not tabShip._wmpsIsOn() and asScene(tabLight) and near(gun.getPowerDraw(), gunPower.default))
	check("the switch off: the click again, not the alarm", clickSound.plays == 2 and list._wmpsAlarmPlayer == null and alarm.plays == 0)

	# The key: the ship's alarm, on a copy of its player, more times for on than for off; no click.
	yield(tapKey(Shared.KEY), "completed")
	var copy = list._wmpsAlarmPlayer
	check("key on: on, the cabin light red, the switch and the row show it", tabShip._wmpsIsOn() and red(tabLight) and switch.pressed and row[1].self_modulate == list.colorOk)
	check("key on: the alarm plays on a copy of the ship's alarm player, beside it", is_instance_valid(copy) and copy != alarm and copy.get_parent() == noises)
	if not is_instance_valid(copy):
		freeList(list)
		freeAll()
		return
	check("key on: the copy has the alarm's sound, volume, bus and script", copy.stream == alarm.stream and copy.volume_db == alarm.volume_db and copy.bus == alarm.bus and copy.get_script() == alarm.get_script(), [copy.volume_db, copy.bus])
	check("key on: the first play, on the copy", copy.plays == 1 and alarm.plays == 0, [copy.plays, alarm.plays])
	finish(copy, onTimes + 1)
	check("key on: its plays one after the other, then no more", copy.plays == onTimes, copy.plays)
	check("key on: no click", clickSound.plays == 2)
	yield(tapKey(Shared.KEY), "completed")
	check("key off: off, the cabin light back, the switch shows it", not tabShip._wmpsIsOn() and asScene(tabLight) and not switch.pressed)
	check("key off: the first play", copy.plays == onTimes + 1, copy.plays)
	finish(copy, offTimes + 1)
	check("key off: its plays, then no more", copy.plays == onTimes + offTimes, copy.plays)
	check("key off: no click", clickSound.plays == 2)

	# Pressed again while a cue sounds: the new cue starts at once, and the old one's plays left are dropped.
	var before = copy.plays
	yield(tapKey(Shared.KEY), "completed")
	yield(tapKey(Shared.KEY), "completed")
	check("key on, then off at once: both cues start, on the same copy", list._wmpsAlarmPlayer == copy and copy.plays == before + 2 and not tabShip._wmpsIsOn())
	finish(copy, onTimes + offTimes + 1)
	check("key on, then off at once: only the off cue's plays follow", copy.plays == before + 1 + offTimes, copy.plays)

	var plays = copy.plays
	yield(tapKey(KEY_O if Shared.KEY != KEY_O else KEY_I), "completed")
	check("another key: nothing", not tabShip._wmpsIsOn() and copy.plays == plays and clickSound.plays == 2)
	list.hide()
	yield(tapKey(Shared.KEY), "completed")
	check("with the OMS closed (the list hidden), the key switches on all the same, with the alarm", tabShip._wmpsIsOn() and red(tabLight) and copy.plays == plays + 1)
	finish(copy, onTimes)
	yield(tapKey(Shared.KEY), "completed")
	finish(copy, offTimes)
	list.show()
	plays = copy.plays
	tabShip.cutscene = true
	yield(tapKey(Shared.KEY), "completed")
	check("during a cutscene, the key does nothing", not tabShip._wmpsIsOn() and copy.plays == plays)
	tabShip.cutscene = false
	tabShip.playerControlled = false
	yield(tapKey(Shared.KEY), "completed")
	check("on a ship not the player's, the key does nothing", not tabShip._wmpsIsOn() and copy.plays == plays)
	tabShip.playerControlled = true

	# In bullet time the alarm is slowed as the ship's own (PitchAdjustedAudio.gd), the same both ways, so the count of
	# plays still tells which way it switched.
	Engine.time_scale = 0.5
	yield(tapKey(Shared.KEY), "completed")
	var onPitch = copy.pitch_scale
	finish(copy, onTimes)
	yield(tapKey(Shared.KEY), "completed")
	var offPitch = copy.pitch_scale
	finish(copy, offTimes)
	Engine.time_scale = 1.0
	check("in bullet time: the key's alarm slowed as the ship's own, the same for on and off", near(onPitch, copy.defaultPitch * 0.5) and near(offPitch, onPitch), [onPitch, offPitch, copy.defaultPitch])

	# With a gamepad: the switch takes the focus as the game's switches do, its tooltip shows, and A presses it.
	var tooltips = switch.get_node_or_null("PlaySoundsOnTheseButtons")
	switch.grab_focus()
	check("gamepad: the switch takes the focus and shows its tooltip, through the game's tooltip node", switch.has_focus() and tooltips != null and tooltips.tooltipPosition.visible and tooltips.tooltipLabel.text == Tab._WMPS_TOOLTIP, tooltips.tooltipLabel.text if tooltips != null else null)
	var clicks = clickSound.plays
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("gamepad: A on the highlighted switch switches on, with the click", tabShip._wmpsIsOn() and switch.pressed and red(tabLight) and clickSound.plays == clicks + 1)
	yield(tapJoy(JOY_BUTTON_0), "completed")
	check("gamepad: A again switches off, with the click", not tabShip._wmpsIsOn() and not switch.pressed and asScene(tabLight) and clickSound.plays == clicks + 2)
	freeList(list)

	# A ship with no alarm: the key switches all the same, silently.
	var quiet = makeShip(load(SHIP))
	mounted(quiet, HARDPOINT, MASS_DRIVER, "weaponSlot.main.type_SYSTEM_EMD14")
	var quietList = makeList(quiet)
	quietList.update()
	yield(tapKey(Shared.KEY), "completed")
	check("no alarm: the key switches on, silently", quiet._wmpsIsOn() and quietList._wmpsAlarmPlayer == null)
	freeList(quietList)
	remove_child(noises)
	noises.free()
	freeAll()

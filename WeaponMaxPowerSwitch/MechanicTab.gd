extends "res://hud/SystemList.gd"

# WeaponMaxPowerSwitch's row in the OMS Mechanic tab (hud/OMS.tscn: the tab's list, the only SystemList.gd with
# toggleSystem on), and the switch's key. The row comes first in the list, built from the list's own parts as the game
# builds a system's row (the on/off switch, the name, the key, the damage columns), and shows only while the ship has
# a weapon the switch changes. Its switch and the key both switch the ship's weapons to their highest power (Code.gd),
# which every dive starts without. The game only ever adds rows at the end (update), so the row stays first.
# The key, which works with the tab closed too, tells which way it switched by the ship's own alarm (the one a full
# storage sounds), played more times for on than for off (_WMPS_ALARM_ON, _WMPS_ALARM_OFF). The switch shows its
# state, and clicks as the game's switches do.
#
# Stacking: update falls through to the parent with `.update()`; the game's script has no _input; new members start
# with `_wmps`.

const WeaponMaxPowerSwitch = preload("res://WeaponMaxPowerSwitch/Shared.gd")

# The row's name and its switch's tooltip, in i18n/en.po.
const _WMPS_ROW = "WEAPONMAXPOWERSWITCH_ROW"
const _WMPS_TOOLTIP = "WEAPONMAXPOWERSWITCH_TOOLTIP"
# How many times in a row the key plays the ship's alarm: switching on (the weapons to their highest power), and
# switching off (the emergency is over). The same sound and pitch both ways, so the count holds in bullet time, which
# lowers the alarm's pitch.
const _WMPS_ALARM_ON = 2
const _WMPS_ALARM_OFF = 1

var _wmpsCells = [] # the row's cells, in the list's order
var _wmpsSwitch = null
var _wmpsLabel = null
var _wmpsKeys = null
var _wmpsAlarmPlayer = null # the key's alarm: a copy of the ship's alarm player (_wmpsAlarm)
var _wmpsAlarmLeft = 0 # the plays still to come after the one sounding

# The game's code runs this every readEvery seconds while the tab shows, and when the ship's systems change.
func update():
	.update()
	_wmpsRow()

# The key, gated as the game gates a hardpoint's (ships/WeaponSlot.gd _input), and silent when it changes nothing.
func _input(event):
	if not toggleSystem or not event.is_action_pressed(WeaponMaxPowerSwitch.KEY_ACTION):
		return
	if not _wmpsReady() or ship.cutscene or ship._wmpsWeapons().empty():
		return
	var was = ship._wmpsIsOn()
	ship._wmpsSetOn(not was)
	var on = ship._wmpsIsOn()
	if on != was:
		_wmpsAlarm(_WMPS_ALARM_ON if on else _WMPS_ALARM_OFF)
	_wmpsRow()

# The ship's alarm sound (ships/ship-ctrl.gd playerAlert, its Noises/Alert, each ship model's own), `times` times in a
# row, each play right after the last, as the game repeats its own alarm (avFeedback). A cue still sounding stops, with
# the plays it had left. It plays on a copy of the ship's player (its stream, volume, bus and script,
# sfx/PitchAdjustedAudio.gd, which slows it with bullet time), made once beside it: the ship stops its own player every
# frame while no alarm is raised (avFeedback). Beside the ship's alarm, not in this list, whose children other mods
# may count on (a row kept last by the list's last child).
func _wmpsAlarm(times):
	if not is_instance_valid(_wmpsAlarmPlayer):
		var alarm = ship.get("playerAlert")
		if not is_instance_valid(alarm) or not (alarm is AudioStreamPlayer) or alarm.stream == null:
			return
		_wmpsAlarmPlayer = alarm.duplicate()
		alarm.get_parent().add_child(_wmpsAlarmPlayer)
		_wmpsAlarmPlayer.connect("finished", self, "_wmpsAlarmFinished")
	_wmpsAlarmLeft = times - 1
	_wmpsAlarmPlayer.play()

func _wmpsAlarmFinished():
	if _wmpsAlarmLeft > 0 and is_instance_valid(_wmpsAlarmPlayer):
		_wmpsAlarmLeft -= 1
		_wmpsAlarmPlayer.play()

# The list's ship, once the game has set it up, while the player flies it.
func _wmpsReady() -> bool:
	if not toggleSystem or not is_instance_valid(ship) or not ("setup" in ship) or not ship.setup:
		return false
	return ship.has_method("_wmpsSetOn") and ship.isPlayerControlled()

func _wmpsRow():
	if not _wmpsReady():
		return
	if _wmpsCells.empty():
		_wmpsBuild()
	for i in range(_wmpsCells.size()):
		if _wmpsCells[i].get_index() != i:
			move_child(_wmpsCells[i], i)
	var shown = not ship._wmpsWeapons().empty()
	for cell in _wmpsCells:
		if cell.visible != shown:
			cell.visible = shown
	var on = ship._wmpsIsOn()
	if _wmpsSwitch.pressed != on:
		_wmpsSwitch.pressed = on
	# Coloured as the game colours a system that is on or off, at full power.
	var color = colorOk if on else colorOff
	_wmpsLabel.self_modulate = color
	_wmpsSwitch.modulate = color
	if _wmpsKeys != null:
		_wmpsKeys.modulate = color

# The row, cell for cell as the game's code lays out a system's row (update, makeTogglerFor, makeLabelFor,
# makeCtrlsFor, and damageLabel({}) for the damage columns a system leaves empty), so the list's columns stay aligned.
# A GridContainer leaves hidden cells out, so the hidden row takes no place.
func _wmpsBuild():
	_wmpsSwitch = toggleButton.instance()
	_wmpsSwitch.hint_tooltip = _WMPS_TOOLTIP
	_wmpsSwitch.light_mask = 0
	_wmpsSwitch.connect("pressed", self, "_wmpsSwitched")
	_wmpsCells = [_wmpsSwitch]
	if showKeys:
		_wmpsKeys = _wmpsKeyHint()
		if hotkeysFirst:
			_wmpsCells.append(_wmpsKeys)
	_wmpsLabel = makeLabelFor({"name": _WMPS_ROW})
	_wmpsLabel.rect_min_size.y = minSize
	_wmpsCells.append(_wmpsLabel)
	if showKeys and not hotkeysFirst:
		_wmpsCells.append(_wmpsKeys)
	for i in range(detailedDamage):
		_wmpsCells.append(damageLabel({}))
	for cell in _wmpsCells:
		add_child(cell)

# The key, shown as the game shows a hardpoint's (makeCtrlsFor).
func _wmpsKeyHint():
	var ctrls = HBoxContainer.new()
	ctrls.size_flags_horizontal = SIZE_FILL
	ctrls.size_flags_vertical = SIZE_EXPAND_FILL
	var hint = cscd.instance()
	hint.action = WeaponMaxPowerSwitch.KEY_ACTION
	ctrls.add_child(hint)
	return ctrls

# As the game's own switches (toggle): the ship's weapons follow the switch, with the list's click.
func _wmpsSwitched():
	if _wmpsReady():
		ship._wmpsSetOn(_wmpsSwitch.pressed)
	if clickSound:
		clickSound.play()
	_wmpsRow()

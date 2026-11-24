extends "res://hud/SystemList.gd"

# TurretLockableFacing's row in the OMS Mechanic tab (hud/OMS.tscn: the tab's list, the only SystemList.gd with
# toggleSystem on), and the facing lock's key. The row comes last in the list, built from the list's own parts as the
# game builds a system's row (the on/off switch, the name, the key, the damage columns), and shows only while the ship
# has a turret. Its switch and the key both switch the facing lock (Shared.gd), which every dive starts without. Its
# first damage column, where the other rows have their jury-rig sliders, holds the locked turrets' angle, on the same
# slider.
#
# Stacking: update falls through to the parent with `.update()`; the game's script has no _input; new members start
# with `_tlf`.

const TurretLockableFacing = preload("res://TurretLockableFacing/Shared.gd")

# The row's name and its switch's tooltip, in i18n/en.po.
const _TLF_ROW = "TURRETLOCKABLEFACING_ROW"
const _TLF_TOOLTIP = "TURRETLOCKABLEFACING_TOOLTIP"
# The angle's text, with the value (and with "_TOOLTIP", its tooltip), in i18n/en.po.
const _TLF_ANGLE = "TURRETLOCKABLEFACING_ANGLE"

var _tlfCells = [] # the row's cells, in the list's order
var _tlfSwitch = null
var _tlfLabel = null
var _tlfKeys = null
var _tlfAngleCell = null # hud/components/DamageLabel.tscn, as the jury-rig sliders

# The game's code runs this every readEvery seconds while the tab shows, and when the ship's systems change; it adds
# the rows of new systems at the end, after which the facing lock's row moves back to the end.
func update():
	.update()
	_tlfRow()

# The key, gated as the game gates a hardpoint's (ships/WeaponSlot.gd _input), and silent as that is.
func _input(event):
	if not toggleSystem or not event.is_action_pressed(TurretLockableFacing.KEY_ACTION):
		return
	if not is_instance_valid(ship) or not ship.has_method("isPlayerControlled"):
		return
	if not ship.isPlayerControlled() or ship.cutscene:
		return
	if TurretLockableFacing.mounts(ship).empty():
		return
	TurretLockableFacing.setLocked(ship, not TurretLockableFacing.isLocked(ship))
	_tlfRow()

func _tlfRow():
	if not toggleSystem or not is_instance_valid(ship) or not ("setup" in ship) or not ship.setup:
		return
	if _tlfCells.empty():
		_tlfBuild()
	if get_child(get_child_count() - 1) != _tlfCells.back():
		for cell in _tlfCells:
			move_child(cell, get_child_count() - 1)
	var shown = not TurretLockableFacing.mounts(ship).empty()
	for cell in _tlfCells:
		if cell.visible != shown:
			cell.visible = shown
	var locked = TurretLockableFacing.isLocked(ship)
	if _tlfSwitch.pressed != locked:
		_tlfSwitch.pressed = locked
	# Coloured as the game colours a system that is on or off, at full power.
	var color = colorOk if locked else colorOff
	_tlfLabel.self_modulate = color
	_tlfSwitch.modulate = color
	if _tlfKeys != null:
		_tlfKeys.modulate = color
	if _tlfAngleCell != null:
		_tlfAngleSync()
		# As the jury-rig sliders of a system in good shape (DamageLabel.gd recolor), grey when off.
		_tlfAngleCell.modulate = _tlfAngleCell.colorOk if locked else colorOff

# The row, cell for cell as the game's code lays out a system's row (update, makeTogglerFor, makeLabelFor,
# makeCtrlsFor), so the list's columns stay aligned. A GridContainer leaves hidden cells out, so the hidden row takes
# no place.
func _tlfBuild():
	_tlfSwitch = toggleButton.instance()
	_tlfSwitch.hint_tooltip = _TLF_TOOLTIP
	_tlfSwitch.light_mask = 0
	_tlfSwitch.connect("pressed", self, "_tlfSwitched")
	_tlfCells = [_tlfSwitch]
	if showKeys:
		_tlfKeys = _tlfKeyHint()
		if hotkeysFirst:
			_tlfCells.append(_tlfKeys)
	_tlfLabel = makeLabelFor({"name": _TLF_ROW})
	_tlfLabel.rect_min_size.y = minSize
	_tlfCells.append(_tlfLabel)
	if showKeys and not hotkeysFirst:
		_tlfCells.append(_tlfKeys)
	for i in range(detailedDamage):
		if i == 0:
			_tlfAngleCell = _tlfAngleSlider()
			_tlfCells.append(_tlfAngleCell)
		else:
			var blank = Control.new()
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tlfCells.append(blank)
	for cell in _tlfCells:
		add_child(cell)
	if _tlfAngleCell != null:
		_tlfAngleSync()

# The angle's cell: the list's own damage cell (damageLabel), with its name, its full bar (a system in good shape) and
# its jury-rig slider, which keeps the game's mouse and gamepad handling (RepeatingHSlider.gd: the D-pad reaches the
# name, A moves to the slider, left and right change it, A or B go back), from -FACING_ANGLE_MAX to FACING_ANGLE_MAX.
# The name shows the angle.
func _tlfAngleSlider():
	var cell = damageLabelResource.instance()
	cell.systemName = _TLF_ANGLE
	cell.status = 1.0
	cell.slider.min_value = - TurretLockableFacing.FACING_ANGLE_MAX
	cell.slider.max_value = TurretLockableFacing.FACING_ANGLE_MAX
	cell.slider.step = TurretLockableFacing.FACING_ANGLE_STEP
	cell.connect("juryRigChanged", self, "_tlfAngleChanged")
	return cell

# The slider's value, and the name, from the ship's angle (Shared.gd). The value is set only where it differs, and the
# signal that follows finds nothing to store.
func _tlfAngleSync():
	var angle = TurretLockableFacing.angle(ship)
	if _tlfAngleCell.slider.value != angle:
		_tlfAngleCell.slider.value = angle
	_tlfAngleName(angle)

func _tlfAngleChanged(value):
	if value != TurretLockableFacing.angle(ship):
		TurretLockableFacing.setAngle(ship, value)
	_tlfAngleName(TurretLockableFacing.angle(ship))

# The name with the angle, signed, in whole degrees or with its decimals (str: 2 for 2.0, 2.5 for 2.5), as the other
# cells' names are written (DamageLabel.gd: translated, upper case).
func _tlfAngleName(angle):
	var shown = "0" if angle == 0 else ("+" if angle > 0 else "") + str(angle)
	_tlfAngleCell.label.text = (tr(_TLF_ANGLE) % shown).to_upper()

# The key, shown as the game shows a hardpoint's (makeCtrlsFor).
func _tlfKeyHint():
	var ctrls = HBoxContainer.new()
	ctrls.size_flags_horizontal = SIZE_FILL
	ctrls.size_flags_vertical = SIZE_EXPAND_FILL
	var hint = cscd.instance()
	hint.action = TurretLockableFacing.KEY_ACTION
	ctrls.add_child(hint)
	return ctrls

# As the game's own switches (toggle): the facing lock follows the switch, with the list's click.
func _tlfSwitched():
	TurretLockableFacing.setLocked(ship, _tlfSwitch.pressed)
	if clickSound:
		clickSound.play()
	_tlfRow()

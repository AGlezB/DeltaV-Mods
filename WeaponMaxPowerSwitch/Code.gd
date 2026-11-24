extends "res://ships/ship-ctrl.gd"

# WeaponMaxPowerSwitch's switch, on every ship (ships/ship-ctrl.gd), switched only on the player's (MechanicTab.gd:
# the OMS Mechanic tab's row and the key). While it is on, the ship's weapons read their Tuning as if its slider sat at
# one end: each weapon's power at its highest, and a pulse laser's Pulse frequency at the end it fights best with
# (_WMPS_FREQUENCY). The ends are each weapon's own (its getTuneables, as the Tuning screen draws its sliders).
#
# Every system reads its Tuning through getTunedValue, the game's only read of it, and mass drivers, lasers and
# microwave emitters read it every frame while they fire (weapons/massdriver.gd, laser.gd and emp.gd getPowerDraw), so
# a switch applies at once. Nothing is written: the player's ship works on the save's own config (Shipyard.gd
# createShipByConfig), and the game builds the ship anew for every dive (Game.gd _respawn_ship, CurrentGame.gd
# createPlayerShip), for the station and for the simulator, so every dive starts with the switch off.
#
# While the switch is on, the ship's cabin light (ships/CabinLight.gd, the Adrenaline booster's node: the lit cabin and
# the spotlight it hangs, which lights the ship and what is around it) is red, however the switch was flipped. That
# script sets only the light's energy and the cabin's alpha (self_modulate), never their colour, so the tint holds.
#
# Stacking: getTunedValue falls through to the parent with `.getTunedValue()`; new members start with `_wmps`.

# The Tuning entries set to their highest while the switch is on: each weapon family's power (weapons/massdriver.gd,
# weapons/laser.gd, weapons/emp.gd getTuneables). A microwave emitter's Water Resonance (emp.gd) isn't power, and its
# best for mining and for fighting are the same, so it stays as tuned; so does the exhaust weapons' Thrust
# (sfx/thruster.gd), whose highest adds no damage that counts.
const _WMPS_HIGHEST = ["TUNE_MASSDRIVER_POWER", "TUNE_LASER_POWER", "TUNE_EMP_POWER"]
# A pulse laser's Pulse frequency (weapons/laser.gd), by the laser's systemName, and which end it is set to while the
# switch is on: the lower the frequency, the larger the kinetic part of each pulse. The CL-600P's pulses at its lowest
# are all kinetic and strong enough to make a reactor leak; the CL-200AP's (its laser, SYSTEM_CL200P in
# ships/modules/act-laser.tscn) never are, so it fights with heat, at its highest. Other lasers keep theirs.
const _WMPS_FREQUENCY_KEY = "TUNE_LASER_FREQUENCY"
const _WMPS_FREQUENCY = {"SYSTEM_CL600P": "min", "SYSTEM_CL200P": "max"}
# A weapon's slotName, the game's key for its tuning, starts with this when it sits on a hardpoint (ships/WeaponSlot.gd
# loadPlaceholder; ships/modules/PDT.gd _setSlotName for a turret's weapon).
const _WMPS_SLOT_PREFIX = "weaponSlot."
# The cabin light's systemName (ships/CabinLight.gd), in every ship the player can fly.
const _WMPS_CABIN_LIGHT = "SYSTEM_ADRENALINE_BOOSTER"
# The cabin light's colour while the switch is on: the hue of the Mechanic tab's red (hud/SystemList.gd colorErr), at
# full brightness so the light keeps its strength.
const _WMPS_LIGHT_COLOR = Color(1, 0.17, 0.17)

var _wmpsOn = false
# The ends the switch sets: the weapon's slotName -> {Tuning entry: value}. Null until worked out (_wmpsWeapons).
var _wmpsEnds = null
# The cabin lights tinted while the switch is on, with the colours they had: node -> [modulate, its light's color].
var _wmpsLightWas = {}

func getTunedValue(system, tune, default):
	if _wmpsOn and _wmpsEnds != null:
		var ends = _wmpsEnds.get(system)
		if ends != null and ends.has(tune):
			return ends[tune]
	return .getTunedValue(system, tune, default)

func _wmpsIsOn() -> bool:
	return _wmpsOn

# Only the player's ship is switched on, and only once its weapons' ends are known. The cabin light follows a change.
func _wmpsSetOn(how):
	how = bool(how) and isPlayerControlled()
	if how == _wmpsOn:
		return
	if how:
		_wmpsWeapons()
	_wmpsOn = how
	_wmpsLight(how)

# Every cabin light red, or back to the colours it had (read from the scene, not assumed).
func _wmpsLight(on):
	if on:
		_wmpsLightWas = {}
		_wmpsCabinLights(self)
		for cabin in _wmpsLightWas:
			cabin.modulate = _WMPS_LIGHT_COLOR
			if is_instance_valid(cabin.lightNode):
				cabin.lightNode.color = _WMPS_LIGHT_COLOR
	else:
		for cabin in _wmpsLightWas:
			if is_instance_valid(cabin):
				cabin.modulate = _wmpsLightWas[cabin][0]
				if is_instance_valid(cabin.lightNode):
					cabin.lightNode.color = _wmpsLightWas[cabin][1]
		_wmpsLightWas = {}

# The cabin lights in the ship's nodes, kept in _wmpsLightWas with their colours.
func _wmpsCabinLights(node):
	for child in node.get_children():
		if "lightNode" in child and str(child.get("systemName")) == _WMPS_CABIN_LIGHT:
			var light = child.lightNode
			_wmpsLightWas[child] = [child.modulate, light.color if is_instance_valid(light) else null]
		_wmpsCabinLights(child)

# The ship's weapons that the switch changes, with the ends it sets them to. Worked out once, and again when the ship's
# systems change (fillInSystems emits systemsChanged only when the list of systems changes). While it is worked out,
# getTunedValue finds no ends and reads the Tuning as it is.
func _wmpsWeapons() -> Dictionary:
	if _wmpsEnds == null:
		_wmpsEnds = {}
		var ends = {}
		_wmpsScan(self, ends)
		_wmpsEnds = ends
		if not is_connected("systemsChanged", self, "_wmpsSystemsChanged"):
			connect("systemsChanged", self, "_wmpsSystemsChanged")
	return _wmpsEnds

func _wmpsSystemsChanged(_systems):
	_wmpsEnds = null
	_wmpsWeapons()

# Every weapon in the ship's nodes. A hardpoint (ships/WeaponSlot.gd) and a turret (ships/modules/PDT.gd) hold their
# weapon as `system` and pass its Tuning on: they are left out, and their weapon is found itself.
func _wmpsScan(node, ends):
	for child in node.get_children():
		if child.has_method("getTuneables") and not ("system" in child) and "slotName" in child:
			var slot = str(child.slotName)
			if slot.begins_with(_WMPS_SLOT_PREFIX):
				var weaponEnds = _wmpsEndsOf(child)
				if not weaponEnds.empty():
					ends[slot] = weaponEnds
		_wmpsScan(child, ends)

# A weapon's ends, from its own Tuning entries: none for what isn't a weapon (the arm, drone plants: no entry of
# _WMPS_HIGHEST).
func _wmpsEndsOf(weapon) -> Dictionary:
	var ends = {}
	var tuneables = weapon.getTuneables()
	if not (tuneables is Dictionary):
		return ends
	for key in _WMPS_HIGHEST:
		var power = tuneables.get(key)
		if power is Dictionary and power.has("max"):
			ends[key] = power["max"]
	if ends.empty():
		return ends
	var end = _WMPS_FREQUENCY.get(str(weapon.get("systemName")))
	var frequency = tuneables.get(_WMPS_FREQUENCY_KEY)
	if end != null and frequency is Dictionary and frequency.has(end):
		ends[_WMPS_FREQUENCY_KEY] = frequency[end]
	return ends

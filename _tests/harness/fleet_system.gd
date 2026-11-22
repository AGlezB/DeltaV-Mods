extends Node

# Stub of a piece of equipment with Tuning settings, for the fleet suite: what Tuning.gd fillTuneableSystems reads from
# one of the ship's systems (getTuneables: each setting's type, default and step). One mounted on a slot has a
# `slotName` too (harness/fleet_slot_system.gd), under which its settings are filed.

var tuneables = {}

func getTuneables():
	return tuneables

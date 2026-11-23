extends VBoxContainer

# For the repairs suite: a group of the Equipment screen (enceladus/UpgradeGroup.gd), with what ShipRepairAdvisor reads
# of it: its slot, `always` and `restrictType`, and its visibility, which the suite sets as reexamine would for the ship.
export var slot = ""
export var always = true
export var restrictType = ""

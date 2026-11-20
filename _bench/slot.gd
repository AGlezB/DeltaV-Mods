extends Node2D

# Stands in for ships/WeaponSlot.gd: what the systems mounted on a hardpoint read from it (drone-plant.gd its slot,
# emp.gd and massdriver.gd its type and key, as the mount they look for).

var slot = ""
var type = ""
var key = ""

extends Node

# Stub of BulletTimer.tscn's root (BulletTimer.gd) for the combat suite: it connects CurrentGame's gameOver in its
# _ready, as the game's does (CombatSimulator's arena cuts that connection); the bullet time itself doesn't run.

var gameOver = false

func _ready():
	CurrentGame.connect("gameOver", self, "_on_gameOver")

func _on_gameOver():
	gameOver = true

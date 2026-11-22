extends Node

# Stub of the game's Achivements autoload (achievement/AchivementAbstract.tscn, the game's spelling): what Game.gd and
# enceladus/Enceladus.gd call. Steam and the game's own achievements are left out: the calls do nothing. Its
# achivedOffline signal, as achievement/AchivementAbstract.gd declares it, is a notice DiveSkipTransit connects.

signal achivedOffline(what)

func achive(_id):
	pass

func presence(_status, _detail = null):
	pass

func setStat(_stat, _value):
	pass

func updateLeaderboard(_board, _value):
	pass

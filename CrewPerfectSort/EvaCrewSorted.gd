extends "res://CurrentGame.gd"

# The derelict conversation's choice of who goes on EVA, in the Your Crew screen's order. The conversation offers one
# reply per crew member aboard (comms/conversation/subtrees/DIALOG_DERELICT_RANDOM.tscn, DIALOG_DERELICT_SWITCH_CREW|<n>,
# agenda "CREW/<n>"), each asking getSpecificMemberNr for the n-th member (comms/ConversationPlayer.gd
# getAgendaMember). The game's getActiveMembers walks state.crew, which keeps the hire order, so the replies came in
# that order. Only those replies ask getSpecificMemberNr; getRandomMember, who speaks first, keeps the game's order.

const CrewPerfectSort = preload("res://CrewPerfectSort/Shared.gd")


# As the game's, with the crew aboard sorted first. The parent's returns a single member, so it can't be reordered
# after the call: this replaces it.
func getSpecificMemberNr(nr: int):
	var members = getActiveMembers()
	members.sort_custom(self, "_cpsBefore")
	if nr < members.size():
		return members[nr]
	else:
		return null


func _cpsBefore(a, b):
	return CrewPerfectSort.yourCrewBefore(a, b)

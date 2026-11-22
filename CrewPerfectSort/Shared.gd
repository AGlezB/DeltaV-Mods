extends Reference

# The code CrewPerfectSort's scripts share, static: never instanced. The Your Crew order, which
# CurrentCrewManagementSorted.gd sorts the Your Crew screen by, and EvaCrewSorted.gd the derelict conversation's choice
# of who goes on EVA.


# The Your Crew order: by job, then salary (lowest first), then name, so the order never shuffles. a and b are the
# screen's entries (enceladus/CrewBio.gd) or the game's crew records (CurrentGame.state.crew): both have these fields.
static func yourCrewBefore(a, b):
	if a.occupation != b.occupation:
		return a.occupation < b.occupation
	if a.salary != b.salary:
		return a.salary < b.salary
	return a.fullName < b.fullName

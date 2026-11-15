extends "res://enceladus/CurrentCrewManagement.gd"

# The "Your crew" screen, sorted by job, then salary (lowest first).


func fillCrew():
	.fillCrew()
	var crew = []
	for entry in crewNode.get_children():
		if not entry.is_queued_for_deletion():
			crew.append(entry)
	crew.sort_custom(self, "_before")
	for i in range(crew.size()):
		crewNode.move_child(crew[i], i)


func _before(a, b):
	if a.occupation != b.occupation:
		return a.occupation < b.occupation
	if a.salary != b.salary:
		return a.salary < b.salary
	return a.fullName < b.fullName

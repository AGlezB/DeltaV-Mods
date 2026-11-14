extends "res://enceladus/HireableCrew.gd"

# The hire screen, sorted by salary, then job.


func fillCrew():
	.fillCrew()
	var crew = []
	for entry in hireableCrew.get_children():
		if not entry.is_queued_for_deletion():
			crew.append(entry)
	crew.sort_custom(self, "_before")
	for i in range(crew.size()):
		hireableCrew.move_child(crew[i], i)
	if crew.empty():
		return
	# The screen focuses `firstItem`, the entry the game put first, so use ours.
	firstItem = crew[0]
	if is_visible_in_tree():
		Tool.deferCallInPhysics(firstItem, "focus")


func _before(a, b):
	if a.salary != b.salary:
		return a.salary < b.salary
	if a.occupation != b.occupation:
		return a.occupation < b.occupation
	return a.fullName < b.fullName

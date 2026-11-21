extends Node

# CrewHighlightJobAndSalary - makes the job and salary of every crew entry easy to
# spot: the job in bright yellow, the salary in amber, and the other details dimmed.

const CREW_SCRIPT = "res://enceladus/CrewBio.gd"
const JOB_COLOR = Color(1.0, 0.95, 0.5)
const SALARY_COLOR = Color(1.0, 0.75, 0.35)
const DIM_COLOR = Color(0.6, 0.6, 0.6)
# How long a new entry is left before it is painted, in seconds: its labels are onready nodes, filled by fillData from
# its _ready (enceladus/CrewBio.gd), which runs after the tree's node_added.
const SETTLE_TIME = 0.3


func _ready():
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node):
	var script = node.get_script()
	if script == null or script.resource_path != CREW_SCRIPT:
		return
	yield(get_tree().create_timer(SETTLE_TIME), "timeout")
	if not is_instance_valid(node):
		return
	_paint(node.occupationNode, JOB_COLOR)
	_paint(node.salaryNode, SALARY_COLOR)
	for label in [node.fullNameNode, node.educationNode, node.experienceNode, node.salaryDue, node.leaveUntil]:
		_paint(label, DIM_COLOR)


# salaryDue and leaveUntil are not always labels, so skip anything else.
func _paint(label, color):
	if label is Label:
		label.add_color_override("font_color", color)

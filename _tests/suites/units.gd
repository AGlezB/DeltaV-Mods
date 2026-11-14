extends "res://harness/suite.gd"

# Unit checks of the two arm mods, ported from the claude.ai harness (DVModTestHarness 1.0.0, arm/main.gd) with as
# few changes as possible: the mods come from the harness loader instead of --mods=, the stubs are the harness's
# (its synthetic ships keep the claude.ai stub's cutscene = true), and the game's real Tool.gd is used. The checks
# build synthetic arms around the game's DockingArm.gd (make_arm). A group whose mod is not loaded runs "control"
# checks of the game alone instead. A last section (vp) checks the real Eagle-Prospector-VP rig of harness/rig.gd.

var hasT = false
var hasP = false

func make_arm(ship_rot, arm_pos, arm_rot, arm_scale, extents, area_off, idle = 1e9):
	var field = Node2D.new(); field.name = "Field"
	var ship = StaticBody2D.new(); ship.set_script(load("res://harness/ship.gd")); ship.name = "Ship"; ship.rotation = ship_rot
	ship.cutscene = true
	field.add_child(ship)
	var arm = Node2D.new(); arm.set_script(load("res://ships/modules/DockingArm.gd")); arm.name = "Arm1"
	arm.position = arm_pos; arm.rotation = arm_rot; arm.scale = arm_scale; arm.idleAtReady = idle
	arm.targetOnlyShips = false
	var area = Area2D.new(); area.name = "DockArea"; arm.add_child(area)
	var cs = CollisionShape2D.new(); cs.name = "CS"; cs.position = area_off
	var rs = RectangleShape2D.new(); rs.extents = extents; cs.shape = rs; area.add_child(cs)
	for n in ["Lock", "Release", "Transfer", "Actuation"]:
		var p = AudioStreamPlayer2D.new(); p.name = n; arm.add_child(p)
	var slot = Node2D.new(); slot.name = "DockSlot"; slot.position = Vector2(100, 0); arm.add_child(slot)
	var j = PinJoint2D.new(); j.name = "Joint"; slot.add_child(j)
	var a = Node2D.new(); a.set_script(load("res://ships/modules/Arm.gd")); a.name = "Arm"; arm.add_child(a)
	var t = Node2D.new(); t.name = "Target"; a.add_child(t)
	var A = Node2D.new(); A.name = "A"; a.add_child(A)
	var B = Node2D.new(); B.name = "B"; A.add_child(B)
	var AA = Node2D.new(); AA.name = "Arm"; B.add_child(AA)
	var sp = Node2D.new(); sp.set_script(load("res://harness/spotlight.gd")); sp.name = "Spotlight"; B.add_child(sp)
	ship.add_child(arm)
	return [field, ship, arm, cs]

func geometry(label, ship_rot, arm_pos, arm_rot, arm_scale, extents, area_off, rear = 0.0):
	var r = make_arm(ship_rot, arm_pos, arm_rot, arm_scale, extents, area_off)
	var cs = r[3]; var arm = r[2]
	add_child(r[0])
	if not hasT:
		check("control geometry " + label + ": the game's rectangle stays", cs.shape is RectangleShape2D)
		r[0].queue_free()
		return
	var R = 2.0 * arm_scale.x * 300
	var base = arm.global_position
	var axis = Vector2(0, -1).rotated(arm.global_rotation)
	var centre = base + axis * _const(arm, "BUFFER_AREA_FACTOR") * R
	var n = arm.AREA_SEGMENTS
	var ok = cs.shape is ConvexPolygonShape2D and cs.shape.points.size() == n + 1
	var why = ""
	var world = []
	if ok:
		for p in cs.shape.points:
			world.append(cs.global_transform.xform(p))
		for i in range(n + 1):
			if abs(world[i].distance_to(centre) - R) > 0.01:
				ok = false; why += " point %d off the circle" % i
			if (world[i] - base).dot(axis) < -0.01:
				ok = false; why += " point %d behind the base" % i
		for i in [0, n]:
			if abs((world[i] - base).dot(axis)) > 0.01:
				ok = false; why += " end %d not on the base line" % i
		var step = (world[1] - centre).angle_to(world[0] - centre)
		for i in range(1, n):
			if abs((world[i + 1] - centre).angle_to(world[i] - centre) - step) > 1e-4:
				ok = false; why += " uneven step at %d" % i
		var front = centre + axis * R * 0.999
		if not Geometry.is_point_in_polygon(cs.global_transform.affine_inverse().xform(front), cs.shape.points):
			ok = false; why += " straight ahead is outside"
	check("geometry " + label + ": %d segments on the reach circle, cut at the arm base" % n, ok, why)
	check("geometry " + label + ": rear edge of the game's area %.1f" % rear, abs(arm._rear - rear) < 0.05, str(arm._rear))
	r[0].queue_free()

func run():
	hasT = hasMod("ArmAltTargetSelection")
	hasP = hasMod("ArmAltPullBehavior")
	yield(get_tree(), "physics_frame")

	# ---- area geometry
	geometry("plain", 0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	geometry("ship rotated", 0.7, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	geometry("arm rot 90 (OCP)", 0.7, Vector2(-80, 30), PI / 2, Vector2(1, 1), Vector2(1500, 1500), Vector2(100, 40))
	geometry("arm rot 180 scale .5", -1.2, Vector2(-80, 30), PI, Vector2(0.5, 0.5), Vector2(3000, 3000), Vector2(0, 0))
	geometry("arm rot -90 scale .5 off", 0.2, Vector2(50, 0), -PI / 2, Vector2(0.5, 0.5), Vector2(2000, 3000), Vector2(1000, -500))
	# the AR-1500 as in SalvageArm.tscn / DockingArm.tscn: scale 0.75, area rectangle 633.553 x 476.834 at (0, -570)
	geometry("AR-1500", 0.0, Vector2(60, -20), 0.0, Vector2(0.75, 0.75), Vector2(633.553, 476.834), Vector2(0, -570), 69.875)
	geometry("AR-1500, ship rotated", 2.1, Vector2(60, -20), 0.0, Vector2(0.75, 0.75), Vector2(633.553, 476.834), Vector2(0, -570), 69.875)
	geometry("AR-1500, turned mount", 0.0, Vector2(62, -109), PI / 2, Vector2(0.75, 0.75), Vector2(633.553, 476.834), Vector2(0, -570), 69.875)

	# ---- the strip between the arm base and the game's area (AR-1500: reach 450, strip 69.9 deep)
	var r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(0.75, 0.75), Vector2(633.553, 476.834), Vector2(0, -570))
	add_child(r[0])
	var ship = r[1]; var arm = r[2]
	ship.cutscene = false
	var sb = {}
	var bal = _const(arm, "BALANCE")
	# the base line: y = -20; the strip: -89.9 < y < -20. The targets outside the strip are placed from the reach
	# circle, whose centre BUFFER_AREA_FACTOR moves ahead of the arm base.
	var reach = 2.0 * 0.75 * 300
	var centre = Vector2(60, -20) + Vector2(0, -1) * _const(arm, "BUFFER_AREA_FACTOR", 0.0) * reach
	var sp = {"S1": Vector2(60, -50), "S2": Vector2(200, -60), "N1": centre + Vector2(240, -235), "N2": centre + Vector2(-260, -335),
		"Behind": Vector2(60, 10), "Far": centre + Vector2(0, - (reach + 45)), "Side": centre + Vector2(reach + 50, 0),
		"Edge": centre + Vector2(0, - (reach - 10))}
	for k in sp:
		var b = RigidBody2D.new(); b.name = k; b.gravity_scale = 0; b.position = sp[k]
		var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = 1; b.add_child(c)
		r[0].add_child(b); sb[k] = b
	for i in range(3): yield(get_tree(), "physics_frame")
	if hasT:
		var a2 = arm.areaDockArea
		check("area: strip targets S1, S2 are in it", a2.overlaps_body(sb["S1"]) and a2.overlaps_body(sb["S2"]))
		check("area: N1, N2 are in it", a2.overlaps_body(sb["N1"]) and a2.overlaps_body(sb["N2"]))
		check("area: straight ahead, just inside the reach circle (the buffer area, if any) is in it", a2.overlaps_body(sb["Edge"]))
		check("area: behind the arm base is not", not a2.overlaps_body(sb["Behind"]))
		check("area: straight ahead, just beyond the reach circle is not", not a2.overlaps_body(sb["Far"]))
		check("area: beyond the reach at the side is not", not a2.overlaps_body(sb["Side"]))
		check("strip: alone, a strip target is taken", _pick(arm, ["S1"]) == sb["S1"])
		check("strip: any target outside the strip comes first (N1 over S1)", _pick(arm, ["S1", "N1"]) == sb["N1"])
		check("strip: ... whatever the queue order", _pick(arm, ["N1", "S1"]) == sb["N1"])
		var sBest = _best(["S1", "S2"], sb, bal, ship.global_position)
		check("strip: between strip targets, the better score wins (%s)" % sBest.name, _pick(arm, ["S2", "S1"]) == sBest)
		var nBest = _best(["N1", "N2"], sb, bal, ship.global_position)
		check("strip: between other targets, the better score wins (%s)" % nBest.name, _pick(arm, ["S1", "N1", "S2", "N2"]) == nBest)
		check("strip: targets out of the area are not taken", _pick(arm, ["Behind", "Far", "Side"]) == null)
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- selection (arm at (60, -20), reach 600, the circle centre moved BUFFER_AREA_FACTOR of it ahead, base line
	# y = -20). C and D lie straight ahead (x = 0), E and F 10 ahead of the base line, just beyond / inside the circle.
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0])
	ship = r[1]; arm = r[2]
	ship.cutscene = false
	var bodies = {}
	reach = 600.0
	centre = Vector2(60, -20) + Vector2(0, -1) * _const(arm, "BUFFER_AREA_FACTOR", 0.0) * reach
	var sideDy = -30 - centre.y
	var mk = {"A": Vector2(5, -400), "B": Vector2(100, -200), "C": Vector2(0, centre.y - sqrt(pow(reach + 43, 2) - 3600)),
		"D": Vector2(0, centre.y - sqrt(pow(reach - 37, 2) - 3600)), "E": Vector2(60 + sqrt(pow(reach + 42, 2) - sideDy * sideDy), -30),
		"F": Vector2(60 - sqrt(pow(reach - 38, 2) - sideDy * sideDy), -30), "G": Vector2(140, -150), "G2": Vector2(130, -60), "H": Vector2(0, 40), "I": Vector2(300, -25)}
	for k in mk:
		var b = RigidBody2D.new(); b.name = k; b.gravity_scale = 0; b.position = mk[k]
		var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = 1; b.add_child(c)
		r[0].add_child(b); bodies[k] = b
	for i in range(3): yield(get_tree(), "physics_frame")
	if hasT:
		check("reach: D (straight ahead, just inside the circle) is allowed", _pick(arm, ["D"]) == bodies["D"])
		check("reach: C (straight ahead, just beyond the circle) rejected", _pick(arm, ["C"]) == null)
		check("reach: E (side, just beyond the circle) rejected", _pick(arm, ["E"]) == null)
		check("reach: F (side, just inside the circle) allowed", _pick(arm, ["F"]) == bodies["F"])
		check("reach: H (behind the arm base) rejected", _pick(arm, ["H"]) == null)
		check("reach: I (just ahead of the arm base) allowed", _pick(arm, ["I"]) == bodies["I"])
	var slotpos = ship.global_position # no grinder or excavator: the entry point is the ship centre
	var sets = [["B", "A"], ["A", "B", "G2"], ["B", "G", "G2", "A"], ["G2", "B"], ["F", "H", "A", "B", "G"], ["C", "E", "B"], ["H", "I", "C"]]
	for names in (sets if hasT else []):
		var inArea = []
		for n in names:
			var p = bodies[n].global_position
			if p.distance_to(centre) <= reach and p.y <= -20:
				inArea.append(n)
		var best = _best(inArea, bodies, bal, slotpos)
		check("weighted pick " + str(names) + " -> " + (best.name if best else "none"), _pick(arm, names) == best)
	if hasT and bal == 1.0:
		check("balance 1: centerline only", _pick(arm, ["B", "G2", "A"]) == bodies["A"])
	if hasT and bal == 0.0:
		check("balance 0: dock slot only", _pick(arm, ["B", "A", "G2"]) == bodies["G2"])
	if hasT: check("order in the queue doesn't matter", _pick(arm, ["B", "G2", "A"]) == _pick(arm, ["A", "G2", "B"]))
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- hysteresis through the real _physics_process
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0), 0.0)
	add_child(r[0])
	ship = r[1]; arm = r[2]
	var b1 = RigidBody2D.new(); b1.gravity_scale = 0; b1.position = Vector2(100, -200); r[0].add_child(b1)
	var b2 = RigidBody2D.new(); b2.gravity_scale = 0; b2.position = Vector2(300, -300); r[0].add_child(b2)
	yield(get_tree(), "physics_frame")
	arm.addToQueue(b2); arm.addToQueue(b1)
	for i in range(5): yield(get_tree(), "physics_frame")
	if hasT: check("first pick: b1 (closer to the centerline)", arm.target == b1)
	var b3 = RigidBody2D.new(); b3.gravity_scale = 0; b3.position = Vector2(0, -150); r[0].add_child(b3)
	arm.addToQueue(b3)
	for i in range(10): yield(get_tree(), "physics_frame")
	if hasT: check("hysteresis: stays on b1 although b3 is better", arm.target == b1)
	arm.queue.erase(b1)
	for i in range(5): yield(get_tree(), "physics_frame")
	if hasT: check("after b1 lost: switches to b3", arm.target == b3)
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- no acceleration push: while the game pulls the target, the mod adds nothing when the ship accelerates
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0])
	ship = r[1]; arm = r[2]
	var tb = RigidBody2D.new(); tb.gravity_scale = 0; tb.mass = 10.0; tb.linear_damp = 0; tb.position = Vector2(10, -100); r[0].add_child(tb)
	yield(get_tree(), "physics_frame")
	arm.target = tb; arm.locked = true
	var gm = Node2D.new(); gm.set_script(load("res://harness/grinder.gd")); r[0].add_child(gm)
	var g1 = Node2D.new(); g1.position = Vector2(-20, 0); ship.add_child(g1)
	var g2 = Node2D.new(); g2.position = Vector2(40, 0); ship.add_child(g2)
	gm.grinder1node = g1; gm.grinder2node = g2
	ship.systems = {"SYSTEM_GRINDER": {"name": "SYSTEM_GRINDER", "ref": gm}}
	for i in range(60):
		ship.linear_velocity += Vector2(0, -200) / 60.0
		ship.position += ship.linear_velocity / 60.0
		yield(get_tree(), "physics_frame")
	check("no acceleration push: target untouched, nothing back to the ship", tb.linear_velocity.length() < 0.001 and ship.impulses.length() < 0.001, "%s %s" % [tb.linear_velocity, ship.impulses])
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- cost of the mod's pull: energy, wear and weakening as in the game's own pull
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0]); ship = r[1]; arm = r[2]
	var cm = Node2D.new(); cm.set_script(load("res://harness/grinder.gd")); r[0].add_child(cm)
	var c1 = Node2D.new(); c1.position = Vector2(-20, 0); ship.add_child(c1)
	var c2 = Node2D.new(); c2.position = Vector2(40, 0); ship.add_child(c2)
	cm.grinder1node = c1; cm.grinder2node = c2
	ship.systems = {"SYSTEM_GRINDER": {"name": "SYSTEM_GRINDER", "ref": cm}}
	# These rotors have no shapes: they reach 0 ahead of the tip (10, 0), so the red line is the clearance
	# (CHUNK_RADIUS_CLEARENCE_FACTOR chunk radii) ahead of it; the corridor is 30 either side.
	var ctClear = _const(arm, "CHUNK_RADIUS_CLEARENCE_FACTOR", 0.0) * VP.CHUNK_RADIUS
	var ctStart = Vector2(250, -0.7 * ctClear)   # behind the red line, outside the corridor
	var ct = RigidBody2D.new(); ct.gravity_scale = 0; ct.position = ctStart; r[0].add_child(ct)
	yield(get_tree(), "physics_frame")
	if hasP:
		var cdt = 1.0 / 60.0
		var crel = Vector2(0, 100)
		var s0 = 100.0
		var p0 = s0 * arm.powerDraw * max(arm.stallDrawVelocityEquivalent, crel.length()) / 10
		ship.energy = 0.0
		var got = arm._cost(s0, crel, cdt)
		check("cost: energy as the game's pull, full impulse when nothing limits it", abs(got - s0) < 1e-6 and abs(ship.energy - p0) < 1e-6, "%s %s %s" % [got, ship.energy, p0])
		arm.tunedPowerLimit = p0 / cdt / 4000.0
		ship.energy = 0.0
		got = arm._cost(s0, crel, cdt)
		check("cost: capped by the power limit (a quarter of the energy, a quarter of the impulse)", abs(ship.energy - p0 / 4) < 1e-6 and abs(got - s0 / 4) < 1e-6, "%s %s" % [got, ship.energy])
		arm.tunedPowerLimit = null
		arm.damageModel = true; arm.wearChance = 1.0; arm.wearCache = 1.0; arm.overheatCache = 0.5
		ship.damage = {}
		got = arm._cost(s0, crel, cdt)
		check("cost: an overheated arm delivers less (overheatCache 0.5 halves it)", abs(got - s0 * 0.5) < 1e-6, str(got))
		check("cost: wear as the game's formula (no power limit: energy x powerWearRatio)", abs(ship.damage.get("wear", 0.0) - p0 * arm.powerWearRatio) < 1e-6, str(ship.damage))
		arm.wearCache = 0.0; arm.overheatCache = 1.0
		var lo = INF; var hi = - INF
		for i in range(50):
			var g = arm._cost(s0, crel, cdt); lo = min(lo, g); hi = max(hi, g)
		check("cost: a worn arm (wearCache 0) delivers a random part of it", lo >= 0 and hi <= s0 and hi - lo > 1, "%s..%s" % [lo, hi])
		arm.wearCache = 1.0
		check("cost: nothing to deliver, nothing drawn", arm._cost(0.0, crel, cdt) == 0.0)
		ship.damage = {}
		arm.feed = 1.0
		arm.queue.append(ct); arm.target = ct; arm.locked = true
		for i in range(10): yield(get_tree(), "physics_frame")
		check("cost: pulling forward (behind the red line) wears the arm", arm._outside() != null and ship.damage.get("wear", 0.0) > 0, str(ship.damage))
		var done = false
		for i in range(900):
			yield(get_tree(), "physics_frame")
			arm._outside()
			if arm._feedIn:
				done = true
				break
		check("pull: feeding, straight to the opening: the target gets into the corridor, slows down and is pulled in", done and abs(ct.global_position.x - 10.0) <= 30.0, str(ct.global_position))
		# a block of hull right below the target, its top edge half the clearance away: the line to the opening comes
		# too close, so it goes straight forward first
		var hb = CollisionShape2D.new(); hb.shape = RectangleShape2D.new(); hb.shape.extents = Vector2(20, 20); hb.position = ctStart + Vector2(0, 0.5 * ctClear + 20); ship.add_child(hb)
		ct.linear_velocity = Vector2(); ct.position = ctStart; arm._lastTarget = null
		yield(get_tree(), "physics_frame")
		var o2 = arm._outside()
		var wasForward = o2 != null and abs(o2.x) < 0.01
		done = false
		var straight = true
		for i in range(900):
			yield(get_tree(), "physics_frame")
			var o3 = arm._outside()
			if arm._feedIn:
				done = true
				break
			if o3 != null and abs(o3.x) < 0.01 and abs(ct.global_position.x - 250.0) > 0.5:
				straight = false
		check("pull: feeding, too close to the hull: straight forward first, then to the opening and pulled in from the corridor", wasForward and straight and done and abs(ct.global_position.x - 10.0) <= 30.0, str(ct.global_position))
		hb.queue_free()
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- not locked: nothing applied
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0]); ship = r[1]; arm = r[2]
	var tb2 = RigidBody2D.new(); tb2.gravity_scale = 0; tb2.position = Vector2(100, 0); r[0].add_child(tb2)
	yield(get_tree(), "physics_frame")
	arm.target = tb2
	for i in range(30):
		ship.linear_velocity += Vector2(0, -200) / 60.0
		ship.position += ship.linear_velocity / 60.0
		yield(get_tree(), "physics_frame")
	if hasP:
		check("not locked: target untouched", tb2.linear_velocity.length() < 0.001)
	# ---- switching the arm off and on
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0), 0.0)
	add_child(r[0]); ship = r[1]; arm = r[2]
	ship.cutscene = false
	var X = RigidBody2D.new(); X.name = "X"; X.gravity_scale = 0; X.position = Vector2(640, -600); _shape(X); r[0].add_child(X)   # out of reach: in the game's area only
	var Y = RigidBody2D.new(); Y.name = "Y"; Y.gravity_scale = 0; Y.position = Vector2(100, -200); _shape(Y); r[0].add_child(Y)
	var S = RigidBody2D.new(); S.name = "S"; S.gravity_scale = 0; S.position = Vector2(5000, 5000); _shape(S); r[0].add_child(S)   # never in the area
	for i in range(10): yield(get_tree(), "physics_frame")
	if hasT:
		check("on: X (out of reach) never enters the queue, Y is taken", not arm.queue.has(X) and arm.target == Y)
	else:
		note("control: queue %s target %s" % [arm.queue, arm.target])
	arm.queue.append(S)
	arm.locked = true
	arm.enabled = false
	for i in range(5): yield(get_tree(), "physics_frame")
	if not hasT:
		note("control: target after 5 frames off: %s" % [arm.target])
	else:
		check("off: target dropped, unlocked", arm.target == null and arm.locked == false)
	var Z = RigidBody2D.new(); Z.name = "Z"; Z.gravity_scale = 0; Z.position = Vector2(0, -100); _shape(Z); r[0].add_child(Z)
	for i in range(30): yield(get_tree(), "physics_frame")
	if hasT:
		check("off: nothing is selected while off", arm.target == null)
		check("off: the queue stays empty while off (Z entered the area)", arm.queue.empty())
	arm.enabled = true
	for i in range(5): yield(get_tree(), "physics_frame")
	if hasT:
		check("on: stale queue entry S is gone", not arm.queue.has(S))
		check("on: queue holds what is in the area", not arm.queue.has(X) and arm.queue.has(Y) and arm.queue.has(Z))
		check("on: fresh selection takes the best target (Z)", arm.target == Z)
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- pull-in limit near the grinder / excavator
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0]); ship = r[1]; arm = r[2]
	arm.feedVelocity = Vector2(0, -200)   # axis (0, -1); dock slot at (160, -20)
	var mouth = Node2D.new(); r[0].add_child(mouth)
	var holder = Node2D.new(); holder.name = "Claw Holder"; mouth.add_child(holder)
	var w1 = Node2D.new(); w1.name = "Claw Left"; w1.position = Vector2(150, 40); holder.add_child(w1)
	var spr = Node2D.new(); spr.name = "Claw Left"; w1.add_child(spr)
	var w2 = Node2D.new(); w2.name = "Claw Right"; w2.position = Vector2(170, 40); holder.add_child(w2)
	for w in [w1, w2]:
		var cc = CollisionShape2D.new(); var sh = CircleShape2D.new(); sh.radius = 12.0; cc.shape = sh; w.add_child(cc)
	mouth.set_script(load("res://harness/grinder.gd")); mouth.grinder1node = w1; mouth.grinder2node = w2
	var pb = RigidBody2D.new(); pb.gravity_scale = 0; pb.position = Vector2(160, 0); r[0].add_child(pb)
	for i in range(5): yield(get_tree(), "physics_frame")
	arm.target = pb
	# [label, system, tip, target position, target velocity, expected, feeding, hull]
	#  expected: 1 = the game's pull, 2 = pulled straight to the middle of the opening (on the red line),
	#  0 = pulled straight forward to a chunk's radius past the red line, 3 = feeding in the corridor: pulled straight in
	#  by the mod (1.5.0; it used to be left to the game), towards the corridor's middle line
	#  feeding: the excavator command is held (the arm's `feed`)
	#  hull: a block of hull 120 wide and 40 deep, 40 behind the tip (sides at x = +-60, from 40 to 80 behind the tip)
	# rotors/claws are 60 apart (circle radius 12): opening 60 wide, they reach 12 ahead of the tip; the red line is the
	# clearance (CHUNK_RADIUS_CLEARENCE_FACTOR chunk radii) further ahead. Targets near the red line or the hull are
	# placed from those two distances.
	# the arm is moved in line with the corridor, its dock slot 300 ahead of it (at (160, -320))
	var clear = _const(arm, "CHUNK_RADIUS_CLEARENCE_FACTOR", 0.0) * VP.CHUNK_RADIUS
	var redAhead = 12.0 + clear
	var T = Vector2(160, 40)
	arm.position = Vector2(160, -20); arm.areaDockSlot.position = Vector2(0, -300)
	var cases = [
		["feeding: in the corridor, ahead of the tip", "SYSTEM_GRINDER", T, T + Vector2(0, -40), Vector2(0, 0), 3, 1],
		["feeding: in the corridor, 28 sideways", "SYSTEM_GRINDER", T, T + Vector2(28, -30), Vector2(0, 0), 3, 1],
		["feeding: in the corridor, past the red line", "SYSTEM_GRINDER", T, T + Vector2(10, - (redAhead + 96)), Vector2(0, 0), 3, 1],
		["feeding: behind the tip, in line", "SYSTEM_GRINDER", T, T + Vector2(24, 20), Vector2(0, 0), 3, 1],
		["feeding: 45 sideways, halfway to the red line", "SYSTEM_GRINDER", T, T + Vector2(45, - redAhead / 2), Vector2(0, 0), 2, 1],
		["feeding: 35 sideways, 45 ahead, to the left", "SYSTEM_GRINDER", T, T + Vector2(-35, -45), Vector2(0, 0), 2, 1],
		["feeding: beside the tip, 99", "SYSTEM_GRINDER", T, T + Vector2(99, 0), Vector2(0, 0), 2, 1],
		["feeding: behind the tip, off to the side", "SYSTEM_GRINDER", T, T + Vector2(60, 20), Vector2(0, 0), 2, 1],
		["feeding: 65 sideways, past the red line, outside the corridor", "SYSTEM_GRINDER", T, T + Vector2(65, - (redAhead + 16)), Vector2(0, 0), 2, 1],
		["feeding: far to the left, 200 ahead", "SYSTEM_GRINDER", T, T + Vector2(-150, -200), Vector2(0, 0), 2, 1],
		["feeding, hull: 45 sideways, halfway to the red line (the line to the opening stays clear of the hull)", "SYSTEM_GRINDER", T, T + Vector2(45, - redAhead / 2), Vector2(0, 0), 2, 1, true],
		["feeding, hull: right beside the hull (half the clearance out, 50 behind the tip)", "SYSTEM_GRINDER", T, T + Vector2(60 + 0.5 * clear, 50), Vector2(0, 0), 0, 1, true],
		["feeding, hull: behind and beside the hull, the line to the opening passes close to it", "SYSTEM_GRINDER", T, T + Vector2(60 + 1.44 * clear, 80 + 0.96 * clear), Vector2(0, 0), 0, 1, true],
		["feeding: excavator, 45 sideways, 40 ahead", "SYSTEM_EXCAVATOR", T, T + Vector2(45, -40), Vector2(0, 0), 2, 1],
		["feeding: excavator, 28 sideways, 30 ahead (inside)", "SYSTEM_EXCAVATOR", T, T + Vector2(28, -30), Vector2(0, 0), 3, 1],
		["not feeding: 45 sideways, 30 ahead (the line to the dock slot is clear)", "SYSTEM_GRINDER", T, T + Vector2(45, -30), Vector2(0, 0), 1, 0],
		["not feeding: 65 sideways, past the red line", "SYSTEM_GRINDER", T, T + Vector2(65, - (redAhead + 16)), Vector2(0, 0), 1, 0],
		["not feeding: in the corridor", "SYSTEM_GRINDER", T, T + Vector2(0, -40), Vector2(0, 0), 1, 0],
		["not feeding, hull: right beside the hull (the line to the dock slot touches it)", "SYSTEM_GRINDER", T, T + Vector2(60 + 0.5 * clear, 50), Vector2(0, 0), 0, 0, true],
		["not feeding, hull: far out beside the hull (the line to the dock slot is clear)", "SYSTEM_GRINDER", T, T + Vector2(60 + 2.2 * clear, 30), Vector2(0, 0), 1, 0, true],
	]
	var hull = CollisionShape2D.new(); hull.shape = RectangleShape2D.new(); hull.shape.extents = Vector2(60, 20); hull.position = T + Vector2(0, 60)
	for c in cases:
		ship.systems = {}
		ship.systems[c[1]] = {"name": c[1], "ref": mouth}
		if c.size() > 7 and hull.get_parent() == null:
			ship.add_child(hull)
		elif c.size() <= 7 and hull.get_parent() != null:
			ship.remove_child(hull)
		w1.position = c[2] - Vector2(30, 0); w2.position = c[2] + Vector2(30, 0)
		arm.feed = c[6]
		pb.linear_velocity = Vector2(); pb.position = c[3]
		if hasP:
			arm._lastTarget = null
		for i in range(3): yield(get_tree(), "physics_frame")
		pb.linear_velocity = c[4]
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "idle_frame")
		if hasP:
			var side = arm._outside()
			var axis = Vector2(0, -1).rotated(arm.global_rotation)
			if c[5] == 1:
				check("pull: " + c[0] + ": original pull", side == null and arm.maxThrust == arm._maxThrust and arm._maxThrust > 0, "maxThrust %s side %s" % [arm.maxThrust, side])
			elif c[5] == 3:
				var lat = axis.rotated(PI / 2)
				var across = (pb.global_position - c[2]).dot(lat)
				var v = arm._pullTo(side, Vector2(), 1.0 / 60.0) if side != null else Vector2()
				check("pull: " + c[0] + ": pulled straight in along the corridor, towards its middle line", side != null and arm._feedIn and arm.maxThrust == 0.0 and v.dot(- axis) > 0 and (abs(across) < 0.01 or v.dot(lat) * across < 0), "maxThrust %s impulse %s side %s" % [arm.maxThrust, v, side])
			else:
				# red line: the front of the rotors / claws (12) plus the clearance. Forward: to a chunk's radius past it.
				var F = redAhead
				var ok = side != null
				var v = Vector2()
				var why = ""
				if ok:
					v = arm._pullTo(side, arm.velocity - pb.linear_velocity, 1.0 / 60.0)
					var dest = pb.global_position - side
					var lat = axis.rotated(PI / 2)
					ok = arm.maxThrust == 0.0 and v.dot(side) < 0
					if c[5] == 0:
						ok = ok and abs((dest - c[2]).dot(axis) - (F + VP.CHUNK_RADIUS)) < 0.01 and abs((dest - pb.global_position).dot(lat)) < 0.01
					else:
						ok = ok and (dest - (c[2] + axis * F)).length() < 0.01
					why = "dest ahead %.2f, across %.2f" % [(dest - c[2]).dot(axis), (dest - c[2]).dot(lat)]
				check("pull: " + c[0] + (": pulled straight forward to clear the red line" if c[5] == 0 else ": pulled straight to the middle of the opening"), ok, "maxThrust %s %s impulse %s side %s" % [arm.maxThrust, why, v, side])
	if hull.get_parent() != null:
		ship.remove_child(hull)
	hull.free()
	# ---- opening measured tip to tip, with the EIME's claw polygons (beak open: nodes 65 either side)
	if hasP:
		arm.rotation = 0.0
		ship.systems = {"SYSTEM_EXCAVATOR": {"name": "SYSTEM_EXCAVATOR", "ref": mouth}}
		for w in [w1, w2]:
			for k in w.get_children():
				if k is CollisionShape2D:
					w.remove_child(k)
		w1.position = T - Vector2(65, 0); w2.position = T + Vector2(65, 0)
		var pr = CollisionPolygon2D.new(); pr.position = Vector2(-17, 21)
		pr.polygon = PoolVector2Array([Vector2(0, -134), Vector2(36, -108), Vector2(69, 33), Vector2(0, 4), Vector2(0, 20), Vector2(64, 56), Vector2(88, 50), Vector2(52, -104), Vector2(44, -116), Vector2(0, -148)]); w2.add_child(pr)
		var pl = CollisionPolygon2D.new(); pl.position = Vector2(17, 21)
		pl.polygon = PoolVector2Array([Vector2(0, -134), Vector2(-36, -108), Vector2(-69, 33), Vector2(0, 4), Vector2(0, 20), Vector2(-64, 56), Vector2(-88, 50), Vector2(-52, -104), Vector2(-44, -116), Vector2(0, -148)]); w1.add_child(pl)
		yield(get_tree(), "physics_frame")
		var en = arm._entry()
		check("claws tip to tip: half opening 48 (nodes 65 apart, tips 17 inside them)", abs(en[1] - 48.0) < 0.01, str(en))
		var RL = 127.0 + clear
		check("claws tip to tip: red line 127 ahead of the tip + the clearance", abs(en[2] - RL) < 0.01, str(en))
		arm.feed = 1.0
		arm._lastTarget = null
		# hysteresis at the corridor's edge, 100 ahead of the tip (behind the red line): opening edge 48; pulling it straight in starts there and goes on until 48 + a chunk radius (58.4)
		var steps = [[0, true], [40, true], [55, true], [62, false], [55, false], [45, true]]
		for st in steps:
			pb.linear_velocity = Vector2(); pb.position = T + Vector2(st[0], -100)
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "idle_frame")
			var hs = arm._outside()
			check("hysteresis: %s sideways, behind the red line -> %s" % [st[0], "pulled straight in" if st[1] else "pulled forward"], hs != null and arm._feedIn == st[1], "%s, pulled in %s" % [hs, arm._feedIn])
		# while feeding, crossing the red line outside the corridor does not hand it back (the feed would push it behind the line again)
		var fsteps = [[-30, false], [1, false], [40, false], [-5, false]]
		for st in fsteps:
			pb.linear_velocity = Vector2(); pb.position = T + Vector2(100, - (RL + st[0]))
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "idle_frame")
			check("feeding: %s from the red line, outside the corridor -> the mod keeps it" % st[0], arm._outside() != null, str(arm._outside()))
		# a slow target in the corridor is handed back; a fast one (sideways) is not
		pb.position = T + Vector2(20, -100); pb.linear_velocity = Vector2(300, 0)
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "idle_frame")
		check("feeding: in the corridor but moving sideways fast -> the mod keeps it", arm._outside() != null, str(pb.linear_velocity))
		pb.linear_velocity = Vector2()
		for i in range(30):
			yield(get_tree(), "physics_frame")
			arm._outside()
			if arm._feedIn:
				break
		check("feeding: in the corridor, slowed down -> pulled straight in", arm._outside() != null and arm._feedIn, str(pb.position))
		# a closed beak: nothing fits, so there is no corridor
		w1.position = T - Vector2(17, 0); w2.position = T + Vector2(17, 0)
		pb.position = T + Vector2(0, -100)
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "idle_frame")
		var cb = arm._outside()
		check("closed beak: a centred target behind the red line is pulled forward", cb != null and cb.dot(Vector2(0, -1)) < 0 and abs(cb.x) < 0.01 and arm.maxThrust == 0.0, str(cb))
		pb.position = T + Vector2(0, - (RL + 5))
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "idle_frame")
		check("closed beak, feeding: ahead of the red line, the mod holds it a chunk's radius past the line (nothing can go in)", arm._outside() != null and abs(arm._outside().y - (VP.CHUNK_RADIUS - 5)) < 0.01, str(arm._outside()))
		arm.feed = 0.0
		arm._lastTarget = null
		yield(get_tree(), "physics_frame")
		yield(get_tree(), "idle_frame")
		check("closed beak, not feeding: ahead of the red line, the game's pull", arm._outside() == null and arm.maxThrust == arm._maxThrust)
		arm.feed = 1.0
		w1.position = T - Vector2(65, 0); w2.position = T + Vector2(65, 0)
		# a ship without a grinder or excavator is left to the game, also when the ship type changes
		pb.linear_velocity = Vector2(); pb.position = T + Vector2(100, -100)
		for i in range(3): yield(get_tree(), "physics_frame")
		check("switch: with the excavator the target is pulled forward (maxThrust 0)", arm.maxThrust == 0.0 and arm._outside() != null)
		ship.systems = {}
		for i in range(3): yield(get_tree(), "physics_frame")
		check("switch: without grinder / excavator the mod does nothing", arm._entry() == null and arm._outside() == null and arm.maxThrust == arm._maxThrust and arm._maxThrust > 0)
		ship.systems = {"SYSTEM_GRINDER": {"name": "SYSTEM_GRINDER", "ref": mouth}}
		for i in range(3): yield(get_tree(), "physics_frame")
		check("switch: and back to a grinder at once", arm.maxThrust == 0.0 and arm._outside() != null)
		ship.systems = {"SYSTEM_EXCAVATOR": {"name": "SYSTEM_EXCAVATOR", "ref": null}}
		check("switch: a system without a usable ref is left to the game", arm._entry() == null)
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	# ---- intake axis / entry point in the target choice
	r = make_arm(0.0, Vector2(60, -20), 0.0, Vector2(1, 1), Vector2(1500, 1500), Vector2(0, 0))
	add_child(r[0]); ship = r[1]; arm = r[2]
	var ib = {}
	for k in {"P": Vector2(160, -300), "Q": Vector2(500, -20), "R1": Vector2(160, -30), "R2": Vector2(160, -200)}:
		var b = RigidBody2D.new(); b.name = k; b.gravity_scale = 0
		b.position = {"P": Vector2(160, -300), "Q": Vector2(500, -20), "R1": Vector2(160, -30), "R2": Vector2(160, -200)}[k]
		r[0].add_child(b); ib[k] = b
	var im = Node2D.new(); r[0].add_child(im); im.set_script(load("res://harness/grinder.gd"))
	var ih = Node2D.new(); ih.name = "Claw Holder"; im.add_child(ih)
	var iw1 = Node2D.new(); iw1.name = "Claw Left"; iw1.position = Vector2(150, 40); ih.add_child(iw1)
	var iw2 = Node2D.new(); iw2.name = "Claw Right"; iw2.position = Vector2(170, 40); ih.add_child(iw2)
	im.grinder1node = iw1; im.grinder2node = iw2
	yield(get_tree(), "physics_frame")
	if hasT:
		check("intake: arm facing forward -> the ship's centreline (P, straight ahead, over Q, off to the side)", _pick(arm, ["Q", "P"]) == ib["P"])
		arm.rotation = PI / 2
		# scored against the line across the side opening (Q is level with it, P straight ahead of the ship)
		var across = _best(["P", "Q"], ib, bal, ship.global_position, Vector2(0, -1).rotated(arm.global_rotation))
		check("intake: arm turned 90 deg (OCP) -> the centerline is the line across the side opening (%s)" % across.name, _pick(arm, ["P", "Q"]) == across)
		arm.feedVelocity = Vector2(-140, -280)
		check("intake: the tilted feedVelocity is not used (%s)" % across.name, _pick(arm, ["P", "Q"]) == across)
		arm.feedVelocity = Vector2()
		arm.rotation = 0.0
		check("entry: no grinder -> the ship's centre", arm._intakePosition() == ship.global_position)
		ship.systems = {"SYSTEM_GRINDER": {"name": "SYSTEM_GRINDER", "ref": im}}
		check("entry: grinder rotors midpoint (160, 40) -> R1 closer", _pick(arm, ["R2", "R1"]) == ib["R1"])
		ship.systems = {"SYSTEM_EXCAVATOR": {"name": "SYSTEM_EXCAVATOR", "ref": im}}
		check("entry: excavator claws midpoint -> R1 closer", _pick(arm, ["R2", "R1"]) == ib["R1"])
	r[0].queue_free()
	yield(get_tree(), "physics_frame")

	yield(vp(), "completed")

# Not in the claude.ai unit tests: the real Eagle-Prospector-VP rig (harness/rig.gd), and the inertia moving.gd uses.
func vp():
	var rig = Rig.build(self, {"shipMass": shipMass})
	yield(frames(2), "completed")
	var arm = rig.arm
	if hasP:
		check("VP: a chunk's radius is read from the game's mineral scene", abs(arm._radius - VP.CHUNK_RADIUS) < 0.001, arm._radius)
		var rotors = Rig.rotorCentres()
		var tip = rig.ship.to_global((rotors[0] + rotors[1]) / 2.0)
		var entry = arm._entry()
		var redLine = VP.ROTOR_RADIUS + _const(arm, "CHUNK_RADIUS_CLEARENCE_FACTOR") * VP.CHUNK_RADIUS
		check("VP: opening tip to tip between the real rotors, red line ahead of them", entry != null and entry[0].distance_to(tip) < 0.01 and abs(entry[1] - abs(rotors[0].x)) < 0.01 and abs(entry[2] - redLine) < 0.01, str(entry))
	rig.field.queue_free()
	yield(frames(1), "completed")

	var dock = Rig.build(self, {"shipMass": shipMass, "systemName": "SYSTEM_DOCKING_ARM"})
	yield(frames(1), "completed")
	check("VP: an arm that is not a salvage arm keeps the game's area, and the pull mod leaves it alone", dock.arm.areaDockArea.get_child(0).shape is RectangleShape2D and (not hasP or not dock.arm._active))
	dock.field.queue_free()
	yield(frames(1), "completed")

	var body = RigidBody2D.new()
	body.gravity_scale = 0
	body.mass = VP.SHIP_MASS
	var hull = CollisionPolygon2D.new()
	hull.polygon = PoolVector2Array(VP.HULL)
	body.add_child(hull)
	add_child(body)
	yield(frames(2), "completed")
	var expected = VP.SHIP_INERTIA_PER_TONNE * VP.SHIP_MASS
	check("VP: the hull's turning inertia in this Godot matches the one moving.gd uses", abs(body.inertia - expected) / expected < 0.005, "%.1f, expected %.1f" % [body.inertia, expected])
	body.queue_free()
	yield(frames(1), "completed")

func _pick(arm, names):
	arm.queue.clear()
	for n in names:
		arm.addToQueue(arm.get_parent().get_parent().get_node(n))
	return arm.switchTarget()

func _shape(b):
	var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = 10; b.add_child(c)

# A mod's constant, read from the arm's script chain (`default` when no loaded mod declares it). The checks take every
# value of the mods' constants from here, so another value of a constant still passes.
func _const(obj, cname, default = null):
	var sc = obj.get_script()
	while sc != null:
		var m = sc.get_script_constant_map()
		if cname in m:
			return m[cname]
		sc = sc.get_base_script()
	return default

# The body among `names` that TargetSelection should pick by its weighted score with BALANCE `bal`: the distance to
# the intake centerline (through the entry point `entry` along `axis`, the direction the arm faces) and the distance
# to `entry`. Null for none.
func _best(names, bodies, bal, entry, axis = Vector2(0, -1)):
	var best = null
	var bs = INF
	for n in names:
		var p = bodies[n].global_position
		var sc = bal * abs((p - entry).cross(axis)) + (1.0 - bal) * p.distance_to(entry)
		if sc < bs:
			bs = sc
			best = bodies[n]
	return best

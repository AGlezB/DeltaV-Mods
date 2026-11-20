extends Node

# Records what happens to every chunk of a bench run and turns it into the run's metrics (one CSV row), a per-chunk
# log and pictures: the whole run seen from above, and snapshots around the ship.
# A chunk is in range while it is within the drones' reach of a plant (the plant's DronePickupArea). It escaped when
# it was in range at some point and ends the run out of range (or despawned) without having been taken into the hold.

const SLOW_SPEED = 20.0 # px/s: a chunk this slow relative to the ship counts as stopped
const GATHER_RADIUS = 300.0 # px around the haul drones' gathering spot where a chunk counts as waiting there
const SAMPLE_EVERY = 0.5 # s between samples (trails, averages)
const TRAIL_SCALE = 20.0 # px of the field per pixel of the run's picture
const SNAP_SCALE = 10.0 # px of the field per pixel of a snapshot
const SNAP_SIZE = 1000 # pixels a side
const SNAP_TIMES = [60, 180, 300, 420, 540] # s

var ship
var field
var plants = []
var geologist
var prices = {}
var colors = {}
var t = 0.0
var frontalHits = 0 # roids a PDW had queued that hit the ship in its direction of travel: the course was too fast
var gapHits = 0 # roids no PDW ever queued that hit it: out of every turret's reach, ignored
var turrets = []
var rocksCaptured = 0
var fellOut = 0 # times a chunk left the hold after being taken in
var outDir = ""
var label = ""

var _chunks = {} # chunk -> record
var _order = []
var _rocks = [] # [position, class] where roids were added
var _sampleClock = 0.0
var _samples = 0
var _inRangeSum = 0
var _inRangeMax = 0
var _gatherSum = 0
var _plantState = {} # plant -> {target, inFlight}
var _switches = 0
var _switchesLost = 0
var _dronesLost = 0.0
var _snaps = []
var _shipPath = []

func setup(shipNode, fieldNode, plantNodes: Array, turretNodes: Array, geologistNode, dir: String, runLabel: String):
	ship = shipNode
	turrets = turretNodes
	field = fieldNode
	plants = plantNodes
	geologist = geologistNode
	outDir = dir
	label = runLabel
	prices = field.mineralPrices
	colors = CurrentGame.specificMineralColors
	field.connect("chunkSpawned", self, "_onChunk")
	field.connect("rockAdded", self, "_onRock")
	ship.connect("captured", self, "_onCaptured")
	ship.connect("released", self, "_onReleased")
	ship.connect("rockHit", self, "_onRockHit")
	for p in plants:
		_plantState[p] = {"target": null, "inFlight": 0.0}

func _onRock(rock):
	_rocks.append([rock.global_position, rock.asteroidClass])

func _onChunk(chunk, parent):
	var ore = 0.0
	var value = 0.0
	var comp = chunk.getComposition()
	for m in comp:
		if m != chunk.filler:
			ore += comp[m] * 1000
			value += comp[m] * 1000 * prices.get(m, 0.0)
	var r = {
		"id": _order.size(), "mineral": chunk.mineral, "scene": chunk.get_meta("benchScene").get_file() if chunk.has_meta("benchScene") else "", "mass": chunk.mass,
		"ore": ore, "value": value, "born": t, "bornPos": chunk.global_position,
		"parentClass": parent.asteroidClass if parent != null and is_instance_valid(parent) else -1,
		"bornSpeed": -1.0, "inRange": false, "everInRange": false, "firstInRange": -1.0, "exits": 0,
		"lastExit": -1.0, "exitPos": Vector2(), "slowed": -1.0, "targeted": -1.0, "acquisitions": 0, "identified": -1.0,
		"captured": -1.0, "capturePos": Vector2(), "captureLocal": Vector2(), "releasePos": Vector2(), "fellOut": 0, "gone": -1.0, "trail": [chunk.global_position], "node": chunk,
	}
	_chunks[chunk] = r
	_order.append(r)
	chunk.connect("tree_exiting", self, "_onGone", [chunk])

func _onGone(chunk):
	if chunk in _chunks:
		var r = _chunks[chunk]
		if r.captured < 0:
			r.gone = t
			if r.inRange:
				r.inRange = false
				r.exits += 1
				r.lastExit = t
				r.exitPos = chunk.global_position
		r.node = null
		_chunks.erase(chunk)

func _onCaptured(body):
	if body in _chunks:
		var r = _chunks[body]
		if r.captured < 0:
			r.captured = t
			r.capturePos = body.global_position
			r.captureLocal = ship.to_local(body.global_position)
	elif not body.is_in_group("pickable"):
		rocksCaptured += 1

# A chunk that leaves the hold again (the excavator stays open) is no longer counted as taken in.
func _onReleased(body):
	if body in _chunks and _chunks[body].captured >= 0:
		_chunks[body].captured = -1.0
		_chunks[body].fellOut += 1
		_chunks[body].releasePos = ship.to_local(body.global_position)
		fellOut += 1

# A roid that hit the ship ahead counts only if a PDW had it in its queue (PDT.gd queue: it entered the turret's rock
# area); one no turret could have picked is a gap hit.
func _onRockHit(body):
	if body.has_meta("benchQueued"):
		frontalHits += 1
	else:
		gapHits += 1

func _reach(plant) -> float:
	var shape = plant.get_node_or_null("DronePickupArea/Shape")
	if shape != null and shape.shape is CircleShape2D:
		return min(shape.shape.radius, plant.laserRange)
	return plant.laserRange

func _physics_process(delta):
	t += delta
	for tr in turrets:
		if is_instance_valid(tr):
			for body in tr.queue:
				if is_instance_valid(body) and not body.has_meta("benchQueued"):
					body.set_meta("benchQueued", true)
	for p in plants:
		if not is_instance_valid(p):
			continue
		var st = _plantState[p]
		var current = p.drones.targetNode
		if current != st.target:
			if st.target != null and is_instance_valid(st.target) and current != null:
				_switches += 1
				if st.inFlight > 0:
					_switchesLost += 1
					_dronesLost += st.inFlight
			if current != null and current in _chunks:
				var r = _chunks[current]
				r.acquisitions += 1
				if r.targeted < 0:
					r.targeted = t
			st.target = current
		st.inFlight = _inFlight(p.drones)
	for chunk in _chunks:
		var r = _chunks[chunk]
		if r.captured >= 0:
			continue
		if r.bornSpeed < 0 and t - r.born >= 2.0 / 60.0:
			r.bornSpeed = (chunk.linear_velocity - ship.linear_velocity).length()
		if r.identified < 0 and ship.identifiedObjects.has(hash(chunk)):
			r.identified = t
		var near = false
		for p in plants:
			if is_instance_valid(p) and p.global_position.distance_to(chunk.global_position) <= _reach(p):
				near = true
				break
		if near and not r.inRange:
			r.everInRange = true
			if r.firstInRange < 0:
				r.firstInRange = t
		elif r.inRange and not near:
			r.exits += 1
			r.lastExit = t
			r.exitPos = chunk.global_position
		r.inRange = near
		if near and r.slowed < 0 and (chunk.linear_velocity - ship.linear_velocity).length() < SLOW_SPEED:
			r.slowed = t
	_sampleClock += delta
	if _sampleClock >= SAMPLE_EVERY:
		_sampleClock -= SAMPLE_EVERY
		_sample()
	for s in SNAP_TIMES:
		if not s in _snaps and t >= s:
			_snaps.append(s)
			_snapshot(s)

func _inFlight(drones) -> float:
	var n = 0.0
	for e in drones.queue:
		n += e.x * e.y
	for e in drones.stopQueue:
		n += e.x * e.y
	return n

func gatherSpot() -> Vector2:
	if plants.empty() or not is_instance_valid(plants[0]) or ship.excavator == null:
		return ship.global_position
	var p = plants[0]
	return ship.excavator.global_position + p.haulGatherSpot.rotated(ship.excavator.global_rotation)

func _sample():
	_samples += 1
	_shipPath.append(ship.global_position)
	var inRange = 0
	var waiting = 0
	var spot = gatherSpot()
	for chunk in _chunks:
		var r = _chunks[chunk]
		if r.captured >= 0:
			continue
		r.trail.append(chunk.global_position)
		if r.inRange:
			inRange += 1
		if chunk.global_position.distance_to(spot) <= GATHER_RADIUS:
			waiting += 1
	_inRangeSum += inRange
	_inRangeMax = max(_inRangeMax, inRange)
	_gatherSum += waiting

static func _median(values: Array) -> float:
	if values.empty():
		return -1.0
	values.sort()
	return values[values.size() / 2]

static func _p90(values: Array) -> float:
	if values.empty():
		return -1.0
	values.sort()
	return values[int(floor((values.size() - 1) * 0.9))]

func header() -> Array:
	var h = ["label", "valid", "frontal_hits", "gap_hits", "chunks", "chunks_in_range", "captured", "captured_value", "escaped",
		"escaped_value", "in_range_end", "in_range_end_value", "never_in_range", "be_chunks", "be_captured",
		"be_escaped", "be_escaped_value", "capture_s_median", "capture_s_p90", "stopped_not_captured",
		"stopped_to_capture_s_median", "waiting_at_gather_mean", "in_range_mean", "in_range_max", "drone_kg",
		"target_switches", "switches_with_drones_in_flight", "drones_lost", "rocks_captured", "fell_out_of_hold", "hold_chunks_end",
		"born_speed_mean", "born_speed_max", "identified", "escaped_unidentified", "be_escaped_unidentified"]
	for m in field.traceMinerals:
		h.append("captured_" + m)
		h.append("escaped_" + m)
	return h

func row() -> Dictionary:
	var out = {"label": label, "valid": 1 if frontalHits == 0 else 0, "frontal_hits": frontalHits, "gap_hits": gapHits}
	var n = 0
	var inRangeEver = 0
	var captured = 0
	var capturedValue = 0.0
	var escaped = 0
	var escapedValue = 0.0
	var inRangeEnd = 0
	var inRangeEndValue = 0.0
	var never = 0
	var be = 0
	var beCaptured = 0
	var beEscaped = 0
	var beEscapedValue = 0.0
	var captureTimes = []
	var stoppedNotCaptured = 0
	var stoppedToCapture = []
	var bornSpeeds = []
	var identified = 0
	var escapedUnidentified = 0
	var beEscapedUnidentified = 0
	var perMineral = {}
	for m in field.traceMinerals:
		perMineral[m] = [0, 0]
	for r in _order:
		n += 1
		if r.bornSpeed >= 0:
			bornSpeeds.append(r.bornSpeed / 10.0)
		var isBe = r.mineral == "Be"
		if isBe:
			be += 1
		if r.identified >= 0:
			identified += 1
		if r.everInRange or r.captured >= 0:
			inRangeEver += 1
		if r.captured >= 0:
			captured += 1
			capturedValue += r.value
			captureTimes.append(r.captured - r.born)
			if r.slowed >= 0:
				stoppedToCapture.append(r.captured - r.slowed)
			if isBe:
				beCaptured += 1
			if r.mineral in perMineral:
				perMineral[r.mineral][0] += 1
		elif r.inRange and r.gone < 0:
			inRangeEnd += 1
			inRangeEndValue += r.value
			if r.slowed >= 0:
				stoppedNotCaptured += 1
		elif r.everInRange:
			escaped += 1
			escapedValue += r.value
			if r.slowed >= 0:
				stoppedNotCaptured += 1
			if r.identified < 0:
				escapedUnidentified += 1
			if isBe:
				beEscaped += 1
				beEscapedValue += r.value
				if r.identified < 0:
					beEscapedUnidentified += 1
			if r.mineral in perMineral:
				perMineral[r.mineral][1] += 1
		else:
			never += 1
	var bornMean = 0.0
	var bornMax = 0.0
	for s in bornSpeeds:
		bornMean += s
		bornMax = max(bornMax, s)
	if not bornSpeeds.empty():
		bornMean /= bornSpeeds.size()
	out.chunks = n
	out.chunks_in_range = inRangeEver
	out.captured = captured
	out.captured_value = round(capturedValue)
	out.escaped = escaped
	out.escaped_value = round(escapedValue)
	out.in_range_end = inRangeEnd
	out.in_range_end_value = round(inRangeEndValue)
	out.never_in_range = never
	out.be_chunks = be
	out.be_captured = beCaptured
	out.be_escaped = beEscaped
	out.be_escaped_value = round(beEscapedValue)
	out.capture_s_median = stepify(_median(captureTimes), 0.01)
	out.capture_s_p90 = stepify(_p90(captureTimes), 0.01)
	out.stopped_not_captured = stoppedNotCaptured
	out.stopped_to_capture_s_median = stepify(_median(stoppedToCapture), 0.01)
	out.waiting_at_gather_mean = stepify(float(_gatherSum) / max(1, _samples), 0.01)
	out.in_range_mean = stepify(float(_inRangeSum) / max(1, _samples), 0.01)
	out.in_range_max = _inRangeMax
	out.drone_kg = stepify(ship.dronePartsUsed, 0.1)
	out.target_switches = _switches
	out.switches_with_drones_in_flight = _switchesLost
	out.drones_lost = round(_dronesLost)
	out.rocks_captured = rocksCaptured
	out.fell_out_of_hold = fellOut
	out.hold_chunks_end = ship.cargo.size()
	out.born_speed_mean = stepify(bornMean, 0.01)
	out.born_speed_max = stepify(bornMax, 0.01)
	out.identified = identified
	out.escaped_unidentified = escapedUnidentified
	out.be_escaped_unidentified = beEscapedUnidentified
	for m in perMineral:
		out["captured_" + m] = perMineral[m][0]
		out["escaped_" + m] = perMineral[m][1]
	return out

func writeChunks(path: String):
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		return
	f.store_line("id,mineral,scene,mass_t,ore_kg,value,born_s,parent_class,born_speed_mps,first_in_range_s,exits,last_exit_s,stopped_s,targeted_s,acquisitions,captured_s,gone_s,capture_x,capture_y,fell_out,release_x,release_y")
	for r in _order:
		f.store_line("%d,%s,%s,%.3f,%.1f,%.0f,%.2f,%d,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%d,%.2f,%.2f,%.0f,%.0f,%d,%.0f,%.0f" % [r.id, r.mineral,
			r.scene, r.mass, r.ore, r.value, r.born, r.parentClass, r.bornSpeed / 10.0, r.firstInRange, r.exits,
			r.lastExit, r.slowed, r.targeted, r.acquisitions, r.captured, r.gone, r.captureLocal.x, r.captureLocal.y,
			r.fellOut, r.releasePos.x, r.releasePos.y])
	f.close()

# The whole run from above: the ship's path, where roids were added, each chunk's trail in its mineral's colour, a
# green dot where it was taken in, a red cross where it left the drones' reach for good.
func drawRun(path: String):
	var minX = -10000.0
	var maxX = 10000.0
	var minY = INF
	var maxY = -INF
	for p in _shipPath:
		minY = min(minY, p.y)
		maxY = max(maxY, p.y)
	if _shipPath.empty():
		return
	minY -= 8000
	maxY += 6000
	var w = int((maxX - minX) / TRAIL_SCALE)
	var h = int((maxY - minY) / TRAIL_SCALE)
	var img = Image.new()
	img.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.05, 0.08))
	img.lock()
	for rk in _rocks:
		_disc(img, _px(rk[0], minX, minY, TRAIL_SCALE), max(1, 4 - rk[1]), Color(0.35, 0.35, 0.35))
	for i in range(_shipPath.size() - 1):
		_line(img, _px(_shipPath[i], minX, minY, TRAIL_SCALE), _px(_shipPath[i + 1], minX, minY, TRAIL_SCALE), Color(0.9, 0.9, 0.9))
	for r in _order:
		var c = colors.get(r.mineral, Color(1, 1, 0))
		for i in range(r.trail.size() - 1):
			_line(img, _px(r.trail[i], minX, minY, TRAIL_SCALE), _px(r.trail[i + 1], minX, minY, TRAIL_SCALE), c * 0.8)
		if r.captured >= 0:
			_disc(img, _px(r.capturePos, minX, minY, TRAIL_SCALE), 2, Color(0.2, 1, 0.2))
		elif r.everInRange and (not r.inRange or r.gone >= 0):
			var p = _px(r.exitPos, minX, minY, TRAIL_SCALE)
			_line(img, p + Vector2(-3, -3), p + Vector2(3, 3), Color(1, 0.15, 0.15))
			_line(img, p + Vector2(-3, 3), p + Vector2(3, -3), Color(1, 0.15, 0.15))
	img.unlock()
	img.save_png(path)

# Around the ship at one moment: the drones' reach, the ship, every chunk in its mineral's colour with its velocity
# relative to the ship (2 s), the plants' current targets ringed in white, roids in grey.
func _snapshot(seconds):
	if outDir == "":
		return
	var img = Image.new()
	img.create(SNAP_SIZE, SNAP_SIZE, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.05, 0.08))
	img.lock()
	var centre = ship.global_position
	var half = SNAP_SIZE * SNAP_SCALE / 2
	var o = centre - Vector2(half, half)
	for p in plants:
		if is_instance_valid(p):
			_circle(img, _px(p.global_position, o.x, o.y, SNAP_SCALE), _reach(p) / SNAP_SCALE, Color(0.2, 0.3, 0.5))
	for kid in field.get_children():
		if kid is RigidBody2D and kid.is_in_group("asteroid") and kid.global_position.distance_to(centre) < half * 1.5:
			var rr = kid.estimatedRadius / SNAP_SCALE if "estimatedRadius" in kid else 3
			_circle(img, _px(kid.global_position, o.x, o.y, SNAP_SCALE), max(2, rr), Color(0.45, 0.45, 0.45))
	_rect(img, _px(centre + Vector2(-158, -436), o.x, o.y, SNAP_SCALE), _px(centre + Vector2(158, 362), o.x, o.y, SNAP_SCALE), Color(0.8, 0.8, 0.8))
	var targets = []
	for p in plants:
		if is_instance_valid(p) and p.drones.targetNode != null:
			targets.append(p.drones.targetNode)
	for chunk in _chunks:
		var r = _chunks[chunk]
		if r.captured >= 0 or not is_instance_valid(chunk):
			continue
		var p = _px(chunk.global_position, o.x, o.y, SNAP_SCALE)
		var c = colors.get(r.mineral, Color(1, 1, 0))
		_line(img, p, p + (chunk.linear_velocity - ship.linear_velocity) * 2.0 / SNAP_SCALE, c * 0.7)
		_disc(img, p, 3, c)
		if chunk in targets:
			_circle(img, p, 7, Color(1, 1, 1))
	img.unlock()
	img.save_png(outDir.plus_file("%s-snap-%03d.png" % [label, seconds]))

func _px(p: Vector2, ox: float, oy: float, scale: float) -> Vector2:
	return Vector2((p.x - ox) / scale, (p.y - oy) / scale)

func _plot(img: Image, x: int, y: int, c: Color):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _line(img: Image, a: Vector2, b: Vector2, c: Color):
	var n = int(max(abs(b.x - a.x), abs(b.y - a.y)))
	if n > 4000:
		return
	for i in range(n + 1):
		var p = a.linear_interpolate(b, float(i) / max(1, n))
		_plot(img, int(p.x), int(p.y), c)

func _disc(img: Image, p: Vector2, r: float, c: Color):
	for y in range(int(-r), int(r) + 1):
		for x in range(int(-r), int(r) + 1):
			if x * x + y * y <= r * r:
				_plot(img, int(p.x) + x, int(p.y) + y, c)

func _circle(img: Image, p: Vector2, r: float, c: Color):
	var n = int(max(8, r * 6.3))
	for i in range(n):
		var a = TAU * i / n
		_plot(img, int(p.x + cos(a) * r), int(p.y + sin(a) * r), c)

func _rect(img: Image, a: Vector2, b: Vector2, c: Color):
	_line(img, a, Vector2(b.x, a.y), c)
	_line(img, Vector2(b.x, a.y), b, c)
	_line(img, b, Vector2(a.x, b.y), c)
	_line(img, Vector2(a.x, b.y), a, c)

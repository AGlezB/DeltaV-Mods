extends Node2D

# The bench's asteroid field: the parent of the ship and of every rock and chunk, as the game's AsteroidField is
# ("space" in drone-plant.gd). It does what AsteroidSpawner.gd does for the bodies the bench needs:
# - spawnAsteroidByClass and kill, which asteroid.gd calls when a rock fractures, ported line by line (the scene
#   table, the intersection test, the scale, splitsTo, the velocities), with the vein (TheRing.gd getVeinAt) drawn
#   from the game's vein map;
# - roids at the density of one spot of the game's ring map in every 1 km cell (TheRing.gd getTargetDensityAt,
#   ceil(target / cellDensity) per class, as spawnProperThings fills a cell), placed up front from the run's seed and
#   added once the ship comes within ACTIVATION_RADIUS, so every setting meets the same roids (the game adds them from
#   maxSpawnRadius out, 3 km; nearer is enough, as a rock beyond 1.2 km of the ship breaks into nothing, and it saves
#   simulating hundreds of drifting rocks);
# - despawning bodies beyond getLoadDespawnRadius.
# Values come from the game's own files at run time (AsteroidSpawner.gd, TheRing.gd, AsteroidField.tscn, the scenes).
# Every rock and chunk gets its own seed, and the global RNG is re-seeded from it right before the game's scripts
# draw for it (asteroid.gd and mineral.gd in _ready, a fracture's shards), so what a rock turns into doesn't depend on
# what else drew random numbers first.

const ACTIVATION_RADIUS = 15000.0 # px

signal chunkSpawned(chunk, parent)
signal rockAdded(rock)

var scenes # the scene reader (scenes.gd)
var gameRoot = ""
var ship = null
# One chaos for the whole field (TheRing.gd getChaosAt): the drift and spin of the roids placed, and the grade shift of
# the chunks (spawnAsteroidByClass, adjustedClass). 0.5 leaves grades uniform and loses no chunk to a negative shift.
var chaos = 0.5
var spot = Vector2() # the ring map pixel the course starts from (the veins along it), and whose density every cell gets
var densitySpot = null # another pixel whose density every cell gets instead, when set
var origin = Vector2() # global ring coordinates of the field's (0, 0)

var objectClass = [] # per class: an Array of scene paths, or for the minerals a Dictionary by mineral
var estimatedRadiusByClass = []
var adjustedClass = 5
var chaosLinear = 500.0
var chaosAngular = 50.0
var cellSize = 10000.0
var cellDensity = 9
var initialMargin = 1.0
var asteroidIntersectionTest = 3
var maxSpawnRadius = 30000.0
var despawnRadiusAsteroids = 40000.0
var despawnRadiusAsteroidsLoad = 20000.0
var throttle = {}
var maxDensity = []
var smallScale = 1024.0
var pixelToKm = 10000.0
var traceMinerals = []
var mineralPrices = {}

var mapImage: Image
var veinImage: Image
var _packed = {}
var _pending = [] # roids placed up front, not added yet: {pos, path, oc, s, rot, v, av, seed}
var _sources = {} # fracturing rocks -> shards made so far
var _frame = 0

func setup(reader, root: String, ringSpot = null):
	scenes = reader
	gameRoot = root
	_readSpawner()
	mapImage = _image("ring/ring-map.png")
	veinImage = _image("ring/ring-veins.png")
	spot = ringSpot if ringSpot != null else densestSpot()
	origin = spot * pixelToKm + Vector2(pixelToKm, pixelToKm) / 2

func _readSpawner():
	var spawner = _text("AsteroidSpawner.gd")
	var ring = _text("TheRing.gd")
	estimatedRadiusByClass = _scriptValue(spawner, "estimatedRadiusByClass")
	adjustedClass = _scriptValue(spawner, "adjustedClass")
	chaosLinear = float(_scriptValue(spawner, "chaosLinear"))
	chaosAngular = float(_scriptValue(spawner, "chaosAngular"))
	cellSize = float(_scriptValue(spawner, "cellSize"))
	cellDensity = int(_scriptValue(spawner, "cellDensity"))
	initialMargin = float(_scriptValue(spawner, "initialMargin"))
	maxSpawnRadius = float(_scriptValue(spawner, "maxSpawnRadius"))
	despawnRadiusAsteroids = float(_scriptValue(spawner, "despawnRadiusAsteroids"))
	despawnRadiusAsteroidsLoad = float(_scriptValue(spawner, "despawnRadiusAsteroidsLoad"))
	for k in ["throttleActiveObjectsStart", "throttleActiveObjects", "throttleCollisionPairsStart", "throttleCollisionPairs", "throttleAdjust"]:
		throttle[k] = float(_scriptValue(spawner, k))
	asteroidIntersectionTest = int(_scriptValue(spawner, "asteroidIntersectionTest"))
	var fieldScene = scenes.tree("res://AsteroidField.tscn")
	asteroidIntersectionTest = int(scenes.value(fieldScene, "asteroidIntersectionTest", asteroidIntersectionTest))
	maxDensity = _scriptValue(ring, "maxDensity")
	smallScale = float(_scriptValue(ring, "smallScale"))
	pixelToKm = float(_scriptValue(ring, "pixelToKm"))
	var game = _text("CurrentGame.gd")
	traceMinerals = _scriptValue(game, "traceMinerals")
	mineralPrices = _scriptValue(game, "mineralPrices")
	# The scene table (AsteroidSpawner.gd objectClass): class-1x to class-5x, then the chunks by mineral, in order.
	var table = spawner.substr(spawner.find("objectClass"))
	var re = RegEx.new()
	re.compile("res://asteroids/(class-(\\d)\\d*|mineral-(\\w+)-\\d+)\\.tscn")
	var classes = [[], [], [], [], [], {}]
	for m in re.search_all(table):
		var path = "res://asteroids/%s.tscn" % m.get_string(1)
		if m.get_string(2) != "":
			var oc = int(m.get_string(2)) - 1
			if oc >= 0 and oc < 5:
				classes[oc].append(path)
		else:
			var mineral = m.get_string(3).capitalize()
			if mineral.length() > 2:
				mineral = mineral.substr(0, 1).to_upper() + mineral.substr(1).to_lower()
			for tm in traceMinerals:
				if tm.to_lower() == m.get_string(3).to_lower():
					mineral = tm
			if not mineral in classes[5]:
				classes[5][mineral] = []
			classes[5][mineral].append(path)
	objectClass = classes

func _text(rel: String) -> String:
	var f = File.new()
	if f.open(gameRoot.plus_file(rel), File.READ) != OK:
		printerr("BENCH ERROR: cannot read %s" % rel)
		return ""
	var t = f.get_as_text()
	f.close()
	return t

# The value a game script gives a constant or variable ("const x = ...", "var x = ...", "export var x = ...").
func _scriptValue(text: String, name: String):
	var re = RegEx.new()
	re.compile("(?m)^(?:export(?:\\s*\\([^)]*\\))?\\s+)?(?:const|var)\\s+" + name + "\\s*(?::[^=]*)?=\\s*(.+?);?\\s*$")
	var m = re.search(text)
	if m == null:
		printerr("BENCH ERROR: no %s in a game script" % name)
		return null
	var raw = m.get_string(1)
	var start = m.get_start(1)
	while not scenes._balanced(raw):
		var nl = text.find("\n", start + raw.length())
		var next = text.find("\n", nl + 1)
		if nl < 0:
			break
		raw = text.substr(start, (next if next >= 0 else text.length()) - start)
	var v = str2var(raw)
	if v == null:
		var e = Expression.new()
		if e.parse(raw) == OK:
			v = e.execute()
	return v

func _image(rel: String) -> Image:
	var img = Image.new()
	if img.load(gameRoot.plus_file(rel)) != OK:
		printerr("BENCH ERROR: cannot load %s" % rel)
	return img

# TheRing.gd getPixelAt, for global ring coordinates (px).
func pixelAt(pos: Vector2) -> Color:
	var size = mapImage.get_size()
	var x = int(clamp(floor(pos.x / pixelToKm), 0, size.x - 1))
	var sy = int(size.y)
	var y = ((int(floor(pos.y / pixelToKm)) % sy) + sy) % sy
	var x1 = int(clamp(x + 1, 0, size.x - 1))
	var y1 = (y + 1) % sy
	if x <= 0:
		return Color(0, 0, 0, 0)
	mapImage.lock()
	var p00 = mapImage.get_pixel(x, y)
	var p10 = mapImage.get_pixel(x1, y)
	var p11 = mapImage.get_pixel(x1, y1)
	var p01 = mapImage.get_pixel(x, y1)
	mapImage.unlock()
	var cx = (pos.x - floor(pos.x / pixelToKm) * pixelToKm) / pixelToKm
	var cy = (pos.y - floor(pos.y / pixelToKm) * pixelToKm) / pixelToKm
	var pu = p00 * (1 - cx) + p10 * cx
	var pd = p01 * (1 - cx) + p11 * cx
	return pu * (1 - cy) + pd * cy

# TheRing.gd getTargetDensityAt for a pixel (no other ships around).
func targetDensity(pixel: Color) -> Array:
	var totalMass = pixel.b * smallScale
	var sizeBias = pixel.g
	var density = [0, 0, 0, 0, 0]
	var classes = float(density.size() - 1)
	for ac in [0, 1, 2, 3, 4]:
		var mc = pow(5 - ac, 2)
		var cfv = float(classes - ac) / classes
		var d = 1 - abs(cfv - sizeBias)
		var pick = totalMass * pow(d, 3)
		density[ac] = int(clamp(int(pick / mc), 0, maxDensity[ac]))
		totalMass = max(0, totalMass - density[ac] * mc)
	return density

func rocksPerCell(pixel: Color) -> Array:
	var out = []
	for t in targetDensity(pixel):
		out.append(int(ceil(float(t) / cellDensity)))
	return out

# The pixel of the ring map whose cells hold the most roids.
func densestSpot() -> Vector2:
	var size = mapImage.get_size()
	var best = Vector2(1, 0)
	var bestCount = -1
	mapImage.lock()
	for y in range(size.y):
		for x in range(1, size.x):
			var count = 0
			for n in rocksPerCell(mapImage.get_pixel(x, y)):
				count += n
			if count > bestCount:
				bestCount = count
				best = Vector2(x, y)
	mapImage.unlock()
	return best

# Among the spots holding at least DENSE_SHARE of the densest spot's roids, the one whose course (from its centre, the
# way the ship flies, courseLength px) crosses the most Be in the vein maps: the share of the vein weights getVeinAt
# draws from, averaged along the course.
const DENSE_SHARE = 0.9
const COURSE_SAMPLES = 60

func beRichSpot(courseLength: float) -> Vector2:
	var size = mapImage.get_size()
	var counts = {}
	var most = 0
	mapImage.lock()
	for y in range(size.y):
		for x in range(1, size.x):
			var count = 0
			for n in rocksPerCell(mapImage.get_pixel(x, y)):
				count += n
			if count > 0:
				counts[Vector2(x, y)] = count
				most = max(most, count)
	mapImage.unlock()
	var best = Vector2(1, 0)
	var bestShare = -1.0
	for p in counts:
		if counts[p] < DENSE_SHARE * most:
			continue
		var share = courseShare(p, courseLength, "Be")
		if share > bestShare:
			bestShare = share
			best = p
	return best

# A point of a spot's course (from its centre, the way the ship flies): sample i of COURSE_SAMPLES.
func coursePoint(p: Vector2, courseLength: float, i: int) -> Vector2:
	return p * pixelToKm + Vector2(pixelToKm, pixelToKm) / 2 + Vector2(0, -courseLength * i / (COURSE_SAMPLES - 1))

# A mineral's share of the vein weights (veinShare), averaged along a spot's course.
func courseShare(p: Vector2, courseLength: float, mineral: String) -> float:
	var share = 0.0
	for i in range(COURSE_SAMPLES):
		share += veinShare(coursePoint(p, courseLength, i), mineral)
	return share / COURSE_SAMPLES

# The chaos (TheRing.gd getChaosAt: the map's red channel) averaged along a spot's course.
func courseChaos(p: Vector2, courseLength: float) -> float:
	var sum = 0.0
	for i in range(COURSE_SAMPLES):
		sum += pixelAt(coursePoint(p, courseLength, i)).r
	return sum / COURSE_SAMPLES

# Among the spots whose course averages at least HIGH_CHAOS, the one whose course crosses the most Be. The runs take
# its veins and its course's chaos, and the densest spot's density (densitySpot).
const HIGH_CHAOS = 0.7 # about the top 1 % of the ring map's spots (game 1.92.5)

func beChaosSpot(courseLength: float) -> Vector2:
	# First a quick mean of the map pixels the course crosses, then the exact course chaos for the spots near enough.
	var size = mapImage.get_size()
	var rows = int(ceil(courseLength / pixelToKm))
	var candidates = []
	mapImage.lock()
	for y in range(size.y):
		for x in range(1, size.x - 1):
			if mapImage.get_pixel(x, y).r < HIGH_CHAOS - 0.1:
				continue
			var sum = 0.0
			for k in range(rows + 1):
				var yk = posmod(y - k, int(size.y))
				sum += mapImage.get_pixel(x, yk).r + mapImage.get_pixel(x + 1, yk).r
			if sum / (2 * (rows + 1)) >= HIGH_CHAOS - 0.05:
				candidates.append(Vector2(x, y))
	mapImage.unlock()
	var best = Vector2(1, 0)
	var bestShare = -1.0
	for p in candidates:
		if courseChaos(p, courseLength) < HIGH_CHAOS:
			continue
		var share = courseShare(p, courseLength, "Be")
		if share > bestShare:
			bestShare = share
			best = p
	return best

# A mineral's share of the weights getVeinAt draws a chunk's mineral from, at global ring coordinates.
func veinShare(pos: Vector2, mineral: String) -> float:
	var p1 = _veinPixel(pos / 1861.0)
	var p2 = _veinPixel(pos / -2531.0)
	var values = [p1.r, p1.g, p1.b, p1.a, p2.r, p2.b, p2.g, p2.a]
	var total = 0.0
	var mine = 0.0
	for n in range(traceMinerals.size()):
		var w = pow(values[n] / pow(mineralPrices.get(traceMinerals[n], 1), 0.2), 4)
		total += w
		if traceMinerals[n] == mineral:
			mine = w
	return mine / total if total > 0 else 0.0

func spotPixel() -> Color:
	mapImage.lock()
	var p = mapImage.get_pixel(int(spot.x), int(spot.y))
	mapImage.unlock()
	return p

# The pixel whose density every cell gets.
func densityPixel() -> Color:
	var at = densitySpot if densitySpot != null else spot
	mapImage.lock()
	var p = mapImage.get_pixel(int(at.x), int(at.y))
	mapImage.unlock()
	return p

# TheRing.gd getVeinAt (global ring coordinates); draws from the global RNG.
func veinAt(pos: Vector2) -> String:
	var p1 = _veinPixel(pos / 1861.0)
	var p2 = _veinPixel(pos / -2531.0)
	var values = [p1.r, p1.g, p1.b, p1.a, p2.r, p2.b, p2.g, p2.a]
	var total = 0
	for n in range(traceMinerals.size()):
		var tm = traceMinerals[n]
		values[n] = pow(values[n] / pow(mineralPrices.get(tm, 1), 0.2), 4)
		total += values[n]
	var rnd = randf() * total
	var nr = 0
	for n in values:
		rnd -= n
		if rnd < 0:
			return traceMinerals[nr]
		nr += 1
	return traceMinerals[0]

func _veinPixel(pos: Vector2) -> Color:
	var size = veinImage.get_size()
	var x = posmod(int(floor(pos.x)), int(size.x))
	var y = posmod(int(floor(pos.y)), int(size.y))
	var x1 = posmod(int(floor(pos.x)) + 1, int(size.x))
	var y1 = posmod(int(floor(pos.y)) + 1, int(size.y))
	veinImage.lock()
	var p00 = veinImage.get_pixel(x, y)
	var p10 = veinImage.get_pixel(x1, y)
	var p11 = veinImage.get_pixel(x1, y1)
	var p01 = veinImage.get_pixel(x, y1)
	veinImage.unlock()
	var cx = fposmod(pos.x, 1)
	var cy = fposmod(pos.y, 1)
	var pu = p00.linear_interpolate(p10, cx)
	var pd = p01.linear_interpolate(p11, cx)
	return pu.linear_interpolate(pd, cy)

func globalCoords(local: Vector2) -> Vector2:
	return origin + local

func packed(path: String) -> PackedScene:
	if not path in _packed:
		var d = scenes.tree(path)
		var node = scenes.build(d)
		scenes._own(node, node)
		var p = PackedScene.new()
		p.pack(node)
		node.free()
		_packed[path] = p
	return _packed[path]

# Places the roids of every 1 km cell the rectangle touches, from the seed: positions, scenes, scales, spins and
# drifts as spawnProperThings and spawnAsteroidByClass draw them, without overlaps between them, and none within
# clearRadius of the ship's start.
func placeRoids(rect: Rect2, rng: RandomNumberGenerator, clearRadius: float):
	var counts = rocksPerCell(densityPixel())
	var placed = []
	var c0 = (rect.position / cellSize).floor()
	var c1 = (rect.end / cellSize).ceil()
	for cy in range(int(c0.y), int(c1.y)):
		for cx in range(int(c0.x), int(c1.x)):
			for oc in range(5):
				for n in range(counts[oc]):
					var list = objectClass[oc]
					for attempt in range(20):
						var pos = Vector2(cx + rng.randf(), cy + rng.randf()) * cellSize
						var path = list[rng.randi() % list.size()]
						var s = rng.randf_range(0.75, 1.25)
						var radius = _sceneRadius(path) * s
						if pos.length() < clearRadius + radius:
							continue
						var free = true
						for p in placed:
							if p.pos.distance_to(pos) < p.r + radius + initialMargin:
								free = false
								break
						if not free:
							continue
						var mass = _sceneMass(path) * s
						var drift = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
						var r = {"pos": pos, "path": path, "oc": oc, "s": s, "r": radius,
							"rot": rng.randf_range(0, PI * 2),
							"av": rng.randf_range(-1, 1) * chaos * chaos * chaosAngular / clamp(mass, 0, 100),
							"v": drift * chaos * chaos * chaosLinear / clamp(mass, 0, 100),
							"seed": rng.randi()}
						placed.append(r)
						break
	_pending = placed

var _masses = {}
func _sceneMass(path: String) -> float:
	if not path in _masses:
		_masses[path] = float(scenes.value(scenes.tree(path), "mass", 1.0))
	return _masses[path]

var _radii = {}
func _sceneRadius(path: String) -> float:
	if path in _radii:
		return _radii[path]
	var d = scenes.tree(path)
	var col = scenes.child(d, "Collision")
	var r = 10.0
	if col != null:
		var shape = scenes.value(col, "shape")
		if shape is CircleShape2D:
			r = shape.radius
		elif shape is RectangleShape2D:
			r = shape.extents.length()
		var poly = scenes.value(col, "polygon")
		if poly is PoolVector2Array:
			r = 0.0
			for p in poly:
				r = max(r, p.length())
		var sc = scenes.value(col, "scale", Vector2(1, 1))
		r *= max(sc.x, sc.y)
	_radii[path] = r
	return r

func pendingCount() -> int:
	return _pending.size()

func _physics_process(_delta):
	_frame += 1
	if ship == null:
		return
	if _frame % 10 == 1:
		_activate()
	if _frame % 30 == 0:
		_despawn()

# Adds the placed roids the ship has come within ACTIVATION_RADIUS of.
func _activate():
	var keep = []
	for r in _pending:
		if r.pos.distance_to(ship.global_position) <= ACTIVATION_RADIUS:
			seed(r.seed)
			var rock = packed(r.path).instance()
			rock.position = r.pos
			rock.rotation = r.rot
			if rock.has_method("setScale"):
				rock.setScale(r.s)
			rock.set_meta("benchSeed", r.seed)
			rock.set_meta("benchScene", r.path)
			add_child(rock)
			rock.asteroidClass = r.oc
			if rock.estimatedRadius == 0:
				rock.estimatedRadius = estimatedRadiusByClass[r.oc] * r.s
			if "splitsTo" in rock:
				rock.splitsTo = int(clamp(5 - r.oc, 1, 4))
			rock.angular_velocity = r.av
			rock.linear_velocity = r.v
			_watch(rock)
			emit_signal("rockAdded", rock)
		else:
			keep.append(r)
	_pending = keep

func _watch(rock):
	if rock.has_signal("destroyed") and not rock.is_connected("destroyed", self, "_onFracture"):
		rock.connect("destroyed", self, "_onFracture", [rock])

func _onFracture(rock):
	_sources[rock] = 0

# AsteroidSpawner.gd getThrottleFactor and getLoadDespawnRadius.
func despawnRadius() -> float:
	var taa = clamp(range_lerp(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), throttle.throttleActiveObjectsStart, throttle.throttleActiveObjects, 1, 0), 0, 1)
	var tcp = clamp(range_lerp(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS), throttle.throttleCollisionPairsStart, throttle.throttleCollisionPairs, 1, 0), 0, 1)
	var tf = min(taa, tcp) + throttle.throttleAdjust
	return range_lerp(sqrt(clamp(tf, 0.05, 1)), 1, 0, despawnRadiusAsteroids, despawnRadiusAsteroidsLoad)

func _despawn():
	var r = despawnRadius()
	for kid in get_children():
		if kid == ship or not kid is RigidBody2D:
			continue
		if "inCargoHold" in kid and kid.inCargoHold:
			continue
		if kid.global_position.distance_to(ship.global_position) > r:
			kill(kid, true)

# AsteroidSpawner.gd isInDespawnCell / isInDespawnRadius for a rock.
func _inDespawnRadius(pos: Vector2) -> bool:
	if ship == null:
		return false
	var dist = despawnRadius()
	for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var corner = ((pos / cellSize).floor() + offset) * cellSize
		if corner.distance_to(ship.global_position) > dist:
			return true
	return false

# AsteroidSpawner.gd spawnAsteroidByClass, as asteroid.gd calls it for each shard of a fracture.
func spawnAsteroidByClass(oc, spot, chaosHere, spawnPointRandomness = 0.0, initialLinearVelocity = Vector2(0, 0), initialAngularVelocity = 0.0, tries = 1, spawned = true):
	if oc >= objectClass.size() or oc < 0:
		return null
	var source = null
	for rock in _sources.keys():
		if is_instance_valid(rock) and rock.position == spot:
			source = rock
			break
	var shardSeed = 0
	if source != null:
		_sources[source] += 1
		shardSeed = hash([source.get_meta("benchSeed") if source.has_meta("benchSeed") else 0, _sources[source]])
		seed(shardSeed)
	var pos = spot + Vector2(randf() - 0.5, randf() - 0.5).normalized() * spawnPointRandomness
	if _inDespawnRadius(pos):
		return null
	var gp = globalCoords(spot)
	var vein = veinAt(gp)
	var obs = objectClass[oc] if objectClass[oc] is Array else objectClass[oc].get(vein, [])
	var l = obs.size()
	if l == 0:
		return null
	var spaceState = get_world_2d().direct_space_state
	while tries > 0:
		var nr = randi() % l
		if oc == adjustedClass:
			var adj = (chaos - 0.5) * l
			var iadj = int(adj)
			nr = int(clamp(nr + iadj, -1, l - 1))
			if nr < 0:
				return {}
		var instance = packed(obs[nr]).instance()
		instance.set_meta("benchScene", obs[nr])
		instance.position = pos
		instance.rotation = rand_range(0, PI * 2)
		var s = 1.0
		if instance.has_method("setScale"):
			s = rand_range(0.75, 1.25)
			instance.setScale(s)
		var free = false
		var collider = instance.getCollider()
		if collider != null:
			var shape
			if collider.has_method("get_shape"):
				shape = collider.get_shape()
			else:
				shape = ConvexPolygonShape2D.new()
				shape.points = collider.polygon
			var params = Physics2DShapeQueryParameters.new()
			params.set_shape(shape)
			params.margin = initialMargin
			instance.scale = Vector2(s, s)
			params.transform = instance.transform
			instance.scale = Vector2(1, 1)
			params.collision_layer = asteroidIntersectionTest
			params.collide_with_areas = true
			params.collide_with_bodies = true
			if not spaceState.intersect_shape(params, 1):
				free = true
				instance.set_meta("benchSeed", hash([shardSeed, "shard"]))
				add_child(instance)
		if free:
			instance.asteroidClass = oc
			if instance.estimatedRadius == 0:
				instance.estimatedRadius = estimatedRadiusByClass[oc] * s
			if "splitsTo" in instance:
				instance.splitsTo = int(clamp(5 - oc, 1, 4))
			instance.angular_velocity = (rand_range(-1, 1)) * chaosHere * chaosHere * chaosAngular / clamp(instance.mass, 0, 100)
			instance.linear_velocity = initialLinearVelocity + Vector2(rand_range(-1, 1), rand_range(-1, 1)).normalized() * chaosHere * chaosHere * chaosLinear / clamp(instance.mass, 0, 100)
			if instance.is_in_group("pickable"):
				emit_signal("chunkSpawned", instance, source)
			else:
				_watch(instance)
				emit_signal("rockAdded", instance)
			return instance
		instance.free()
		tries -= 1
	return null

func kill(me, despawn = false):
	if me.has_method("_onDespawn"):
		me._onDespawn()
	_sources.erase(me)
	Tool.remove(me)

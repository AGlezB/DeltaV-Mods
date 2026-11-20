extends Reference

# Reads the game's own scenes (.tscn text) from the decompiled game at run time and rebuilds them as nodes with their
# real values, so the bench never carries a copy of a game value. A scene is parsed into descriptors (one per node,
# with the raw text of its properties and the scene each property came from), instanced scenes are merged in with the
# overrides the outer scene gives them, and a chosen placeholder (instance_placeholder) is expanded the same way.
# Building turns descriptors into nodes: the node's class, its script when the bench project has that game script
# (the others are left out), and its properties. Resources: shapes and particle materials are rebuilt from their
# values, physics materials load the game's own file (bench.ps1 copies every .phymat), materials become empty
# ShaderMaterials (scripts set shader parameters on them), a PackedScene property is rebuilt and packed, and
# textures, sounds and the rest are left out. Signal connections are made where both ends exist.

var gameRoot = "" # the decompiled game's folder
var scripts = {} # res:// path of each game script the bench project has
var _parsed = {}
var _subCache = {}

func _init(root: String, gameScripts: Array):
	gameRoot = root
	for s in gameScripts:
		scripts[s] = true

# The scene at a res:// path: {"path", "ext": {id: {path, type}}, "sub": {id: {type, props}}, "nodes": [...],
# "connections": [...]}. A node: {name, type, parent, instance, placeholder, groups, props}; props hold raw text.
func parse(path: String) -> Dictionary:
	if path in _parsed:
		return _parsed[path]
	var file = File.new()
	var full = gameRoot.plus_file(path.trim_prefix("res://"))
	if file.open(full, File.READ) != OK:
		printerr("BENCH ERROR: cannot read %s" % full)
		return {}
	var lines = file.get_as_text().split("\n")
	file.close()
	var scene = {"path": path, "ext": {}, "sub": {}, "nodes": [], "connections": []}
	var current = null
	var i = 0
	while i < lines.size():
		var line = lines[i].strip_edges(false, true)
		i += 1
		if line == "":
			continue
		if line.begins_with("["):
			var header = _header(line)
			var attrs = header.attrs
			current = null
			match header.tag:
				"ext_resource":
					scene.ext[attrs.get("id", "")] = {"path": attrs.get("path", ""), "type": attrs.get("type", "")}
				"sub_resource":
					var sub = {"type": attrs.get("type", ""), "props": {}}
					scene.sub[attrs.get("id", "")] = sub
					current = sub.props
				"node":
					var node = {
						"name": attrs.get("name", ""),
						"type": attrs.get("type", ""),
						"parent": attrs.get("parent", null),
						"instance": _refId(attrs.get("instance", "")),
						"placeholder": attrs.get("instance_placeholder", ""),
						"groups": attrs.get("groups", ""),
						"props": {},
					}
					scene.nodes.append(node)
					current = node.props
				"connection":
					scene.connections.append(attrs)
		elif current != null:
			var eq = line.find(" = ")
			if eq < 0:
				continue
			var key = line.substr(0, eq)
			var value = line.substr(eq + 3)
			while not _balanced(value) and i < lines.size():
				value += "\n" + lines[i]
				i += 1
			current[key] = value
	_parsed[path] = scene
	return scene

# The descriptor tree of a scene: {name, type, props: {key: [scene, raw]}, children, placeholder, groups,
# connections}, with instanced scenes merged in and the outer scene's overrides applied.
func tree(path: String) -> Dictionary:
	var scene = parse(path)
	if scene.empty():
		return {}
	var byPath = {}
	var root = null
	for n in scene.nodes:
		var nodePath = "."
		if n.parent != null:
			nodePath = n.name if n.parent == "." else "%s/%s" % [n.parent, n.name]
		if nodePath in byPath and n.type == "" and n.instance == "" and n.placeholder == "":
			_merge(byPath[nodePath], scene, n.props)
			continue
		var d
		if n.instance != "":
			d = tree(scene.ext[n.instance].path)
			d.name = n.name
		else:
			d = {"name": n.name, "type": n.type, "props": {}, "children": [], "placeholder": n.placeholder,
				"groups": [], "connections": []}
		_merge(d, scene, n.props)
		if n.groups != "":
			var g = str2var(n.groups)
			if g is Array:
				d.groups += g
		_register(byPath, nodePath, d)
		if n.parent == null:
			root = d
		else:
			var parentPath = "." if n.parent == "." else n.parent
			if parentPath in byPath:
				byPath[parentPath].children.append(d)
	if root != null:
		for c in scene.connections:
			root.connections.append({"from": c.get("from", ""), "to": c.get("to", ""),
				"signal": c.get("signal", ""), "method": c.get("method", "")})
	return root

# The descriptor of a placeholder made real: the scene it names, with the placeholder's own properties on top.
func expand(placeholder: Dictionary) -> Dictionary:
	if placeholder.placeholder == "":
		return placeholder
	var d = tree(placeholder.placeholder)
	d.name = placeholder.name
	for key in placeholder.props:
		d.props[key] = placeholder.props[key]
	return d

func child(d: Dictionary, path: String):
	var current = d
	for part in path.split("/"):
		var found = null
		for c in current.children:
			if c.name == part:
				found = c
				break
		if found == null:
			return null
		current = found
	return current

# A property's value: Variant, or null when it is a resource the bench leaves out.
func value(d: Dictionary, key: String, default = null):
	if not key in d.props:
		return default
	var v = resolve(d.props[key][0], d.props[key][1])
	return default if v == null else v

func build(d: Dictionary) -> Node:
	var type = d.type if d.type != "" else "Node2D"
	var node = ClassDB.instance(type)
	if node == null:
		printerr("BENCH ERROR: no class %s for %s" % [type, d.name])
		node = Node2D.new()
	node.name = d.name
	if "script" in d.props:
		var s = value(d, "script")
		if s is Script:
			node.set_script(s)
	for key in d.props:
		if key == "script" or key == "__meta__":
			continue
		var v = value(d, key)
		if key == "process_material" and v is ShaderMaterial:
			v = ParticlesMaterial.new() # a binary .material the bench cannot read: particles need their own kind
		if v != null:
			node.set(key, v)
	for g in d.groups:
		node.add_to_group(g, true)
	for c in d.children:
		if c.placeholder != "":
			continue
		node.add_child(build(c))
	return node

# Connects the scene's signals, and those of every scene merged into it, once the nodes exist.
func connectSignals(d: Dictionary, node: Node):
	for c in d.connections:
		var from = node if c.from == "." else node.get_node_or_null(c.from)
		var to = node if c.to == "." else node.get_node_or_null(c.to)
		if from != null and to != null and to.has_method(c.method) and from.has_signal(c.signal):
			if not from.is_connected(c.signal, to, c.method):
				from.connect(c.signal, to, c.method)
	for c in d.children:
		if c.placeholder == "":
			var n = node.get_node_or_null(c.name)
			if n != null:
				connectSignals(c, n)

func resolve(scene: Dictionary, raw: String):
	var ext = _refId(raw) if raw.begins_with("ExtResource") else ""
	if ext != "":
		return _ext(scene, scene.ext.get(ext, {}))
	var sub = _refId(raw) if raw.begins_with("SubResource") else ""
	if sub != "":
		return _sub(scene, sub)
	if "ExtResource" in raw or "SubResource" in raw:
		return null
	return str2var(raw)

func _ext(scene: Dictionary, ext: Dictionary):
	var path = ext.get("path", "")
	match ext.get("type", ""):
		"Script":
			return load(path) if path in scripts else null
		"PhysicsMaterial":
			return load(path) if ResourceLoader.exists(path) else null
		"Material", "ShaderMaterial", "CanvasItemMaterial":
			return ShaderMaterial.new()
		"PackedScene":
			var d = tree(path)
			var node = build(d)
			_own(node, node)
			var packed = PackedScene.new()
			packed.pack(node)
			node.free()
			return packed
	return null

func _sub(scene: Dictionary, id: String):
	var key = "%s#%s" % [scene.path, id]
	if key in _subCache:
		return _subCache[key]
	var sub = scene.sub.get(id, {})
	var res = null
	match sub.get("type", ""):
		"CircleShape2D", "RectangleShape2D", "CapsuleShape2D", "ConvexPolygonShape2D", "ConcavePolygonShape2D", \
		"SegmentShape2D", "RayShape2D", "LineShape2D", "ParticlesMaterial", "PhysicsMaterial":
			res = ClassDB.instance(sub.type)
			for k in sub.props:
				var v = resolve(scene, sub.props[k])
				if v != null:
					res.set(k, v)
		"ShaderMaterial", "CanvasItemMaterial":
			res = ShaderMaterial.new()
	_subCache[key] = res
	return res

func _own(node: Node, owner: Node):
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)

func _merge(d: Dictionary, scene: Dictionary, props: Dictionary):
	for key in props:
		d.props[key] = [scene, props[key]]

func _register(byPath: Dictionary, path: String, d: Dictionary):
	byPath[path] = d
	for c in d.children:
		_register(byPath, c.name if path == "." else "%s/%s" % [path, c.name], c)

func _refId(raw: String) -> String:
	var open = raw.find("(")
	var close = raw.find(")")
	if open < 0 or close < open:
		return ""
	return raw.substr(open + 1, close - open - 1).strip_edges()

func _balanced(text: String) -> bool:
	var depth = 0
	var quoted = false
	var i = 0
	while i < text.length():
		var ch = text[i]
		if quoted:
			if ch == "\\":
				i += 1
			elif ch == "\"":
				quoted = false
		elif ch == "\"":
			quoted = true
		elif ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth -= 1
		i += 1
	return depth <= 0 and not quoted

# "[tag key=value key=value]" -> {tag, attrs}; quoted values come back without their quotes.
func _header(line: String) -> Dictionary:
	var body = line.substr(1, line.length() - 2)
	var space = body.find(" ")
	var tag = body if space < 0 else body.substr(0, space)
	var attrs = {}
	var i = space + 1 if space >= 0 else body.length()
	while i < body.length():
		while i < body.length() and body[i] == " ":
			i += 1
		var eq = body.find("=", i)
		if eq < 0:
			break
		var key = body.substr(i, eq - i).strip_edges()
		i = eq + 1
		var start = i
		var val = ""
		if i < body.length() and body[i] == "\"":
			i += 1
			while i < body.length() and body[i] != "\"":
				if body[i] == "\\":
					i += 1
				i += 1
			val = body.substr(start + 1, i - start - 1)
			i += 1
		else:
			var depth = 0
			while i < body.length() and not (body[i] == " " and depth == 0):
				if body[i] in "([":
					depth += 1
				elif body[i] in ")]":
					depth -= 1
				i += 1
			val = body.substr(start, i - start)
		attrs[key] = val
	return {"tag": tag, "attrs": attrs}

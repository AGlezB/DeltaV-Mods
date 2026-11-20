extends SceneTree

# Run once by bench.ps1 on the assembled project (--script): writes the stand-ins of the files the game scripts preload
# but the bench has no use for (asteroid.gd's effects and material, massdriver.gd's default bullet), as scenes and
# resources Godot can load. None carries a game value.

func _init():
	_scene("res://sfx/dust-cloud-persistent.tscn", _scripted(Node2D.new(), "res://bench/stubs/dust.gd"))
	var calamity = Particles2D.new()
	calamity.process_material = ParticlesMaterial.new()
	_scene("res://sfx/calamity.tscn", calamity)
	_scene("res://sfx/StoneJet.tscn", _scripted(Node2D.new(), "res://bench/stubs/jet.gd"))
	_scene("res://asteroids/visibility.tscn", VisibilityNotifier2D.new())
	_scene("res://weapons/projectiles/massdriverProjectile.tscn", RigidBody2D.new())
	if ResourceSaver.save("res://asteroids/asteroid.material", ShaderMaterial.new()) != OK:
		printerr("BENCH ERROR: cannot write res://asteroids/asteroid.material")
	quit()

func _scripted(node: Node, path: String) -> Node:
	node.set_script(load(path))
	return node

func _scene(path: String, node: Node):
	Directory.new().make_dir_recursive(path.get_base_dir())
	var packed = PackedScene.new()
	packed.pack(node)
	if ResourceSaver.save(path, packed) != OK:
		printerr("BENCH ERROR: cannot write %s" % path)
	node.free()

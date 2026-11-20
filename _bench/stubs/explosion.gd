extends Particles2D

# Stands in for weapons/projectiles/Explosion.gd on a bullet's Explosion node: only its suicide().

func suicide():
	queue_free()

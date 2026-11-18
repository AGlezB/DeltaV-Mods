extends "res://TheRing.gd"

# The arena's map: what the asteroid field (AsteroidSpawner.gd) asks about the ring around the ship. Built on the
# game's own map (TheRing.gd, extended here as a script of the mod's, not installed as an extension), so the game's
# density formula (getTargetDensityAt) and mineral veins (getVeinAt) run as they are. It is made with new() and never
# added to the tree, so the ring's _ready, events and timers don't run: it shares the station ring's decoded images
# instead (EnceladusMenu/DiveTarget/TheRing), and CombatLayer.gd hands it to the field as its mapInstance.
# What differs from the ring:
# - every pixel's chaos (red) and density (blue) are the dialog's; its size bias (green) stays the ring's;
# - no random events or extra ships: getOddityAt finds none, canEventBeAt allows none;
# - the ships counted for the density's ship allowance are the arena's (the game counts the whole tree, which holds
#   the station's ship).

var chaos = 0.0
var density = 0.0
var field = null # the asteroid field, whose children are the arena's ships

func shareImagesOf(ring):
	image = ring.image
	size = ring.size
	veinImage = ring.veinImage
	veinSize = ring.veinSize

func getPixelAt(pos):
	var pixel = .getPixelAt(pos)
	return Color(chaos, pixel.g, density, pixel.a)

func getOddityAt(pos: Vector2):
	return null

func canEventBeAt(event: String, position: Vector2) -> bool:
	return false

func howManyShips():
	var count = 0
	if field != null and is_instance_valid(field):
		for child in field.get_children():
			if child.is_in_group("ships"):
				count += 1
	return count

# The ring's spot whose chaos and density are closest to the dialog's, out of `samples` random pixels at least
# `margin` pixels from the ring's inner and outer edges (the depth across the map), as global coordinates (a pixel is
# pixelToKm world units). Sampling at random also varies the spot from one run to the next.
func pickSpot(samples: int, margin: int) -> Vector2:
	var best = Vector2(margin + 0.5, 0.5)
	var bestDistance = INF
	var width = int(size.x)
	var height = int(size.y)
	if width <= 2 * margin or height <= 0:
		return best * pixelToKm
	image.lock()
	for i in samples:
		var x = margin + randi() % (width - 2 * margin)
		var y = randi() % height
		var pixel = image.get_pixel(x, y)
		var distance = Vector2(pixel.r - chaos, pixel.b - density).length()
		if distance < bestDistance:
			bestDistance = distance
			best = Vector2(x + 0.5, y + 0.5)
	image.unlock()
	return best * pixelToKm

extends "res://hud/LIDAR.gd"

# How much louder the lidar contact ping is, in dB, on top of the game's own volume. Every 6 dB doubles the
# amplitude; 10 dB sounds about twice as loud. 0 leaves the game's volume. The sound already peaks at full scale, so
# well above 10 the game's compressor on the Master bus squashes the pings and briefly lowers other sounds with them.
const LOUDER_PING_DB = 15.0

const _LOUDER_PING_BUS_SUFFIX = " (LidarLouderPing)"

# The game sets the ping's volume_db before every ping (`_physics_process`), so a gain on the player itself would be
# overwritten. The player is moved instead to a bus of the mod's, which sends to the player's own bus with the gain;
# from there on the sound goes the game's way (its effects, the volume settings). The bus name keeps a second copy
# of the mod from adding the gain twice.
func _ready():
	if soundBleep == null or LOUDER_PING_DB == 0.0 or soundBleep.bus.ends_with(_LOUDER_PING_BUS_SUFFIX):
		return
	soundBleep.bus = _louderPingBus(soundBleep.bus)

# The mod's bus that sends to `original`, added on first use and shared by every lidar on that bus. It goes last:
# a bus can only send to one before it.
func _louderPingBus(original: String) -> String:
	var busName = original + _LOUDER_PING_BUS_SUFFIX
	var index = AudioServer.get_bus_index(busName)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, busName)
		AudioServer.set_bus_send(index, original)
	AudioServer.set_bus_volume_db(index, LOUDER_PING_DB)
	return busName

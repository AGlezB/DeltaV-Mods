# The control scenario's settings (README.md): what bench.ps1 uses unless told otherwise.
@{
	# The PDW types and the spots (densest: the ring map's densest spot; be: the dense spot whose course crosses the
	# most Be; be-chaos, by -Spots only: the high-chaos spot whose course crosses the most Be, with its chaos and the
	# densest spot's density) the runs cover.
	Pdw = @('ONMWG', 'NDPT')
	Spots = @('densest', 'be')
	Seeds = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
	Minutes = 10
	# The geologist's talent (Education) and experience: an average one.
	Geologist = '0.5,0.5'
	# Course speed (m/s), from the Speed calibration with the Tuning below (game 1.92.5). NDPT-4205: no roid hits the
	# ship at any speed tried (up to 25 m/s); 10 m/s gives the chaos of unattended mining, dozens of chunks in range.
	# ONMWG-650: on the K225 its rock areas leave a strip ahead that no turret watches, and hits from roids no turret
	# queued are ignored; from 4 to 6 m/s about one seed in fifteen still gets a hit from a roid that brushed a rock area
	# (those runs are left out), above that one in three.
	Speed = @{
		ONMWG = 6
		NDPT = 10
	}
	# Pdw calibration: the ONMWG-650's beam never overshoots, so every Tuning gives chunks of the same speed and the
	# strongest breaks roids fastest; the NDPT-4205 at its lowest power is the only Tuning whose hits never make a roid
	# skip a class (which throws chunks several times faster).
	Tuning = @{
		ONMWG = @{ TUNE_EMP_POWER = 75; TUNE_EMP_RESONANCE = 90 }
		NDPT = @{ TUNE_MASSDRIVER_POWER = 200 }
	}
}

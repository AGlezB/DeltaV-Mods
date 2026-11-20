# The drone bench

Deterministic simulations of the nanodrones at work, to tune how the MPI Tug drones and MLF Haul Drones pick their
chunks (the DroneAltPriorities mod) from data instead of guesses. It is the repository's own tooling, like `_tests\`
and `_shots\`: it ships in no zip.

The game's own scripts do the work: the drone plants and their launch manager (`weapons/drone-plant.gd`,
`weapons/drones/DroneLaunchManager.gd`), the PDWs (`ships/modules/PDT.gd` with `weapons/emp.gd` or
`weapons/massdriver.gd` and its bullets, `weapons/projectiles/projectile.gd`), the excavator (`ships/Front Bumper.gd`),
the chunks (`asteroids/mineral.gd`) and the roids' damage and fracture (`asteroids/asteroid.gd`). Their scenes, the
ring and vein maps and the values the bench needs are read from the newest decompiled game at run time, and nothing of
the game is committed. Only what the drones don't depend on is the bench's own: the field around the ship (as
`AsteroidSpawner.gd` fills it), the ship flying its course, and the geologist.

## The control scenario

Unattended mining, the hardest case the drones meet: an Antonoff-Titan K225 flies a fixed course with nobody at the
controls, its two PDWs break every roid in their reach, and its two haul drone plants have to bring in the chunks,
dozens of them, of every ore, flying every way, while new ones keep coming. If the drones perform there, they perform
in normal play. Only the drone settings change from one run to another.

- The ship (`scenario.gd`, built from `ships/ATK225.tscn`): its hull; its excavator, the real claws on their pins and
  springs, held open as a double tap holds them; the Rusatom-Antonoff MPU's walls in the hold; the hold's two capture
  areas; THI containers in the middle and back bays (only their hulls, at `POD_SPOTS`: the arm that docks them isn't
  simulated). A chunk or roid taken into the hold leaves the simulation (`removeOnCapture`, `--hold=keep` to keep
  it): the drones' job ends at the intake, and processing it changes nothing for them.
- Its course: an ideal NDCI Autopilot, constant heading and velocity (`ship.gd`, which moves the ship every physics
  frame and pushes what it meets). A run where a roid hits the ship in its direction of travel is invalid: the course
  was too fast for the PDWs.
- PDWs: two ONMWG-650 or two NDPT-4205 (its fire command held) in the middle hardpoints, one type per run, with the
  Tuning `scenario.psd1` gives (chosen by the `Pdw` calibration: the one that makes the slowest chunks, and of those
  the one that breaks a roid fastest; the targeting weights stay at the game's defaults).
- Drones: two MLF Haul Drones plants in the front bays, with the game's default Tuning, and a Geologist-tab filter
  that takes every chunk.
- The field (`field.gd`): every 1 km cell holds the roids of the densest spot of the ring map, as many per class as
  `AsteroidSpawner.gd` puts in a cell, placed from the run's seed before it starts and added once the ship comes within
  `ACTIVATION_RADIUS`; minerals come from the vein maps along the course; bodies beyond the spawner's despawn radius
  are removed. One chaos holds for the whole field: 0.5, which leaves chunk grades uniform, at the `densest` and `be`
  spots; at `be-chaos`, the high-chaos spot whose course crosses the most Be (`field.gd` `beChaosSpot`), its course's
  own chaos, with the densest spot's roids. High chaos makes the roids drift and spin faster (their chunks inherit
  the drift) and shifts chunk grades up (`AsteroidSpawner.gd` `spawnAsteroidByClass`).
- The geologist (`geologist.gd`): an average one (talent and experience at the middle of their range; `-Geologist`
  sets others), identifying chunks as the game's HUD does, so the drones' Geologist-tab filter and anything that
  reads identified ore see what the game would show.
- Energy, ammunition deliveries and drone parts never run out, and nothing takes damage: the bench measures the
  drones, not the ship's budget.

## Running it

PowerShell 7, from the repo root; Godot, the decompiled game and the work folder come from `paths.local.psd1`
(MODDING.md *Folders outside the repo*), or from `-GodotPath`, `-GameSource`, `-DecompiledRoot`, `-WorkDir`.

```powershell
.\_bench\bench.ps1 -Mode Pdw                    # PDW tuning calibration, both types
.\_bench\bench.ps1 -Mode Speed -Speeds 2,3,4,5  # course speed calibration, in vanilla
.\_bench\bench.ps1 -Mode Run                    # the scenario: scenario.psd1's PDW types, spots and seeds, in vanilla
.\_bench\bench.ps1 -Mode Run -Pdw NDPT -Candidate dap.gd -ParamsFile .\_bench\sweeps\phase-a.txt
.\_bench\bench.ps1 -Mode Run -Seeds (31..50) -Mod DroneAltPriorities  # the mod itself, switch on, its defaults
.\_bench\bench.ps1 -Mode SelfTest               # one ONMWG-650 run twice: both must give the same results
.\_bench\analyze.ps1 -Last 2                    # rank the parameter sets of the last two Run folders against vanilla
```

`analyze.ps1` compares each candidate run with vanilla's run of the same spot and seed, which starts from the same
field: the field accounts for most of the spread between runs, so paired differences tell sets apart with a few
seeds where plain averages need many. The folders it reads must include vanilla's runs of those seeds.

`-Pdw`, `-Spots` (`densest`, `be`, `be-chaos`), `-Seeds` and `-Geologist` (talent and experience: `0.1,0.1`)
override `scenario.psd1`; `-Repeat` runs each seed that many times (the runs aren't
exactly repeatable, see *Determinism*); `-Minutes` sets the run length; `-Parallel` how many Godot processes run at
once. `-Candidate <file>` installs a candidate ranking from `candidates\` over the game's `drone-plant.gd` (as a mod's
script extension would), with each parameter set of `-Params` or of `-ParamsFile` (one per line, `#` for comments):
`key=value,key=value` lists, which `candidates\dap.gd` describes. `-Mod <ModName>` (the repo's folder, packaged as a
release zip in the work folder) or `-ModZip <zip>` (a release zip) runs the mod itself instead: its `Code.gd` over the
game's script, as the game's loader installs it, with its switch on and its default settings in the ship's
`hud.config`. The Tuning travels the same way (Windows strips the
quotes JSON would need). The ring map's spots are found once per game version and kept in the work folder.

Results go to `TempDir\bench\results\<time>-<mode>\`: per run a CSV row (`all.csv` gathers them), a per-chunk log
(`<run>-chunks.csv`), a picture of the whole run from above (`<run>-run.png`: the ship's path, where roids were added,
each chunk's trail in its mineral's colour, a green dot where it was taken in, a red cross where it left the drones'
reach for good) and snapshots around the ship (`<run>-snap-<s>.png`: the drones' reach, each chunk with its velocity
relative to the ship, the plants' targets ringed).

## What a run measures

A chunk is in range while it is within a plant's reach (its `DronePickupArea`); it escaped when it was in range at
some point and ends out of range, or despawned, without having been taken in. With `--hold=keep`, a chunk counts as
taken in only while it is in the hold: with the excavator held open, some drift back out of its mouth.

| Column | What |
|---|---|
| `valid`, `frontal_hits` | Whether a roid hit the ship in its direction of travel, and how many times |
| `chunks`, `chunks_in_range`, `never_in_range` | Chunks born, those that were ever in range, those never in range |
| `captured`, `captured_value` | Chunks in the hold at the end, and their ore's value at the game's base prices |
| `escaped`, `escaped_value` | Chunks that escaped, and their ore's value |
| `in_range_end`, `in_range_end_value` | Chunks still in range, not taken in, when the run ends |
| `be_*`, `captured_<mineral>`, `escaped_<mineral>` | The same per mineral, Be apart |
| `capture_s_median`, `capture_s_p90` | Seconds from a chunk's birth to its capture |
| `stopped_not_captured`, `stopped_to_capture_s_median` | Chunks slowed to near the ship's speed (`SLOW_SPEED`) that were never taken in; seconds from slowed to taken in |
| `waiting_at_gather_mean` | Chunks waiting around the haul drones' gathering spot, ahead of the intake, on average |
| `in_range_mean`, `in_range_max` | Chunks in range, on average and at most: the chaos the drones face |
| `drone_kg`, `target_switches`, `switches_with_drones_in_flight`, `drones_lost` | Drone parts spent; target changes; changes that threw away drones in flight, and how many |
| `rocks_captured`, `fell_out_of_hold`, `hold_chunks_end` | Roids that went into the hold; times a chunk left the hold again; bodies in the hold at the end |
| `born_speed_mean`, `born_speed_max` | Chunks' speed relative to the ship just after they are born (m/s) |
| `identified`, `escaped_unidentified`, `be_escaped_unidentified` | Chunks the geologist identified; escaped chunks it never identified, all and Be |

Each row also holds the run's settings: spot, PDW type, seed, speed, minutes, candidate and its parameters, Tuning,
chaos and geologist.

## Determinism

What a run starts from is fixed: a seed fixes the whole field before the run starts, and every rock and chunk gets its
own seed (the global random generator is re-seeded from it right before the game's scripts draw for it, so what a rock
breaks into doesn't depend on what drew random numbers before); the geologist has its own generator; `Tool.gd`'s idle
queue, which runs on a wall-clock budget in the game, drains every frame.

What happens next is not exactly repeatable. Godot 3's physics solves the contacts of bodies that touch at once in an
order that follows their memory addresses, and Windows places a program's memory differently at every launch, so two
launches of the same run can part ways by a ten-thousandth of a pixel at the first frame several bodies touch, and from
there on as chunks collide. Runs with the ONMWG-650 stay identical (its beam is a ray, and the chunks rarely touch);
with the NDPT-4205 they part within seconds (bullets that lose their speed linger and keep touching roids), and the
same seed then ends with roughly a tenth more or fewer chunks in the hold. The game itself behaves the same way. So a
setting is judged on many runs: several seeds, each repeated (`-Repeat`), compared on averages. `-Mode SelfTest` runs
the ONMWG-650 scenario twice and checks that everything up to the physics is the same. `--trace=1` (on `main.gd`)
prints a checksum of every body each frame, and `--trace-from` / `--trace-to` every body's state, to find where two
runs part.

## Files

- `bench.ps1`: assembles the project in `TempDir\bench\project` (this folder's scripts, `_tests\harness\stubs\` and
  `loader.gd`, the game's scripts and physics materials, the game's physics settings), runs the jobs in parallel,
  gathers the results.
- `scenario.psd1`: the scenario's settings (seeds, minutes, speed and Tuning per PDW type).
- `main.gd`: the entry point (modes `run`, `pdw`, `spot`).
- `scenes.gd`: reads the game's scenes and rebuilds them with their real values.
- `field.gd`, `scenario.gd`, `ship.gd`, `slot.gd`, `geologist.gd`, `recorder.gd`: the field, the ship and its
  equipment, the geologist, the metrics and pictures.
- `prepare.gd`, `stubs\`: stand-ins for the effects and resources the game's scripts preload but the bench doesn't use.
- `candidates\dap.gd`: the candidate ranking for DroneAltPriorities, every formula and extra under test behind its
  parameters; `sweeps\`: the parameter sets of each search phase.
- `analyze.ps1`: the parameter sets of Run folders on averages with their standard errors, ranked by the ore value
  they bring in more than vanilla, run against run.

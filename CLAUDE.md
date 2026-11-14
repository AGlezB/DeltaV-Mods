# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mods for **ΔV: Rings of Saturn** (Godot 3 engine, GDScript). Each top-level folder not starting with `_` is one
independent mod and ships as one zip. There is no build system; `_tests\` is a test harness for the two arm mods,
DiveDisableAdrenalineBooster and BootSkipLogos (see *Testing*). The source is in git since 14 Nov 2026; `.gitignore` keeps out every zip, so the
versions released before that exist only as release zips.

## Local paths

| What | Path |
|---|---|
| Game (GOG) | `<GameDir>` (`Delta-V.exe`, `mods\`) |
| Decompiled game 1.91.61 | `<TempDir>\gdre\Delta-V-1.91.61\`, where the `res://` paths the mods extend resolve (`res://ModLoader.gd`, `res://ships/modules/DockingArm.gd`, …) |
| Godot 3.6 (the game's engine) and GDRE Tools 2.7.4 | `<GodotDir>\` |
| Generated and temporary files: zips being packaged, test runs, scratch scripts | `<TempDir>\`, never the repo |

Do not read outside these paths and this folder without asking first.

After a game update, decompile it again with GDRE Tools
(`gdre_tools.exe --recover=<the game's Delta-V.pck>`).

## Testing

`_tests\run.ps1` (PowerShell 7) tests ArmAltPullBehavior, ArmAltTargetSelection, DiveDisableAdrenalineBooster and
BootSkipLogos in a headless Godot 3.6, in a few seconds. It assembles a Godot project in
`<TempDir>\tests\project` from `_tests\`, the game's own `DockingArm.gd`, `Arm.gd`, `CabinLight.gd`, `Boot.gd`,
`Tool.gd` and `gdunzip.gd` (copied from the decompiled source on every run, never committed: they are the game's
code) and a stub mineral scene with the chunk radius read from the game's. It packages each mod as a release
zip and loads the zips as `ModLoader.gd` does, at the same moment (`_tests\harness\loader.gd` is the `ModLoader`
autoload, and loads in its `_init`; the autoloads keep the game's order), so the zip layout is tested too. Logs:
`<TempDir>\tests\logs`.

```powershell
.\_tests\run.ps1                                               # every suite, each with its own mods in the game's order
.\_tests\run.ps1 -Suite moving -AllOrders                      # one suite, every load order
.\_tests\run.ps1 -Matrix                                       # moving with 109.29/330 t ships x 2.8/5 t chunks, every order
.\_tests\run.ps1 -ModZip <a release zip>                       # a release zip in place of the mod's folder
.\_tests\run.ps1 -Suite units -Mods ArmAltPullBehavior         # other mods than the suite's own (@() = none)
```

Call it from a pwsh prompt or `pwsh -Command`: under `pwsh -File`, list arguments such as `-Suite still,moving` are
not parsed as arrays. Exit code 0 = every run passed; a script error fails its run even if every check passed.

The suites are ported from the claude.ai harness (DVModTestHarness 1.0.0; the original was deleted once ported),
except `boot`. `units`, `still` and `moving` load the two arm mods by default, `dive` loads
DiveDisableAdrenalineBooster, `boot` loads BootSkipLogos.

- `units`: the claude.ai unit tests (`arm/main.gd`) nearly verbatim, on synthetic arms around the game's
  `DockingArm.gd`. TargetSelection: area geometry on turned, scaled and offset arms, reach, the strip, the weighted
  pick, keeping the current target, switch off/on, intake and entry point. PullBehavior: where the pull goes (20
  cases: feeding or not, grinder or excavator, a block of hull), the EIME's claws, hand-back hysteresis, closed
  beak, switching ship types, cost, nothing pushed while the game pulls (the 1.3.0 bug). Plus 4 checks on the real
  Eagle-Prospector-VP rig, including the hull inertia `moving` uses. A group whose mod is not loaded runs "control"
  checks of the game alone.
- `still` (9 cases, `arm/real.gd`) and `moving` (16 cases, `arm/real_move.gd`): ArmAltPullBehavior bringing a chunk
  in on a simulated Eagle-Prospector-VP, standing still, held in place, cruising at 10–40 m/s or turning, feeding
  or not; two start points are where the author's in-game logs started. Each case expects the chunk in between the
  rotors without touching them, at the dock slot, or moved straight forward first.
- `dive` (`dive/main.gd`): the player's Adrenaline Booster (the game's `CabinLight.gd`) starts disabled; another
  ship's booster, other cabin-light systems and a light with no ship are untouched; switching it on sticks; it gives
  adrenaline only when enabled. The control check (the game alone starts it enabled) runs on the game's own script,
  the base of the extension, so it needs no separate run.
- `boot` (`suites/boot.gd`): runs with `_tests\harness\boot.tscn` as the main scene (a scene path on Godot's
  command line), whose root has the game's `Boot.gd`, so the engine loads it after the autoloads, as the game loads
  `Boot.tscn`. Checks that this startup scene got the extension, runs the game's own start-up and then asks for the
  title screen; that the first launch (`Settings.firstBoot`) keeps the logos; and, as control, that the game's
  script alone does not leave them. A `Loader` stub records the calls instead of switching scenes.
- `_tests\harness\rig.gd` builds the arm's node tree as the game nests it, with the values in
  `_tests\harness\vp_data.gd`; each cites its scene file and line, so re-check them after a game update. The ship
  is a stub moved by hand (it takes the arm's impulses and torque; inertia from the hull); the rotors don't collide.
- **Baseline** (PullBehavior 1.4.0, TargetSelection 1.2.1; both load orders give the same results, which match the
  claude.ai ones case for case): `units` 114 checks with both mods (64 with PullBehavior alone, 61 with
  TargetSelection alone), `still` 9, `moving` 16, `dive` 8 (DiveDisableAdrenalineBooster 1.0.0), `boot` 5 (BootSkipLogos 1.0.0; 3 control checks with
  `-Mods @()`), all passing. `-Matrix` gives 16, 15, 16, 16 of 16: the miss is
  feeding while turning at 20°/s with a 5 t chunk, the limit in ArmAltPullBehavior's README. PullBehavior 1.3.1,
  which broke in the game, gives 0, 0, 12, 4 of 16. The miss's numbers differ from the claude.ai ones in the third
  decimal only because this ship also takes the arm's torque reaction, as the game's does (the claude.ai stub
  dropped it).

The harness doesn't replace the game, and the crew and ship-list mods have no tests at all. The real check is playing
the game with the mods.

## How the game loads a mod (`res://ModLoader.gd`, an autoload)

- Only with `--enable-mods`. **Every file** in `mods\` is mounted with `load_resource_pack(path, true)`, replacing
  game files at the same path. Two versions of one mod both load, and their `ModMain.gd` runs twice.
- Every zip entry whose file name starts with `modmain` and ends in `.gd` (case-insensitive) is loaded as
  `"res://" + <entry path>`. So the mod folder name, the zip root and every `res://<ModName>/…` path in the code
  must match.
- `ModMain` scripts run sorted by an optional `const MOD_PRIORITY` (default 0, ascending), then by path. Each is
  created with `new(modLoader)` and added as a child of the `ModLoader` node, so its `_ready` runs once the tree is up.
- All of this happens in `ModLoader`'s `_init`, while the engine creates the autoloads and before it loads the main
  scene (`Boot.tscn`). An extension installed from a `ModMain`'s `_init` therefore applies even to the boot scene
  (BootSkipLogos relies on it; the `boot` suite checks it). Autoloads after `ModLoader` in the game's
  `project.godot` (`Settings`, `Loader`, `CurrentGame`, …) are still null at that point.
- `modLoader.installScriptExtension(path)` loads the child script, makes **one throwaway instance** of it (its
  `_init` runs with no scene or ship), then `take_over_path`s the parent's path: everything loaded afterwards gets
  the child. A second mod extending the same game script extends the first mod's extension.
- `Mod.manifest` is not read by the game's loader.
- The loader also has `addTranslationsFromCSV`, `appendNodeInScene` and `saveScene` (unused so far).

## The two ways these mods hook in

1. **Script extension**: ArmAltTargetSelection and ArmAltPullBehavior (`ships/modules/DockingArm.gd`),
   DiveDisableAdrenalineBooster (`ships/CabinLight.gd`), BootSkipLogos (`Boot.gd`), CrewPerfectSort (`enceladus/HireableCrew.gd`,
   `enceladus/CurrentCrewManagement.gd`).
   `ModMain.gd` only calls `installScriptExtension`; the extension `extends "res://<game script>"`. Rules that let
   mods stack on the same script (header of `ArmAltTargetSelection/DockingArmTargetSelection.gd`):
   - Never call the parent's `_ready` or `_physics_process`. Godot 3 runs them at every level of the script chain
     by itself: `_ready` base first (so `ship` etc. are set), `_physics_process` child first.
   - Ordinary functions are not chained: call the parent with `.name()`, and fall through to it where the mod does
     not apply (`if not _targeting: return .switchTarget()`).
   - Gate the change on a condition (`systemName == "SYSTEM_SALVAGE_ARM" and ship != null`,
     `ship.isPlayerControlled()`), so the script's other users are untouched.
   - New members and helpers start with `_`, have unique names, and are listed in the README's *For modders*.
2. **Scene-tree observer**: CrewHighlightJobAndSalary (`enceladus/CrewBio.gd`), ShipHighlightTypeAndPrice and
   ShipSortByTypeAndPrice (`enceladus/SystemBuyUI.gd`). No game script is changed: `ModMain._ready` connects the
   tree's `node_added`, matches `node.get_script().resource_path`, `yield`s a 0.3 s timer (entries fill their labels
   after entering the tree) and re-checks `is_instance_valid`. Entries get re-added (the dealer does it every hour),
   so handlers must be idempotent (`is_connected` checks, cached copies). Shared resources such as the game's fonts
   are duplicated, never edited; rows are hidden with `self_modulate` alpha 0, not `visible`, which the game toggles.

## Cross-mod dependencies

- ArmAltPullBehavior and ArmAltTargetSelection both extend `DockingArm.gd` and both override `_ready` and
  `_physics_process`. `ModMain` scripts run in path order, so the chain is game ← ArmAltPullBehavior ←
  ArmAltTargetSelection. Their member names must stay distinct, and both find the intake the same way (grinder
  rotors / excavator claws via `ship.hasSystem`): change `_entry` and `_intakePosition` together.
- CrewPerfectSort replaces `CrewSortByJobAndSalary` (the first mod, not in this folder) and must not be installed
  with it: both sort the same lists.

## Working rules

- Read values from the game (the ship's nodes and collision shapes, scene files, the arm's own properties), never
  from per-ship tables. A constant is only a fallback for when the game data can't be read (`CHUNK_RADIUS_FALLBACK`).
- Find field names and game behaviour in the decompiled source; don't ship a logging-only build to discover them.
- Every zip handed over gets a new version (0.0.x before the first 1.0). Going to 1.0 means: remove all
  logging, simplify, set 1.0.0, and document the what and why of each feature in the README for other modders.
- The wiki's manifest format is outdated; follow [DVTools](https://github.com/rwqfsfasxc100/DVTools).

## Salvage arm facts (for the ArmAlt mods)

- Only ships with high-stress hardpoints can mount the AR-1500 arm (not the Cothon series, not the Kitsune).
- Intakes: a grinder (two toothed rotors, e.g. the Eagle-Prospector-VP), an excavator (a beak that splits in the
  middle, e.g. the EIME), or the OCP-209's side bay (opens front to back, mounts two arms).
- The arm reaches only ahead of its mount; each section turns about 180°, like a human arm.
- Mineral chunks weigh about 5 t. The ship in the author's in-game tests is over 111 t, and can reach about three
  times that with equipment and load. The arm is normally used while moving at 10–40 m/s, rarely standing still.

## Conventions

- **Godot 3 GDScript, not Godot 4**: `.method()` for parent calls, `yield(…, "timeout")`, `connect("signal", self,
  "method")`, `PoolVector2Array`, `xform`, `extents`, `add_color_override`.
- Tabs; UTF-8 without BOM; LF line endings (`.gitattributes` enforces them whatever `core.autocrlf` says). Script
  extensions use the game's camelCase, the observer mods snake_case: match the file.
- Tunables are commented `const`s at the top of the script, and the README names them as what a user may edit
  inside the zip. When a tunable or the behaviour changes, update the README's text and figures too (e.g. the 45 m
  reach and 4.5 m buffer in ArmAltTargetSelection; the game shows 10 world units as 1 m).
- Game behaviour a mod relies on is cited with the game file and function it comes from (`Game.gd`
  `_respawn_ship`, `hud/SystemList.gd`). Check it in the decompiled source, not from memory.
- **A version bump touches three places**: `[version]` in `Mod.manifest`, the `Version X.Y.Z.` line of the README,
  and the zip name in the README's *Install* step.
- `Mod.manifest`: `id = "aglezb.<ModName>"`, `author = "aglezb"`, a one-line `description`, the `group` tag naming
  the game script the mod touches, `manifest_version = 2.2`.
- README layout: `# <ModName> - ΔV: Rings of Saturn`; version line and summary; *What it does and why* (What / Why
  bullets); *For modders* for script extensions (what is extended, overrides, new members, constants, how it was
  tested); *Install* (three steps, `--enable-mods`); the "Mods are unofficial … Keep a backup of your save." line;
  *About* (made with the help of Claude; GPLv3).

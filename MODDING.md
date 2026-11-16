# ΔV: Rings of Saturn mods - for modders

For those who read or change the code: how the repository is laid out, how the game loads a mod and how these mods
hook in, packaging and releasing, the conventions they follow and the game's terms. The mods themselves, and how to
install them, are in the [README](README.md); the test harness is in [`_tests/README.md`](_tests/README.md).

## The repository

The mods are written in GDScript for the game's engine, Godot 3. Each top-level folder not starting with `_` is one
independent mod and ships as one zip. There is no build system: `package.ps1` builds a mod's release zip (see
*Packaging and releasing*), and `_tests\` is a test harness for most mods (see *Testing*). The source has been in git since 14 Nov 2026, and `.gitignore` keeps out every zip, so the versions
released before that exist only as release zips. Later changes are in the git history and, from 1.0.0 on, in each
mod's `CHANGES.md`.

## Folders outside the repo

The folders outside the repo differ per machine, so they are set in `paths.local.psd1` at the repo root, which is
git-ignored: copy `paths.example.psd1` to it and set yours. These docs name them by its keys: `TempDir\gdre` means
the `gdre` folder under `TempDir`. `_tests\run.ps1` and `package.ps1` read the file, and in PowerShell
`$paths = Import-PowerShellDataFile .\paths.local.psd1` (from the repo root) gives `$paths.GameDir` and the others.
Never write their values into a committed file.

| Key or path | What |
|---|---|
| `GameDir` | The game (`Delta-V.exe`, `mods\`) |
| `TempDir\gdre\Delta-V-<version>\` | The decompiled game, one folder per game version (1.91.61 so far) |
| `GodotDir` | Godot 3.6 (the game's engine) and GDRE Tools 2.7.4 |
| `TempDir` | Generated and temporary files: zips being packaged, test runs, scratch scripts; never the repo |

The decompiled game is where the `res://` paths the mods extend resolve (`res://ModLoader.gd`,
`res://ships/modules/DockingArm.gd`, …). **Always read and test against the newest version there.** After a game
update, decompile it next to the older versions:
`gdre_tools.exe --recover="<GameDir>\Delta-V.pck" --output="<TempDir>\gdre\Delta-V-<version>"`. The harness takes the
newest folder by itself (by version number) and warns when `_tests\harness\vp_data.gd` was checked against another
version (`CHECKED_AGAINST`): then re-check the values it cites and update that constant.

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
  the child. A second mod extending the same game script extends the first mod's extension. The throwaway instance
  is never freed, and it is what keeps the child script alive: freed, the script goes too and later loads get the
  game's script back (tried in the harness).
- `Mod.manifest` is not read by the game's loader.
- The loader also has `addTranslationsFromCSV`, `appendNodeInScene` and `saveScene` (unused so far; the harness's
  loader offers `addTranslationsFromCSV` too). **`addTranslationsFromCSV` reads nothing from a mod's zip**: a file in
  a zip reports its end before the first read (`eof_reached()` is true right after `open`, false after one `get_8()`),
  and `get_csv_line` checks for the end before reading (found in the harness's Godot 3.6). A mod's texts go in a
  `i18n/<locale>.po` loaded with `TranslationServer.add_translation(load(...))`, as the game loads its own `.po` files
  (LidarLouderPing).

## The two ways these mods hook in

1. **Script extension**: ArmAltTargetSelection and ArmAltPullBehavior (`ships/modules/DockingArm.gd`),
   DiveDisableAdrenalineBooster (`ships/CabinLight.gd`), BootSkipLogos (`Boot.gd`), LidarLouderPing (`hud/LIDAR.gd`),
   CrewPerfectSort (`enceladus/HireableCrew.gd`, `enceladus/CurrentCrewManagement.gd`), CrewCheapHireNotifier
   (`enceladus/EnceladusMenu.gd`; it also adds its settings screen to the station's right-hand screens, the children
   of `enceladus/HidingMarginContainer.gd`, copying the Tuning screen's frame and behaving like the game's screens;
   and `enceladus/HireableCrew.gd`, the Hire screen), GeologyByMass (`hud/Hud.gd`; it also adds its tab to the OMS,
   right after the Geologist tab, from `instance()`), ShipCopyPaste (`enceladus/SystemBuyUI.gd`, the Fleet screen's
   entries; it prices through the Equipment screen's items), DiveSkipTransit (`Game.gd`, the ring scene's cutscenes;
   `ships/ship-ctrl.gd`, astrogation; `enceladus/Enceladus.gd`, the station's fade-in and launch sequence; and
   `enceladus/EnceladusMenu.gd`, where Shift+Click on the dive entry opens its settings screen, as
   CrewCheapHireNotifier's Crew entry does). `ModMain.gd` only calls
   `installScriptExtension("res://<ModName>/Code.gd")` (CrewPerfectSort: once for each of its two extension files;
   CrewCheapHireNotifier: `Code.gd`, then `HireScreen.gd`; DiveSkipTransit: `Code.gd`, `Station.gd`,
   `StationMenu.gd`, then `Ship.gd`); `Code.gd` `extends "res://<game script>"`. Rules that let mods stack on the same
   script (header of `ArmAltTargetSelection/Code.gd`):
   - Never call the parent's `_ready`, `_process`, `_physics_process` or `_notification`. Godot 3 runs them at every
     level of the script chain by itself: `_ready` base first (so `ship` etc. are set), `_process`,
     `_physics_process` and `_notification` child first. LidarLouderPing overrides `onSetup` (an ordinary function)
     and `_process`.
   - Ordinary functions are not chained: call the parent with `.name()`, and fall through to it where the mod does
     not apply (`if not _targeting: return .switchTarget()`).
   - Gate the change on a condition (`systemName == "SYSTEM_SALVAGE_ARM" and ship != null`,
     `ship.isPlayerControlled()`), so the script's other users are untouched.
   - New members and helpers start with `_`, have unique names, and are listed in the README's *For modders*.
2. **Scene-tree observer**: CrewHighlightJobAndSalary (`enceladus/CrewBio.gd`), ShipHighlightTypeAndPrice and
   ShipSortByTypeAndPrice (`enceladus/SystemBuyUI.gd`). No game script is changed: `ModMain.gd` adds a node with
   `Code.gd` (`add_child(preload("res://<ModName>/Code.gd").new())` in its `_init`), whose `_ready` connects the
   tree's `node_added`, matches `node.get_script().resource_path`, `yield`s a 0.3 s timer (entries fill their labels
   after entering the tree) and re-checks `is_instance_valid`. Entries get re-added (the dealer does it every hour),
   so handlers must be idempotent (`is_connected` checks, cached copies). Shared resources such as the game's fonts
   are duplicated, never edited; rows are hidden with `self_modulate` alpha 0, not `visible`, which the game toggles.
   HudHideLabels (the titles of the `hud/Display-*.tscn` screens) matches a Label's `text` instead of a script, and
   acts at once without the yield: `node_added` runs before any `_ready` of the new subtree, so the LIDAR's title
   (`hud/HardwareLabel.gd`, renamed in `_ready`) still holds its key.

## Cross-mod dependencies

- ArmAltPullBehavior and ArmAltTargetSelection both extend `DockingArm.gd` and both override `_ready` and
  `_physics_process`. `ModMain` scripts run in path order, so the chain is game ← ArmAltPullBehavior ←
  ArmAltTargetSelection. Their member names must stay distinct, and both find the intake the same way (grinder
  rotors / excavator claws via `ship.hasSystem`): change `_entry` and `_intakePosition` together.
- CrewPerfectSort replaces `CrewSortByJobAndSalary` (the first mod, not in this folder) and must not be installed
  with it: both sort the same lists.
- CrewCheapHireNotifier (`HireScreen.gd`) and CrewPerfectSort (`HireableCrewSorted.gd`) both extend `HireableCrew.gd`
  and both override `fillCrew`, each calling the parent's first: by path the chain is game ← CrewCheapHireNotifier ←
  CrewPerfectSort, and CrewPerfectSort only reorders the entries, so the marks stay (both orders tested in `crew`).
  Their member names must stay distinct.
- CrewCheapHireNotifier (`Code.gd`) and DiveSkipTransit (`StationMenu.gd`) both extend `EnceladusMenu.gd`, each
  hooking Shift+Click on its own menu entry (Crew, Launch Ring Dive) to open its settings screen among the station's
  right-hand screens. By path the chain is game ← CrewCheapHireNotifier ← DiveSkipTransit; both override `_ready` and
  `_notification` (the game's script has neither) without calling the parent's. Their member names must stay
  distinct; opening one screen hides the other (`hidefoka`). Loaded together in `skip`.
- ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice find the ship entries by `node.get_script().resource_path`;
  ShipCopyPaste extends that script, and `take_over_path` keeps the path, so they still find them (loaded together in
  `fleet`).

## Packaging and releasing

A mod ships as `<ModName>-<version>.zip`, which holds the whole mod folder (README, `CHANGES.md` and images included)
at its root, with a copy of the repository's `LICENSE` in it: the GPL asks for one with every copy given out.
`package.ps1` (PowerShell 7) builds it in `TempDir`, or in `-OutDir`:

```powershell
.\package.ps1 <ModName>                # builds the zip and prints its path
.\package.ps1 <ModName> -VersionOnly   # prints the version the zip would have
```

The version comes from `[version]` of `Mod.manifest`. The script refuses to overwrite a zip, and refuses a mod whose
`CHANGES.md` doesn't start with that version. It checks that every entry is `<ModName>/…` with forward slashes: the
game needs them for the `res://` paths, and Windows PowerShell 5.1's `Compress-Archive` writes `\` instead, hence
PowerShell 7.

A release gets a new version, picked by semver (see *Conventions*) from the changes since the last release, set in
`[version]` of `<ModName>\Mod.manifest`. From 1.0.0 on, those changes are the `## NEXT` section of
`<ModName>\CHANGES.md`, which is then renamed to that number. Before 1.0.0 there is no `CHANGES.md`, and the git
history is the only record of them. A new mod's first release is its manifest version as it is.

Keep exactly one zip per mod in the game's `mods` folder: the game loads every file there, so two versions of one mod
would both load (see *How the game loads a mod*). The running game keeps every zip in `mods` open, so close it before
replacing one: otherwise the old zip can't be moved out, while the new one can still be moved in.

## Testing

`_tests\run.ps1` (PowerShell 7) tests most of the mods in a headless Godot 3.6, in a few seconds, against the newest
decompiled game; `.\_tests\run.ps1` runs every suite. What each suite checks, the options and the baseline results are
in [`_tests/README.md`](_tests/README.md). The harness doesn't replace the game: the real check is playing the game
with the mods.

## Conventions

- **Godot 3 GDScript, not Godot 4**: `.method()` for parent calls, `yield(…, "timeout")`, `connect("signal", self,
  "method")`, `PoolVector2Array`, `xform`, `extents`, `add_color_override`.
- Tabs; UTF-8 without BOM; LF line endings (`.gitattributes` enforces them whatever `core.autocrlf` says). Script
  extensions use the game's camelCase, the observer mods snake_case: match the file.
- **File names in a mod folder**:
  - `ModMain.gd` only hooks the mod in, and keeps its name (the game runs only zip entries named `modmain*.gd`): a
    script extension calls `installScriptExtension("res://<ModName>/Code.gd")`, an observer adds a node with
    `Code.gd` (see *The two ways these mods hook in*).
  - `Code.gd` is the mod's main code.
  - A second script extension next to `Code.gd` is named for the screen it changes: CrewCheapHireNotifier's
    `HireScreen.gd` (the Hire screen, `enceladus/HireableCrew.gd`), DiveSkipTransit's `Station.gd` (the station,
    `enceladus/Enceladus.gd`), `StationMenu.gd` (the station menu, `enceladus/EnceladusMenu.gd`) and `Ship.gd` (every
    ship, `ships/ship-ctrl.gd`). Code more than one of them uses goes in `Settings.gd`, which they already share:
    CrewCheapHireNotifier's rule (`limitFor` / `isCheapHire`), DiveSkipTransit's static helpers (`playThrough`,
    `chargeDv`, `chargeSeconds`).
  - `SettingsUI.gd` is the mod's settings UI, when it has one.
  - `Settings.gd`, only in a mod with a settings UI, is the settings model `Code.gd` and `SettingsUI.gd` share, built
    like the game's own `Settings` autoload (`res://Settings.gd`: a `cfg` dict of defaults, a `ConfigFile` in
    `user://`, `loadFromFile` / `saveToFile`, a `settingsChanged` signal). A `const` can't hold a value the player
    changes and Godot 3 has no static variables, so one shared instance holds, for each setting:
    - its current value;
    - its description (key, default, type, range or choices, label keys), so each default is declared once, there;
    - the conversion between the units shown and the ones the code uses (10 world units = 1 m, a fraction shown
      as %);
    - clamping of what is loaded, so a settings file edited by hand can't break the code;
    - saving, with a format version (renaming a saved key without a migration is a major version; DiveSkipTransit's
      `loadFromFile` migrates format 2's `skipArrival` and `skipExit` into `skipTransit`);
    - a change signal, so a change applies at once.

    The mod's version is read from the zip's `Mod.manifest`, not repeated. Scripts reach the file through a preload
    constant named for the mod, never `Settings`, which would hide the game's autoload (and stacked extensions break
    on same-named constants). Constants that aren't settings (game paths, fallbacks) stay in `Code.gd`. The first
    mod with settings settles the API.

    The API, as settled by CrewCheapHireNotifier (`extends Reference`):
    - `static func shared()`: the one instance, kept as metadata of the script (`load()` of its own path), which every
      script that preloads the file gets as the same cached resource.
    - `const SETTINGS`: one description per setting, in display order: `label`, `default`, `min`, `max`, `step`,
      `unit`, `shown`, the factor from the stored value to the one shown (a fraction shown as %), and `perJob` where
      the setting holds one value per job (CrewCheapHireNotifier's crew limit), all sharing its default, range and
      step. `label` is a translation key of the mod's `i18n/en.po`. A switch (DiveSkipTransit's skips) has
      `type: "bool"` and only `label` and `default` besides: no range, unit or conversion, and anything that isn't a
      bool gives its default; the screen shows it with the game's Tuning switch. Where a mod's settings mix switches and
      sliders (DiveSkipTransit's transit speed), each has a `type` (`"bool"` or `"float"`), and a slider its `min`,
      `max`, `step`, `unit` and the `format` of the value shown; `group` puts it in one of the screen's groups, and
      `dimmedWhen` names the switch while which it doesn't apply. `var cfg`: the current values by key
      (a dictionary by job key for a per-job setting), set to the defaults in `_init`. `const FORMAT_VERSION`.
    - `jobs()`: the jobs a per-job setting has values for, the game's `CurrentGame.occupations`; `isPerJob(key)`.
    - `getValue(key, job = null)`; `setValue(key, value, job = null)` clamps and snaps to the step, and only on a change stores
      (`saveToState()`) and emits `settingsChanged`; `job` is only for a per-job setting. `toShown(key, value)` /
      `fromShown(key, shown)`.
    - `loadFromState()` / `saveToState()`: settings kept per save game (CrewCheapHireNotifier's) live in
      `CurrentGame.state.ui` (the game's per-save UI store, `setUiValue` / `getUiValue`, written with the save
      as JSON, so numbers come back as floats) under the mod's id from `Mod.manifest`, so other authors' mods can't
      collide; the entry holds `formatVersion`, `modVersion` and one value per setting (a copy of the dictionary for
      a per-job setting). Loading starts from the defaults and clamps and snaps each saved value. A mod whose settings
      are game-wide (DiveSkipTransit's) uses the `user://` `ConfigFile` above instead, with `loadFromFile` /
      `saveToFile`: a file of its own, `user://<the mod's id>.cfg` (in `filePath`, so a test can point it elsewhere),
      holding one section named by the mod's id with the same entry, written at every change; `shared()` loads it when
      it makes the instance.
    - `modId()`, `modName()`, `modVersion()`: read from `Mod.manifest` (path: the script's folder) with `ConfigFile`.

    `SettingsUI.gd` builds the screen from `SETTINGS` through `toShown`, with the game's own UI parts, and writes back
    with `setValue(key, fromShown(key, shown), job)`; `Code.gd` loads the save's values when its scene is built (the
    station is rebuilt after every load and new game) and listens to `settingsChanged`.
  - A mod without a settings UI has no `Settings.gd`, and no constants file either: that would only add a prefix to
    every use.
  - Settings that belong to a ship system go in the game's Tuning screen instead (`registerSubsystem` from the
    system's `onSetup`; LidarLouderPing). The game draws them, keeps them per ship with its tuning (saved with the
    game) and signals a change (`tuningChanged`), so the mod has no stored value, saving or signal of its own. With
    one or two, their default, range and step are constants in `Code.gd`, read through a clamping helper. With more,
    or spread over several game systems, they split into `Settings.gd` (the descriptions and a clamped read from a
    ship; no shared instance) and `TuningUI.gd` (the registration, called from `Code.gd`'s `onSetup`).
  - Settings that change what a game system's own settings already decide follow that system's pattern
    (GeologyByMass): they live in that system's config, next to the game's, under the mod's id from
    `Mod.manifest`, changed in place as the game changes its own, so the game saves, loads and carries them. Then
    `Settings.gd` has one instance per system, made by `Code.gd` (no `shared()`, no `loadFrom…` / `saveTo…`, no
    signal when the game re-reads by itself): the descriptions as constants, getters that never write and give the
    defaults where nothing is stored (clamped, snapped to the step), setters that write only a change, an entry with
    `formatVersion` and `modVersion`, and `modId()` / `modName()` / `modVersion()`. GeologyByMass: the HUD's
    `mineralConfig` (the ship's `hud.config`), next to the Geologist tab's settings.
  - `i18n/<locale>.po` (`i18n/en.po`, …), in a subfolder named as the game's own `i18n/`: the mod's texts in that
    language, loaded by `ModMain.gd` (see *How the game loads a mod*). English is Godot's fallback language, so
    `en.po` covers every language until it gets its own file.
  - CrewPerfectSort, with two extensions and no single main file, keeps its file names for now.
- Tunables are commented `const`s at the top of `Code.gd`, and the README names them as what a user may edit inside
  the zip. In a mod with a settings UI they are settings in `Settings.gd`, and the README names them as settings; a
  Tuning entry's default, range and step stay constants in `Code.gd` (see above), and the README names the entry.
- **A constant's value exists in one place only: where the constant is declared**, so that changing it touches
  nothing but that file. READMEs, manifests, these docs, `CLAUDE.md`, comments in other files and the tests refer to a constant by
  its name and never repeat its value or a figure computed from it. The tests read constants from the mod (`_const`
  in `units.gd`, the instance in `lidar.gd`, the script's constant map in `hud.gd`) and build their layouts from them,
  so another value of a constant still passes. Base-game values a modder would have trouble finding may be quoted
  (the arm's 45 m reach; the game shows 10 world units as 1 m). Known exception, to fix when those mods next change:
  the legends of `ArmAltTargetSelection/TargetSelection.png` and of the two `ArmAltPullBehavior` images still show
  values of their constants.
- Read values from the game (the ship's nodes and collision shapes, scene files, the arm's own properties), never
  from per-ship tables. A constant is only a fallback for when the game data can't be read (`CHUNK_RADIUS_FALLBACK`).
- Game behaviour a mod relies on is cited with the game file and function it comes from (`Game.gd`
  `_respawn_ship`, `hud/SystemList.gd`). Check it in the decompiled source, not from memory.
- Versions follow [semver](https://semver.org): **major** for a change that breaks what players or modders rely on
  (a feature removed or changed incompatibly, saved settings that no longer load), **minor** for new behaviour or
  settings that keep the old working, **patch** for fixes and for changes with no visible effect (a file renamed,
  code moved between files). Every zip released gets a new version, and a released version is never changed.
  A new mod always starts at **0.1.0**. Going to 1.0.0 comes with a clean-up: all logging removed, the code
  simplified, and the what and why of each feature documented in the README for other modders.
- **The version lives only in `[version]` of `Mod.manifest` and in `CHANGES.md`**. It never appears anywhere else in
  the mod: not in the README (whose *Install* step says "the mod's zip" and names neither the mod nor the zip), the
  code, comments or images. Godot's and the game's own versions may be mentioned. The version is bumped only at
  release (see *Packaging and releasing*).
- **`CHANGES.md`**: a mod at 1.0.0 or later gets one in its folder (so it ships in the zip) as soon as it changes
  after 1.0.0. Changes not yet released accumulate in a `## NEXT` section at the top: every change to the mod adds its
  bullets there, while the manifest keeps the released version. At release the section is renamed to the new version
  (see *Packaging and releasing*), so below it there is one section per released version above 1.0.0, newest on top.
  1.0.0 is the baseline and gets no section, nor do the versions before it: only changes from 1.0.0 on matter.
  Entries are short bullets on what changed for a player or a modder (behaviour, fixes, files, constants and members
  renamed or added, README changes); like everywhere else, they name a constant and never repeat its value.

  ```markdown
  # <ModName> - Changes

  ## NEXT
  - …

  ## 1.2.1
  - …
  ```
- `Mod.manifest`: `id = "AGlezB.<ModName>"`, `author = "AGlezB"`, a one-line `description` that only says what the
  mod does (the details go in the README), the `group` tag naming the game script or the part of the game the mod
  touches (`DockingArm`, `Hud`), `manifest_version = 2.2`. The wiki's manifest format is outdated; follow
  [DVTools](https://github.com/rwqfsfasxc100/DVTools).
- README layout: `# <ModName> - ΔV: Rings of Saturn`; the summary (no version), with its images, if any; for a mod
  that changes how the game plays in a dive, *Warning*: in short, what it changes compared to vanilla, and to check a
  bug without the mod before reporting it to the game's developers; *What it does and why* (What / Why bullets); *For
  modders* for script extensions (what is extended, overrides, new members, constants, how it was tested); *Install*
  (three steps; the second, the same in every README, is "Put the mod's zip in it, and remove any other version of
  the mod from there: they would all load. Do not unzip it."; the third, `--enable-mods`); the "Mods are unofficial …
  Keep a backup of your save." line; *About* (made with the help of Claude; GPLv3). When the behaviour changes, update
  the README's text, *Warning* and figures too.
- The root `README.md`, this file and `_tests/README.md` are the repository's own (they ship in no zip). Update the
  README's *Mods* table when a mod is added or removed or a mod's summary changes, and its *Mods that change how the
  game plays* when a mod gains or loses its *Warning*; update `_tests/README.md` with every change to the harness or
  its suites.

## Salvage arm facts (for the ArmAlt mods)

- Only ships with high-stress hardpoints can mount the AR-1500 arm (not the Cothon series, not the Kitsune).
- Intakes: a grinder (two toothed rotors, e.g. the Eagle-Prospector-VP), an excavator (a beak that splits in the
  middle, e.g. the EIME), or the OCP-209's side bay (opens front to back, mounts two arms).
- The arm reaches only ahead of its mount; each section turns about 180°, like a human arm.
- Mineral chunks weigh about 5 t. The ship in the author's in-game tests is over 111 t, and can reach about three
  times that with equipment and load. The arm is normally used while moving at 10–40 m/s, rarely standing still.

## Glossary

The game's terms as these mods, their READMEs and their code use them. The key after a term is its translation key in
the game's `i18n/en.po` (what a Label's `text` holds before translation, and what mods match on); check a term's
English text there.

- **Adrenaline**: the game's bullet time. A level from 0 to 1 (`adrenaline` in `BulletTimer.gd`, changed through
  `CurrentGame.adrenaline(delta)`) that slows game time (`CurrentGame.targetTimeScale` → `Engine.time_scale`),
  blurs the view around the ship and muffles the sound, and drains by itself. Three things raise it: the Adrenaline
  Booster; the smart camera (a display setting, `Settings.cfg.display.smartCamera`; `ships/camera.gd`) when
  objects close in fast; and the pilot, when their Course anticipation (`CREW_STATS_PILOT_ANTICIPATION`) foresees
  a collision (`ship-ctrl.gd` `handlePilotAdrenaline`). How slow time gets at full adrenaline is the pilot's
  Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`, `CurrentGame.getAdrenalSlowdown`), set by their talent.
- **Adrenaline Booster** (`SYSTEM_ADRENALINE_BOOSTER`, `ships/CabinLight.gd`): equipment the player fires with
  the `bullet_time` action (`CONTROLS_GAMEPAD_ADRENALINE`) for a burst of adrenaline, followed by a cooldown
  (`adrenalineBoost`, `adrenalineCooldown`); fired again during the cooldown, it cuts the burst short. Switched off
  in the OMS's Mechanic tab, it pushes adrenaline down every frame instead, which also damps bullet time from the
  other sources. DiveDisableAdrenalineBooster starts the player's booster switched off at every dive.
- **Arm**: the AR-1500 Manipulator (`SYSTEM_SALVAGE_ARM`, `ships/modules/DockingArm.gd`), the ship's arm that grabs
  chunks and brings them to the intake (see *Salvage arm facts*).
- **Astrogation** (fast travel): travel inside the ring to a known destination, picked in the Astrogator tab and
  started with PLOT A COURSE (`HUD_PLOT_COURSE`; `hud/AstrogatorPanel.gd`, `CurrentGame.fastTravelTo`).
  - The trip: the ship first speeds up to the tab's travel velocity (`HUD_VELOCITY`), flown by the autopilot while Use
    autopilot (`HUD_ASTROGATION_AUTOPILOT_MATCH`) is on (`Game.gd` `initiateFastTravel`). Then it jumps to the
    destination, in-game time advances by the distance divided by that velocity, and the autopilot brakes the ship
    (`ship-ctrl.gd` `fastTravelTo`). A faster trip takes less time and more remass, for speeding up and braking. A
    destination too close can't be picked (`HINT_POI_TOO_CLOSE`). Enceladus (`DESTINATION_ENCELADUS`) is always
    listed: picking it leaves the ring, through the exit cutscene and the transit back.
  - Destinations: kept per save in `CurrentGame.state.astrogation`, each with a deadline (`time`). A trackable one
    stays usable until the crew's Coordinate tracking time (see *Crew stats*) after its deadline
    (`getTimeLeftForDestination`, shown next to its name). Entering its spot again moves the deadline to that moment,
    plus the spot's own extra days (`story/Discovery.gd`, `discoverPoi`).
  - Past that time a destination is lost: listed only with Show lost destinations (`HUD_ASTROGATION_SHOW_EXPIRED`),
    and a trip to it lands off target, by an error that grows to `expiredAstrogationPeakError` (18 km) over one more
    tracking time (`getDestinationUncertinty`). Destinations that aren't trackable (timed events) drop off the list
    at their deadline. Every in-game hour counts against them: transit, the dive itself, astrogation and the hours
    spent at the station.
- **Astrogator**: the crew occupation for navigation, and the OMS tab with the map: points of interest (see
  *Astrogation*), distances, plotting a course (`HUD_PLOT_COURSE`).
- **Chunk** (mineral chunk, ore chunk): a loose piece of ore floating in the rings; what the arm grabs, the MPU
  processes and the HUD's mineral targeting marks. A `RigidBody2D` with `asteroids/mineral.gd`, one scene per
  mineral and size (`asteroids/mineral-<mineral>-<n>.tscn`); `mineral` names its mineral, `composition` its
  content. Weight: see *Salvage arm facts*.
- **Crew** (`ENCELADUS_CREW`): the people hired at the station, each with an occupation (`CurrentGame.occupations`:
  Pilot, Mechanic, Geologist, Astrogator, keys `CREW_OCCUPATION_*`) and a salary; the player is the captain. The
  dive crew are those aboard. Passengers (`CREW_OCCUPATION_PASSENGER`, no salary) are listed with the crew. The
  **Crew screen** (`enceladus/Crew.tscn`), opened by the station menu's Crew entry, has two tabs: Your Crew
  (`ENCELADUS_CREW_CURRENT`, `enceladus/CurrentCrewManagement.gd`) and the Hire screen.
- **Crew stats**: what the crew is good at, per occupation. Each member has a talent, shown as Education
  (`CREW_EDUCATION`), and an experience (`CREW_EXPERIENCE`), both from 0 to 1 in their own occupation and shown on
  their entry as levels (`CurrentGame.talentLevels`, `experienceLevels`; `enceladus/CrewBio.gd`).
  - The crew's value for an occupation is the best among the dive crew in it, not counting those on leave, raised by
    that member's good morale and lowered by bad (`morale`, which has no text in `en.po`; `CurrentGame.getCrewStats`).
  - Each occupation's talent and experience give one stat each, shown on Your Crew (`deriveStats`, `skillMatrix`):
    Pilot, Adrenal slowdown and Course anticipation; Mechanic, Jury-rig efficiency and Repair limit; Geologist, Price
    prediction accuracy and Mineral discovery range; Astrogator, Tactical awareness range and Coordinate tracking time
    (`CREW_STATS_ASTROGATOR_TIME`: how long trackable destinations stay usable, see *Astrogation*; the longer of 12 h
    and 90 days × experience).
  - Both grow through `giveXp`, which events call (an astrogator revisiting a destination, among others); a member's
    growth is pulled towards the best member of their occupation (`mentorXpGain`).
- **Cutscene**: a stretch where the game flies the ship and the player has no control, while the ship's `cutscene`
  flag is on (`ship-ctrl.gd` `_setCutscene`, which emits `cutscene`). The ring scene has five: the arrival at the start
  of a dive, the exit (`ship-ctrl.gd` `escapeTheRing`, then the `exit` animation), the rescue of a helpless ship (out
  of remass or power: `helpless`), fast travel inside the ring (`ship-ctrl.gd` `fastTravelTo`, `fasttravel`) and the
  game over (`gameover`). Each plays a title card on `Game.tscn`'s `TitleAnimPlayer`; the arrival's, `intro`, shows
  `CUTSCENE_RINGS_OF_SATURN`, the transponder, the date and the transit tip (`codex/TransitTip.gd`). Holding
  `cutscene_ff` (Space, the left mouse button, gamepad buttons 0 and 1; no text of its own in `en.po`) runs a cutscene
  at up to 3x speed (`Game.gd` `_process`, through `CurrentGame.targetTimeScale`), with VHS stripes over the screen
  while `Engine.time_scale` is above 1 and post-processing is on (`FastForward.gd`). In the arrival, the ship comes in
  fast towards the dive entry point and brakes to a crawl, turned to face into the rings (`Game.gd` `_ready` and
  `_process`: `initialSpeed` from `desiredAcceleration` and `initialCutsceneTime`, braking for `totalCutsceneTime`;
  `Game.tscn` sets the two times). The arrival, astrogation and the exit really fly the ship: its thrusters and its
  reactor's turbine burn remass, and in-game time passes. DiveSkipTransit skips each of the five, the arrival and the
  exit (the transit) under one setting, and charges what it would have cost; with the transit not skipped, it plays
  both at a speed of its own, without Space.
- **Dealer** (`ENCELADUS_SHIP_MARKET`, `enceladus/Dealer.tscn`): the station's ship market. Its entries are
  `enceladus/SystemBuyUI.gd` (the ship-list mods change them); its Examine tab can launch the simulator. **Fleet**
  (`ENCELADUS_OWNED_SHIPS`): the ships the player owns, and the station screen listing them (`enceladus/Owned.tscn`,
  an instance of `Dealer.tscn` with the same entries, the current ship first), where the player switches ships
  (`GARAGE_SWITCH`, `Dealer.gd` `use`) and sells them (`GARAGE_SELL`). Each owned ship keeps its own config: equipment,
  Tuning, mineral targeting, damage, cargo (`CurrentGame.state.ship`, the others in `state.garage`), and a crew list
  (`preferredCrew`), which the game writes only when the crew changes while that ship is flown (hiring, firing, who
  dives) and puts aboard when the player switches to it (`CurrentGame.gd` `validateEmployment`); a ship without one
  keeps whoever is aboard. The crew itself belongs to the player, not to a ship.
- **Depth** (`HUD_DEPTH`): how far into the rings the ship is.
- **Dive** (ring dive): one trip from the station into Saturn's rings to mine, until the ship is back. Started with
  Launch Ring Dive (`ENCELADUS_RETURN_TO_RING`), at the dive entry point picked before launch
  (`ENCELADUS_DIVE_TARGET`, `enceladus/DiveTarget.tscn`); fees, licences, insurance and consumables are paid per
  dive, and on return the dive's output is stored or sold.
- **E$**: the game's currency.
- **Enceladus**, **the station**: Enceladus Prime station (`ENCELADUS_*`, `enceladus/`), the home base at Saturn's
  moon Enceladus. Its menu (`enceladus/EnceladusMenu.gd`) opens the station's screens on its right (the children of
  `enceladus/HidingMarginContainer.gd`). On every arrival the station fades in (`Enceladus.tscn`'s `AnimationPlayer`,
  `FadeInCRT`), and its menu stays disabled until the animation calls `disable(false)` on it, a few seconds in;
  DiveSkipTransit skips the fade-in.
- **Equipment**: the parts fitted to a ship (engine, reactor, LIDAR, MPU, arm, Adrenaline Booster, …), and the
  station screen where they are bought and fitted to its hardpoints (`ENCELADUS_SHIP_UPGRADES`,
  `enceladus/Upgrades.tscn`; also called the Upgrades screen, after its key and scene). The code calls one piece a
  system: each has a `SYSTEM_*` key, which its script holds in `systemName` (`SYSTEM_SALVAGE_ARM`); a few texts say
  "system" too (the OMS's on/off switch, the trade-in tip).
- **EVA** (extravehicular activity): a crew member in a space suit outside the ship. It has no key of its own; the
  word is in conversation lines ("Getting into EVA.", `DIALOG_DERELICT_GO_SURE`). In flight an EVA is only a suited
  sprite with a lamp (`ships/modules/EVAflight.tscn`, `EVAflight.gd`), which flies between the player's ship and the
  ship the player is talking with when a conversation line sets `evaDirection` (`comms/ConversationPlayer.gd`
  `execute`, over the line's `evaTime`; `ship-ctrl.gd` `handleEvaProgress`). -1 flies from the player's ship to the
  other ship, 1 from the other ship to the player's. The sprite is decoration: the line's other fields decide what
  happens. The player can't order an EVA. The base game shows one only in the cases below. The first three are
  conversations during a dive, and in them the one who goes out is a member of the dive crew, so a captain flying
  alone never gets them:
  - **Derelicts**: abandoned ships with their reactor off, in the `helpless` faction (`story/RescueOperation.gd`, a
    random event of the rings in `story/TheRing.tscn`, sometimes with a rescue ship nearby;
    `story/FlightForRescue.gd`, on a rescue ship's path). A derelict can't be hailed. It opens its conversation
    (`comms/conversation/DerelictConversation.tscn`) by itself, once, when the player's ship comes within its
    `aiCuriosityDisance` (150 m; `ship-ctrl.gd` `AI.examine`). Unless a rescue ship (faction `helper`) is in sight
    (then it's taken: see *Salvage claim*), a random crew member reports it (`DIALOG_DERELICT_RANDOM.tscn`), and
    the player can send them over to restart it (`DIALOG_DERELICT_GO_AND_BRING_IT`). On board, they may get it
    running, and it joins the player's fleet (`getThisShip`). Or they come back with nothing, or injured (leave days,
    `addAgendaLeaveTime`). What they find varies (the `DIALOG_DERELICT_*` subtrees: brick, junk, solo dead, hole,
    ghost ship).
  - **Crew agendas**: an agenda is a crew member's personal story (`AGENDA_*`, followed in
    `CurrentGame.state.agenda`). The member looking for their child (`AGENDA_LOOKING_FOR_CHILD`, a branch of the same
    derelict conversation) and the one looking for their sibling (`AGENDA_LOOKING_FOR_SIBLING`, a derelict spawned for
    it by `story/AgendaSpecificDerelict.gd`, which talks within 250 m: `AI.playDeadButTalk`) go over to the ship
    they were looking for.
  - **Vilcy** (faction `vilcy`, bounty hunters): a Vilcy ship hails the player about an ex-pirate in the crew
    (`AGENDA_EX_PIRATE`, `comms/conversation/VilcyConversation.tscn`). Handing them over
    (`AGENDA_EX_PIRATE_TAKE_HIM`) fires them, with an EVA.
  - **At the station**, outside any conversation: the dock in Enceladus's background shows up to five suited
    workers with flickering welding lights (`faces/EVA.tscn`, `faces/EVA.gd`; `EVA01`–`EVA05` in
    `enceladus/Enceladus.tscn`). Each one is there while the player's ship is in maintenance
    (`CurrentGame.isShipMaintained`: the in-game hours that fitting equipment and repairs take) or damaged past its
    `damageRequired` (`1 - getCombatCapacity()`). They are scenery, not crew.
- **Geologist**: the crew occupation for mining, and the OMS tab with the cargo's composition and the mineral
  targeting: which minerals the HUD marks, and their Minimum value (`HUD_MIN_PRICE`), kept in the HUD's
  `mineralConfig`.
- **Hardpoint**: a ship's mount for a piece of equipment: high-stress, low-stress or spinal. Only high-stress ones
  take the arm.
- **Hire screen** (`ENCELADUS_CREW_HIRE`, "Hire"; also the Hire list): the Crew screen's tab of the people for hire
  that day, the `HireableCrew` node of `enceladus/Crew.tscn` (`enceladus/HireableCrew.gd`), filled from
  `CurrentGame.getAvailableCrew()` on the first show and every in-game day. One entry per person
  (`enceladus/CrewBio.tscn`, `CrewBio.gd`): their skills compared with the crew's, name, occupation, education,
  experience, salary, portrait, and a Hire button (`CREW_HIRE`, the entry's `hireButton`), disabled while the
  player can't pay the salary.
- **HUD**: the ship's flight display (`hud/Hud.gd`), laid out per ship model in `hud/Display-<model>.tscn`.
- **Intake**: where the arm feeds chunks into the ship: a grinder, an excavator or a side bay (see *Salvage arm
  facts*).
- **Launch sequence**: what the station plays after Launch Ring Dive (`ENCELADUS_RETURN_TO_RING`) and the dive target:
  the ship powers up and leaves the dock (`enceladus/Enceladus.gd` `_on_DiveTarget_launch`: `ExitPlayer`'s
  `LaunchSequence`, then, once the ship has power, `Autopilot`'s `GoToRing`, which ends in `goToRing()`, the switch to
  the ring scene). Esc or `cutscene_ff` cuts it short (`Enceladus.gd` `_physics_process`). The ship flown there is the
  station's, thrown away with the scene. DiveSkipTransit cuts the sequence as soon as it starts.
- **LIDAR** (`HUD_LIDAR`, "Doppler LIDAR"; `hud/LIDAR.gd`): the HUD's scanner of nearby objects. Its sweep plays a
  ping (the `Bleep` node) for each strong return, pitched and set in volume by the distance; a Tuning switch
  (`doBleep`) turns the pings off.
- **Mechanic**: the crew occupation for repairs, and the OMS tab listing the ship's equipment, to switch each piece
  on and off and fix it.
- **Mineral**: what a chunk is made of, named in code by its element symbol (`mineral = "PT"`). Processed ore
  (`HUD_CARGO_LIST_PROCESSED`) is what the MPU has extracted; it is sold or stored at the **Mineral Market**
  (`ENCELADUS_MINERAL_MARKET`).
- **MPU** (`SYSTEM_CARGO_MPU*`, `ships/modules/MineralProcessingUnit.gd`): the Mineral Processing Unit, which turns
  the chunks taken in into processed ore and, in most models, their water into remass.
- **OMS** (`HUD_OMS`, `hud/OMS.gd`, `hud/OMS.tscn`): the Onboard Maintenance System, the console opened with `J` in
  flight. Its tabs are named by the crew occupation keys: Mechanic, Astrogator, Geologist, Pilot.
- **Reactor** (`SYSTEM_REACTOR_*`; `ships/Reactor.gd`): the ship's nuclear reactor, the equipment that makes heat. The
  turbine (`SYSTEM_TURBINE_*`, equipment for fission ships, read as the config `turbine.power`) turns that heat into
  electricity and burns remass to do it (`turbineConsumption`). With no remass left, it makes no power. The reactor
  engages and disengages by itself to hold its target temperature, a Tuning setting (`TUNE_TARGET_TEMPERATURE`). The
  HUD shows the temperature as `HUD_REACTOR_TEMP`, and the `power_reactor_toggle` action switches the reactor on and
  off. Its damage is listed in the Mechanic tab (`hud/SystemList.gd`): Fuel rods jammed (`DAMAGE_RODS`, from hard
  accelerations: slower to engage and disengage, and the temperature swings), Reactor leak (`DAMAGE_LEAK`) and
  Turbine Galling (`DAMAGE_TURBINE`, from overheating: the turbine needs more heat to make power). If the reactor
  stays above its meltdown temperature for a few seconds (`telegraphTimeLimit`, with a growing glow as warning), it
  explodes and the ship is lost. For the player's ship, that is game over. The EIME's StarCAT Stellarator
  (`SYSTEM_REACTOR_EIME`, `ships/modules/FusionReactor.gd`) is a fusion reactor with other kinds of damage (coils,
  coolant, lasers) and no leak.
- **Reactor leak** (`DAMAGE_LEAK`): damage to a nuclear reactor from impacts close to it (`Reactor.gd` `_on_impact`:
  the impact's power divided by the distance squared, counted above a threshold). The spot that was hit becomes a
  leak point. Used ships start with some leak damage (`ageIfNeeded`). Past a quarter of its capacity
  (`damageLeakOffset`), the leak vents remass at random moments. It vents more often the worse the leak, and more
  remass the hotter the reactor; it doesn't vent while the reactor is below `leakTemperature`. Each vent wastes
  remass, cools the reactor and pushes the ship from the leak point. The leak also lowers the meltdown temperature
  (`meltdownTemperature - jamTemperatureAdj * leak`), so an overheating reactor explodes sooner. Leaks matter most in
  combat: they are the only way to disable an enemy ship so it can be captured, because a ship that runs out of
  remass stops working.
- **Remass**: reaction mass, the ship's propellant (`HUD_FUEL`, shown as "propellant").
- **Repairs** (`ENCELADUS_SHIP_REPAIRS`, `enceladus/Repairs.gd`): the station screen that fixes the current ship's
  damaged equipment for E$ and in-game hours (`enceladus/SystemShipRepairUI.gd`): Replace (the piece's
  `repairReplacementPrice` less what it is still worth, in `repairReplacementTime` hours) or Fix (`repairFixPrice` per
  step, in `repairFixTime` hours shortened by the crew's mechanics). The hours are the ship's maintenance, a time
  stored in that ship's own config (`maintaineceUntil`, `CurrentGame.isShipMaintained`); fitting equipment adds to it
  only when the piece replaced was damaged (`ship-ctrl.gd` `getSlotTime`). A ship in maintenance can't dive
  (`Enceladus.gd` `shipPassesInspection`; the pre-flight inspection offers a hotel stay until it is done) or be sold,
  but the player can switch to another ship of the fleet, while the first one's maintenance runs on.
- **Rescue**: how a dive ends when the player's ship is helpless: out of remass (or with no capacitor,
  `ship-ctrl.gd` `isHelpless`) for longer than `helplessTimeLimit`, outside a cutscene (`Game.gd` `_process`). The game
  switches the reactor off, claims the cargo and plays the `helpless` cutscene: `sendHelp` advances the clock by a
  random stranded time (up to `strandedTIme`, two weeks) and spawns a MAD-CERF of the `helper` faction near the ship
  (the ship counts as `helpless`, so the MAD-CERF goes for it as it does for a derelict, see *Salvage claim*; this
  changes nothing), and `goToEnceladus` ends the dive at the station. The transit back isn't charged. DiveSkipTransit
  skips the cutscene, charging only its in-game time.
- **Ring scene**: the scene of a dive in the rings (`Game.tscn`, `Game.gd`), loaded from the station by `goToRing()`
  and left for the station by `goToEnceladus()`, or for the title screen after a game over. It holds the player's
  ship, the asteroid field (`AsteroidField.tscn`, whose `AsteroidSpawner.gd` also moves the in-game time on every
  frame) and the title cards of its cutscenes.
- **Roid**: an asteroid (`asteroids/asteroid.gd`, a `RigidBody2D`), the rocks that fill the rings; the game's own
  texts say "roids" too.
- **Salvage claim**: a phrase from one derelict line, "…with that rescue ship on our back, they'll file for a salvage
  claim anyway." (`DIALOG_DERELICT_TAKEN_4`), not a mechanic: the game records no claim on a derelict (see *EVA*).
  What decides who gets one:
  - **The rescue ship**: a MAD-CERF of the `helper` faction, spawned with the derelict (`story/RescueOperation.gd`) or
    before it, the derelict then appearing on its path after `time` (`story/FlightForRescue.gd`). It goes for
    `helpless` ships. A powerless one (`powerBalance` at or below 0, as a derelict is with its reactor off and no
    remass) it docks with its clamps (`SYSTEM_DOCKING_CLAMPS`; `ship-ctrl.gd` `AI.dock`), and after
    `aiDockingSecureTime` it leaves (`AI.exit`). Nothing passes to it: the derelict doesn't become its cargo.
  - **The derelict's conversation**: if the derelict sees a rescue ship when the conversation opens
    (`mustSeeFaction = "helper"`, tested on the derelict's `getObjectsAIisAwareOf`), a random crew member says one of
    the four `DIALOG_DERELICT_TAKEN_*` lines and the conversation ends, without the offer to send them over. Every
    other branch needs no rescue ship in sight (`cantSeeFaction`). A derelict talks once, so for that one the chance
    is gone.
  - **The arm**: a ship the arm holds (`addTemporaryCargo`, which sets its `docked`) counts as taken for the AI
    (`aiIsTaken`), so a rescue ship no longer goes for it. If the arm still holds it when the dive ends at the
    station, it joins the fleet for free when `CurrentGame.isShipSalvageable` says so: abandoned (every derelict),
    of the `pirate` faction, or without a transponder (`ship-ctrl.gd` `handleExitToEnceladus`,
    `CurrentGame.addShip`; the arm's manual says so too, `SYSTEM_SALVAGE_ARM_MANUAL`). A rescue ship nearby doesn't
    prevent it. A `helpless` ship that isn't salvageable pays 10 % of its value instead (`getShipValue`). Nothing
    held is taken when the player's own ship ends the dive helpless (see *Rescue*).
- **Ship models**: Eagle-Prospector-VP (the VP), EIME, OCP-209, K37 TNTRL, the Cothon series, the Kitsune, …: names
  of ships as the Dealer shows them.
- **Simulator** (MVFS; `ENCELADUS_LAUNCH_VR`, `enceladus/Simulator/`): the Minding Virtual Flight Service, the
  station's flight simulator for trying a ship as fitted; launched from the Tuning and Equipment screens and the
  Dealer's Examine tab. A Premium subscription (`SERVICE_SIMULATOR`) adds a simulated ring scenario.
- **Transit**: the interlunar trip between the station and the rings, which costs remass and in-game time each way and
  isn't flown. Each way covers the ΔV for trajectory (`MAP_DV`) of the dive entry point picked (`DiveTarget.gd`
  `getPrices`, kept in `CurrentGame.dvToEnceladus`). The main drives, the ship's thrusters, cover it in
  `CurrentGame.timeDistanceToEnceladus` (12 h), burning the remass the rocket equation gives for the ship's whole mass
  and its best thruster's exhaust velocity (`ship-ctrl.gd` `getRemassRequiredForDv`, `getBestThrusterVe`); the xenon
  drive covers it in `xenonBurnToEnceladus` (96 h) and burns none.
  - Out, at the start of a dive: charged once the ship is set up (`Game.gd` `_ready`: `getInterlunarTransitRemass`,
    `getInterlunarTransitTime`), then the arrival cutscene plays. The xenon drive's Tuning setting splits the ΔV
    between the two drives, and the time between their two times, in the same shares; the remass doesn't follow the
    shares, because the rocket equation isn't linear. The dive entry point screen shows that remass as Interlunar
    propellant usage (`HUD_RETURN_FUEL_XENON`) and won't launch without it (`HUD_WARN_PROPELLANT`).
  - Back, at the end: charged during the exit cutscene (`Game.gd` `interlunarToEnceladus`), whatever the setting. The
    main drives burn all the remass aboard, up to the Transit reserve (`HUD_RETURN_FUEL`: the remass for the whole ΔV
    at the ship's mass then, cargo included), and the xenon drive does the rest. The time is split between the two
    drives' times by the share of the reserve burned (`getTimeRequiredToBurnToEnceladus`, the HUD's Transit time,
    `HUD_RETURN_TIME`), so a ship out of remass comes back in the xenon drive's time, never stranded.
  - The K37 TNTRL's HUD also shows Estimated interlunar transit time and Interlunar propellant usage
    (`HUD_RETURN_*_XENON`, `hud/trtl/ShipParams.tscn`): the outbound figures at the ship's current mass, not the trip
    back.
- **Tuning** (`ENCELADUS_SHIP_TUNING`, `enceladus/Tuning.tscn`): the station screen with the settings of each piece
  of the current ship's equipment, registered by its script with `registerSubsystem` and saved with the game (see
  *Conventions*).
- **Xenon drive**: the low-thrust, economical drive every ship has for transit, which burns no remass (the game keeps
  no stock of xenon). Its Tuning setting, Interplanetary Xenon transit drive usage (`TUNE_XENON_BURN`, a HUD built-in:
  `hud/Hud.gd` `getTuneables`; 0–100 %, default 100 %, kept per ship), is the share of the outbound ΔV it covers
  (`ship-ctrl.gd` `getXenonBurnRatio`); the main drives cover the rest. The trip back ignores it (see *Transit*).

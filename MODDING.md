# ΔV: Rings of Saturn mods - for modders

For those who read or change the code: how the repository is laid out, how the game loads a mod and how these mods
hook in, packaging and releasing, the users' wiki, the conventions they follow and the game's terms. The mods
themselves, and how to install them, are in the [README](README.md); the test harness is in
[`_tests/README.md`](_tests/README.md).

## The repository

The mods are written in GDScript for the game's engine, Godot 3. Each top-level folder not starting with `_` or `.`
is one independent mod and ships as one zip. There is no build system: `package.ps1` builds a mod's release zip (see
*Packaging and releasing*), `_tests\` is a test harness for most mods (see *Testing*), and `_wiki\` is the users'
wiki, checked by `wiki.ps1`, published by `.github\workflows\wiki.yml`, with its screenshots of the station and the
OMS taken by `_shots\shots.ps1` (see *The users' wiki*). The source has been in git since 14 Nov 2026, and `.gitignore` keeps out
every zip, so the versions
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
| `TempDir\gdre\Delta-V-<version>\` | The decompiled game, one folder per game version (1.91.61 and 1.92.5 so far) |
| `GodotDir` | Godot 3.6 (the game's engine) and GDRE Tools 2.7.4 |
| `TempDir` | Generated and temporary files: zips being packaged, test runs, the wiki's screenshot runs (`shots\`), scratch scripts; never the repo |

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
  `project.godot` (`Settings`, `Loader`, `CurrentGame`, …) are still null at that point. The engine creates them
  afterwards from their script paths, so an extension of one of their scripts installed then applies to the autoload
  itself (AltTransponderCodes extends `CurrentGame.gd`; its throwaway instance is safe because the game's script has
  no `_init` and no initializer that needs another autoload).
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
   CrewCheapHireNotifier's Crew entry does), DealerNotifier (`enceladus/EnceladusMenu.gd`, the Dealer entry's mark and
   Shift+Click, its settings screen copying the Dealer screen's frame; and `enceladus/Dealer.gd`, the Dealer screen,
   whose refreshes tell it the stock), AltTransponderCodes (`CurrentGame.gd`, the autoload, where the game makes
   transponder codes, with a `node_added` handler, as the observers below have, for the objects whose code is built
   from a ship's; and `menu/NewGamePlus.gd`, the New Game+ screen). `ModMain.gd` only calls
   `installScriptExtension("res://<ModName>/Code.gd")` (CrewPerfectSort: once for each of its two extension files;
   CrewCheapHireNotifier: `Code.gd`, then `HireScreen.gd`; DiveSkipTransit: `Code.gd`, `Station.gd`,
   `StationMenu.gd`, then `Ship.gd`; DealerNotifier: `Code.gd`, then `DealerScreen.gd`; AltTransponderCodes:
   `Code.gd`, then `NewGamePlusScreen.gd`, from `_init`, before the engine creates `CurrentGame`); `Code.gd`
   `extends "res://<game script>"`. Rules that let mods stack on the same script (header of
   `ArmAltTargetSelection/Code.gd`):
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
- CrewCheapHireNotifier (`Code.gd`), DealerNotifier (`Code.gd`) and DiveSkipTransit (`StationMenu.gd`) all extend
  `EnceladusMenu.gd`, each hooking Shift+Click on its own menu entry (Crew, Dealer, Launch Ring Dive) to open its
  settings screen among the station's right-hand screens. By path the chain is game ← CrewCheapHireNotifier ←
  DealerNotifier ← DiveSkipTransit; all override `_ready` and `_notification` (the game's script has neither) without
  calling the parent's. Their member names must stay distinct; opening one screen hides the others (`hidefoka`).
  Loaded together in `skip` (CrewCheapHireNotifier and DiveSkipTransit) and in `dealer` (all three, every order).
- ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice find the ship entries by `node.get_script().resource_path`;
  ShipCopyPaste extends that script, and `take_over_path` keeps the path, so they still find them (loaded together in
  `fleet`). DealerNotifier reads the stock from the Dealer screen's entries in any order and hangs its badge in each
  entry's name, so it works with all three.

## Packaging and releasing

A mod ships as `<ModName>-<version>.zip`, which holds the whole mod folder (README, `CHANGES.md` and images included)
at its root, with a copy of the repository's `LICENSE` in it: the GPL asks for one with every copy given out.
`package.ps1` (PowerShell 7) builds it in `TempDir`, or in `-OutDir`:

```powershell
.\package.ps1 <ModName>                # builds the zip and prints its path
.\package.ps1 <ModName> -VersionOnly   # prints the version the zip would have
```

The version comes from `[version]` of `Mod.manifest`. The script refuses to overwrite a zip, refuses a mod whose
`CHANGES.md` doesn't start with that version, and refuses a mod whose page in the users' wiki is missing or out of
date (`wiki.ps1 -Mod <ModName>`, see *The users' wiki*): a new mod needs its page before its first release. It checks
that every entry is `<ModName>/…` with forward slashes: the game needs them for the `res://` paths, and Windows
PowerShell 5.1's `Compress-Archive` writes `\` instead, hence PowerShell 7.

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

## The users' wiki

The repository's GitHub wiki explains each mod to players, so that sharing a mod means sharing a link: one page per
mod, in plain words, with "without the mod / with the mod" pictures where a mod changes what the screen shows. Its
source is `_wiki\`; `.github\workflows\wiki.yml` copies it to the wiki when a push to `main` changes it, or when the
workflow is run by hand (Actions, Wiki, Run workflow). The wiki is a mirror: whatever is edited on the website is
overwritten at the next publish, so edit `_wiki\` only. The wiki's settings restrict editing to collaborators.

**Files.** `_wiki\` holds only pages and images, since everything in it is published:

- `Home.md`: what the mods are, every mod in groups with a plain one-line summary, *Mods that change how the game
  plays*, and *Installing mods* (where a zip comes from, the `mods` folder, `--enable-mods`, a backup of the save).
- `_Sidebar.md` (Home and every mod page, in Home's groups) and `_Footer.md`.
- `<ModName>.md`, one per mod: the page's name is the mod's, so its link is `…/wiki/<ModName>`.
- `images\<ModName>-<view>-without.png` and `-with.png` (a single picture: `<ModName>-<view>.png`): PNG, at most 2 MB,
  a screenshot cropped to the part of the screen that changes. The mods' READMEs keep their pictures here too (the
  arm diagrams), linked as `../_wiki/images/<file>`, so a mod's zip carries none; such a picture's values are listed
  in the values block of the mod's page like any other.

**Pictures.** Only mods with a screen of their own, or that add to or change a game screen, have screenshots; mods
that only reorder a list or change how the game plays have none. Every screenshot is taken with bloom off (the game's
Bloom setting at No Bloom). Screenshots of the station's screens and of the OMS (which `shots.ps1` opens in a dive)
are taken by `_shots\shots.ps1` in an isolated copy of the game, from a fixture save, each mod's in a run without it
and a run with it ([`_shots/README.md`](_shots/README.md); its steps in `_shots\shots.psd1`); those of flight, which
depend on what is around the ship (the HUD, the info boxes), by hand, the pair from the same save, ship and view.

**A mod's page**, in this order (GitHub shows the file name as the title, so there is no `#` heading):

1. One sentence on what the mod does for the player.
2. `## What changes`: what the player sees or gets, compared with the game without the mod. Pictures go side by side
   in a two-column table, *Without the mod* and *With the mod*, or one under the other when they are wide (the HUD);
   each has alt text.
3. `## Settings`, for a mod that has any: how to open them, and for each its name as the screen shows it, what it
   does, its default and its range, in the units the screen shows.
4. `## Changes how the game plays`, exactly when the README has a *Warning*: in short, what differs from the normal
   game, and to try without the mod before reporting a bug to the game's developers.
5. `## Works with other mods`, where it matters (mods that stack, mods that must not be installed together).
6. `## Install`: a link to Home's *Installing mods*.
7. The values block (below).

**Writing.** For players of any age the game is for: short sentences, "you", the active voice. Game words exactly as
the game shows them in English (check them in the newest decompiled game's `i18n/en.po`), each explained in a few
words the first time a page uses it if a new player wouldn't know it ("remass, your ship's propellant"). No code words:
no constant, file or member names, translation keys, "script" or "world units". Numbers in the units the game shows,
rounded where that reads better, ranges written with "to". No mod versions (the version rule holds here too). The
wiki describes `main`, so for a while it can be ahead of a zip already shared.

**The values block.** The wiki is the one place besides the code where a constant's value may appear (see
*Conventions*), and the values block is what keeps it true. Every mod page ends with a hidden comment listing what
the page shows, in its text or its pictures, that can change. For a made-up mod:

```
<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.92.5
SomeMod/Settings.gd SETTINGS.share.default = 0.25 -> 25 % | images/SomeMod-settings.png
SomeMod/i18n/en.po SOMEMOD_SHARE = "Share of the cargo"
SomeMod/Code.gd SEGMENTS = 12
game: 45 m, how far the AR-1500 reaches (ships/modules/SalvageArm.tscn scale, Arm.gd armLength)
note: 400 t and 100 t, an example worked out from the share's default: change it with that
-->
```

- A value line: a file of a mod (a `.gd`, or a `.po` for the mod's on-screen texts), a constant (`NAME`, `NAME.key`,
  `NAME[0]`; a key may have dashes, as the game's model keys do: `MODEL_CODES.TRTL-LCB`) or a text's key, `=` its value written as in the code, then optionally `->` how the page writes it (10 %,
  4.5 m, 24x, on) and `|` the pictures that show it. A constant that names another one is followed to its value.
- `game:` a value of the base game, in words, with where it comes from; `game-checked:` the game version the page's
  game values and its "without" pictures were checked against.
- `note:` a number in the text that isn't a value (a rule of thumb, an example).
- The wiki quotes only constants, the mods' `.po` texts and `game:` values. A value written inline in the code becomes
  a constant first.

**`wiki.ps1`** (PowerShell 7) checks every page, or with `-Mod <ModName>` one page. It fails when:

- a listed value no longer matches the code (it names the page's lines showing the old value, and the pictures to
  re-take), or a listed value doesn't show in the page's text or a picture;
- a number in a page's text isn't in its values block (names such as OCP-209 or K37 don't count);
- a setting the mod describes isn't listed: every setting of its `Settings.gd` (its default, its `min` and `max`, the
  text of its `label`) and every Tuning entry it registers (`registerSubsystem`: the constants of its default and
  range, the text of its key);
- a mod has no page, Home or the sidebar doesn't link it, or a page has no mod; a page's *Changes how the game plays*
  doesn't match its README's *Warning*;
- a link between pages or to a heading doesn't resolve, an image is missing (spelling counts: GitHub's servers are
  case-sensitive), unused, not a PNG or larger than 2 MB, or `_wiki\` holds anything but pages and `images\`; a mod's
  README shows a picture from anywhere but `_wiki\images\`.

Where `paths.local.psd1` points at a decompiled game, it also warns when a page's `game-checked` is older than the
newest one. It runs by hand (`.\wiki.ps1`), in `package.ps1` for the mod being packaged (so a release stops before
anything is built), and in the workflow before anything is published (so a push that leaves a page out of date fails
there).

**Keeping it up to date.** A change to anything a mod's page says (behaviour, settings, a listed value or text, a
screen its pictures show) updates the page, its values block and its pictures in the same change. A release reviews
the page against the mod's `## NEXT` bullets, since no check catches a change of behaviour. A picture `wiki.ps1` names
to re-take is taken again with `.\_shots\shots.ps1 -Mod <ModName>`, or by hand for one of flight. After a game
update, every page's `game:` lines and "without" pictures are checked against the new version (the station's with
`.\_shots\shots.ps1 -NewFixture`) before its `game-checked` changes.
Adding or removing a mod adds or removes its page, and its lines in Home and the sidebar.

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
    ship, `ships/ship-ctrl.gd`), DealerNotifier's `DealerScreen.gd` (the Dealer screen, `enceladus/Dealer.gd`). Code
    more than one of them uses goes in `Settings.gd`, which they already share: CrewCheapHireNotifier's rule
    (`limitFor` / `isCheapHire`), DiveSkipTransit's static helpers (`playThrough`, `chargeDv`, `chargeSeconds`),
    DealerNotifier's stock and rule (`setStock`, `markSeen`, `newShips`).
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
      `dimmedWhen` names the switch while which it doesn't apply. `perModel` (DealerNotifier's switch) is `perJob` for
      the ship models the dealer can offer. `var cfg`: the current values by key (a dictionary by job or model key for
      a per-job or per-model setting), set to the defaults in `_init`. `const FORMAT_VERSION`.
    - `jobs()`: the jobs a per-job setting has values for, the game's `CurrentGame.occupations`; `isPerJob(key)`.
      DealerNotifier's `models()` and `isPerModel(key)` are the same for its ship models, and its `getValue` /
      `setValue` take a model where CrewCheapHireNotifier's take a job.
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

    Players don't open the zip, so they never read the README: the screen explains every setting itself, as the game's
    Tuning screen does. Under the title, a window framed as the Tuning screen's description shows the selected row's
    description: the key of its `label` followed by `SettingsUI.gd`'s `DESCRIPTION_SUFFIX`, in the mod's
    `i18n/en.po`. It is set on every `tuningChanged`, which a row emits when it changes and when it gets the focus
    (`Tuning.gd` `tuningChanged` does the same with `<key>_DESC`). Every setting has one, written as the game's
    `TUNE_*_DESC` are: what it does, a blank line, then the details. DiveSkipTransit has it; CrewCheapHireNotifier
    doesn't yet, to add when it next changes. DealerNotifier's rows are ship models, all of one setting: its window,
    framed as the Dealer screen's, shows the game's own description of the selected ship, as the Dealer does
    (`<shipName>_DESC`), and its setting's description is a note between the window and the list.
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
  its name and never repeat its value or a figure computed from it. The one exception is the users' wiki, which shows
  players the values they meet: each page lists every value it shows in its values block, and `wiki.ps1` fails when
  one no longer matches the code (see *The users' wiki*). The tests read constants from the mod (`_const`
  in `units.gd`, the instance in `lidar.gd`, the script's constant map in `hud.gd`) and build their layouts from them,
  so another value of a constant still passes. Base-game values a modder would have trouble finding may be quoted
  (the arm's 45 m reach; the game shows 10 world units as 1 m). The arm diagrams, whose legends show values of their
  mods' constants, are pictures of the users' wiki, listed in their pages' values blocks.
- Read values from the game (the ship's nodes and collision shapes, scene files, the arm's own properties), never
  from per-ship tables. A constant is only a fallback for when the game data can't be read (`CHUNK_RADIUS_FALLBACK`).
- Game behaviour a mod relies on is cited with the game file and function it comes from (`Game.gd`
  `_respawn_ship`, `hud/SystemList.gd`). Check it in the decompiled source, not from memory.
- Versions follow [semver](https://semver.org): **major** for a change that breaks what players or modders rely on
  (a feature removed or changed incompatibly, saved settings that no longer load), **minor** for new behaviour or
  settings that keep the old working, **patch** for fixes and for changes with no visible effect (a file renamed,
  code moved between files). Every zip released gets a new version, and a released version is never changed.
  A new mod always starts at **0.0.0**. Going to 1.0.0 comes with a clean-up: all logging removed, the code
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
  touches (`DockingArm`, `Hud`), `manifest_version = 2.2`. The game's modding wiki has an outdated manifest format; follow
  [DVTools](https://github.com/rwqfsfasxc100/DVTools).
- README layout: `# <ModName> - ΔV: Rings of Saturn`; the summary (no version), with its images, if any (kept in
  `_wiki\images\` and linked from there, see *The users' wiki*, so the zip carries none); for a mod
  that changes how the game plays in a dive, *Warning*: in short, what it changes compared to vanilla, and to check a
  bug without the mod before reporting it to the game's developers; *What it does and why* (What / Why bullets); *For
  modders* for script extensions (what is extended, overrides, new members, constants, how it was tested); *Install*
  (three steps; the second, the same in every README, is "Put the mod's zip in it, and remove any other version of
  the mod from there: they would all load. Do not unzip it."; the third, `--enable-mods`); the "Mods are unofficial …
  Keep a backup of your save." line; *About* (made with the help of Claude; GPLv3). When the behaviour changes, update
  the README's text, *Warning* and figures too, and the mod's page in the users' wiki.
- The root `README.md`, this file, `_tests/README.md` and `_wiki\` are the repository's own (they ship in no zip, and
  `CHANGES.md` doesn't list their changes). Update the README's *Mods* table when a mod is added or removed or a mod's
  summary changes, and its *Mods that change how the game plays* when a mod gains or loses its *Warning*, and the
  wiki's Home and sidebar with them; update `_tests/README.md` with every change to the harness or its suites.

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
- **ATLAS**: an autonomous drone that hunts rogue AI; the ship has no name text in `en.po`, and calls itself an
  "autonomous Edge Runner" (`DIALOG_ATLAS_BEING_AUDITED_1`). ATLAS stands for the Artificial Threat Location and
  Apprehension Specialists (`DIALOG_ATLAS_WHATS_ATLAS_EXPLAIN`). Scene `ships/drone/ATLAS.tscn` (Shipyard model
  `ATLAS`): faction `ai`, no crew, two MWG emitters (see *EMP*), no EMP shielding.
  - Spawn: a random event of the rings (`AtlasRandom` in `story/TheRing.tscn`, a `story/RingRace.gd` with
    `racerModel = "ATLAS"`). It passes at any depth, with no roll and no chaos limit, so it spawns once every pass of
    the shuffled event list (see *Salvage*).
  - The audit (`comms/conversation/AtlasConversation.tscn`): curious about the player's ship, it comes to talk once,
    asking for an AT audit (Artificial Threat, `DIALOG_ATLAS_WHATS_AT_SCAN_EXPLAIN`). Granting access ends it with a
    scan and one of three random closing lines, none of which has an effect ("Autopilot shackles upgraded",
    `DIALOG_ATLAS_SHACKLES_ADJUSTED`, changes nothing). Refusing, or not answering within the line's `timeout`
    (30 s), brings a threat (`DIALOG_ATLAS_AUTHORIZED_FORCE`). Refusing again, or not answering, makes it hostile
    (`DIALOG_ATLAS_PREPARE_FOR_AUDIT`, `changeHostility`): it closes in and fires its MWGs (`ship-ctrl.gd`, the AI's
    hunter mode). After the line's `noReplyTimeout` (20 s) it declares the scan complete and stops being hostile
    (`DIALOG_ATLAS_SCAN_COMPLETE`). An ATLAS that is already hostile when it starts talking skips straight to that
    forced audit.
  - Crew agendas (see *EVA*): with the AI conspiracy theorist (`AGENDA_CONSPIRACY_AI_THEORIST`) in the dive crew, the
    player can ask for a human in charge; the agent recognises them and authorizes deadly force. With the android
    (`AGENDA_ANDROID`), they can answer for the ship (`AGENDA_ANDROID_ATLAS_PROTECTED`), and ATLAS lets it go. After
    an audit, the theorist complains (their morale drops by 0.2). If the android is there too and replies, the game
    grants the Short Circuit achievement (`ACHIEVEMENT_CREW_SHORTCIRCUT`).
  - Destroyed, it leaves an AI core (`ships/drone/AICore.tscn`, the ship's `lifepod`). The core is an oddity: an
    object the station pays a fixed price for when it comes back as cargo (`CurrentGame.isOddity`, `specialPrice`),
    here 250,000 E$ (`ODDITY_AICORE`, "Quantum computer retrieval reward"). The drone itself has a transponder, so
    holding it with the arm never adds it to the fleet (`CurrentGame.isShipSalvageable`, see *Salvage claim*).
- **Chaos**: no text of its own in `en.po`. A value from 0 to 1 for each spot of the rings: the red channel of the
  ring map (`ring/ring-map.png`, one pixel per km, depth across and the way around the ring down, wrapping), read by
  `TheRing.gd` `getChaosAt`; its blue channel is the density (`getRawDensityAt`). Random events of the rings need a
  minimum chaos where they spawn (each event's `chaosLimit` in `story/TheRing.tscn`; see *Salvage*). The dive entry
  point's Environmental damages fee (`MAP_FEE_ENVIRONMENT`) grows with chaos × density (`DiveTarget.gd` `getPrices`,
  `chaosPricePerChaos`), less the geologist's cut (see *Crew stats*), so of two spots of the same density the dearer
  is the more chaotic. By depth, on the 1.92.5 map: under 0.35 in the first 10 km; from 10 to 600 km about 0.35–0.4
  on average, 0.4 or more in 20–60 % of spots and 0.5 or more in under 10 %; deeper, 0.45–0.5 on average, 0.5 or
  more in 20–50 % of spots.
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
    that member's good morale and lowered by bad (see *Morale*; `CurrentGame.getCrewStats`).
  - Each occupation's talent and experience give one stat each, shown on Your Crew (`deriveStats`, `skillMatrix`).
    With no one of an occupation in the dive crew, its values are 0, and its stats still apply where 0 gives them a
    value.
    - Pilot. Adrenal slowdown (`CREW_STATS_PILOT_ADRENALINE`, from talent; see *Adrenaline*): game time at full
      adrenaline runs at 0.7 − 0.5 × talent of its normal speed, from 0.7 with no pilot to 0.2 (`getAdrenalSlowdown`,
      `BulletTimer.gd`); Your Crew shows it as the gain in the pilot's perception of time, 43 % to 400 %. Course
      anticipation (`CREW_STATS_PILOT_ANTICIPATION`, from experience): how far ahead, 4 s × experience, the pilot
      checks the ship's course for collisions; one foreseen raises adrenaline (`ship-ctrl.gd`
      `handlePilotAdrenaline`), so with no pilot only the other sources do.
    - Mechanic. Jury-rig efficiency (`CREW_STATS_MECHANIC_JURYRIG`, from talent; 25 % + 75 % × talent). Jury-rigging
      is the OMS Mechanic tab's slider on each kind of damage a piece of equipment can take, from -1 to 1; moving one
      moves the piece's others the opposite way by as much in total (`ship-ctrl.gd` `setSystemJuryRig`). A slider
      multiplies that kind's damage capacity by 1 + slider × efficiency, at least 0.1
      (`getCrewAdjustedJuryRigFactorForSystem`), and the damage counts against that capacity: at full efficiency the
      same damage counts half at 1 and ten times at -1. Repair limit (`CREW_STATS_MECHANIC_FIX`, from experience;
      71 % + 29 % × experience, at most 99.5 %; `getRepairLimit`): the Repairs screen offers Fix only for a piece
      whose condition is below it, and fixes it only up to it; past it, only Replace
      (`enceladus/SystemShipRepairUI.gd`). It counts the whole crew not on leave, not only the dive crew. How long a
      Fix takes depends on the number of mechanics, not on their stats (`getMechanicMultiplier`).
    - Geologist. Price prediction accuracy (`CREW_STATS_GEOLOGIST_PREDICTION`, from talent; 10 % + 80 % × talent). At
      the Mineral Market (see *Mineral*), the price forecast's error is (time ahead / 40 days)² / accuracy, and at 1
      the forecast is noise (`getMineralPricePredictionError`, `enceladus/MineralPriceChart.gd`): about 13 days ahead
      at 10 %, 38 days at 90 %. In a dive, each chunk's info box (`hud/MineralMark.gd`: the box the HUD shows by a
      chunk, with the mass of each mineral in it and its value) gets one random error within ±(1 − accuracy), from
      ±90 % to ±10 %, on both the masses and the value, and the ship records the chunk with those figures
      (`addIdentifiedObject`). Mineral discovery range (`CREW_STATS_GEOLOGIST_RANGE`, from experience;
      100 m + 1000 m × experience, 0 with no geologist in the dive crew): only chunks within it get an info box
      (`hud/AutopilotOverlay.gd` `geologistMineralMarkers`). It also sets how many past finds of each mineral the
      Geologist tab's mineral map keeps (`getMineralHistoryLength`, `hud/components/MineralMap.gd`).
    - Astrogator. Tactical awareness range (`CREW_STATS_ASTROGATOR_RANGE`, from talent; 500 m + 5000 m × talent, 0
      with no astrogator in the dive crew): ships, stations and other tactical objects within it that the LIDAR has
      seen get a marker with their transponder and name, the more likely the closer they are (a chance of
      (1 − distance / range)² at each check; `hud/AutopilotOverlay.gd` `astrogatorTacticalMarkers`,
      `hud/ShipMark.gd`). Coordinate tracking time (`CREW_STATS_ASTROGATOR_TIME`, from experience): how long trackable
      destinations stay usable, see *Astrogation*; the longer of 12 h and 90 days × experience.
    - Launch fees, on the dive entry point screen (see *Dive*; `DiveTarget.gd` `getPrices`): the dive crew's
      astrogator talent cuts the Xaser pathway burn fee (`MAP_FEE_DEPTH`), and its geologist experience the
      Environmental damages fee (`MAP_FEE_ENVIRONMENT`), each by 99 % × the value.
  - Salary: the occupation's base (`CurrentGame.baseSalary`: Pilot 1700, Mechanic 1500, Geologist 2400, Astrogator
    2100 E$) × (1 + bias + experience + 3 × talent)², the bias a random -0.5 to 0.5 per person
    (`getExpectedSalaryFrom`), so talent counts three times as much as experience. It is fixed when the person is
    offered, rounded up to 100 E$, and doesn't follow their growth; a raise request compares it with this figure
    (see *Morale*). Each candidate on the Hire screen gets talent and experience as a uniform random number squared
    (`randomizeAvailableCrewMember`), so most are low.
  - Growth (`giveXp`): a step of size x first pulls a value towards the best member of the occupation by
    `mentorXpGain` (0.5 %) × x of the difference, then closes `normalXpGain` (0.25 %) × x of what is left to 1.
    - Talent: one step per in-game day, wherever the ship is, for the whole crew, aboard, at the station or on leave
      (`daysPassed` → `grantXpAtStation`, despite its name). Alone, a member's gap to 1 halves in about 277 days.
    - Experience, from events: everyone aboard, a step of 0.5 about once a minute while the ship flies faster than
      5 m/s outside a cutscene (`ship-ctrl.gd` `handleExperience`); the pilot, the more the longer the ship has flown
      on through foreseen collisions without hitting anything (`leafOnTheWind`, reset by every impact); the
      geologist, for each chunk identified, more for a valuable one (`hud/MineralMark.gd`); the astrogator, for each
      ship identified (`hud/ShipMark.gd`) and each destination revisited after its deadline, more the later
      (`discoverPoi`); every mechanic hired, for each repair at the station, by its hours (`SystemShipRepairUI.gd`).
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
  `enceladus/SystemBuyUI.gd` (the ship-list mods change them); its Examine tab can launch the simulator.
  - The stock is stored nowhere: `CurrentGame.getShipsAvailableForSale` builds it anew on every call from the in-game
    day, the week and the save's `state.seed`. It holds a few models new every week (named in its code), one used ship a
    day kept 10 days (its model drawn from `CurrentGame.usedShipsPool`, by weight), and the ships the player sold
    (`state.soldShips`), for 10 days; ships the player owns are left out.
  - Only `Dealer.gd` `doAddShips` asks for it: when the station loads, every in-game hour (`hourPassed`) and when the
    screen opens; a dive doesn't, and nothing signals a change.
  - A ship's transponder is the same from one refresh, visit or save to the next (`getNewTransponder` is seeded), so it
    tells ships apart; `shipHashFromConfig` doesn't (it holds the moment the ship was instanced, `madeIn`).

  **Fleet**
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
- **Drones** (no key of their own; the word is in the NT Mining Companion's description, `SYSTEM_SCOOP_DESC`): small
  craft a ship launches from a cradle, equipment on a hardpoint, each a ship of its own (`ship-ctrl.gd`) with a
  transponder made from the ship's by the cradle's `ships/modules/ClaimOwner.gd` (see *Transponder*). A physics frame
  after the cradle enters the tree, it lets its drone go into the ship's parent (`ClaimOwner.gd` `_ready`, unless the
  cradle has left the tree by then), so the drone outlives the ship's node: whoever takes a ship out of a scene takes
  its drones out too (`Upgrades.gd`'s preview removes every rigid body; DealerNotifier frees each picture's whole
  viewport). The THI Cargo
  Container and THI Monocargo Container (`SYSTEM_EXSTORAGE`, `SYSTEM_EXMONO`; `ships/drone/StoragePod.tscn`,
  `StoragePodMono.tscn`) are storage pods that carry processed ore back to the station; the NT Mining Companion
  (`SYSTEM_SCOOP`, `ships/drone/CargoScoop.tscn`) is a mining drone; the B8 Claim Beacon (`SYSTEM_CLAIM`,
  `ships/drone/ClaimBeacon.tscn`) holds the player's excavation claim on a spot of the rings. The External Impact
  Absorber (`SYSTEM_HUNK`, `ships/modules/Hunk.tscn`) hangs in a cradle too, but is a block, with no transponder.
  Not drones in this sense: the nanodrones (`SYSTEM_DND_*`, the MPI Tug, MLF Haul and OME Maintenance drones,
  `weapons/drone-plant.gd`), which the drone plant draws and which aren't objects of their own; and the NPC drones
  (the racing drone and ATLAS, built by the Shipyard; locusts, berserk drones and mines in some events).
- **E$**: the game's currency.
- **EMP**: electromagnetic damage to a ship (`ship-ctrl.gd` `applyEmpDamage`); no key of its own, the word is in
  Short Circuit's tooltip (`DAMAGE_SHORT_CIRCUIT_TOOLTIP`, "Caused by EMP damage."). Sources: the MWG microwave
  emitter (`SYSTEM_MWG`, `weapons/emp.gd`; the ONMWG-650 turret, `SYSTEM_PDMWG`, is built on it), whose EMP is its
  draw × 0.9 × (1 − its Water Resonance tuning, `TUNE_EMP_RESONANCE`), up to about 61 MW; the SPC Gungnir
  (`SYSTEM_SYNCHRO`, `weapons/synchrotron.gd`), a quarter of its charge in one frame; ring storms
  (`story/RingStormManager.gd`: arcs that a storm beacon, `story/StormBeacon.tscn`, strikes between two objects, a
  weak corona for a few seconds, then a discharge of up to 2 s); the Singularity Core, 5 MW on everything within 40 m
  (see *Hybrid*); and, in one go, some conversation lines (`damageEmp`) and the derelicts as they spawn (`extraEmp` in
  `RescueOperation.gd`, `AgendaSpecificDerelict.gd`).
  - EMP shielding (in the Dealer's specs, "EMP shielding: 100 MW"; no key of its own): the ship's `empShield`, the
    larger of its scene's value and its config's `shielding.emp`. It comes with the hull: no equipment changes it.
    Each hit loses the shielding's MW over that frame (`empShield × 1000 × delta`; 1000 per second is 1 MW, the scale
    the MWG's Tuning shows), and only the rest gets through, so it stops continuous sources up to that power and
    barely touches one-frame ones. It applies per hit: two sources at once are each cut by the whole of it. The
    Hybrid has 500 MW (the config its random event gives it, see *Hybrid*); the Runasimi KR37 TNTRL 200 MW; the
    Cothon-212, the Cothon-211 "Chonker", the Cothon-217 "Bender" and the Antonoff-Titan K225 (modified) (the
    derelict of the sibling agenda, see *EVA*) 100 MW; the Cothon-213 "Triplet" and every other ship model none.
  - What gets through (the `damageEMP` signal): Short Circuit (`DAMAGE_SHORT_CIRCUIT`) on the HUD, which falsifies its
    readouts and may reboot it on each hit, the likelier the more damaged (`hud/Hud.gd` `_on_emp`); Pump Failure
    (`DAMAGE_LASER_PUMP`) on the lasers (`weapons/laser.gd`: the CL-150, the CL-600P, the laser turret); and, near a
    fission reactor, an emergency shutdown (`Reactor.gd` `_on_emp`, with the EMP falling off with the square of the
    distance from the reactor): the reactor disengages instead of engaging while the EMP lasts, so the ship loses
    power. The EIME's fusion reactor ignores EMP (`FusionReactor.gd`). The hull's sparks and their crackle (`empLevel`)
    are only effects.
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
    ghost ship). Which models are derelicts, where they come from and how often: see *Salvage*.
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
- **Frozen bodies** (corpses; `ODDITY_DEAD_BODY`, "Evidence gathering reward"): dead people floating in the rings,
  oddities (see *Oddity*). Groups of 2 to 9 (`story/DeadBody.gd`, one of `story/body1.tscn`–`body10.tscn` each, on
  `story/body.gd`) drift around a talking beacon (`story/DeadTalkingBeacon.tscn`), in chaotic parts of the rings or on
  any spot from 25 October to 1 November by the computer's clock (`canBeAt`); up to 19 more float around the destroyed
  habitat (`story/habitat/DestoryedHabitat.gd`) until one is picked up. A body's transponder is its group's (one
  random code, which the beacon shows bare) plus its initials (`body.gd` `getTransponder`); its name is a random crew
  name. Picking one up gives the achievement `DISCOVER_FROZEN_BODY`.
- **Geologist**: the crew occupation for mining, and the OMS tab with the cargo's composition and the mineral
  targeting: which minerals the HUD marks, and their Minimum value (`HUD_MIN_PRICE`), kept in the HUD's
  `mineralConfig`.
- **Hardpoint**: a ship's mount for a piece of equipment: high-stress, low-stress or spinal. Only high-stress ones
  take the arm. In the ship's scene each is a `ships/WeaponSlot.gd` node, inline (some nested, the ND-LIS Kitsune's is
  `Front/WeaponSlot`) or a placeholder of `weapons/WeaponSlot.tscn`, which stores only the values it overrides
  (RA-TRTL's and the Vulture Prospector's main hardpoint leaves `slot` to the scene's own, `main`). In the ship's config
  `weaponSlot.<slot>.type` holds what is mounted. A hardpoint the config names nothing for gets its node's `default`
  when the ship enters the tree: `SYSTEM_NONE`, nothing, on every model the dealer sells. The Equipment screen offers
  None on every hardpoint, free, as its default (`enceladus/Upgrades/WeaponSlotUpgrade.tscn`).
- **Hire screen** (`ENCELADUS_CREW_HIRE`, "Hire"; also the Hire list): the Crew screen's tab of the people for hire
  that day, the `HireableCrew` node of `enceladus/Crew.tscn` (`enceladus/HireableCrew.gd`), filled from
  `CurrentGame.getAvailableCrew()` on the first show and every in-game day. One entry per person
  (`enceladus/CrewBio.tscn`, `CrewBio.gd`): their skills compared with the crew's, name, occupation, education,
  experience, salary, portrait, and a Hire button (`CREW_HIRE`, the entry's `hireButton`), disabled while the
  player can't pay the salary.
- **HUD**: the ship's flight display (`hud/Hud.gd`), laid out per ship model in `hud/Display-<model>.tscn`.
- **Hybrid** (players call it the dorito): a ship that matches no known model, with no name text in `en.po`. Scene
  `ships/HYB-based.tscn` (Shipyard model `HYBRID`), faction `secret`. It flies with an ordinary transponder and ship
  name, and can't be hailed (`hailable`). Its reactor shows a Singularity Core that spins faster the hotter the
  reactor runs (`ships/Artifact.gd`).
  - Spawn: a random event of the rings, `HybridHunterHuntingPlayer` in `story/TheRing.tscn`
    (`story/HybridHunter.gd`), only where the chaos is above 0.3 (see *Chaos*). It never spawns on the Peaceful
    difficulty (`SETTINGS_DIFFICULTY_0`). On Balanced (`SETTINGS_DIFFICULTY_1`) it needs the player to have at least
    30,000 E$ and their ship's combat capacity to be at least 0.6. Combat capacity (`getCombatCapacity`,
    `getRealStatus`) is the condition of the ship's worst piece of equipment, doubled and capped at 1, less the share of
    its pieces switched off: 0.6 needs every piece at 30 % or better and none switched off. The event fits it with one
    MWG and 500 MW of EMP shielding, which stops any MWG's EMP (see *EMP*).
  - Behaviour: its faction's disposition towards the player (`keepsecret` in `Factions.gd`) is mostly curious and
    partly hostile. It first comes close to look at the player's ship. A crew member with one of five agendas (see
    *EVA*) may remark on it (`comms/conversation/HybridEnconters.tscn`: `AGENDA_EX_PIRATE`, `AGENDA_LOOKING_FOR_CHILD`,
    `AGENDA_ANDROID`, `AGENDA_HAS_CAT`, `AGENDA_SINGER`; the android's line, `AGENDA_ANDROID_HYBRID_SHIP`, is "This
    doesn't match any signature I know of."). Once it has looked, it attacks with its MWG (`ship-ctrl.gd`, the AI's
    choice of action). It only fires while its hostility, scaled by its own combat capacity and by the distance, is
    above `aiHostilityToFire`, so a damaged one stops firing.
  - Destroyed, it leaves its Singularity Core (`story/SingularityCore.tscn`, `story/SingularityCore.gd`; the ship's
    `lifepod`). The core is an oddity: an object the station pays a fixed price for when it comes back as cargo
    (`CurrentGame.isOddity`, `specialPrice`), here 1,000,000 E$ (`ODDITY_SINGULARITY_CORE`, "Research material").
    While the core floats loose, two gravity areas (`Attractor`, `Repellant`) pull objects in from a few hundred
    metres and push back those that come within 50 to 90 m. The core also puts out 5 MW of EMP (`empPerSecond`) on
    everything within 40 m (`EmpArea`), and plays the game's mystery music. In a cargo hold the pull and push stop,
    but the EMP doesn't (`setInCargoHold`). Taking it in gives the achievement A touch of Singularity
    (`ACHIEVEMENT_TOUCH_SINGULARITY`).
  - The same core also floats free, among 2 to 9 iron chunks, in another random event of the rings, `Singularity`
    (`story/Singularity.gd`): only where the chaos is above 0.5 and no other event is within 2 km.
  - The ship has a transponder, so holding it with the arm never adds it to the fleet (`CurrentGame.isShipSalvageable`,
    see *Salvage claim*).
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
- **Lifepod** (`ODDITY_LIFEPOD`, "Lifepod rescue reward"): an escape pod, `ships/Lifepod.tscn`, a ship of its own
  (`ship-ctrl.gd`) and an oddity (see *Oddity*). A ship whose scene names a `lifepod` leaves one when it explodes
  (`ship-ctrl.gd` `vanish`), with the ship's transponder, faction and speed: every ship model has one but the
  Tsukuyomi, the racing drone and the Obonto habitat. Others float alone in the rings (`story/LifepodIsFloating.gd`)
  or are a pirate's bait (`story/PirateTrap.gd`, `ships/LifepodTrap.tscn`); a lone one gets a random transponder
  (`ships/LifepodFeedback.gd`). A pirate's own lifepod (`ships/LifepodPirate.tscn`) is a bounty
  (`ODDITY_LIFEPOD_BOUNTY`). It talks to the ship that picks it up (`comms/conversation/LifepodConversation.tscn`,
  `DIALOG_LIFEPOD_*`). The ATLAS drone leaves an AI core instead (`ships/drone/AICore.tscn`, `ODDITY_AICORE`,
  "Quantum computer retrieval reward").
- **Mechanic**: the crew occupation for repairs, and the OMS tab listing the ship's equipment, to switch each piece
  on and off and fix it.
- **Mineral**: what a chunk is made of, named in code by its element symbol (`mineral = "PT"`). Processed ore
  (`HUD_CARGO_LIST_PROCESSED`) is what the MPU has extracted; it is sold or stored at the **Mineral Market**
  (`ENCELADUS_MINERAL_MARKET`).
- **Morale** (crew happiness): each crew member's mood, `morale` in their entry of `CurrentGame.state.crew`, from
  -0.5 to 0.5 (`changeCrewMorale` clamps it), 0 for a new hire. It has no text in `en.po` and no number on screen.
  The crew line-up at the station (`enceladus/CrewFaceOnEnceladus.gd`) shows a happy icon above `moraleLimit` (0.3)
  and a sad one below minus that. The dive HUD's crew faces (`hud/CrewFaceOnDive.tscn`) hide both icons.
  - Effect: the crew stats use the exponent `1 - morale` on the member's talent and experience (`getCrewStats`). At
    0.5 a talent of 0.5 counts as about 0.71, and at -0.5 as about 0.35. The Hire screen's comparison leaves morale
    out (`CrewBio.gd`). Some crew conversations need it inside a range (`maxAgendaMorale` / `minAgendaMorale`,
    `comms/ConversationPlayer.gd`). A crew member asks for a raise (`DIALOG_NEED_RAISE`) only when their morale is 0
    or less and their salary is below the market's (`getExpectedSalaryFrom`). If the player refuses and their morale
    is -0.4 or less, they quit and are fired on the spot (`DIALOG_RAISE_I_QUIT`).
  - Drift: every in-game day, morale closes 5 % of the gap to a target (`erodeCrewMorale`, `moraleErodePerDay`), so it
    halves in about two weeks. For the dive crew, from launch to return (transits included), the target is the ship's
    `crewMoraleBonus`: the Eagle-Prospector-VP -0.3, the Eagle-Prospector-Lux 0.4, the OCP-209 0.3, other ships 0.
    Everywhere else the target is 0, except during a hotel stay.
  - Changes: the station's Services screen (`ENCELADUS_SERVICES`, `enceladus/ServiceUI.gd`, `Services.tscn`; paid
    bars, hotels and other services). A hotel stay sets the target to its `moraleStay` for the hours it lasts. Some
    services also add their `moraleChange` at the end to the crew not on leave: The Twins (a bar, 4 h, once a day)
    adds 0.1. Moonview Capsule Hotel (24 h) sets the target to 0.2. The Underside Inn (168 h) sets it to 0.2, then
    adds 0.1. SkyDome Resort (72 h) sets it to 0.3, then adds 0.15. Conversations also change morale
    (`adjustGlobalMorale` for the crew aboard, `adjustAgendaMorale` for one member). A round of drinks at a space bar
    (`DIALOG_SPACE_BAR_ROUND_OF_DRINKS`) gives everyone 0.2. Agenda events (see *EVA*, *Crew agendas*) give or take up
    to 0.5 from that member, and a refused raise takes 0.2. When the player can't pay a member's wages, which are due
    every 30 days, that member loses 0.05 every in-game hour at the station (`payWages`, called from `Enceladus.gd`).
    At 45 days past due (`baseCrewPatience`) they are fired.
- **MPU** (`SYSTEM_CARGO_MPU*`, `ships/modules/MineralProcessingUnit.gd`): the Mineral Processing Unit, which turns
  the chunks taken in into processed ore and, in most models, their water into remass.
- **Oddity**: an object worth a reward of its own (`specialPrice`, named by its `specialName`): a lifepod, a frozen
  body, an AI core and others. One the arm holds when the dive ends goes into the cargo (`ship-ctrl.gd`
  `handleExitToEnceladus`) and is sold for its reward (`CurrentGame.gd` `getMarketPrice`).
- **OMS** (`HUD_OMS`, `hud/OMS.gd`, `hud/OMS.tscn`): the Onboard Maintenance System, the console opened with `J` in
  flight. Its tabs are named by the crew occupation keys: Mechanic, Astrogator, Geologist, Pilot. The Pilot tab (the
  pilot screen) lists what the ship has identified (`hud/ShipList.gd`, the ship's `identifiedShips`): every object
  with a transponder the LIDAR has swept, and what the astrogator's marks name (`hud/ShipMark.gd`), each with its name
  and transponder, a button to hail it (`HUD_HAIL`), its bearing and distance and its IFF.
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
- **Salvage** (`POI_SALVAGE`, "Salvage: {0}"; the `ACHIEVEMENT_SALVAGE_*` achievements, "Recover a derelict ship"):
  taking a derelict (see *EVA*) into the fleet, by holding it with the arm until the dive ends at the station or by
  sending a crew member over to restart it (see *Salvage claim*). Only the models below are ever derelicts; pirate
  ships are salvageable too (`CurrentGame.isShipSalvageable`), but only once disabled in combat. Derelicts come from:
  - **Random events of the rings** (`story/TheRing.tscn`, `TheRing.gd` `getOddityAt`, asked by the asteroid field for
    a spot near the ship). The ring scene spawns one only after 600 in-game seconds of flight since the last
    (`odditiesEvery`; astrogation restarts the count, cutscenes don't count), once the basic tutorial is done, while
    no other ship is around (`suppressEventIfShips`), and deeper than the edge limit (4 km at the start of a game,
    shrinking to 0 over 300 in-game days; shallower, only miners come). The events, about a hundred, are walked in a
    shuffled order, each tested once per pass, and the first that passes spawns. A derelict's event passes with a
    chance of base × (1 − cash / ceiling), at least 10 %, where cash is the E$ in hand (`CurrentGame.getMoney()`,
    without insurance), and only where the chaos (see *Chaos*) is at least its limit (`story/RescueOperation.gd`
    `canBeAt`). Base, ceiling and chaos limit, by series, with the names the game shows:
    - TNTRL: K37 TNTRL (80 %, 5 million E$, 0.2); KX37 TNTRL, Runasimi KR37 TNTRL, KTA24 TNTRL and K44 MHFTR
      Prototype (40 %, 5 million E$, 0.2 each). Two more K37 TNTRLs come with a rescue ship (see *Salvage claim*):
      one beside it (`RescueOperation`: 100 %, 10 million E$, any chaos), and one on a lone rescue ship's path
      3 minutes after it spawns, if it is still there (`story/FlightForRescue.gd`, always). The rescue ship is often
      in sight when the derelict talks, and then only the arm can take it.
    - Eagle Prospector: Eagle Prospector (100 %, 10 million E$, 0.4); Peacock Prospector, Vulture Prospector (the
      VP, `ships/Eagle-Prospector-VP.tscn`) and Pelican Prospector (50 %, 10 million E$, 0.4 each).
    - Cothon: Cothon-212 (80 %, 10 million E$, 0.3); Cothon-211 "Chonker", Cothon-213 "Triplet" and Cothon-217
      "Bender" (40 %, 10 million E$, 0.3 each).
    - Antonoff-Titan K225 and Eon Interstellar Model E, the EIME (50 %, 2 million E$, 0.5 each); Antonoff-Titan
      K225-BB, ND-LIS Kitsune and OCP-209 (30 %, 2 million E$, 0.5 each).

    The derelict is a random used build of its model (`ships/Shipyard.gd` `createShipBuildByName`), so its equipment
    varies, with its reactor off, no remass and, from these events, a random kinetic and EMP hit
    (`applyExtraDamage`).
  - **Scrapwright Recovery Operations** (`SERVICE_SALVAGE_LICENCE`, SRO): a subscription on the station's Services
    screen (see *Morale*), 300,000 E$ for 30 days (`enceladus/Services.tscn`). While it lasts, three more random
    events (`SalvageCall`, wherever the chaos is above 0) spawn a beacon whose broadcast
    (`comms/conversation/SalvageBanter.tscn`) lists two derelicts, sometimes three, as destinations (see
    *Astrogation*) 100 to 1,600 km away, for 24 h. Each listing is one of 50 lines of equal weight, three per model
    above (two for the K225-BB, none for the K44 MHFTR), offered only if that model's event passes its test at one of
    three random spots. At the spot, the derelict then spawns without a further roll.
  - **Conversations** that reveal a destination, where the derelict spawns without a roll: crew chatter
    (`DIALOG_POI_RANDOM_2`: a K37 TNTRL 10 to 100 km away); a rescue ship asked "Seen anything worth salvaging?"
    (`DIALOG_HELPER_SALVAGE_ANY`, one of its four answers: a K37 TNTRL 25 km away, offered only if its event passes
    there); the same answer to a member looking for their child who asks a rescue ship for clues (see *EVA*); and
    pirates friendly enough to talk business (`DIALOG_PIRATE_BUSINESS_SHIP_*`: a K37 TNTRL, a Cothon-212 or an Eagle
    Prospector about 500 km deeper, for 200,000 E$, kept for 7 days). The sibling's ship (see *EVA*), an
    Antonoff-Titan K225 (modified) with full remass and no extra damage, comes only that way
    (`story/AgendaSpecificDerelict.gd`).
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
- **Ship models**: the kinds of ship, each with a key in `Shipyard.ships` (`TRTL`, `PROSPECTOR-VP`, …), a scene
  (`ships/RA-TRTL.tscn`) and the translation key of its name in the ship's `shipName` (`SHIP_TRTL`). The Dealer shows
  the names: K37 TNTRL, Eagle Prospector, Vulture Prospector, EIME (Eon Interstellar Model E), OCP-209, the Cothons,
  the ND-LIS Kitsune, …. These docs also name some by their scenes: the Eagle-Prospector-VP (the VP) is the Vulture
  Prospector, the Eagle-Prospector-Lux the Peacock Prospector.
  - A **series** is a base model and its variants, as `Shipyard.gd` `configAlias` folds each variant into its base
    model (`getShipAlias`); a variant's `baseShipName` is its base's name. In game 1.92.5: K37 TNTRL (KX37, Runasimi
    KR37 and KTA24 TNTRL, K44 MHFTR Prototype), Eagle Prospector (Vulture, Peacock and Pelican Prospector), Cothon-212
    (Cothon-211 "Chonker", -213 "Triplet", -217 "Bender"), Antonoff-Titan K225 (K225-BB, K225 (modified)); the other
    models are alone in theirs. Which models the dealer offers: see *Dealer*.
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
- **Transponder** (no key of its own; the word is in many lines, `{origin/transponder}`): the code a ship or object
  broadcasts. The Dealer and Fleet show it as Registration, and the HUD's ship marks, the LIDAR's labels, the OMS
  Pilot tab, comms, the dive's title card and the save slots show it too.
  - The game's codes: one of five prefixes, a dash and four digits (`CurrentGame.gd` `getNewTransponder`: `SE1`,
    `JG4`, `ETH`, `MRS`, `BLT`), from a seed. The prefixes read as a place of registry: a crew member reads `SRA-01`
    as "Saturn, Ring A, station 01" (`AGENDA_LOOKING_FOR_SIBLING_TAXI_JOB_HABITATS`). A ship the Shipyard builds gets
    its code through `getTransponder`, which keeps it in the save against the ship's build (`state.transponders`), so
    a ship met again has its old code; the player's first ship gets one on a new game.
  - A ship keeps its code for good (its config's `transponder`). The game makes the ship's name from it
    (`generateShipNameFromTransponder`, kept in `state.shipNames`) and its captain's and crew's names in comms
    (`getCrewMember`), picks some lines by it, and keeps what it remembers about the ship by it (dispositions,
    encountered ships).
  - Codes made from a ship's: its lifepod's is the ship's; a drone's is `<ship>-CC42` (`ClaimOwner.gd`); frozen
    bodies take their group's plus initials. Fixed codes: the stations (`IRRS-*`, the habitats `SRA-01`–`SRA-07`)
    and beacons (`SE1`, `SE1-SG`).
  - Pirates broadcast none (`ship-ctrl.gd` `getTransponder` returns ""; the LIDAR's tutorial sticker,
    `TUTORIAL_STICKER_LIDAR`, says "NO TRANSPONDER - pirate RUN!").
  - AltTransponderCodes makes new codes say what carries them.
- **Tuning** (`ENCELADUS_SHIP_TUNING`, `enceladus/Tuning.tscn`): the station screen with the settings of each piece
  of the current ship's equipment, registered by its script with `registerSubsystem` and saved with the game (see
  *Conventions*).
- **Xenon drive**: the low-thrust, economical drive every ship has for transit, which burns no remass (the game keeps
  no stock of xenon). Its Tuning setting, Interplanetary Xenon transit drive usage (`TUNE_XENON_BURN`, a HUD built-in:
  `hud/Hud.gd` `getTuneables`; 0–100 %, default 100 %, kept per ship), is the share of the outbound ΔV it covers
  (`ship-ctrl.gd` `getXenonBurnRatio`); the main drives cover the rest. The trip back ignores it (see *Transit*).

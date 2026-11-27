# ΔV: Rings of Saturn mods - for modders

For those who read or change the code: how the repository is laid out, how the game loads a mod and how these mods
hook in, packaging and releasing, the users' wiki, the conventions they follow and the game's terms. The mods
themselves, and how to install them, are in the [README](README.md); how the game works behind its terms, in
[GAME.md](GAME.md); the test harness, in [`_tests/README.md`](_tests/README.md).

## The repository

The mods are written in GDScript for the game's engine, Godot 3. Each top-level folder not starting with `_` or `.`
is one independent mod and ships as one zip. There is no build system: `package.ps1` builds a mod's release zip, and
`release.ps1`, run by `.github\workflows\release.yml` on every push to `main`, publishes the mods' new versions as
GitHub Releases (see *Packaging and releasing*), `_tests\` is a test harness for most mods (see *Testing*), `_bench\`
simulates the nanodrones at work to tune DroneAltPriorities (see *The drone bench*), and `_wiki\` is the users' wiki,
checked by `wiki.ps1`, published by `.github\workflows\wiki.yml`, with its screenshots of the station, the OMS and the
HUD taken by `_shots\shots.ps1` (see *The users' wiki*). The source has been in git since 14 Nov 2026, and
`.gitignore` keeps out every zip, so the versions released before that exist only as release zips. Later changes are
in the git history and, from 1.0.0 on, in each mod's `CHANGES.md`.

## Folders outside the repo

The folders outside the repo differ per machine, so they are set in `paths.local.psd1` at the repo root, which is
git-ignored: copy `paths.example.psd1` to it and set yours. These docs name them by its keys: `TempDir\gdre` means
the `gdre` folder under `TempDir`. `_tests\run.ps1`, `package.ps1`, `release.ps1`, `wiki.ps1`, `_shots\shots.ps1`,
`_bench\bench.ps1` and `_bench\analyze.ps1` read the file, and in PowerShell
`$paths = Import-PowerShellDataFile .\paths.local.psd1` (from the repo root) gives `$paths.GameDir` and the others.
Never write their values into a committed file.

| Key or path | What |
|---|---|
| `GameDir` | The game (`Delta-V.exe`, `mods\`) |
| `TempDir\gdre\Delta-V-<version>\` | The decompiled game, one folder per game version (1.91.61, 1.92.5 and 1.93.1 so far) |
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
  itself (TransponderAltCodes extends `CurrentGame.gd`; its throwaway instance is safe because the game's script has
  no `_init` and no initializer that needs another autoload).
- `modLoader.installScriptExtension(path)` loads the child script, makes **one throwaway instance** of it (its
  `_init` runs with no scene or ship), then `take_over_path`s the parent's path: everything loaded afterwards gets
  the child. A second mod extending the same game script extends the first mod's extension. The throwaway instance
  is never freed, and it is what keeps the child script alive: freed, the script goes too and later loads get the
  game's script back (tried in the harness).
- Installing an extension from `_init` also loads, there and then, its parent script and whatever that script
  preloads (scenes, and the scripts their nodes hold), and the child's own preloads: all of it before the mods after it
  in path order install theirs. A scene loaded then keeps the scripts it was loaded with, so a later extension of one
  of them misses it. `ships/Shipyard.gd` preloads every ship scene: extending it would make every ship miss the later
  mods' extensions of ship scripts (CombatSimulator `WeaponSlot.gd` and `PDT.gd`, DiveSkipTransit `ship-ctrl.gd`,
  DiveDisableAdrenalineBooster `CabinLight.gd`, DroneAltPriorities `Hud.gd`, GeologyByMass `ship-ctrl.gd` and `Hud.gd`,
  LidarContactCallout `Hud.gd`, LidarLouderPing `LIDAR.gd`, TurretLockableFacing `PDT.gd` and `SystemList.gd`,
  WeaponMaxPowerSwitch `ship-ctrl.gd` and `SystemList.gd`).
  That is why CombatSimulator has no Shipyard extension; none of the game scripts the mods extend preloads a ship
  scene.
- `Mod.manifest` is not read by the game's loader.
- The loader also has `addTranslationsFromCSV`, `appendNodeInScene` and `saveScene` (unused so far; the harness's
  loader offers `addTranslationsFromCSV` too). **`addTranslationsFromCSV` reads nothing from a mod's zip**: a file in
  a zip reports its end before the first read (`eof_reached()` is true right after `open`, false after one `get_8()`),
  and `get_csv_line` checks for the end before reading (found in the harness's Godot 3.6). A mod's texts go in a
  `i18n/<locale>.po` loaded with `TranslationServer.add_translation(load(...))`, as the game loads its own `.po` files
  (LidarLouderPing).

## The two ways these mods hook in

1. **Script extension**: each extension file `extends "res://<game script>"`, and `ModMain.gd`'s `_init` only calls
   `installScriptExtension("res://<ModName>/<file>")` for each, in the order below (for the mods that extend
   `CurrentGame.gd`, before the engine creates the autoload), and, in a mod with texts of its own, loads its
   `i18n/en.po` (see *How the game loads a mod*). The mods, each file → the game script it extends:
   - ArmAltPullBehavior and ArmAltTargetSelection: `Code.gd` → `ships/modules/DockingArm.gd`.
   - BootSkipLogos: `Code.gd` → `Boot.gd`.
   - CombatSimulator: `CurrentGame.gd` → `CurrentGame.gd` (the autoload, which holds the running arena and keeps what
     its ships do out of the save); `Code.gd` → `enceladus/Enceladus.gd` (the station, where Shift+Click on the
     simulator's buttons, or Shift plus its key, or their gamepad twins, opens its dialog, and Start runs its arena, a
     layer of the station's); `PauseMenu.gd` → `PauseLayer.gd` (the pause menu, whose station copy opens the arena's end
     confirmation during a run); `Hardpoint.gd` → `ships/WeaponSlot.gd` and `Turret.gd` → `ships/modules/PDT.gd` (the
     hardpoints and turrets, for its disabled weapons); `HudRingMap.gd` → `hud/Video.gd`, `HudGravimetric.gd` →
     `hud/GravimetricReadout.gd` and `MassDriver.gd` → `weapons/massdriver.gd` (the HUD's ring map, its gravimetric
     readout and the mass driver's reload sound, which the game keeps for a ship in the rings).
   - CrewCheapHireNotifier: `Code.gd` → `enceladus/EnceladusMenu.gd` (the Crew entry; it also adds its settings screen
     to the station's right-hand screens, the children of `enceladus/HidingMarginContainer.gd`, copying the Tuning
     screen's frame and behaving like the game's screens); `HireScreen.gd` → `enceladus/HireableCrew.gd` (the Hire
     screen).
   - CrewPerfectSort: `HireableCrewSorted.gd` → `enceladus/HireableCrew.gd`; `CurrentCrewManagementSorted.gd` →
     `enceladus/CurrentCrewManagement.gd`; `EvaCrewSorted.gd` → `CurrentGame.gd` (the autoload, which picks the crew a
     derelict's conversation offers for an EVA).
   - DealerNotifier: `Code.gd` → `enceladus/EnceladusMenu.gd` (the Dealer entry's mark and Shift+Click, its settings
     screen copying the Dealer screen's frame); `DealerScreen.gd` → `enceladus/Dealer.gd` (the Dealer screen, whose
     refreshes tell it the stock).
   - DiveDisableAdrenalineBooster: `Code.gd` → `ships/CabinLight.gd`.
   - DiveSkipTransit: `Code.gd` → `Game.gd` (the ring scene's cutscenes, and the notices its notification panel still
     had to show when it goes to the station); `Station.gd` → `enceladus/Enceladus.gd` (the station's fade-in and
     launch sequence, and its notification panel, which shows those notices); `StationMenu.gd` →
     `enceladus/EnceladusMenu.gd` (Shift+Click on the dive entry opens its settings screen, as CrewCheapHireNotifier's
     Crew entry does); `Ship.gd` → `ships/ship-ctrl.gd` (astrogation).
   - DroneAltPriorities: `Code.gd` → `weapons/drone-plant.gd` (the nanodrone plants' choice of target); `OmsScreen.gd`
     → `hud/Hud.gd` (its OMS tab, added right after the Geologist tab as GeologyByMass adds its own).
   - GeologyByMass: `Code.gd` → `ships/ship-ctrl.gd` (the rule every row of the Geologist tab is judged by,
     `isValidMineralTarget`, and its switch that turns every mineral on in its tab when the player's ship is built for a
     dive, from `_ready`); `OmsScreen.gd` → `hud/Hud.gd` (its OMS tab, added right after the Geologist tab from
     `instance()`); `GeologistTab.gd` → `hud/SystemMineralList.gd` (the Geologist tab's rows, whose mineral switches and
     Minimum values it disables and dims while its switch is on).
   - LidarContactCallout: `Code.gd` → `hud/Hud.gd` (the player's HUD in a dive or a simulator, whose comms line it
     adds its callouts to, as `gotMessage` adds the game's lines).
   - LidarLouderPing: `Code.gd` → `hud/LIDAR.gd`.
   - MarketAdvisor: `Code.gd` → `enceladus/MineralMarket.gd` (the Mineral Market: the row of advice and the Trade
     button at its bottom, which trades through the market's own slider rows, the row under your cash in its header
     with what the ore it bought would sell for today, and Shift+Click on the Trade button, even disabled, opening its
     settings screen in the market's place, which copies the Mineral Market's frame and the Tuning screen's description
     window); `StationMenu.gd` → `enceladus/EnceladusMenu.gd` (the alert mark on the Mineral Market entry, which a
     setting switches off; the entry's Shift+Click is left free).
   - ServiceNotifier: `Code.gd` → `enceladus/EnceladusMenu.gd` (the alert mark on the Services entry, from the game's
     own rows of the Services screen, and Shift+Click on it opening its settings screen, which copies the Services
     screen's frame and the Tuning screen's description window).
   - ShipCopyPaste: `Code.gd` → `enceladus/SystemBuyUI.gd` (the Fleet screen's entries, whose buttons it also sets
     closer together; it prices through the Equipment screen's items).
   - ShipRepairAdvisor: `Code.gd` → `enceladus/Repairs.gd` (the Repairs screen: the row at its bottom, with the Repair
     button, which presses the screen's own Fix and Replace, its table, and the Park button, which also buys through the
     Equipment screen's items, after its confirmation; Shift+Click on Repair, or its gamepad twin, opening its settings
     screen in the Repairs screen's place, which copies the Repairs screen's frame and the Tuning screen's description
     window).
   - ShipSaleAdvisor: `Code.gd` → `enceladus/SystemBuyUI.gd` (the Fleet screen's entries: Sell's offer to prepare the
     ship first and its dialog, priced through the Equipment screen's items and the Repairs screen's rules; Shift+Click
     on Sell, or its gamepad twin, opening its settings screen among the station's screens, which copies the Fleet
     screen's frame and the Tuning screen's description window; and a note at the bottom of the Fleet screen).
   - TransponderAltCodes: `Code.gd` → `CurrentGame.gd` (the autoload, where the game makes transponder codes, with a
     `node_added` handler, as the observers below have, for the objects whose code is built from a ship's);
     `NewGamePlusScreen.gd` → `menu/NewGamePlus.gd` (the New Game Options screen).
   - TurretLockableFacing: `Code.gd` → `ships/modules/PDT.gd` (the gimballed mounts, of which it changes only the
     turrets of the player's ship, while its facing lock is on); `MechanicTab.gd` → `hud/SystemList.gd` (the OMS
     Mechanic tab's list: the facing lock's row, last, and its key, an input action of the mod's own that `ModMain.gd`
     adds).
   - WeaponMaxPowerSwitch: `Code.gd` → `ships/ship-ctrl.gd` (every ship's script, through which every system reads its
     Tuning, `getTunedValue`: the switch, and the cabin light's colour); `MechanicTab.gd` → `hud/SystemList.gd` (the
     OMS Mechanic tab's list: the switch's row, first, and its key, an input action of the mod's own that `ModMain.gd`
     adds).

   Rules that let mods stack on the same script (the arm mods' headers sum them up):
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
  rotors / excavator claws via `ship.hasSystem`, the claws kept per excavator: `_clawsOf`, `_targetingClawsOf`): change
  `_entry` and `_intakePosition` together.
- CrewCheapHireNotifier (`HireScreen.gd`) and CrewPerfectSort (`HireableCrewSorted.gd`) both extend `HireableCrew.gd`
  and both override `fillCrew`, each calling the parent's first: by path the chain is game ← CrewCheapHireNotifier ←
  CrewPerfectSort, and CrewPerfectSort only reorders the entries, so the marks stay (both orders tested in `crew`).
  Their member names must stay distinct.
- CrewHighlightJobAndSalary and CrewCheapHireNotifier (`HireScreen.gd`) both change the Hire screen's entries
  (`enceladus/CrewBio.gd`), each in its own way: CrewHighlightJobAndSalary, an observer, colours their Labels with
  `font_color` overrides, which a Label's children don't take; CrewCheapHireNotifier hangs its badge in the name's
  Label with colours of its own, so the badge keeps its look under the dimmed name.
- CrewCheapHireNotifier (`Code.gd`), DealerNotifier (`Code.gd`), DiveSkipTransit (`StationMenu.gd`), MarketAdvisor
  (`StationMenu.gd`) and ServiceNotifier (`Code.gd`) all extend `EnceladusMenu.gd`, each for its own menu entry
  (MarketAdvisor's: Mineral Market; ServiceNotifier's: Services), and each writes only its own entry's text. By path the
  chain is game ← CrewCheapHireNotifier ← DealerNotifier ← DiveSkipTransit ← MarketAdvisor ← ServiceNotifier; all
  override `_ready`, and all but DiveSkipTransit `_notification` (the game's script has neither), without calling the
  parent's. Their member names must stay distinct; opening one screen hides the others (`hidefoka`). Loaded together
  in `skip` (CrewCheapHireNotifier and DiveSkipTransit) and in `dealer` (all five, every order).
- CombatSimulator (`Code.gd`) and DiveSkipTransit (`Station.gd`) both extend `enceladus/Enceladus.gd`, the station: by
  path the chain is game ← CombatSimulator ← DiveSkipTransit. Both override `_ready` without calling the parent's;
  CombatSimulator adds `_input` (the game's script has none), DiveSkipTransit overrides `_on_DiveTarget_launch`. Their
  member names must stay distinct.
- CombatSimulator, CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit, MarketAdvisor, ServiceNotifier,
  ShipRepairAdvisor and ShipSaleAdvisor each ship the same `Badge.gd`, loaded from its own folder
  (`res://<ModName>/Badge.gd`), so the copies never clash: keep them identical (see *Conventions*, the gamepad twin).
  ShipSaleAdvisor uses its gamepad twin and small font, not its badge.
- CombatSimulator (`CurrentGame.gd`), CrewPerfectSort (`EvaCrewSorted.gd`) and TransponderAltCodes (`Code.gd`) all
  extend `CurrentGame.gd`, the autoload, from `_init`: by path the chain is game ← CombatSimulator ← CrewPerfectSort ←
  TransponderAltCodes. They override different functions (CombatSimulator `giveXp`, `setStory`, `recordEncounter`,
  `setDestinationHighlight` and `addShip`; CrewPerfectSort `getSpecificMemberNr`; TransponderAltCodes `_ready`,
  `getNewTransponder`, `getTransponder`, `validateState` and `createPlayerShip`). Their member names must stay
  distinct.
- DroneAltPriorities (`OmsScreen.gd`) and GeologyByMass (`OmsScreen.gd`) both extend `hud/Hud.gd` and both add an OMS
  tab right after the Geologist tab, each from its own override of `instance()`, which calls the parent's first and
  defers the tab: by path the chain is game ← DroneAltPriorities ← GeologyByMass, so DroneAltPriorities's deferred call
  runs first and GeologyByMass's tab ends up between the Geologist tab and DroneAltPriorities's (the other order swaps
  the two). Both keep their entries in the HUD's `mineralConfig`, each under its own mod id. Their member names must
  stay distinct. Loaded together in `drones` (every order). DroneAltPriorities's plants still ask the ship which chunks
  pass their row (`_dapCheck`), so with GeologyByMass's switch on, the identified chunks they rank are the ones its
  switches and masses let through (an unidentified one passes by the game's rule); the arm mods keep the game's
  `isValidTarget`, which asks the same.
- LidarContactCallout (`Code.gd`) extends `hud/Hud.gd` too, after both by path: game ← DroneAltPriorities ←
  GeologyByMass ← LidarContactCallout. It overrides `instance()` as they do, calling the parent's first and deferring
  its set-up, and adds no tab, so its place in the chain changes nothing. Its member names must stay distinct from
  theirs. Loaded together in `callout` (every order).
- DiveSkipTransit (`Ship.gd`), GeologyByMass (`Code.gd`) and WeaponMaxPowerSwitch (`Code.gd`) all extend
  `ships/ship-ctrl.gd`, every ship's script, from `_init`: by path the chain is game ← DiveSkipTransit ← GeologyByMass ←
  WeaponMaxPowerSwitch. They override different functions (DiveSkipTransit `fastTravelTo`, GeologyByMass
  `isValidMineralTarget`, WeaponMaxPowerSwitch `getTunedValue`); GeologyByMass also has a `_ready`, which Godot runs at
  every level, and the other two have none. Their member names must stay distinct. Loaded together
  in `geology` (the first two, both orders), and all three in `skip` and `power` (every order).
- DiveDisableAdrenalineBooster extends `ships/CabinLight.gd`, whose nodes WeaponMaxPowerSwitch (`Code.gd`) tints red
  while its switch is on (their `modulate` and their spotlight's `color`): DiveDisableAdrenalineBooster only switches the
  booster off when a dive starts (`enabled`), and the game's script never sets a colour, so both apply. Loaded together
  in `dive` and `power` (both orders).
- ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice find the ship entries by `node.get_script().resource_path`;
  ShipCopyPaste and ShipSaleAdvisor extend that script, and `take_over_path` keeps the path, so they still find them
  (loaded together in `fleet`). DealerNotifier reads the stock from the Dealer screen's entries in any order and hangs
  its badge in each entry's name, so it works with all three.
- ShipCopyPaste (`Code.gd`) and ShipSaleAdvisor (`Code.gd`) both extend `enceladus/SystemBuyUI.gd`, and change only the
  Fleet screen's entries (`owned`): by path the chain is game ← ShipCopyPaste ← ShipSaleAdvisor. Both override `_ready`
  and `_input` (the game's script has no `_input`) without calling the parent's; ShipCopyPaste overrides
  `checkCurrentAndOwned`, calling the parent's first, which ShipSaleAdvisor calls once Sell's offer is worked out;
  ShipSaleAdvisor overrides `_on_Sell_pressed`, falling through to the parent's, which ShipCopyPaste leaves alone.
  ShipCopyPaste gives `Use` and `Sell`, with its Copy, copies of their button styles with narrower side margins
  (`add_stylebox_override`), which ShipSaleAdvisor doesn't touch. Their member names must stay distinct. Loaded together
  in `fleet` and `sale` (both orders).
- CombatSimulator (`Turret.gd`) and TurretLockableFacing (`Code.gd`) both extend `ships/modules/PDT.gd`: by path the
  chain is game ← CombatSimulator ← TurretLockableFacing. They override different functions (CombatSimulator `fire` and
  `perhapsFire`; TurretLockableFacing `getTarget`, and `_ready` and `_physics_process`, without calling the parent's).
  CombatSimulator disarms a turret by zeroing `firepower`, which a locked turret fires with, so a disarmed turret stays
  disarmed. Their member names must stay distinct. Loaded together in `combat` and `turret` (both orders).
- TurretLockableFacing (`MechanicTab.gd`) and WeaponMaxPowerSwitch (`MechanicTab.gd`) both extend `hud/SystemList.gd`,
  the OMS Mechanic tab's list: by path the chain is game ← TurretLockableFacing ← WeaponMaxPowerSwitch. Both override
  `update`, calling the parent's first, and add `_input` (the game's script has none), each for its own key action.
  WeaponMaxPowerSwitch keeps its row first and TurretLockableFacing its row last, each moving only its own cells, so the
  game's rows stay between them; WeaponMaxPowerSwitch's alarm player sits beside the ship's alarm, not in the list, so
  the list's last child stays TurretLockableFacing's. Their member names must stay distinct, and their keys (`Shared.gd`
  `KEY`) different. Loaded together in `turret` and `power` (both orders).

## Packaging and releasing

A mod ships as a zip that holds the whole mod folder (README, `CHANGES.md` and images included) at its root, with a
copy of the repository's `LICENSE` in it: the MIT License asks for its notice in every copy. `package.ps1` (PowerShell 7)
builds it as `<ModName>-<version>.zip`, in `TempDir` or in `-OutDir`; on GitHub it is `<ModName>.zip` (see
*Publishing*):

```powershell
.\package.ps1 <ModName>                # builds the zip and prints its path
.\package.ps1 <ModName> -VersionOnly   # prints the manifest's version, without checking CHANGES.md
.\package.ps1 <ModName> -CheckOnly     # runs the release's checks, builds nothing
```

The version comes from `[version]` of `Mod.manifest`. The script refuses to overwrite a zip, refuses a mod whose
`CHANGES.md` doesn't start with that version, and refuses a mod whose page in the users' wiki is missing or out of
date (`wiki.ps1 -Mod <ModName>`, see *The users' wiki*): a mod needs its page from 1.0.0 on, and below 1.0.0 must have
none yet. It checks
that every entry is `<ModName>/…` with forward slashes: the game needs them for the `res://` paths, and Windows
PowerShell 5.1's `Compress-Archive` writes `\` instead, hence PowerShell 7.

**Test builds.** A change is tried in the game before it is released, often over several builds, so a build only
changes what the mod needs to work: the README, `CHANGES.md`, the wiki page and the repository's docs wait for the
release, which brings them all up to date at once. Each build has a prerelease version of the last release,
`x.y.z-next-<n>`: `version_prerelease = "next-<n>"` in `[version]`, after `version_bugfix`, with `x.y.z` unchanged and
`n` going up by one with every build, from 1 after a release. `package.ps1` builds it as `<ModName>-x.y.z-next-<n>.zip`
without the `CHANGES.md` and wiki checks, and `-CheckOnly` fails for it. A test build is never committed, so never
pushed: `release.ps1` fails for a mod whose version is a prerelease. (The mods' `Settings.gd` read only
`x.y.z` as the version they save.)

A release gets a new version, picked by semver (see *Conventions*) from the changes since the last release, set in
`[version]` of `<ModName>\Mod.manifest`, with the test builds' `version_prerelease` removed. From 1.0.0 on, those
changes are the `## NEXT` section of `<ModName>\CHANGES.md`, which is then renamed to that number. Before 1.0.0 there
is no `CHANGES.md`, and the git history is the only record of them. A new mod's first release is its manifest version
as it is. The release also brings up to date everything else its changes touch (the README, the wiki page, the docs,
the harness), and `package.ps1 <ModName> -CheckOnly` passes before it is committed.

**Publishing.** A push to `main` publishes: `.github\workflows\release.yml` runs `release.ps1` on every push to `main`
(and by hand: Actions, Release, Run workflow). Each mod at 1.0.0 or later whose manifest version has no tag
`<ModName>-<version>` on GitHub gets a GitHub Release of that name, never marked Latest, with the tag at the push's
commit, the zip `package.ps1` builds (so its checks stop a release there too) and, as notes, links to the mod's wiki
page and Home's *Installing mods*, then what changed since the mod's newest release: every section of `CHANGES.md`
above that version, each under its version's heading when there are several, since versions committed but held back
from a push are released together and only the newest gets a release ("First release." for a mod with no release
yet). On GitHub the zip is named `<ModName>.zip`, without the version, so that a player's newer zip overwrites the
older one in the game's `mods` folder instead of loading next to it; the zips built locally (test builds, the ones
installed, the backups) keep the version in their names, to tell them apart. The older mod releases, published
before this naming, hold `<ModName>-<version>.zip`, which `release.ps1` takes too. Then the *All mods* release, the
only one marked Latest (so `…/releases/latest`, which Home and the README link, leads to it), holds the newest
published zip of every mod in the repo, downloaded from the mod's release and never rebuilt, as `<ModName>.zip`, with a
line per mod (its wiki page, its release and version, and its manifest's `description`). Whenever those zips or those
lines change, a new All mods (tag `all-mods-<commit>`) replaces it, and the old one is deleted with its tag. A mod
below 1.0.0 is never published: its first release on GitHub is its 1.0.0. Building a zip and trying it in the game
publishes nothing; the push does. A version pushed to `main` is final: it is never rolled back, and the workflow fails
for a mod whose version is below its newest release. One mod failing doesn't stop the others. `.\release.ps1 -DryRun`
shows what the next push would release: it builds the zips in a new folder in `TempDir`, each as `<ModName>.zip` in
a folder `<ModName>-<version>`, and prints their notes, and publishes nothing (publishing runs only in the workflow).
The tags and the releases' names carry the version; the zips on GitHub don't.

Keep exactly one zip per mod in the game's `mods` folder: the game loads every file there, so two versions of one mod
would both load (see *How the game loads a mod*). A zip from GitHub overwrites only the one of the same name: a zip
with a version in its name (a local build, or one from an older release) stays, and must be taken out. The running
game keeps every zip in `mods` open, so close it before replacing one: otherwise the old zip can't be moved out, while
the new one can still be moved in. A renamed mod's first release also takes the zips of its old name out of `mods`
(see *Conventions*): they have another name, and would load next to it.

## Testing

`_tests\run.ps1` (PowerShell 7) tests most of the mods in a headless Godot 3.6, in a few seconds, against the newest
decompiled game; `.\_tests\run.ps1` runs every suite. What each suite checks, the options and the baseline results are
in [`_tests/README.md`](_tests/README.md). The harness doesn't replace the game: the real check is playing the game
with the mods.

## The drone bench

`_bench\bench.ps1` (PowerShell 7) runs deterministic simulations of the nanodrones at work, in a headless Godot 3.6,
to choose from data how DroneAltPriorities ranks chunks: its control scenario is unattended mining in an
Antonoff-Titan K225, with the game's own drone, PDW, excavator, chunk and roid scripts, and the game's scenes and maps
read from the newest decompiled game at run time. It reuses the harness's autoload stubs and mod loader. The scenario,
the modes, what a run measures and how it stays deterministic are in [`_bench/README.md`](_bench/README.md).

## The users' wiki

The repository's GitHub wiki explains each mod to players, so that sharing a mod means sharing a link: one page per
mod, in plain words, with "without the mod / with the mod" pictures where a mod changes what the screen shows. A mod
gets its page (with its pictures, its `_shots\shots.psd1` entry and its lines in Home and the sidebar) at 1.0.0, as it
gets its README: a mod below 1.0.0 has neither. Its
source is `_wiki\`; `.github\workflows\wiki.yml` copies it to the wiki when a push to `main` changes it, or when the
workflow is run by hand (Actions, Wiki, Run workflow). The wiki is a mirror: whatever is edited on the website is
overwritten at the next publish, so edit `_wiki\` only. The wiki's settings restrict editing to collaborators.

**Files.** `_wiki\` holds only pages and images, since everything in it is published:

- `Home.md`: the warning that a mod might break, or work in unexpected ways, alongside another mod or a DLC that
  touches the same parts of the game; what the mods are, every mod in groups with a plain one-line summary, *Mods that
  change how the game plays*, *Installing mods* (where a zip comes from, the `mods` folder, `--enable-mods`, a backup
  of the save), and *Disclaimer* (the game belongs to Kodera Software, the author has no tie to it or to the company,
  and everything in the repository is given as is, for free, without warranty).
- `_Sidebar.md` (Home and every mod page, in Home's groups) and `_Footer.md` (on every page: the mods are unofficial,
  the short disclaimer with its link to Home's, the source code, the license, the AI credit).
- `<ModName>.md`, one per mod: the page's name is the mod's, so its link is `…/wiki/<ModName>`.
- `images\<ModName>-<view>-without.png` and `-with.png` (a single picture: `<ModName>-<view>.png`): PNG, at most 2 MB,
  a screenshot cropped to the part of the screen that changes. The mods' READMEs keep their pictures here too (the
  arm diagrams), linked as `../_wiki/images/<file>`, so a mod's zip carries none; such a picture's values are listed
  in the values block of the mod's page like any other.

**Pictures.** Only mods with a screen of their own, or that add to or change a game screen, have screenshots; mods
that only reorder a list or change how the game plays have none. Every screenshot is taken with bloom off (the game's
Bloom setting at No Bloom). Screenshots of the station's screens, and of the OMS and the HUD (in a dive `shots.ps1`
starts), are taken by `_shots\shots.ps1` in an isolated copy of the game, from a fixture save, each mod's in a run
without it and a run with it ([`_shots/README.md`](_shots/README.md); its steps in `_shots\shots.psd1`); those that
depend on what is around the ship (the info boxes by the chunks), by hand, the pair from the same save, ship and view.
`shots.ps1` also draws the game's ships and weapons alone, for a page that explains combat (CombatSimulator's): one
ship per series (its base model; the variants' reactors sit the same) nose up with a heat map of where hits damage its
reactors, and each weapon mounted on a ship with its cone, range and, for a turret, its pick-up areas. Every ship is
drawn at one scale where it fits; each picture has a scale bar of a round length, which the run prints and the page
states (see `_shots/README.md` *Ship and weapon pictures*).

**A mod's page**, in this order (GitHub shows the file name as the title, so there is no `#` heading):

1. One sentence on what the mod does for the player.
2. `## What changes`: what the player sees or gets, compared with the game without the mod. Pictures go side by side
   in a two-column table, *Without the mod* and *With the mod*, or one under the other when they are wide (the HUD);
   each has alt text. Where what the player sees depends on a piece of equipment they pick (HudHideLabels: the HUD),
   each choice gets a folded section, `<details>` with the name the game shows as its `<summary>`, holding its pair
   one under the other; blank lines around the pictures inside, so GitHub renders them.
3. `## Settings`, for a mod that has any: how to open them, and for each its name as the screen shows it, what it
   does, its default and its range, in the units the screen shows.
4. `## Changes how the game plays`, exactly when the README has a *Warning*: in short, what differs from the normal
   game, and to try without the mod before reporting a bug to the game's developers.
5. `## Works with other mods`, where it matters (mods that stack, mods that must not be installed together).
6. `## Install`: a link to Home's *Installing mods*.
7. The values block (below).

A page that is also a reference to the game (CombatSimulator's `## Ships` and `## Weapons`) has those sections after
*Install*, before the values block. What the station doesn't sell, or sells only after a story event, is folded away
as a spoiler: `<details>` with `<summary><b>SPOILER ALERT</b>: … (click to show)</summary>` (TransponderAltCodes,
CombatSimulator).

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
  4.5 m, 24x, on) and `|` the pictures that show it. A constant that names another one is followed to its value, and
  one that names one of the engine's (`KEY_L`, `JOY_BUTTON_2`) is written and compared by that name.
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
- a mod at 1.0.0 or later has no page, Home or the sidebar doesn't link it, or a page has no mod; a mod below 1.0.0
  has a page; a page's *Changes how the game plays* doesn't match its README's *Warning*;
- a link between pages or to a heading doesn't resolve, an image is missing (spelling counts: GitHub's servers are
  case-sensitive), unused, not a PNG or larger than 2 MB, or `_wiki\` holds anything but pages and `images\`; a mod's
  README shows a picture from anywhere but `_wiki\images\`.

Where `paths.local.psd1` points at a decompiled game, it also warns when a page's `game-checked` is older than the
newest one. It runs by hand (`.\wiki.ps1`), in `package.ps1` for the mod being packaged (so a release stops before
anything is built), and in the workflow before anything is published (so a push that leaves a page out of date fails
there).

**Keeping it up to date.** A change to anything a mod's page says (behaviour, settings, a listed value or text, a
screen its pictures show) updates the page, its values block and its pictures in the release that ships it (test
builds leave them for the release, see *Packaging and releasing*). A release reviews the page against the mod's
`## NEXT` bullets, since no check catches a change of behaviour. A picture `wiki.ps1` names
to re-take is taken again with `.\_shots\shots.ps1 -Mod <ModName>`, or by hand for one of the info boxes. After a game
update, every page's `game:` lines are checked against the new version, then its `game-checked` changes. Its pictures
are taken again (`.\_shots\shots.ps1 -NewFixture`) only where the update changes what the mod acts on (a title
HudHideLabels hides is gone, renamed or already hidden by the game itself). A change to anything else on screen, such
as the background, colours or shaders, doesn't make a pair wrong, however different it looks.
A mod reaching 1.0.0 adds its page, and its lines in Home and the sidebar; removing a mod removes them.

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
  - A second script extension next to `Code.gd` is named for the screen it changes (CrewCheapHireNotifier's
    `HireScreen.gd`, the Hire screen; DiveSkipTransit's `StationMenu.gd`, the station menu), or, for a part of the game
    that isn't a screen, for the part (CombatSimulator's `PauseMenu.gd`, the pause menu; `Hardpoint.gd`,
    `ships/WeaponSlot.gd`). Every script extension is listed in *The two ways these mods hook in*.
    Code more than one of them uses goes in `Settings.gd`, which they already share (CrewCheapHireNotifier's rule,
    `limitFor` / `isCheapHire`; DiveSkipTransit's static helpers, `playThrough`, `chargeDv`, `chargeSeconds`), and in
    a mod without one, in `Shared.gd`: static functions in a script never instanced (`extends Reference`), reached
    through a preload constant named for the mod as `Settings.gd` is (CrewPerfectSort's Your Crew order,
    `yourCrewBefore`). The code is never copied into each script.
  - A script of the mod's own that isn't an extension is named for what it is: CombatSimulator's `CombatLayer.gd` (its
    arena, a layer the station's extension adds), `CombatMap.gd` (the arena's map, built on `TheRing.gd` with
    `extends` but never installed: a subclass made with `new()`, not a replacement of the game's script) and
    `ShipList.gd` (its dialog's ship list, a tab of `SettingsUI.gd`); MarketAdvisor's, ShipRepairAdvisor's and
    ShipSaleAdvisor's `Advisor.gd` (the advice: static functions of what the player can see, which touch neither the
    game nor the scene); ShipRepairAdvisor's `ParkDialog.gd` (its Park button's confirmation); ShipSaleAdvisor's
    `FleetNote.gd` (its note at the bottom of the Fleet screen); `Badge.gd` (the badges, see *Shift
    badge* in the Glossary), the same file in every mod that has one.
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
      `dimmedWhen` names the switch while which it doesn't apply. `perModel` (DealerNotifier's ship switch) is `perJob`
      for the ship models the dealer can offer; DealerNotifier's other switches, New and Used, aren't per model and have
      a `group`. `perService` (ServiceNotifier's switch) is the same for the services it watches, by `serviceName`.
      `var cfg`: the current values by key (a dictionary by job, model or service key for a per-job, per-model or
      per-service setting), set to the defaults in `_init`. `const FORMAT_VERSION`.
    - `jobs()`: the jobs a per-job setting has values for, the game's `CurrentGame.occupations`; `isPerJob(key)`.
      DealerNotifier's `models()` and `isPerModel(key)` are the same for its ship models, and its `getValue` /
      `setValue` take a model where CrewCheapHireNotifier's take a job. ServiceNotifier's `isPerService(key)` has no
      list: its services are the Services screen's rows, and one with no value stored gives the default; its `getValue`
      / `setValue` take a service.
    - `getValue(key, job = null)`; `setValue(key, value, job = null)` clamps and snaps to the step, and only on a
      change stores (`saveToState()`) and emits `settingsChanged`; `job` is only for a per-job setting.
      `toShown(key, value)` / `fromShown(key, shown)`.
    - `loadFromState()` / `saveToState()`: settings kept per save game (CrewCheapHireNotifier's, CombatSimulator's,
      DealerNotifier's, MarketAdvisor's, ServiceNotifier's, ShipRepairAdvisor's, ShipSaleAdvisor's) live in
      `CurrentGame.state.ui` (the game's per-save UI store, `setUiValue` / `getUiValue`, written with the save as JSON,
      so numbers come back as floats) under the mod's id from `Mod.manifest`, so other authors' mods can't collide; the
      entry holds `formatVersion`, `modVersion`
      and one value per setting (a copy of the dictionary for a per-job setting). MarketAdvisor's also holds the tonnes
      its Trade button bought (`parked`, through `getParked` / `setParked`), and DealerNotifier's the ships already
      seen (`known`), which aren't settings: stored without `settingsChanged`. Loading starts from the defaults and
      clamps and snaps each saved value. A mod whose settings are game-wide (DiveSkipTransit's) uses the `user://`
      `ConfigFile` above instead, with `loadFromFile` / `saveToFile`: a file of its own, `user://<the mod's id>.cfg`
      (in `filePath`, so a test can point it elsewhere), holding one section named by the mod's id with the same entry,
      written at every change; `shared()` loads it when it makes the instance.
    - `modId()`, `modName()`, `modVersion()`: read from `Mod.manifest` (path: the script's folder) with `ConfigFile`.

    `SettingsUI.gd` builds the screen from `SETTINGS` through `toShown`, with the game's own UI parts, and writes back
    with `setValue(key, fromShown(key, shown), job)`; `Code.gd` loads the save's values when its scene is built (the
    station is rebuilt after every load and new game) and listens to `settingsChanged`.

    Players don't open the zip, so they never read the README: the screen explains every setting itself, as the game's
    Tuning screen does. Under the title, a window framed as the Tuning screen's description shows the selected row's
    description: the key of its `label` followed by `DESCRIPTION_SUFFIX` (`SettingsUI.gd`'s; CombatSimulator's, which
    two scripts share, in its `Settings.gd`), in the mod's
    `i18n/en.po`. It is set on every `tuningChanged`, which a row emits when it changes and when it gets the focus
    (`Tuning.gd` `tuningChanged` does the same with `<key>_DESC`). Every setting has one, written as the game's
    `TUNE_*_DESC` are: what it does, a blank line, then the details. CrewCheapHireNotifier, DiveSkipTransit,
    MarketAdvisor, ShipRepairAdvisor and ShipSaleAdvisor have it, and so has CombatSimulator's dialog, on each of its
    tabs. The OMS tabs of DroneAltPriorities and GeologyByMass have no room for the window: each row's description is
    its tooltip, which the game's tooltip node shows on hover and on focus. DealerNotifier is the exception: its
    switches (New and Used, then one per ship model) are explained by its README and its wiki page, not on the screen, at the author's choice. Its
    window, framed as the Dealer screen's, shows the game's own description of the selected ship, as the Dealer does
    (`<shipName>_DESC`), and nothing for New and Used. ServiceNotifier's switches, one per service, share one `label`,
    their tooltip; its window shows the description of the service's kind (`Settings.gd` `KINDS`), with the service's
    name and, for a cooldown, how long it lasts, followed by the game's own offer for the service, as the Services
    screen shows it.
  - A mod without a settings UI has no `Settings.gd`, and no constants file either: that would only add a prefix to
    every use. Code its scripts share goes in `Shared.gd` (above).
  - Settings that belong to a ship system go in the game's Tuning screen instead (`registerSubsystem` from the
    system's `onSetup`; LidarLouderPing). The game draws them, keeps them per ship with its tuning (saved with the
    game) and signals a change (`tuningChanged`), so the mod has no stored value, saving or signal of its own. With
    one or two, their default, range and step are constants in `Code.gd`, read through a clamping helper. With more,
    or spread over several game systems, they split into `Settings.gd` (the descriptions and a clamped read from a
    ship; no shared instance) and `TuningUI.gd` (the registration, called from `Code.gd`'s `onSetup`).
  - A setting that belongs to the ship's equipment, as a Tuning setting does, but is set elsewhere
    (TurretLockableFacing's angle, on its row of the OMS Mechanic tab, for the turrets fitted) is kept in the ship's
    tuning too, without a Tuning entry: one entry under the mod's id, with `formatVersion` and `modVersion`, through
    `getConfig("tuning")`, so the game saves it and carries it with the ship. Its default, range and step are
    constants, read through a clamping helper that never writes.
  - Settings that change what a game system's own settings already decide follow that system's pattern
    (GeologyByMass): they live in that system's config, next to the game's, under the mod's id from
    `Mod.manifest`, changed in place as the game changes its own, so the game saves, loads and carries them. Then
    `Settings.gd` has one instance per system or ship, made by each script that reads it (no `shared()`, no
    `loadFrom…` / `saveTo…`, no signal when the game re-reads by itself): the descriptions as constants, getters that
    never write and give the defaults where nothing is stored (clamped, snapped to the step), setters that write only
    a change, an entry with `formatVersion` and `modVersion`, and `modId()` / `modName()` / `modVersion()`.
    GeologyByMass and DroneAltPriorities keep theirs in the HUD's `mineralConfig` (the ship's `hud.config`), next to
    the Geologist tab's settings, for the whole ship, so their `Settings.gd` is made from the ship rather than the HUD
    (`ship.getConfig("hud.config")`): GeologyByMass's ship rule and OMS tab, DroneAltPriorities's drone plants and OMS
    tab, each make their own instance, and all read the same entry, so a change applies at once with no signal.
  - `i18n/<locale>.po` (`i18n/en.po`, …), in a subfolder named as the game's own `i18n/`: the mod's texts in that
    language, loaded by `ModMain.gd` (see *How the game loads a mod*). English is Godot's fallback language, so
    `en.po` covers every language until it gets its own file.
  - CrewPerfectSort, with three extensions and no single main file, keeps its file names for now: each extension is
    named for the list it sorts, with `Sorted` after it (`EvaCrewSorted.gd`, the EVA choice).
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
- **Every Shift+Click has a gamepad twin**, so a mod works with a controller as well as with a mouse: `PAD_BUTTON`
  pressed on the highlighted control while `PAD_MODIFIER` is held (`Badge.gd` `isPadShortcut`; at the station the game
  gives neither button a use), and for a key with Shift, its gamepad button with `PAD_MODIFIER` (CombatSimulator's twin
  of Shift+J). The control gets a Shift badge (`Badge.gd` `dress`, `hangBeside`), whose text and tooltip follow the
  control scheme (see the Glossary): "Shift" and `<MOD>_SETTINGS_TOOLTIP` with keyboard and mouse, the twin and
  `<MOD>_SETTINGS_TOOLTIP_PAD` with a gamepad (`setShiftTooltips`), shown by the game's own tooltip node
  (`attachTooltip`): on hover, and with a gamepad, which shows no hover, while the control has the focus (its
  `focusOwner`). The entry keeps no tooltip of its own. `Badge.gd` is the same file in each mod that has it: a change to
  one is copied to all. The one exception to the badge is ShipSaleAdvisor's Shift+Click on Sell, which every entry of
  the Fleet screen has: one note at the bottom of the screen says it for all of them instead, its text following the
  control scheme as a badge's does (`FleetNote.gd`).
- A mod's screen works with the D-pad and the gamepad's buttons as the game's do: the D-pad moves between its controls
  (focus neighbours where the layout alone doesn't lead there), B and Start close it (`ui_cancel`, `pause`), LB and RB
  switch its tabs, and the right stick scrolls a text that doesn't fit (`ui_scroll_up2` / `ui_scroll_down2`, at the
  game's speed: `enceladus/ScrollWithAnalog.gd`). Its descriptions show when a control is highlighted, as on hover.
- Read values from the game (the ship's nodes and collision shapes, scene files, the arm's own properties), never
  from per-ship tables. A constant is only a fallback for when the game data can't be read (`CHUNK_RADIUS_FALLBACK`).
- Game behaviour a mod relies on is cited with the game file and function it comes from (`Game.gd`
  `_respawn_ship`, `hud/SystemList.gd`). Check it in the decompiled source, not from memory.
- Versions follow [semver](https://semver.org): **major** for a change that breaks what players or modders rely on
  (a feature removed or changed incompatibly, saved settings that no longer load), **minor** for new behaviour or
  settings that keep the old working, **patch** for fixes and for changes with no visible effect (a file renamed,
  code moved between files). Every zip released gets a new version, and a released version is never changed; a test
  build's zip gets a prerelease of the last release, `x.y.z-next-<n>` (see *Packaging and releasing*).
  A new mod always starts at **0.0.0**, except a renamed one (below). Going to 1.0.0 comes with a clean-up: all
  logging removed, the code simplified, and the what and why of each feature documented in the README for other
  modders.
- **A renamed mod** is not a new version of the old one: it is a new mod that replaces it, with the same behaviour and
  only another name. It keeps the old one's version, and its `CHANGES.md` if it has one, retitled, with no section for
  the rename; its first release is that version under the new name. Everything that names the mod follows the new
  name: the folder, `Mod.manifest`'s `name` and `id`, the `res://` paths, the members' prefix, the wiki page, the
  tests. Nothing names the old one any more, as nothing names a mod that was removed; its first release takes the old
  name's zips out of `mods` (see *Packaging and releasing*).
- **A mod's files never name another mod**: not its code and comments, its texts, its manifest, its README or the new
  sections of its `CHANGES.md` (the released ones stay as they were). Each mod is independent and ships alone, so such
  a mention would describe another mod's code, go stale when that mod changes, and need a release of a mod that didn't
  change. Where mods meet (the same game script extended, the order they load in, a pair the harness loads together)
  is written in *Cross-mod dependencies*; a mod's README and comments say only what the mod itself does there, in
  general terms ("other mods may extend `EnceladusMenu.gd` for their own entries: this one writes only the Crew
  entry's text"). The repository's own docs, the harness and the users' wiki (*Works with other mods*) may name mods.
- **The version lives only in `[version]` of `Mod.manifest` and in `CHANGES.md`**. It never appears anywhere else in
  the mod: not in the README (whose *Install* step says "the mod's zip" and names neither the mod nor the zip), the
  code, comments or images. Godot's and the game's own versions may be mentioned. The harness (`_tests\`, its suites
  and its README) may name a mod's released versions where it compares the code with their zips (`-ModZip`), since
  that comparison needs them. The version is bumped only at release, and between releases only the test builds'
  prerelease changes (see *Packaging and releasing*).
- **`CHANGES.md`**: a mod at 1.0.0 or later gets one in its folder (so it ships in the zip) as soon as it changes
  after 1.0.0. Changes not yet released are listed in a `## NEXT` section at the top, by the release at the latest
  (test builds leave it for the release), while the manifest keeps the released version (with a test build's
  prerelease). At release the section is renamed to the new version
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
- A mod gets its README at 1.0.0, with its page in the users' wiki; below 1.0.0 it has neither, and its zip carries
  no README.
- README layout: `# <ModName> - ΔV: Rings of Saturn`; the summary (no version), with its images, if any (kept in
  `_wiki\images\` and linked from there, see *The users' wiki*, so the zip carries none); for a mod
  that changes how the game plays in a dive, *Warning*: in short, what it changes compared to vanilla, and to check a
  bug without the mod before reporting it to the game's developers; *What it does and why* (What / Why bullets); *For
  modders* for script extensions (what is extended, overrides, new members, constants, how it was tested); *Install*
  (three steps; the second, the same in every README, is "Put the mod's zip in it, and remove any other version of
  the mod from there: they would all load. Do not unzip it."; the third, `--enable-mods`); the "Mods are unofficial …
  Keep a backup of your save." line; *About* (made with the help of Claude; MIT License); *Disclaimer* (the game
  belongs to Kodera Software, the author has no tie to it or to the company, the mod is provided as is, for free,
  without warranty; the same text in every README, ending with a pointer to the MIT License, which says so in full).
  When the behaviour changes, the release that ships it updates the README's text, *Warning* and figures too, and the
  mod's page in the users' wiki.
- The root `README.md`, this file, `GAME.md`, `_tests/README.md` and `_wiki\` are the repository's own (they ship in
  no zip, and `CHANGES.md` doesn't list their changes). Update the README's *Mods* table when a mod reaches 1.0.0 or is
  removed or a mod's summary changes, and its *Mods that change how the game plays* when a mod gains or loses its
  *Warning*, and the wiki's Home and sidebar with them; update `_tests/README.md` with every change to the harness or
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
English text there. An entry says what a term is and where it lives in the game. How it works (formulas, figures,
spawn rules, what decides what) is in [GAME.md](GAME.md), in a section of the same name, which the entry links.

- **Adrenaline**: the game's bullet time. A level from 0 to 1 (`adrenaline` in `BulletTimer.gd`, changed through
  `CurrentGame.adrenaline(delta)`) that slows game time (`CurrentGame.targetTimeScale` → `Engine.time_scale`),
  blurs the view around the ship and muffles the sound, and drains by itself. The Adrenaline booster, the smart camera
  and the pilot raise it. Details: [GAME.md](GAME.md#adrenaline).
- **Adrenaline booster** (`SYSTEM_ADRENALINE_BOOSTER`, `ships/CabinLight.gd`): equipment the player fires with
  the `bullet_time` action (`CONTROLS_GAMEPAD_ADRENALINE`) for a burst of adrenaline, followed by a cooldown
  (`adrenalineBoost`, `adrenalineCooldown`); fired again during the cooldown, it cuts the burst short. Switched off
  in the OMS's Mechanic tab, it pushes adrenaline down every frame instead, which also damps bullet time from the
  other sources. DiveDisableAdrenalineBooster starts the player's booster switched off at every dive. Its node, in
  every ship the player can fly, is also the ship's cabin light (no text of its own in `en.po`): a glow over the cabin
  and a spotlight (`lightNode`, a `Light2D` the game's Lights setting can hide, `SETTINGS_LIGHTS`), lit while it has
  power. WeaponMaxPowerSwitch tints it red while its switch is on.
- **Alarm** (no text of its own in `en.po`): the ship's warning sound, each ship model's own (`ship-ctrl.gd`
  `playerAlert`, its `Noises/Alert`), which `soundAlert` plays for a few seconds: for a full mineral storage, a gauge or
  a system in the red, a collision warning. WeaponMaxPowerSwitch's key plays it to tell which way it switched.
- **Alert mark** (not the game's: these mods' own term): the " (*)" a mod puts after the text of a station menu entry
  while something behind it is worth a look, each mod with its own text for it (`<MOD>_ALERT`, "%s (*)", whose `%s`
  is the entry's text). CrewCheapHireNotifier puts it on Crew, DealerNotifier on Dealer, MarketAdvisor on Mineral
  Market, ServiceNotifier on Services.
- **Antonoff Ore Purifier** (`SYSTEM_CARGO_MPUDRY`; `ships/modules/MineralProcessingUnit_DRY.tscn`, on
  `MineralProcessingUnit.gd`): an MPU whose processing area covers the whole hold of the Antonoff-Titan K225
  (`ships/ATK225.tscn` overrides it), and which only strips the chunks' water into remass. Details:
  [GAME.md](GAME.md#antonoff-ore-purifier).
- **Arm**: the AR-1500 Manipulator (`SYSTEM_SALVAGE_ARM`, `ships/modules/DockingArm.gd`), the ship's arm that grabs
  chunks and brings them to the intake (see *Salvage arm facts*). It pulls its target towards its dock slot
  (`areaDockSlot`), and lets go of one that strays too far from the dock slot or the arm base. Details:
  [GAME.md](GAME.md#arm).
- **Astrogation** (fast travel): travel inside the ring to a known destination, picked in the Astrogator tab and
  started with PLOT A COURSE (`HUD_PLOT_COURSE`; `hud/AstrogatorPanel.gd`, `CurrentGame.fastTravelTo`): the ship
  speeds up, then jumps to the destination and brakes in a cutscene, and in-game time passes. Destinations are kept per
  save (`CurrentGame.state.astrogation`), each with a deadline, and are lost some time after it. Details:
  [GAME.md](GAME.md#astrogation).
- **Astrogator**: the crew occupation for navigation, and the OMS tab with the map: points of interest (see
  *Astrogation*), distances, plotting a course (`HUD_PLOT_COURSE`).
- **ATLAS**: an autonomous drone that hunts rogue AI; the ship has no name text in `en.po`, and calls itself an
  "autonomous Edge Runner" (`DIALOG_ATLAS_BEING_AUDITED_1`). ATLAS stands for the Artificial Threat Location and
  Apprehension Specialists (`DIALOG_ATLAS_WHATS_ATLAS_EXPLAIN`). Scene `ships/drone/ATLAS.tscn` (Shipyard model
  `ATLAS`): faction `ai`, no crew, two MWG emitters (see *EMP*), no EMP shielding. A random event of the rings brings
  it to ask to audit the player's ship (`comms/conversation/AtlasConversation.tscn`), and it turns hostile if refused.
  Destroyed, it leaves an AI core, an oddity. Details: [GAME.md](GAME.md#atlas).
- **Chaos**: no text of its own in `en.po`. A value from 0 to 1 for each spot of the rings: the red channel of the
  ring map (`ring/ring-map.png`, one pixel per km, depth across and the way around the ring down, wrapping), read by
  `TheRing.gd` `getChaosAt`; its blue channel is the density (`getRawDensityAt`). Random events of the rings need a
  minimum chaos where they spawn, the chunks are purer the more chaos, and the dive entry point's Environmental damages
  fee (`MAP_FEE_ENVIRONMENT`) grows with it. Details: [GAME.md](GAME.md#chaos).
- **Chunk** (mineral chunk, ore chunk): a loose piece of ore floating in the rings; what the arm grabs, the MPU
  processes and the HUD's mineral targeting marks. A `RigidBody2D` with `asteroids/mineral.gd`, one scene per
  mineral and size (`asteroids/mineral-<mineral>-<n>.tscn`); `mineral` names its mineral, `composition` its
  content. Weight: see *Salvage arm facts*.
- **Combat capacity** (no text of its own in `en.po`): how fit a ship is to fight, from 0 to 1, from the state of its
  equipment (`ship-ctrl.gd` `getCombatCapacity`). The AI, the HUD's ship marks and some random events read it.
  Details: [GAME.md](GAME.md#combat-capacity).
- **Comms line** (no text of its own in `en.po`; the OMS keeps its log under `HUD_COMMS`, "Comms"): the line at the
  edge of the HUD where a message to the player's ship shows, one at a time, with the speaker's face and, in brackets,
  the sender's transponder or a crew member's "Name, Occupation" (`comms/MessageLine.tscn`, `MessageLine.gd`),
  added by `hud/Hud.gd` `gotMessage` on `CurrentGame`'s `broadcast` and kept in the OMS's log (`hud/OMS.gd`
  `dialogNode`). LidarContactCallout adds its callouts there. Details: [GAME.md](GAME.md#comms-line).
- **Control scheme** (`SETTINGS_CONTROLS`, "Controls": Auto, Keyboard + Mouse, Gamepad): the game setting
  `Settings.cfg.ui.controller` (Auto by default), and what the game's control hints follow, `Settings.controlScheme`:
  the setting, or with Auto the device last used (`menu/Mouse.gd`), with the `controlSchemeChaged` signal (the game's
  spelling) at every change. The mods' Shift badges follow it too. Details: [GAME.md](GAME.md#control-scheme).
- **Crew** (`ENCELADUS_CREW`): the people hired at the station, each with an occupation (`CurrentGame.occupations`:
  Pilot, Mechanic, Geologist, Astrogator, keys `CREW_OCCUPATION_*`) and a salary; the player is the captain. The
  dive crew are those aboard. Passengers (`CREW_OCCUPATION_PASSENGER`, no salary) are listed with the crew. The
  **Crew screen** (`enceladus/Crew.tscn`), opened by the station menu's Crew entry, has two tabs: Your Crew
  (`ENCELADUS_CREW_CURRENT`, `enceladus/CurrentCrewManagement.gd`) and the Hire screen.
- **Crew stats**: what the crew is good at, per occupation. Each member has a talent, shown as Education
  (`CREW_EDUCATION`), and an experience (`CREW_EXPERIENCE`), both from 0 to 1 in their own occupation and shown on
  their entry as levels (`CurrentGame.talentLevels`, `experienceLevels`; `enceladus/CrewBio.gd`). The best of each
  occupation in the dive crew gives two stats, shown on Your Crew (`CurrentGame.getCrewStats`, `deriveStats`): the
  pilot's Adrenal slowdown and Course anticipation, the mechanic's Jury-rig efficiency and Repair limit, the
  geologist's Price prediction accuracy and Mineral discovery range, the astrogator's Tactical awareness range and
  Coordinate tracking time (`CREW_STATS_*`). Salaries follow from talent and experience. Details:
  [GAME.md](GAME.md#crew-stats).
- **Cutscene**: a stretch where the game flies the ship and the player has no control, while the ship's `cutscene`
  flag is on (`ship-ctrl.gd` `_setCutscene`, which emits `cutscene`). The ring scene has five: the arrival at the start
  of a dive, the exit (`ship-ctrl.gd` `escapeTheRing`, then the `exit` animation), the rescue of a helpless ship (out
  of remass or power: `helpless`), fast travel inside the ring (`ship-ctrl.gd` `fastTravelTo`, `fasttravel`) and the
  game over (`gameover`). Holding `cutscene_ff` (Space, the left mouse button, gamepad buttons 0 and 1; no text of its
  own in `en.po`) runs one faster. DiveSkipTransit skips each of the five, the arrival and the exit (the transit) under
  one setting, and charges what it would have cost; with the transit not skipped, it plays both at a speed of its own,
  without Space. Details: [GAME.md](GAME.md#cutscene).
- **Dealer** (`ENCELADUS_SHIP_MARKET`, `enceladus/Dealer.tscn`): the station's ship market. Its entries are
  `enceladus/SystemBuyUI.gd` (the ship-list mods change them); its Examine Ship tab can launch the simulator. The
  stock is stored nowhere: `CurrentGame.getShipsAvailableForSale` builds it anew on every call, and only `Dealer.gd`
  `doAddShips` asks for it. An entry marks a new ship NEW, a ribbon on its picture (`SystemBuyUI.gd` `checkPrice`), by
  its age; DealerNotifier's New and Used follow that mark. Details: [GAME.md](GAME.md#dealer).
- **Density** (roid density; no text of its own in `en.po`): how many roids a spot of the rings holds, from the ring
  map's blue and green channels (see *Chaos*; `TheRing.gd` `getTargetDensityAt`), filled in ahead of the ship by
  `AsteroidSpawner.gd` `spawnProperThings`. Chunks come only from roids breaking. Details:
  [GAME.md](GAME.md#density).
- **Depth** (`HUD_DEPTH`, "depth"): how far into the rings the ship is, in km, from its x coordinate, shown on the HUD
  (`ship-ctrl.gd` sensor `diveDepth`). Details: [GAME.md](GAME.md#depth).
- **Derelict**: an abandoned ship with its reactor off, in the `helpless` faction (`story/RescueOperation.gd`,
  `story/FlightForRescue.gd`, `story/AgendaSpecificDerelict.gd`). It talks once when the player's ship comes close,
  and a crew member can go over to restart it (see *EVA*); or the arm can hold it until the dive ends (see
  *Salvage*). Details: [GAME.md](GAME.md#derelict).
- **Difficulty** (`SETTINGS_DIFFICULTY_0` to `_2`: "Difficulty: Peaceful", "Difficulty: Balanced", "Difficulty:
  Challenging"): the game setting `Settings.cfg.gameplay.difficulty`, Balanced by default, also kept in the save
  (`CurrentGame.state.settings.difficulty`). It decides which combat events of the rings may spawn. Details:
  [GAME.md](GAME.md#difficulty).
- **Dive** (ring dive): one trip from the station into Saturn's rings to mine, until the ship is back. Started with
  Launch Ring Dive (`ENCELADUS_RETURN_TO_RING`), at the dive entry point picked before launch
  (`ENCELADUS_DIVE_TARGET`, `enceladus/DiveTarget.tscn`); fees, licences, insurance and consumables are paid per
  dive, and on return the dive's output is stored or sold.
- **Drones** (no key of their own; the word is in the NT Mining Companion's description, `SYSTEM_SCOOP_DESC`): small
  craft a ship launches from a cradle, equipment on a hardpoint, each a ship of its own (`ship-ctrl.gd`) with a
  transponder made from the ship's by the cradle's `ships/modules/ClaimOwner.gd` (see *Transponder*), which lets it
  go into the scene. The THI Cargo Container and THI Monocargo Container (`SYSTEM_EXSTORAGE`, `SYSTEM_EXMONO`;
  `ships/drone/StoragePod.tscn`, `StoragePodMono.tscn`) are storage pods that carry processed ore back to the station;
  the NT Mining Companion (`SYSTEM_SCOOP`, `ships/drone/CargoScoop.tscn`) is a mining drone; the B8 Claim Beacon
  (`SYSTEM_CLAIM`, `ships/drone/ClaimBeacon.tscn`) holds the player's excavation claim on a spot of the rings. The
  External Impact Absorber (`SYSTEM_HUNK`, `ships/modules/Hunk.tscn`) hangs in a cradle too, but is a block, with no
  transponder. Not drones in this sense: the nanodrones (`SYSTEM_DND_*`, the MPI Tug, MLF Haul and OME Maintenance
  drones, `weapons/drone-plant.gd`; see *Nanodrones*), which the drone plant draws and which aren't objects of their
  own; and the NPC drones (the racing drone and ATLAS, built by the Shipyard; locusts, berserk drones and mines in some
  events). Details: [GAME.md](GAME.md#drones).
- **E$**: the game's currency.
- **EMP**: electromagnetic damage to a ship (`ship-ctrl.gd` `applyEmpDamage`); no key of its own, the word is in
  Short Circuit's tooltip (`DAMAGE_SHORT_CIRCUIT_TOOLTIP`, "Caused by EMP damage."). Its main source is the MWG
  microwave emitter (`SYSTEM_MWG`, `weapons/emp.gd`). A ship's EMP shielding (`empShield`, shown in the Dealer's specs;
  no key of its own) comes with the hull and cuts each hit; what gets through upsets the HUD, the lasers and a fission
  reactor. Details: [GAME.md](GAME.md#emp).
- **Enceladus**, **the station**: Enceladus Prime station (`ENCELADUS_*`, `enceladus/`), the home base at Saturn's
  moon Enceladus. Its menu (`enceladus/EnceladusMenu.gd`) opens the station's screens on its right (the children of
  `enceladus/HidingMarginContainer.gd`). It fades in on every arrival, with its menu disabled meanwhile, and
  DiveSkipTransit skips the fade-in. Details: [GAME.md](GAME.md#enceladus).
- **Equipment**: the parts fitted to a ship (engine, reactor, LIDAR, MPU, arm, Adrenaline booster, …), and the
  station screen where they are bought and fitted to its hardpoints (`ENCELADUS_SHIP_UPGRADES`,
  `enceladus/Upgrades.tscn`; also called the Upgrades screen, after its key and scene). The code calls one piece a
  system: each has a `SYSTEM_*` key, which its script holds in `systemName` (`SYSTEM_SALVAGE_ARM`); a few texts say
  "system" too (the OMS's on/off switch, the trade-in tip). Details: [GAME.md](GAME.md#equipment).
- **EVA** (extravehicular activity): a crew member in a space suit outside the ship. It has no key of its own; the
  word is in conversation lines ("Getting into EVA.", `DIALOG_DERELICT_GO_SURE`). In flight it is only a suited
  sprite (`ships/modules/EVAflight.tscn`, `EVAflight.gd`) that some conversation lines fly between the two ships
  (`evaDirection`); the player can't order one. The game shows one with derelicts, with some crew agendas (an agenda
  is a crew member's personal story, `AGENDA_*`), with Vilcy (faction `vilcy`, bounty hunters), and as scenery at the
  station. Details: [GAME.md](GAME.md#eva).
- **Excavator key** (`ship_excavator`; `CONTROLS_GAMEPAD_EXCAVATOR`, "Open Excavator / Grinder"): the input that
  opens the ship's excavator or grinder (Enter, the middle mouse button or the gamepad's LT; a double press holds it
  open), sent as the command `x` to the systems that answer it (`ship-ctrl.gd` `fireMatching`), the arm too, which
  feeds its target in while it is held. Details: [GAME.md](GAME.md#excavator-key).
- **Faction** (no text of its own in `en.po`): the side a ship is on, which sets how its AI treats everyone else
  (`Factions.gd`, an autoload). Ships are `civilian` (miners; `ship-ctrl.gd`'s default), `pirate`, `helper` (the
  rescue ships), `vilcy` (bounty hunters), `secret` (the Hybrid), `ai` (ATLAS), `ai.berserk`, `obonto`, `racer`,
  `racerracing` and `racedrone` (the race), or `player`; `military`, `mineral` and `asteroid` appear only as what
  others feel something towards. What one faction feels towards another is its disposition, five values (`fear`,
  `curiosity`, `hostility`, `greed`, `support`): the faction's default, plus the save's adjustments, plus each AI
  ship's own. CombatSimulator freezes `pirate` for a run. Details: [GAME.md](GAME.md#faction).
- **Fleet** (`ENCELADUS_OWNED_SHIPS`): the ships the player owns, and the station screen listing them
  (`enceladus/Owned.tscn`, an instance of `Dealer.tscn` with the same entries, the current ship first), where the
  player switches ships (`GARAGE_SWITCH`, `Dealer.gd` `use`) and sells them (`GARAGE_SELL`). Each owned ship keeps its
  own config (`CurrentGame.state.ship`, the others in `state.garage`). The crew itself belongs to the player, not to
  a ship. Details: [GAME.md](GAME.md#fleet).
- **Frozen bodies** (corpses; `ODDITY_DEAD_BODY`, "Evidence gathering reward"): dead people floating in the rings,
  oddities (see *Oddity*), in groups around a talking beacon (`story/DeadBody.gd`, `story/body.gd`) or around the
  destroyed habitat. A body's transponder is its group's plus its initials (`body.gd` `getTransponder`). Details:
  [GAME.md](GAME.md#frozen-bodies).
- **Geologist**: the crew occupation for mining, and the OMS tab with the cargo's composition and the mineral
  targeting (`hud/SystemMineralList.gd`): one row per system that picks by mineral (the HUD, each arm, each nanodrone
  plant, the NT Mining Companion, the cargo containers' docks), with the minerals switched on for it, its Minimum
  value (`HUD_MIN_PRICE`) and its Minimum Albedo (`CARGO_UNKNOWN_ALBEDO`), kept in the system's own `mineralConfig`
  (the HUD's is the ship's `hud.config`). The tab's mineral map (`hud/components/MineralMap.gd`) colours the areas
  around the ship where the mineral picked in its list has been found. Details: [GAME.md](GAME.md#geologist).
- **Habitat** (`POI_HABITAT`, "Habitat"; `story/habitat/Habitat.tscn`): a station of Obonto's in the rings, faction
  `obonto`, with docking arms and a conversation of its own; six of them, SRA-02 to SRA-07, each a random event of the
  rings until it is known. SRA-01 is the destroyed habitat (`story/habitat/DestoryedHabitat.tscn`,
  `POI_DESTROYED_HABITAT`, "Habitat Wreckage"), with frozen bodies around it (see *Frozen bodies*).
- **Hardpoint**: a ship's mount for a piece of equipment: high-stress, low-stress or spinal. Only high-stress ones
  take the arm. In the ship's scene each is a `ships/WeaponSlot.gd` node, inline or a placeholder of
  `weapons/WeaponSlot.tscn`; in the ship's config, `weaponSlot.<slot>.type` holds what is mounted, and `SYSTEM_NONE`
  is nothing. Details: [GAME.md](GAME.md#hardpoint).
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
  reactor runs (`ships/Artifact.gd`). A random event of the rings brings it to look at the player's ship, then attack
  it with an MWG; destroyed, it leaves its Singularity Core, an oddity. Details: [GAME.md](GAME.md#hybrid).
- **IFF** (`IFF_AUTO`, `IFF_FRIENDLY`, `IFF_HOSTILE`: "Auto", "Friendly", "Hostile"): the slider beside each object on
  the OMS Pilot tab (`hud/components/IffSliderLabel.gd`), which tells the ship's AI and turrets to treat it as a
  friend or a foe, or as its faction says (Auto, where it starts). Kept while the object stays identified, never
  saved (`ship-ctrl.gd` `setIff`). Details: [GAME.md](GAME.md#iff).
- **Info box** (no text of its own in `en.po`): the box the HUD shows by a chunk the crew's geologist has identified,
  with its minerals in kg and its value (`hud/MineralMark.gd`); it shrinks to a small square while the HUD's row of the
  Geologist tab doesn't let the chunk through. Details: [GAME.md](GAME.md#info-box).
- **Insurance** (`ENCELADUS_INSURED_FOR`, "Insured for"): money kept apart from the player's
  (`CurrentGame.getInsurance`, `state.insurance`) that pays for repairs first. Jameson's Insurance (`SERVICE_JAMESON`),
  at Services, adds to it. Details: [GAME.md](GAME.md#insurance).
- **Intake**: where the arm feeds chunks into the ship: a grinder, an excavator or a side bay (see *Salvage arm
  facts*).
- **Launch sequence**: what the station plays after Launch Ring Dive (`ENCELADUS_RETURN_TO_RING`) and the Dive entry
  point (`ENCELADUS_DIVE_TARGET`): the ship powers up and leaves the dock (`enceladus/Enceladus.gd`
  `_on_DiveTarget_launch`: `ExitPlayer`'s `LaunchSequence`, then, once the ship has power, `Autopilot`'s `GoToRing`,
  which ends in `goToRing()`, the switch to the ring scene). Esc or `cutscene_ff` cuts it short (`Enceladus.gd`
  `_physics_process`). The ship flown there is the station's, thrown away with the scene. DiveSkipTransit cuts the
  sequence as soon as it starts.
- **LIDAR** (`HUD_LIDAR`, "Doppler LIDAR"; `hud/LIDAR.gd`): the HUD's scanner of nearby objects. Its sweep plays a
  ping (the `Bleep` node) for each strong return, pitched and set in volume by the distance; a Tuning switch
  (`doBleep`) turns the pings off. What it has seen (`hasSeen`) and the Pilot tab rows it adds:
  [GAME.md](GAME.md#pilot-tab).
- **Lifepod** (`ODDITY_LIFEPOD`, "Lifepod rescue reward"): an escape pod, `ships/Lifepod.tscn`, a ship of its own
  (`ship-ctrl.gd`) and an oddity (see *Oddity*). A ship whose scene names a `lifepod` leaves one when it explodes
  (`ship-ctrl.gd` `vanish`), with the ship's transponder, faction and speed; others float alone in the rings. Details:
  [GAME.md](GAME.md#lifepod).
- **MAD-CERF** (no name text in `en.po`; CombatSimulator names it, `COMBATSIMULATOR_MODEL_MADCERF`): a large ship with
  docking clamps (`SYSTEM_DOCKING_CLAMPS`) and two reactors, scene `ships/MAD-CERF.tscn` (Shipyard model `MADCERF`).
  The game flies it as the rescue ship of the `helper` faction (see *Rescue* and *Salvage claim*), and as the pirates'
  abductor. Details: [GAME.md](GAME.md#mad-cerf).
- **Mechanic**: the crew occupation for repairs, and the OMS tab listing the ship's equipment, to switch each piece
  on and off and fix it: one row per system (`hud/SystemList.gd`, the list in `hud/OMS.tscn`). WeaponMaxPowerSwitch
  adds its row first, and TurretLockableFacing its row last, on a ship with a turret.
- **Mineral**: what a chunk is made of, named in code by its element symbol (`mineral = "PT"`). Processed ore
  (`HUD_CARGO_LIST_PROCESSED`) is what the MPU has extracted; it is sold or stored at the Mineral Market.
- **Mineral Market** (`ENCELADUS_MINERAL_MARKET`, `enceladus/MineralMarket.tscn`): the station screen where processed
  ore is sold and bought, one row per mineral (`enceladus/MineralSellSlider.gd`): its tonnes held, the price for the
  day, a slider of whole tonnes and a price chart (`enceladus/MineralPriceChart.gd`) with the past and, as the crew's
  geologist predicts it, the coming months. Its header shows the player's money. Details:
  [GAME.md](GAME.md#mineral-market).
- **Morale** (crew happiness): each crew member's mood, `morale` in their entry of `CurrentGame.state.crew`, from
  -0.5 to 0.5 (`changeCrewMorale` clamps it), 0 for a new hire. It has no text in `en.po` and no number on screen;
  the crew line-up at the station (`enceladus/CrewFaceOnEnceladus.gd`) shows a happy or a sad icon. It raises or
  lowers the member's crew stats, drifts every day towards a target, and changes with the station's Services (the
  bar, the hotels and other paid services), conversations and unpaid wages. Details: [GAME.md](GAME.md#morale).
- **MPU** (`SYSTEM_CARGO_MPU*`, `ships/modules/MineralProcessingUnit.gd`): the Mineral Processing Unit, which turns
  the chunks taken in into processed ore and, in most models, their water into remass.
- **Nanodrones** (the word is in their descriptions, `SYSTEM_DND_TS_DESC`): drones a plant on a hardpoint assembles as
  it launches them (`weapons/drone-plant.gd`, `weapons/drone-plant.tscn`), from parts in the ship's nanodrone storage
  (`SYSTEM_DND_1000` and up; `droneWeightKg` each): the MPI Tug drones (`SYSTEM_DND_TS`, `droneFunction` "tug"), the
  MLF Haul Drones (`SYSTEM_DND_HAUL`, "haul") and the OME Maintenance drones (`SYSTEM_DND_FIX`, "repair"). Each plant
  works on one target at a time, picked by `scanForTarget`; DroneAltPriorities changes the choice among the eligible
  objects for the player's tug and haul plants. Details: [GAME.md](GAME.md#nanodrones).
- **New Game Options** (`MENU_NEW_GAME_OPTS`; `menu/NewGamePlus.tscn`, `menu/NewGamePlus.gd`): the popup the title
  screen's New game opens while the tutorial is off, with the new game's seed and the first ship's transponder and
  name (Reroll draws others). OK starts a new game with them (`CurrentGame.newGamePlus`); nothing carries over from
  another game.
- **Notification panel** (no text of its own in `en.po`; its notices' titles are the `NOTIFICATION_*` keys, such as
  `NOTIFICATION_ACQUIRED`, "Acquired"): the notices in the middle of the screen's upper half, one at a time, of a ship
  acquired or lost, a drone's cargo in transit, a crew member's level-up or leaving, a discovery, an achievement and a
  change of money (`achievement/Notifications.tscn`, `Notifications.gd`). The ring scene and the station each have one.
  DiveSkipTransit has the station's show what the ring scene's had left to show. Details:
  [GAME.md](GAME.md#notification-panel).
- **Obonto** (`SERVICE_OBONTO`, "Obonto Habitats"): the company that keeps the SRA series of habitats in the rings,
  "for agricultural and research purposes" (`SERVICE_OBONTO_DESC`), faction `obonto` (see *Habitat*), and its
  compensation row at Services (see *Services*).
- **Oddity**: an object worth a reward of its own (`specialPrice`, named by its `specialName`): a lifepod, a frozen
  body, an AI core and others. One the arm holds when the dive ends goes into the cargo (`ship-ctrl.gd`
  `handleExitToEnceladus`) and is sold for its reward (`CurrentGame.gd` `getMarketPrice`).
- **OMS** (`HUD_OMS`, `hud/OMS.gd`, `hud/OMS.tscn`): the Onboard Maintenance System, the console opened with `J` in
  flight. Its tabs are named by the crew occupation keys: Mechanic, Astrogator, Geologist, Pilot. The Pilot tab (the
  pilot screen) lists what the ship has identified (`hud/ShipList.gd`, the ship's `identifiedShips`): every object
  with a transponder the LIDAR has swept, and what the astrogator's marks name (`hud/ShipMark.gd`), each with its name
  and transponder (UIO for none), a button to hail it (`HUD_HAIL`), its bearing and distance once marked, and its
  IFF. Its Comms section (`HUD_COMMS`) is the log of the comms line. Details: [GAME.md](GAME.md#pilot-tab).
- **Physics rate** (`SETTINGS_FPS`, "Physics Simulation FPS:"): the physics steps the game runs a second
  (`Engine.iterations_per_second`), `Settings.cfg.gameplay.fps`: 60 by default, and the menu offers 30 to 165
  (`menu/SettingsLayer.tscn`). With Dynamic Temporal Simulation Simplification on (`SETTINGS_ADAPTIVE_FPS`,
  `cfg.display.adaptiveFps`, the default), it follows the real frame rate. Weapons and damage that count physics
  frames change with it. Details: [GAME.md](GAME.md#physics-rate).
- **Point Defence Turret** (players call them PDWs; the name is in the Tuning descriptions, `TUNE_SAFETY_DESC`): a
  turret that aims and fires a weapon by itself (`ships/modules/PDT.gd`). The player can buy two: the ONMWG-650
  (`SYSTEM_PDMWG`, `-L`, `-R`; a microwave emitter, `weapons/emp.gd`, firing on its own) and the NDPT-4205
  (`SYSTEM_PDT`, `-L`, `-R`; a minigun, `weapons/massdriver.gd`, which "Fires on human command only": while the fire
  command is held, `autoFire` false), which the Equipment screen offers only after a story event. Each targets hostile
  ships and roids, never a chunk. The same script runs the AEMD-14 and the CL-200AP (`SYSTEM_ACTEMD14`,
  `SYSTEM_ACL200P`), gimballed weapons that turn only a little (`gimbalLimit`). TurretLockableFacing locks the player's
  turrets facing where their hardpoints point. Details: [GAME.md](GAME.md#point-defence-turret).
- **Racing drone** (its scene's `SHIP_DRONE` is a key the game's texts lack; CombatSimulator names it,
  `COMBATSIMULATOR_MODEL_DRONE`): the small crewless drone the ring races are flown to chase (`story/RingRace.gd`,
  faction `racedrone`), scene `ships/drone/Drone.tscn` (Shipyard model `DRONE`), built new (`createShipByName`, age 0).
  Its reactor is tiny (scaled to a quarter), with no body for turrets to aim at, and it has no lifepod.
- **Random event** (no text of its own in `en.po`): something the rings bring by chance ahead of the ship: a derelict,
  pirates, a lifepod, frozen bodies, a habitat, Vilcy, a race and more. Each is a node of `story/TheRing.tscn` with a
  `canBeAt` and a `makeAt`, picked by `TheRing.gd` `getOddityAt` for `AsteroidSpawner.gd`. Details:
  [GAME.md](GAME.md#random-event).
- **Reactor** (`SYSTEM_REACTOR_*`; `ships/Reactor.gd`): the ship's nuclear reactor, the equipment that makes heat. The
  turbine (`SYSTEM_TURBINE_*`, equipment for fission ships, read as the config `turbine.power`) turns that heat into
  electricity and burns remass to do it (`turbineConsumption`). With no remass left, it makes no power. The HUD shows
  the temperature as `HUD_REACTOR_TEMP`, and the `power_reactor_toggle` action switches the reactor on and off. Too
  hot for too long, it explodes. The EIME's StarCAT Stellarator (`SYSTEM_REACTOR_EIME`,
  `ships/modules/FusionReactor.gd`) is a fusion reactor. Details: [GAME.md](GAME.md#reactor).
- **Reactor leak** (`DAMAGE_LEAK`): damage to a nuclear reactor from impacts close to it (`Reactor.gd` `_on_impact`).
  A bad leak vents remass and lowers the meltdown temperature; it is the only way to disable an enemy ship so it can
  be captured. Details: [GAME.md](GAME.md#reactor-leak).
- **Remass**: reaction mass, the ship's propellant (`HUD_FUEL`, shown as "propellant").
- **Repairs** (`ENCELADUS_SHIP_REPAIRS`, `enceladus/Repairs.gd`): the station screen that fixes the current ship's
  damaged equipment for E$ and in-game hours (`enceladus/SystemShipRepairUI.gd`), with Replace or Fix. The hours are
  the ship's maintenance (`CurrentGame.isShipMaintained`), during which it can't dive or be sold. ShipRepairAdvisor adds
  a row at its bottom, with its Repair and Park buttons. Details: [GAME.md](GAME.md#repairs).
- **Rescue**: how a dive ends when the player's ship is helpless, out of remass or power for a while (`ship-ctrl.gd`
  `isHelpless`, `Game.gd` `_process`): the `helpless` cutscene, in which the clock jumps ahead and a MAD-CERF comes,
  then the station.
  DiveSkipTransit skips the cutscene, charging only its in-game time. Details: [GAME.md](GAME.md#rescue).
- **Ring scene**: the scene of a dive in the rings (`Game.tscn`, `Game.gd`), loaded from the station by `goToRing()`
  and left for the station by `goToEnceladus()`, or for the title screen after a game over. It holds the player's
  ship, the asteroid field (`AsteroidField.tscn`, whose `AsteroidSpawner.gd` also moves the in-game time on every
  frame) and the title cards of its cutscenes.
- **Roid**: an asteroid (`asteroids/asteroid.gd`, a `RigidBody2D`), the rocks that fill the rings; the game's own
  texts say "roids" too. Five size classes; a roid's damage adds up until it splits into smaller roids, the smallest
  class into chunks. Details: [GAME.md](GAME.md#roid).
- **Salvage** (`POI_SALVAGE`, "Salvage: {0}"; the `ACHIEVEMENT_SALVAGE_*` achievements, "Recover a derelict ship"):
  taking a derelict into the fleet, by holding it with the arm until the dive ends at the station or by sending a crew
  member over to restart it (see *Salvage claim*). Only some models are ever derelicts; pirate ships are salvageable
  too (`CurrentGame.isShipSalvageable`), but only once disabled in combat. Derelicts come from random events of the
  rings (`story/TheRing.tscn`, `TheRing.gd` `getOddityAt`), from the Scrapwright Recovery Operations subscription
  (`SERVICE_SALVAGE_LICENCE`) and from some conversations. Details: [GAME.md](GAME.md#salvage).
- **Salvage claim**: a phrase from one derelict line, "…with that rescue ship on our back, they'll file for a salvage
  claim anyway." (`DIALOG_DERELICT_TAKEN_4`), not a mechanic: the game records no claim on a derelict. A rescue ship
  in sight when the derelict talks ends the conversation; a ship the arm holds when the dive ends at the station joins
  the fleet if it is salvageable (`ship-ctrl.gd` `handleExitToEnceladus`, `CurrentGame.isShipSalvageable`). Details:
  [GAME.md](GAME.md#salvage-claim).
- **Services** (`ENCELADUS_SERVICES`, `enceladus/Services.tscn`): the station screen of paid services, one row each
  (`enceladus/ServiceUI.gd`, its `serviceName` the service's key): a bar (The Twins, `SERVICE_BAR_TWINS`) and four
  hotels (`SERVICE_HOTEL_*`), which take in-game hours and lift the crew's morale, and monthly ones such as Jameson's
  Insurance (`SERVICE_JAMESON`, see *Insurance*) and Scrapwright Recovery Operations (`SERVICE_SALVAGE_LICENCE`, see
  *Salvage*). Some can't be bought again for a while: those with a cooldown (`cooldownHours`: The Twins and the
  monthly ones), and the compensation rows
  (`enceladus/ServiceUIFactionChange.gd`: Local Vilcy Branch, The Miner's Guild and Obonto Habitats), which pay off a
  faction's hostility and fear towards the player and cost nothing until it holds a grudge again. ServiceNotifier
  marks the station menu's Services entry while one of those can be bought. Details: [GAME.md](GAME.md#services).
- **Shift badge** (not the game's: these mods' own term): the small framed "Shift" beside a station menu entry, or on
  the simulator's button, MarketAdvisor's Trade button or ShipRepairAdvisor's Repair button, whose Shift+Click opens a
  mod's settings or dialog (`Badge.gd`); it reads `PAD_TEXT`, the gamepad twin, while the control scheme is the gamepad,
  and its tooltip says how, in either form: on hover, and with a gamepad while the entry or button is highlighted.
  CombatSimulator, CrewCheapHireNotifier, DealerNotifier, DiveSkipTransit, MarketAdvisor, ServiceNotifier and
  ShipRepairAdvisor have one.
- **Ship models**: the kinds of ship, each with a key in `Shipyard.ships` (`TRTL`, `PROSPECTOR-VP`, …), a scene
  (`ships/RA-TRTL.tscn`) and the translation key of its name in the ship's `shipName` (`SHIP_TRTL`). The Dealer shows
  the names: K37 TNTRL, Eagle Prospector, Vulture Prospector, EIME (Eon Interstellar Model E), OCP-209, the Cothons,
  the ND-LIS Kitsune, …. These docs also name some by their scenes: the Eagle-Prospector-VP (the VP) is the Vulture
  Prospector, the Eagle-Prospector-Lux the Peacock Prospector.
  - A **series** is a base model and its variants, as `Shipyard.gd` `configAlias` folds each variant into its base
    model (`getShipAlias`); a variant's `baseShipName` is its base's name. In game 1.93.1: K37 TNTRL (KX37, Runasimi
    KR37 and KTA24 TNTRL, K44 MHFTR Prototype), Eagle Prospector (Vulture, Peacock and Pelican Prospector), Cothon-212
    (Cothon-211 "Chonker", -213 "Triplet", -217 "Bender"), Antonoff-Titan K225 (K225-BB, K225 (modified)); the other
    models are alone in theirs. Which models the dealer offers: see *Dealer*.
- **Simulator** (MVFS; `ENCELADUS_LAUNCH_VR`, `enceladus/Simulator/`): the Minding Virtual Flight Service, the
  station's flight simulator for trying a ship as fitted; launched from its button (`LaunchVRButton.tscn`, with the
  `jury_rig` action, J or the gamepad's Back, as its shortcut) on the Tuning screen, the Equipment screen's User
  Manual tab and the Examine Ship tab of the Dealer and of Fleet. A Premium subscription (`SERVICE_SIMULATOR`) adds a
  simulated ring scenario. Shift+Click on the button, or Shift plus its key, or their gamepad twins (see *Shift
  badge*), opens CombatSimulator's combat simulation instead.
- **Smart camera** (`SETTINGS_SMART_CAMERA`, "Smart camera"): the default of the game's four camera settings, with
  Direct camera, Smoothed camera and Fixed camera (`SETTINGS_STUPID_CAMERA`, `SETTINGS_SMOOTH_CAMERA`,
  `SETTINGS_FIXED_CAMERA`; `menu/SmartCamera.gd`, `Settings.cfg.display`): the camera follows the action and zooms by
  itself, and, as Smoothed camera does too, raises adrenaline when something closes in fast (`ships/camera.gd`).
  Details: [GAME.md](GAME.md#adrenaline).
- **Thrusters** (no key of their own; the word is in the pieces' names, `SYSTEM_THRUSTER_*`): the equipment that moves
  the ship by burning remass, in two slots of the Equipment screen: the Reaction Control System (`SLOT_RCS`, slot
  `propulsion.rcs`, `ships/modules/ThrusterSlot.tscn`), the RCS, small thrusters that turn and nudge the ship, and Main
  Propulsion (`SLOT_TORCH`, slot `propulsion.main`, `ships/modules/TorchSlot.tscn`), the torches
  (`SYSTEM_MAIN_ENGINE_*`) that push it forward. Every piece runs on `sfx/thruster.gd`, and the Tuning screen sets each
  one's thrust. Firing wears them (`DAMAGE_WEAR`), and a worn thruster misfires. Details:
  [GAME.md](GAME.md#thrusters).
- **Title card** (no key of its own; the arrival's shows `CUTSCENE_RINGS_OF_SATURN`, "The Rings of Saturn"): the
  titles a cutscene of the ring scene shows over the view, on `Game.tscn`'s `TitleAnimPlayer` (`intro`, `exit`,
  `fasttravel`, `gameover`, `helpless`). Details: [GAME.md](GAME.md#cutscene).
- **Transit**: the interlunar trip between the station and the rings, which costs remass and in-game time each way and
  isn't flown: the main drives (the ship's thrusters, which burn remass) and the xenon drive share each way's ΔV, the
  ΔV for trajectory (`MAP_DV`) of the Dive entry point picked. Details: [GAME.md](GAME.md#transit).
- **Transponder** (no key of its own; the word is in many lines, `{origin/transponder}`): the code a ship or object
  broadcasts. The Dealer and Fleet show it as Registration, and the HUD's ship marks, the LIDAR's labels, the OMS
  Pilot tab, comms, the dive's title card and the save slots show it too. The game makes codes in `CurrentGame.gd`
  (`getNewTransponder`, `getTransponder`); a ship keeps its code for good, and the game keys the ship's name and what
  it remembers about the ship on it. Pirates broadcast none. TransponderAltCodes makes new codes say what carries
  them. Details: [GAME.md](GAME.md#transponder).
- **Tsukuyomi** (no name text in `en.po` for the model, which the game's lines call a "Tsukuyomi-class frigate",
  `DIALOG_VILCY_BBW_ITS_BBW`; CombatSimulator names it, `COMBATSIMULATOR_MODEL_TSUKUYOMI`): scene `ships/Tsukuyomi.tscn`
  (Shipyard model `TSUKUYOMI`), a frigate with three large reactors, no hardpoints and seven turrets of its own. The
  one in the rings is the **Big Bad Wolf**, Vilcy's mobile headquarters (its `customName`, transponder `SE1-BBW1`).
  Details: [GAME.md](GAME.md#tsukuyomi).
- **Tuning** (`ENCELADUS_SHIP_TUNING`, `enceladus/Tuning.tscn`): the station screen with the settings of each piece
  of the current ship's equipment, registered by its script with `registerSubsystem` and saved with the game (see
  *Conventions*).
- **UIO** (no key in `en.po`: the `placeholder` of `hud/components/ShipOnOMSLabel.tscn`): what the OMS Pilot tab
  shows in place of a transponder for an object with none (a pirate ship the astrogator has marked;
  `ShipOnOMSLabel.gd` `set_text`). LidarContactCallout's callouts use it too.
- **Vilcy** (`SERVICE_VILCY`, "Local Vilcy Branch"): "an organized bounty hunter group" (`SERVICE_VILCY_DESC`),
  faction `vilcy`, hostile to pirates. Its ships come in random events of the rings (`story/Vilcy.gd`) and hail a
  player with an ex-pirate in the crew (see *EVA*); its headquarters is the Big Bad Wolf (see *Tsukuyomi*). Local
  Vilcy Branch, at Services, pays off its grudges (see *Services*). Details: [GAME.md](GAME.md#vilcy).
- **Weapons** (no key of their own): the equipment that fires, mounted on a hardpoint (`weapons/WeaponSlot.tscn` names
  each system's scene; `enceladus/Upgrades/WeaponSlotUpgrade.tscn` holds the Equipment screen's offers and prices), in
  five families: mass drivers (`weapons/massdriver.gd`), lasers (`weapons/laser.gd`), microwave emitters
  (`weapons/emp.gd`), the SPC Gungnir (`SYSTEM_SYNCHRO`, `weapons/synchrotron.gd`) and exhaust weapons, thrusters
  pointed forward (`sfx/thruster.gd`). A hit does kinetic damage, heat or EMP. A hardpoint fires its weapon with the
  power it is given (`ships/WeaponSlot.gd` `fire`), 0 while it is switched off; CombatSimulator's Disabled weapons
  passes 0 the same way. A weapon's power, and a pulse laser's Pulse frequency, are Tuning settings, which
  WeaponMaxPowerSwitch's switch sets to their ends during a dive. Details: [GAME.md](GAME.md#weapons).
- **Xenon drive**: the low-thrust, economical drive every ship has for transit, which burns no remass (the game keeps
  no stock of xenon). Its Tuning setting, Interplanetary Xenon transit drive usage (`TUNE_XENON_BURN`, a HUD built-in:
  `hud/Hud.gd` `getTuneables`), sets its share of the trip out. Details: [GAME.md](GAME.md#xenon-drive).

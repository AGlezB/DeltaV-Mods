# Screenshots for the users' wiki

`shots.ps1` (PowerShell 7) takes the users' wiki's "without the mod / with the mod" pictures of the station screens
and of the OMS, which it opens in a dive, by running the real game, in an isolated copy, and saves them in
`_wiki\images\` (see MODDING.md *The users' wiki*). Pictures of flight, which depend on what is around the ship (the
HUD, the info boxes), are taken by hand, with bloom off as in the runs.

```powershell
.\_shots\shots.ps1                                    # every mod in shots.psd1
.\_shots\shots.ps1 -Mod LidarLouderPing               # one mod (or several)
.\_shots\shots.ps1 -NewFixture                        # build the fixture save again first
.\_shots\shots.ps1 -Steps 'load', 'wait|10', 'press|{menu}/ShipTuning', 'wait|3', 'shot|tuning' -WithMods LidarLouderPing
                                                      # ad-hoc steps, saved in TempDir\shots\out: to find a view
```

Each mod runs twice from the same save, without the mod and with it, about half a minute each, a minute with a dive; a
run with nothing to shoot (every view only the mod has) is skipped. The game's window opens on a screen other than the
main one, where there is one, and plays without sound. ShotRenderer is what moves it there, so before each run the copy
starts once without a window, for a single frame: if a script doesn't load (ShotRenderer's or a mod's), the run stops
there, before any window opens.

## Which mods

Only mods with a screen of their own, or that add to or change a game screen, have pictures. Mods that only reorder a
list or change how the game plays have none (BootSkipLogos, CrewPerfectSort, DiveDisableAdrenalineBooster,
ShipSortByTypeAndPrice); the arm mods have their diagrams.

## How it works

- **The copy.** In `TempDir\shots\` (`paths.local.psd1`): `bin\Godot.exe`, a copy of the stock Godot 3.6 from
  `GodotDir`, and `bin\Delta-V.pck`, a copy of the game's data from `GameDir`, both copied again when the originals
  change; `bin\mods\`, the mods of the run; `appdata\`, the copy's user folder; `out\`, the pictures before they are
  copied to `_wiki\images\`. Never `Delta-V.exe`: its GOG module would reach the player's account.
- **The player's data is never touched**, by four separate means:
  1. the game runs with `APPDATA` (and the `XDG_*` folders) pointed at `TempDir\shots\appdata`, for that process only;
  2. an `override.cfg` next to the copied `Delta-V.pck` renames the game's user folder from `dV` to `dV-shots`;
  3. ShotRenderer stops the game at once if its user folder is anywhere else;
  4. `shots.ps1` records the names, sizes and times of the files in `%APPDATA%\dV` before and after, and fails if
     anything changed. It refuses to run while the game is running.
- **The copy's settings** (`appdata\dV-shots\settings.cfg`, written at every run): a 1600x900 window, no bloom (the
  game's default is full bloom), no tutorial, English, no sound, and the game's streaming mode, without which the game
  pauses whenever its window loses the focus (`PauseLayer.gd` `_notification`). BootSkipLogos is loaded in every run, to skip the logos.
- **The fixture** (`newgame`, ShotRenderer's `_newGame`): a new game with a fixed seed, money, one hire per job, and
  in the fleet a spare of the same model as the ship flown and two ships of other models. It is built when missing or
  with `-NewFixture`, and saved in the copy's user folder; every run loads it, so a pair of pictures differs only by
  the mod.
- **ShotRenderer** (`ShotRenderer\ModMain.gd`) is a mod loaded only in the copy: it runs the steps of the job file
  `shots.ps1` writes next to the executable (`bin\shotrenderer.cfg`), then quits. Without that file it does nothing.
  Its steps are listed at the top of the script: `load`, `wait`, `press` (a button's `pressed` signal), `click` and
  `clickfind` (a real mouse click, through the game's input), `shiftclick` (Shift+Click, as the mods' settings open),
  `tab` (by number or by the tab's node name), `scroll` and `shot`. In a dive: `dive` (from the station into the ring
  scene, without the dive target screen, which saves, then until the arrival cutscene is over), `action` (an input
  action, as its key: `jury_rig` is J, the OMS) and `set` (a node's property, or a key of a dictionary in it, to a JSON
  value: GeologyByMass's example settings). A path starting with `ship:` starts at the player's ship.
- **`shots.psd1`**: the steps of each mod. `shot|<view>|x,y,w,h` saves that part of the window as
  `<Mod>-<view>-without.png` and `-with.png`; a step starting with `with:` runs only with the mod, and a view shot that
  way is saved once, as `<Mod>-<view>.png`. `{menu}` and `{screens}` stand for the station menu's entries and the
  screens they open, `{oms}` for the OMS's tabs in a dive.

## Notes

- The game's screens are opened with `press`: a real click on the menu's Crew entry gets lost in a run without crew
  mods (something over the lower entries; not looked into further). The mods' own buttons (ShipCopyPaste's) need
  `click`, which also gives them the focus as a player's click does. A mod's settings screen opened with `shiftclick`
  closes only with a real `click` on another entry, so each run opens it last.
- After a game update, run it with `-NewFixture`: the "without" pictures show the game's own screens. When
  `wiki.ps1` names a rendered picture to re-take, run the mod's shots again.
- A new view: find its place with `-Steps`, full-window shots in `TempDir\shots\out`, then add the steps and the crop
  to `shots.psd1`.

# Screenshots for the users' wiki

`shots.ps1` (PowerShell 7) takes the users' wiki's "without the mod / with the mod" pictures of the station screens,
and of the OMS and the HUD in a dive it starts, by running the real game, in an isolated copy, and saves them in
`_wiki\images\` (see MODDING.md *The users' wiki*). It also draws the game's ships and weapons alone, with what a combat
page needs over them (see *Ship and weapon pictures*). Pictures that depend on what is around the ship (the info boxes
by the chunks) are taken by hand, with bloom off as in the runs.

```powershell
.\_shots\shots.ps1                                    # every mod in shots.psd1
.\_shots\shots.ps1 -Mod LidarLouderPing               # one mod (or several)
.\_shots\shots.ps1 -NewFixture                        # build the fixture save again first
.\_shots\shots.ps1 -Steps 'load', 'wait|10', 'press|{menu}/ShipTuning', 'wait|3', 'shot|tuning' -WithMods LidarLouderPing
                                                      # ad-hoc steps, saved in TempDir\shots\out: to find a view
```

Each mod runs twice from the same save, without the mod and with it, about half a minute each, a minute with a dive
(HudHideLabels dives once per HUD, so each of its runs takes several minutes); a run with nothing to shoot (every view
only the mod has) is skipped. The game's window opens on a screen other than the main one, where there is one, and plays
without sound. ShotRenderer is what moves it there, so before each run the copy starts once without a window, for a
single frame: if a script doesn't load (ShotRenderer's or a mod's), the run stops there, before any window opens.

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
  `tab` (by number or by the tab's node name), `scroll`, `set` (a node's property, or a key of a dictionary in it, to a
  JSON value: GeologyByMass's example settings, HudHideLabels' HUD) and `shot`. For a dive: `dive` (from the station
  into the ring scene, without the dive target screen, which saves, then until the arrival cutscene is over) and
  `action` (an input action, as its key: `jury_rig` is J, the OMS). A path starting with `ship:` starts at the player's
  ship, and `ship:.` is the ship itself. `ship` and `weapon` draw a ship, or a weapon mounted on one, alone (see *Ship
  and weapon pictures*). It prints `SHOTRENDERER done` after the last step: a run that ends without it fails.
- **`shots.psd1`**: the steps of each mod. `shot|<view>|x,y,w,h` saves that part of the window as
  `<Mod>-<view>-without.png` and `-with.png`; a step starting with `with:` runs only with the mod, and a view shot that
  way is saved once, as `<Mod>-<view>.png`. `ship|<model>|<view>` and `weapon|<system>|<model>|<slots>|<view>` are
  saved the same way. `{menu}` and `{screens}` stand for the station menu's entries and the screens they open, `{oms}`
  for the OMS's tabs in a dive. `TimeoutSeconds` gives a mod's runs longer than `shots.ps1`'s default before they are
  stopped (HudHideLabels, one dive per HUD; CombatSimulator, every ship and weapon). Before each run, the pictures an
  earlier run of that mod left in `out\` are deleted, so a run that stops early can't pass old ones off as its own.

## Ship and weapon pictures

ShotRenderer's `ship` and `weapon` steps draw in a viewport of their own, never on the window, so they need no screen
open. They take a Dealer entry's viewport (`enceladus/SystemBuyUI.tscn`: its lights and environment, not its camera)
and build the ship as DealerNotifier's settings screen does, kept out of the save, as a dummy with its reactors off.
They draw nose up on a plain dark background, and save RGB pictures with no text. Each has a thin scale bar at the
bottom left, a round length (1, 2 or 5 times a power of ten metres) that the run prints (`SHOTRENDERER scale bar`), for
the wiki to say what it measures.

- **`ship|<model>|<view>`**: a model of `Shipyard.ships`, every hardpoint empty (a built-in turret, as the Tsukuyomi's,
  keeps its weapon), framed to the ship (its collision shapes, hull sprites and turrets) with a margin. Every ship is
  drawn at `SHIP_PX_PER_METRE`, except where the picture's longer side would be smaller than `SHIP_MIN_PX` (scaled up:
  the racing drone) or larger than `SHIP_MAX_PX` (scaled down: the Tsukuyomi). Over it, the heat map of where a hit
  damages a reactor (`Reactor.gd` / `FusionReactor.gd` `_on_impact`: damage falls as 1/d², where d is measured in the
  reactor's own frame, scale included, from the edge of its core). It uses one scale for every ship, so pictures
  compare: full colour where 1/d² is that of the standard fission reactor's core, fading over `HEAT_DECADES` powers
  of ten, with a contour line at each power of ten and around each reactor's core. Reactor leak is in reds and
  yellows; the EIME's fusion reactor, whose hits damage its coolant, in blues.
- **`weapon|<system>|<model>|<slots>|<view>`**: the system (a node name of `weapons/WeaponSlot.tscn`) mounted on the
  hardpoints `<slots>` (comma-separated) of the model, its other hardpoints empty; `-` instead of a system keeps
  what the ship's scene mounts there (the Tsukuyomi's built-in turrets, `ships/modules/PDT.tscn`, which no hardpoint
  takes). Two panels side by side. On the left, the ship close up (at the ship pictures' scale where it fits), with the
  weapon's cone. On the right, a wide view of its reach, the ship as a ringed marker: a fixed weapon's cone out to its
  range, with a mark there; a turret's pick-up areas, the places where it takes a body as a target, and its weapon's
  range around it. What is drawn comes from the mounted weapon's own values:
  - the cone: filled yellow as the weapon fires new and at its default tuning, its widest as orange edges (full focus
    damage; an MWG also at the most power its tuning allows). A laser or an SPC is a straight line. A mass driver's
    cone goes on, fainter, past its range: its slugs have no lifetime, and the range is where the AI aims;
  - an exhaust weapon's plume (`sfx/thruster.gd`): its damage ray, as long as the game makes it, brighter where half
    its rays go, fading as its damage does; past it, the iron thrower's thrown iron goes straight on, out to its own
    range;
  - a turret's arcs, around its pivot in the close-up: in light blue where it can aim (all around, or its gimbal
    limit), brighter where it aims within a second from rest, and in green its safety distance, when it has the safety
    protocol;
  - a turret's pick-up areas: magenta for ships, amber for rocks, violet for both, by the physics layers the area
    watches.

## Notes

- The game's screens are opened with `press`: a real click on the menu's Crew entry gets lost in a run without crew
  mods (something over the lower entries; not looked into further). The mods' own buttons (ShipCopyPaste's) need
  `click`, which also gives them the focus as a player's click does. A mod's settings screen opened with `shiftclick`
  closes only with a real `click` on another entry, so each run opens it last.
- After a game update, run it, with `-NewFixture`, only for a mod whose pictures the update makes wrong: where it
  changes what the mod acts on (a title HudHideLabels hides is gone, renamed or already hidden by the game itself),
  not where it changes anything else on screen (MODDING.md *The users' wiki*, *Keeping it up to date*). When
  `wiki.ps1` names a rendered picture to re-take, run the mod's shots again.
- A new view: find its place with `-Steps`, full-window shots in `TempDir\shots\out`, then add the steps and the crop
  to `shots.psd1`. Ship and weapon pictures are tried the same way:
  `-Steps 'load', 'wait|5', 'weapon|SYSTEM_MWG|TRTL|main|mwg' -WithMods CombatSimulator`.

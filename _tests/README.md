# Test harness - ΔV: Rings of Saturn mods

The repository's own test harness (it ships in no zip). The folder names and conventions it uses are in
[MODDING.md](../MODDING.md).

`_tests\run.ps1` (PowerShell 7) tests the mods listed below in a headless Godot 3.6, in a few seconds. It assembles
a Godot project in `TempDir\tests\project` from `_tests\`; the game's own `DockingArm.gd`, `Arm.gd`,
`CabinLight.gd`, `Boot.gd`, `LIDAR.gd`, `PitchAdjustedAudio.gd`, `HardwareLabel.gd`, `EnceladusMenu.gd`,
`HidingMarginContainer.gd`, `AnalogControlSlider.gd`, `TuningFloatValue.gd`, `TuningItems.gd`, `Hud.gd`, `OMS.gd`,
`TabsWithGamepadControl.gd`, `PriceLabel.gd`, `RepeatingHSlider.gd`, `MineralLabel.gd`, `MineralSystemToggle.gd`,
`HireableCrew.gd`, `CrewBio.gd`, `CurrentCrewManagement.gd`, `PlaySoundsOnTheseButtons.gd`, `SystemBuyUI.gd`,
`SystemShipUpgradeUI.gd`, `Tool.gd`, `gdunzip.gd`, `Shower.tscn`, audio buses (`default_bus_layout.tres`), the skill
icons `CrewBio.gd` preloads and a Fleet entry's Use icon (`enceladus/Upgrades/switch.png`; their `.png.import` and
imported `.stex`, so they load without an import step), copied from the decompiled source on every run and never
committed, since they are the game's; a stub mineral scene with the chunk radius read from the game's; bare stubs of
the two scenes `LIDAR.gd` preloads; and stubs of the Tuning scenes (`TuningFloatValue.tscn`, `TuningItems.tscn`,
`TuningBoolValue.tscn`, `HeaderWithMoney.tscn`), of a Hire screen entry (`CrewBio.tscn`, with a portrait stub,
`harness/crew_video.gd`, and the game's tooltip node, `PlaySoundsOnTheseButtons`), of the Geologist tab's parts
(`MineralSystemToggle.tscn`, `MineralLabel.tscn`, `PriceLabel.tscn`), of a Fleet entry (`SystemBuyUI.tscn`, with the
Use and OK icons, the confirmation's frame and margins, the confirmation animations read from the game's scene, the
game's themes for the entry, its labels' grid and its thumbnail margin (`menu/MenuTheme.tres`, `hud/TNTRL-theme.tres`,
`enceladus/Subwindow.theme`, and every font, stylebox and image they load, found by following their `res://` paths),
so its sizes and looks are the game's, and a
flicker stub, `harness/fleet_flicker.gd`) and of an Equipment item (`SystemShipUpgradeUI.tscn`) with the game's node
paths and scripts but no theme, textures or sounds (beyond those named). It packages each mod as a release zip is laid out (MODDING.md *Packaging and releasing*,
without the `LICENSE` copy) and loads the zips as
`ModLoader.gd` does, at the same moment (`_tests\harness\loader.gd` is the `ModLoader` autoload, and loads in its
`_init`; the autoloads keep the game's order), so the zip layout is tested too. Logs: `TempDir\tests\logs`. Godot and
these folders come from `paths.local.psd1` (MODDING.md *Folders outside the repo*), or from the parameters `-GodotPath`,
`-DecompiledRoot`, `-GameSource` and `-WorkDir`.

```powershell
.\_tests\run.ps1                                               # every suite, its own mods, the game's order
.\_tests\run.ps1 -Suite moving -AllOrders                      # one suite, every load order
.\_tests\run.ps1 -Matrix                                       # moving: 109.29/330 t ships x 2.8/5 t chunks
.\_tests\run.ps1 -ModZip <a release zip>                       # a release zip in place of the mod's folder
.\_tests\run.ps1 -Suite units -Mods ArmAltPullBehavior         # other mods than the suite's own (@() = none)
```

Call it from a pwsh prompt or `pwsh -Command`: under `pwsh -File`, list arguments such as `-Suite still,moving` are
not parsed as arrays. Exit code 0 = every run passed; a script error fails its run even if every check passed.

The suites are ported from the claude.ai harness (DVModTestHarness 1.0.0; the original was deleted once ported),
except `boot`, `lidar`, `hud`, `crew`, `geology` and `fleet`. `units`, `still` and `moving` load the two arm mods by
default, `dive` loads DiveDisableAdrenalineBooster, `boot` loads BootSkipLogos, `lidar` loads LidarLouderPing, `hud`
loads HudHideLabels, `crew` loads CrewCheapHireNotifier, `geology` loads GeologyByMass, `fleet` loads ShipCopyPaste.

- `units`: the claude.ai unit tests (`arm/main.gd`) nearly verbatim, on synthetic arms around the game's
  `DockingArm.gd`. TargetSelection: area geometry on turned, scaled and offset arms, reach, the strip, the weighted
  pick, keeping the current target, switch off/on, intake and entry point. PullBehavior: where the pull goes (20
  cases: feeding or not, grinder or excavator, a block of hull; feeding in the corridor, pulled straight in by the
  mod since 1.5.0), the EIME's claws, the hysteresis at the corridor's edge, closed beak, switching ship types,
  cost, nothing pushed while the game pulls (the 1.3.0 bug). Plus 4 checks on the real
  Eagle-Prospector-VP rig, including the hull inertia `moving` uses. A group whose mod is not loaded runs "control"
  checks of the game alone.
- `still` (9 cases, `arm/real.gd`) and `moving` (16 cases, `arm/real_move.gd`): ArmAltPullBehavior bringing a chunk
  in on a simulated Eagle-Prospector-VP, standing still, held in place, cruising at 10–40 m/s or turning, feeding
  or not; two start points are where the author's in-game logs started. Each case expects the chunk in between the
  rotors without touching them, at the dock slot, or moved straight forward first, and prints how long it took.
  The feeding cases behind the red line beside the hull also have a time limit (1.5.0's times + 25 %, below
  1.4.0's), so a slow-down fails.
- `dive` (`dive/main.gd`): the player's Adrenaline Booster (the game's `CabinLight.gd`) starts disabled; another
  ship's booster, other cabin-light systems and a light with no ship are untouched; switching it on sticks; it gives
  adrenaline only when enabled. The control check (the game alone starts it enabled) runs on the game's own script,
  the base of the extension, so it needs no separate run.
- `boot` (`suites/boot.gd`): runs with `_tests\harness\boot.tscn` as the main scene (a scene path on Godot's
  command line), whose root has the game's `Boot.gd`, so the engine loads it after the autoloads, as the game loads
  `Boot.tscn`. Checks that this startup scene got the extension, runs the game's own start-up and then asks for the
  title screen; that the first launch (`Settings.firstBoot`) keeps the logos; and, as control, that the game's
  script alone does not leave them. A `Loader` stub records the calls instead of switching scenes.
- `lidar` (`suites/lidar.gd`): hidden lidars built in code around the game's `LIDAR.gd`, with a `Bleep` on the
  game's `PitchAdjustedAudio.gd` that records each `play()` (`harness/recording_bleep.gd`), under stubs of the HUD and
  the ship (`harness/lidar_reader.gd`, `lidar_ship.gd`). Checks that the slider is registered right below the Tuning
  switch, in its group, with the mod's range, and stays there; that its value (clamped, the default for a non-number)
  moves the ping to the mod's bus, which sends to its own bus (`ShipBowels`, or `SFX`) with the gain, and a gain of 0
  back to its own bus; that the bus is shared, not added twice, and that a lidar without a ping is left alone; that
  the switch still sets `doBleep`. The demo, on a preview's lidar (`dynamicConnect`) with a synthetic sound, driven
  frame by frame with the game's `TuningFloatValue` row focused: the game's volume and pitch for each distance, the
  spacing and the interval, the preview's own pings muted, nothing with another row, no focus, the switch off or a
  lidar that isn't a preview's. And the texts of `i18n/en.po`, also in a language without them. The control checks (the
  ping stays on its bus) run on the game's own script.
- `hud` (`suites/hud.gd`): trees built in code with the node paths and types of the OCP-209's HUD
  (`hud/Display-OCP209.tscn`), the station's Upgrades screen and the `J` screen (`hud/OMS.tscn`), each scene root
  marked by its `filename`; the HUD is added in one go under stubs of the ship and its Hud (the `lidar` suite's),
  as `Hud.gd` `instance()` does. Checks that each title on the HUD (and the feed sub-scene's) is hidden from the
  first frame when its key is in the mod's `HIDDEN_KEYS` and drawn when not, also the LIDAR's, which the game's
  `HardwareLabel.gd` renames in its `_ready`; that hidden titles keep their space; that other labels, a button with
  a title's text and the same titles outside a `Display-*.tscn` are drawn; and that a title added later follows
  `HIDDEN_KEYS` too. The control checks (with `-Mods @()`): every title is drawn.
- `crew` (`suites/crew.gd`): station menus built in code around the game's `EnceladusMenu.gd`, nested as
  `enceladus/EnceladusMenu.tscn` nests them (a `Crew` and a `Logs` Button), with the hire list and the crew set in the
  `CurrentGame` stub and a test translation in two languages. Salaries and slider values are built from the
  descriptions in the mod's `Settings.gd` (`SETTINGS`) and the jobs from `CurrentGame.occupations`; expected texts
  with `tr()` from the mod's keys. Checks that the Crew entry is marked from the first frame; the
  rule's edges (at and above the threshold, which the tolerance never moves either way, also within the tolerance
  above it; at, within the tolerance of, at the end of and above the best-paid member's salary in that job; the
  threshold above a best-paid below it even after the tolerance; the tolerance clamped to its minimum, and there a
  hire at the best-paid salary times it, above it and, when negative, at the best-paid salary itself; another job);
  the crew limit (a job below it judged as usual; a limit lowered to the crew hired fills the job at once; in a full
  job a hire at the best-paid salary not marked and one below it marked, the threshold and the tolerance at its
  minimum ignored; another job judged as usual; benched and on-leave crew counted; a limit of 0 with nobody in the job
  and with someone; firing frees the job and hiring fills it);
  that `dayPassed` and `employmentChanged` refresh it both ways and an unmarked entry gets its key back; that a marked entry follows a language change; and
  that the other entries, a menu without `Crew` and the game's `disable()` are untouched. The settings model: one
  shared instance; the crew limit per job, for each of `CurrentGame.occupations`, and the salary settings not;
  defaults for a save without the mod's entry, every crew limit at its maximum; a save from before the crew limit;
  a tolerance saved as a dictionary by job read as the default; clamping and snapping of what is loaded or set, also per job,
  and a job missing or not a number in a saved dictionary, or a crew limit that is not one; saving into
  `CurrentGame.state.ui` under the manifest's id, with the format and mod versions and every job, a job's change
  stored for that job only and as a copy, and a signal only on a change; the % conversion. The texts of
  `i18n/en.po`, also in a language without them. The Hire screen: the Hire tab built as `enceladus/Crew.tscn` nests it, around the game's
  `HireableCrew.gd` and `CrewBio.gd`, with a theme holding a Button font color and a flat frame with an overbright
  border, and the menu beside it. Each qualifying person's entry, at and below the limit, has a visible badge:
  above the details grid's values, right-aligned with them, one grid row gap above, at its minimum size and inside
  the entry; the capitals of the manifest's name in the Hire button's font color times `colorBetter`; a copy of the
  Hire button's frame with a `colorBetter` border, the theme's frame unchanged; letting the mouse through; a mouse
  moved onto it through the scene tree's input (after `NOTIFICATION_WM_MOUSE_ENTER`: without it, a window-less Godot
  3.6 sends no control the mouse's enter) shows the limit for the job in the game's tooltip (the entry's
  `PlaySoundsOnTheseButtons`), which took over its `hint_tooltip`, and moving away hides it; the Hire button untouched
  and the entry's height unchanged. Above the limit, no badge; the menu is marked exactly when an entry has one. A new
  day judges kept entries again, one badge each; firing (`employmentChanged`) hides it; hiring there gives another
  pilot one with the new limit; a setting shows and hides it; in a full job the tooltip tells so, with the best-paid
  salary, and gives the limit again once there is room; every tooltip has a second line with how many of that job are
  hired (benched and on-leave crew too) out of its crew limit; the tooltip follows a language change. A new entry is
  hovered a frame after it is made, once its containers have laid it out. With CrewPerfectSort loaded too (`-Mods
  CrewCheapHireNotifier,CrewPerfectSort`), the list is sorted and the badges stay. Then a station built as
  `enceladus/Enceladus.tscn` nests it (the menu, and the game's `HidingMarginContainer.gd` with stubs of the Crew and Tuning screens, `harness/crew_screen.gd`),
  clicked through the scene tree's input: the tooltip, also after a language change; Shift+Click opens the
  settings and not the Crew screen, a plain click the Crew screen, a disabled entry nothing; the screen copies
  Tuning's frame and place; it has two groups in an `Items` box right below the header (the settings that are not per
  job, then the crew limit, one row per job named by its key, in alphabetical order of the jobs' names whatever the case, and in a second language that language's order; test names for all four jobs in both), each row with its range, step and
  value (each job's own); opening it stores nothing; moving a slider (the threshold, the tolerance, the pilots' crew
  limit) flips the mark at once and stores the value (the pilots' only); reset;
  Esc (handled, so `harness/unhandled_probe.gd`, standing in for the pause menu, doesn't get it), the controller's B
  and Start, and focusing another entry close it; after a JSON round trip of the state a new station has the saved
  values; and without a Tuning screen there is no tooltip and Shift+Click is a plain click. Keys and buttons are sent as real
  input events in the idle part of a frame, with the game's bindings: a bare `InputEventAction`, or one sent during
  physics, doesn't make `Input.is_action_just_pressed` true. The control checks (the entry keeps its key; a Hire
  screen entry gets no badge) run on the game's own scripts.
- `geology` (`suites/geology.gd`): HUDs from `harness/geology_hud.tscn` (the game's `Hud.gd`, with an `Inventory`
  placeholder of `harness/geology_oms.tscn`: the game's `OMS.gd` and `TabsWithGamepadControl.gd` over the OMS's four
  role tabs) on `harness/geology_ship.gd`, a ship stub whose `isValidMineralTarget` records each call in place of the
  game's rule; the OMS is built on the ship's `instance` signal, as the game builds it. The mod's settings
  descriptions come from its `Settings.gd`. Checks that the tab comes right after the Geologist tab, titled by its
  key, once however often the OMS is built, and that opening it stores nothing; its switch, with its label at the
  mod's spacing (once laid out); a grid of three columns: the base row first (its name, its slider, an empty cell),
  then one row per mineral the HUD can switch on (name, extra mass slider, total), with the Geologist tab's parts,
  the mod's range, step, unit, format, tooltip and bar width (also once laid out), and the stored values; the switch
  and the sliders store what they show, every total follows the base and its own slider, and the switch dims the
  rows; choosing the tab focuses the switch. The rule: off, the game decides; on, below, at and above a mineral's base
  plus extra mass, a mineral switched off in the Geologist tab, one of two minerals enough, the value and Minimum
  value ignored both ways, each mineral's own extra, the base alone with no extras, the base moving every threshold;
  the game decides a chunk not yet identified, another ship's HUD and a HUD without mineral targeting. The settings
  model: defaults for a ship without the entry; reading and unchanged sets store nothing; the mineral list with and
  without `onlyMinerals`; clamping and snapping of what is set or hand-edited, base and extras; the entry in the HUD's
  `mineralConfig` (the ship's `hud.config`) under the manifest's id, with the format and mod versions, the game's keys
  untouched; a JSON round trip; a format-1 entry (`minMass`, read as the extras) and its rewrite on the first change.
  A preheated ship (its HUD builds the OMS before loading `mineralConfig`) gets the tab with its stored values. And
  the texts of `i18n/en.po`, also in a language without them. The control checks (the OMS keeps its four tabs; the
  game decides) run on the game's own script.
- `fleet` (`suites/fleet.gd`): Fleet entries built from the stub `SystemBuyUI.tscn` (the game's `SystemBuyUI.gd`) as
  `Dealer.gd` `doAddShips` makes them, under a Fleet screen stub (`harness/fleet_screen.gd`, which records
  `shipChanged` and `addShips`, and the Esc presses that reach its `_input`, once per frame, as `Dealer.gd` closes the
  screen on them) and beside a market entry and an Equipment screen stub (`harness/fleet_equipment.gd`:
  `getItems`, and a count of `updatePricesAndAvailability`) holding the game's `SystemShipUpgradeUI.gd` items, whose
  prices the suite sets as the game does (`setValuesDiscount`); the ships are `harness/fleet_ship.gd` (the game's
  config accessors, a recording `clearDamageInSlot`), the game's state the `CurrentGame` stub's (`state.ship`,
  `state.garage`, money, log, maintenance; a `validateEmployment` that records the crew list it would put aboard).
  Checks that the market's entry gets nothing; every Fleet entry gets Copy, then Paste, right before Use, copies of it,
  but shows one: Copy on the other ships' entries, Paste on the current ship's; the shown button and Use at the same
  x on every entry; Copy enabled on another ship of the current ship's model, disabled on another model, and Paste
  disabled with nothing copied, each disabled one with the tooltip saying why; pressing Copy doesn't switch ships;
  the icons have the Use icon's size and flags and its colours (light strokes, dark edge), and differ from it and
  each other. The template: Copy sets it on the Fleet screen, marked in the Owned label's colour with its own tooltip;
  Paste then enabled; pressing a disabled Copy changes nothing; pressing the template's Copy again, closing the
  screen or selling the template forgets it and disables Paste; it survives switches while the screen stays open
  (switched to the template itself, its entry shows Paste, disabled, and the old current ship's shows Copy, enabled;
  back on the spare, the buttons swap back and Paste is enabled again); none of this writes to the state. The dialog: none before
  the first Paste; Paste reprices the Equipment screen first, then opens a `ConfirmationDialog` without a title, the
  entry's Buy confirmation untouched; in the menu theme's window frame, with the game's OK and CANCEL, Cancel focused;
  the question naming both ships in the menu font; the Copied list (each piece bought, by its Equipment name, with its
  price; tuning, mineral targeting, slot filters; the crew aboard) and the Not copied list (what isn't sold, a missing
  lidar read as the ship's default and a missing number as none; then what Paste never copies), under their headings,
  side by side, in the prose font (the entry's `HBox/Margin`, `Subwindow.theme`); the summary (price, repair time);
  each list `COLUMN_SHARE` of the screen wide; the dialog on the screen, centered, at its least height; the entry's
  width kept; Cancel closes it, the focus back on Paste, nothing changed; Esc (a real key press, with the game's
  bindings) closes the dialog only, the Fleet screen not getting it, and with the dialog closed reaches the screen;
  above the money, OK is disabled, the summary says so, and pressing it does nothing; a price changed while it showed
  makes OK show the new plan without pasting. Pasting: the money, each piece fitted (damage cleared, value set) at `getNetPrice()`, pieces
  already the same or not sold left, the repair time from now and not the template's, the log as the Equipment screen
  logs it; the tuning replaced, the spare's own kept for the piece not sold; the mineral targeting, slot configs
  (but the slot kept) and crew list copied, the crew put aboard at once (`validateEmployment` after the list is
  written); identity, damage, cargo and consumables kept; the template untouched; then `shipChanged` and `addShips`,
  the dialog closed and the focus on Paste. A refund (listed with the piece and in the summary, no repair time when the
  piece replaced isn't damaged); the same equipment (only the settings listed, nothing to buy; nothing bought, logged
  or added) with a template without a crew list (its unknown crew among what isn't copied, the spare's list stays,
  nothing put aboard); an empty crew list (nobody aboard); closing the screen with the dialog open. The texts of
  `i18n/en.po`, also in a language without them; the entries' script keeps the game's path. The control checks (no
  Copy, Paste or dialog) run on the game's own script.
- `_tests\harness\rig.gd` builds the arm's node tree as the game nests it, with the values in
  `_tests\harness\vp_data.gd`; each cites its scene file and line, so re-check them after a game update. The ship
  is a stub moved by hand (it takes the arm's impulses and torque; inertia from the hull); the rotors don't collide.
- **Baseline** (both arm load orders give the same results): `units` 114 checks with both arm mods (64 with
  PullBehavior alone, 61 with TargetSelection alone), `still` 9, `moving` 16, `dive` 8, `boot` 5 (3 control checks
  with `-Mods @()`), `lidar` 40 (3 control checks with `-Mods @()`), `hud` 13 (3 control checks with `-Mods @()`),
  `crew` 140 (141 with CrewPerfectSort too, in both load orders; 3 control checks with `-Mods @()`), `geology` 60 (3
  control checks with `-Mods @()`), `fleet` 70 (the same with ShipHighlightTypeAndPrice and ShipSortByTypeAndPrice
  too; 3 control checks with `-Mods @()`), all passing; `-Matrix` gives 16 of 16 in every combination.
  Feeding, a chunk beside the hull is in after 4.4–4.8 s.
  For comparison with `-ModZip` and older release zips: PullBehavior 1.4.0 (the claude.ai results, case for case)
  took 5.9–6.3 s there, fails the 8 time limits, and `-Matrix` gave 16, 15, 16, 16 (feeding while turning with a 5 t
  chunk touched a rotor: the game's pull measures speed against the swinging dock slot); 1.3.1, which broke in the
  game, gives 0, 0, 12, 4 of 16. This ship also takes the arm's torque reaction, as the game's does (the claude.ai
  stub dropped it), which shifts some numbers in the third decimal.

The harness doesn't replace the game. CrewHighlightJobAndSalary has no tests at all, and CrewPerfectSort and the
ship-list mods have none of their own: only CrewPerfectSort's Hire screen sort runs, beside CrewCheapHireNotifier in
`crew`, and the ship-list mods load beside ShipCopyPaste in `fleet` without checks of their own. The real check is
playing the game with the mods.

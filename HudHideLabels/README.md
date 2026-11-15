# HudHideLabels - ΔV: Rings of Saturn

Version 1.0.1. Hides the titles on the screens of the dive HUD.

## What it does and why
- **What:** on every HUD, the titles whose keys are in `HIDDEN_KEYS` are no longer drawn. Each HUD shows some or all
  of them, depending on its layout. The title of the LIDAR is the LIDAR's own name, for example RUNASIMI
  HIGH-RESOLUTION LIDAR. The titles keep their space, so what is under them stays where it was.
- **What not:** the same titles on the station's Upgrades and Tuning screens and the cargo title in the geologist tab
  of the management screen (`J` by default) are left alone. So is everything else on the HUD.
- **Why:** they take room on small screens and some cover the readings, such as the cargo hold's mass on the
  OCP-209's HUD.
- To keep one of the titles, remove its key from `HIDDEN_KEYS` at the top of `HudHideLabels/Code.gd` inside the
  zip; the comment there says which key is which.

## For modders
- No game script or scene is changed. `ModMain.gd` adds a node with `Code.gd`, which connects the scene tree's
  `node_added` in its `_ready` and hides every `Label` whose `text` is one of `HIDDEN_KEYS` and which has a scene
  whose path starts with `DISPLAY_PREFIX` among its ancestors.
  The tag `group = Hud` in `Mod.manifest` names the part of the game it touches.
- Each HUD is one `Display-*.tscn` (K37, Prospector and its Metric and Bald variants, EIME, HAL, AT225, OCP209,
  Kitsune, CERF). The ship's Hud (`hud/Hud.tscn`, `Huds/SYSTEM_HUD_*`) holds them as instance placeholders, and
  `hud/Hud.gd` `instance()` replaces the one in the ship's `hud.type` with the scene during the dive. The titles
  are plain Labels holding translation keys, some of them in shared sub-scenes the HUDs instance:
  `hud/components/EnceladusFeed.tscn`, `hud/RemoteSpectrometer.tscn` and `hud/trtl/CargoHold.tscn`. The station
  screens (`enceladus/Upgrades.tscn`, `enceladus/Tuning.tscn`) reuse the last two, and the management screen
  (`hud/OMS.tscn`, the Hud's `Inventory`) has a `HUD_CARGO` of its own. The check for a `Display-` ancestor (its
  `filename`) leaves all of these alone.
- The LIDAR's title has `hud/HardwareLabel.gd` with `slot = "lidar.type"`, whose `_ready` replaces `HUD_LIDAR` with
  the ship's `getConfigWithDefaults("lidar.type")`. Godot emits `node_added` for every node of a newly added subtree
  before any `_ready` runs, so the mod still finds the key, and the name is never drawn. That is why it acts at once,
  unlike the other observer mods here, which wait a moment for their entries to fill in.
- A title is hidden with `self_modulate` alpha 0, not `visible`, so it keeps its place in its container (on the
  OCP-209 the cargo title is a 50 px row above the cargo scanner) and the `modulate` some titles have still applies.
  No game script or animation sets these properties on the titles.
- Constants: `HIDDEN_KEYS` (a user may edit it) and `DISPLAY_PREFIX`. No members, and nothing shared with other mods.
- Tested only outside the game, in a headless Godot 3.6 with the game's `HardwareLabel.gd` on trees built with the
  node paths of the OCP-209's HUD, the Upgrades screen and the management screen (the `hud` suite of the
  repository's test harness). It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put `HudHideLabels-1.0.1.zip` in it. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).

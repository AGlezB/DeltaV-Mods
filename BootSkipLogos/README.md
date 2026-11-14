# BootSkipLogos - ΔV: Rings of Saturn

Version 1.0.0. The game starts on the title screen, where the save slots are, without the logo sequence first.

## What it does and why
- **What:** at launch, the 22-second sequence of logos (the studio, Godot, the Kurki collective) and the
  photosensitivity warning is skipped, and the game goes straight to the title screen. If the title screen has not
  finished loading yet, the logo screen stays up with the game's loading bar until it has, as when a key is pressed
  that early.
- **What not:** on the very first launch, before the game has written its settings file, the sequence plays in
  full, as without the mod, so the photosensitivity warning is seen once. The story intro of a new game is not
  touched.
- **Why:** the game already skips the sequence when Enter, Esc or a mouse button is pressed. The mod does it
  without waiting for the press.

## For modders
- Script extension of `res://Boot.gd` (`installScriptExtension` in `ModMain.gd`), the script of the game's first
  scene (`run/main_scene = "res://Boot.tscn"` in `project.godot`). The tag `group = Boot` in `Mod.manifest` names
  that game script.
- It works only because the extension is installed in `ModMain`'s `_init`: `ModLoader.gd` loads the mods and runs
  their `ModMain` scripts in its own `_init`, while the engine creates the autoloads, and the engine loads the main
  scene after that. An extension installed later, in `_ready`, would come too late for the boot scene.
- Overrides `_ready` only, which does not call the parent's: the mod loader runs the base first, so `mode` is set
  and the title screen has started loading (`Loader.prepare`) when the override runs.
- The override calls the game's own `go()`, which the animation calls at its end and a key press calls early
  (`_unhandled_input`), under the game's own condition, `not Settings.firstBoot`. `Settings.gd` sets `firstBoot`
  to false in `loadFromFile` once `user://settings.cfg` exists, and writes that file on every launch.
- `go()` leads to `Loader.gd` `goNow`: when the title screen is not loaded yet, it shows its loading bar, waits for
  the load to finish (`fileLoaded`) and then switches.
- Only in `mode == "game"`: with `--screensaver`, `Boot.gd` calls `go()` itself.
- No constants and no members, so nothing to clash with other mods on the same script.
- Tested only outside the game, in a headless Godot 3.6: the game's `Boot.gd` loaded by the engine as the main scene
  after the mod is installed, as the game does, with a stub loader. It has not been checked in a real game.

## Install
1. In the game folder (next to `Delta-V.exe`), create a folder named `mods`.
2. Put `BootSkipLogos-1.0.0.zip` in it. Do not unzip it.
3. Launch the game with `--enable-mods`.

Mods are unofficial and can break after game updates. Keep a backup of your save.

## About
Made with the help of AI (Claude, by Anthropic).
Licensed under the GNU General Public License v3.0 (GNU GPLv3).

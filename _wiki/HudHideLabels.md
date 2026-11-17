Hides the titles on the screens of your ship's HUD, so they don't cover anything.

## What changes

Your ship's HUD, the displays around the view in a dive, has small titles on its screens: *visual feed*, the name of
your LIDAR (for example RUNASIMI HIGH-RESOLUTION LIDAR), *Remote scanner* and *cargo hold*. Which ones you see
depends on your ship. With the mod, they are gone, and everything else stays where it was. On some ships the titles
covered a reading: on the OCP-209, the *cargo hold* title covered the cargo's mass.

The same titles on the station's Equipment and Tuning screens, and the cargo title in the Onboard Maintenance System,
stay as they are.

## Install

See [Installing mods](Home#installing-mods).

<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.92.5
HudHideLabels/Code.gd HIDDEN_KEYS = ["HUD_VISUAL_FEED", "HUD_LIDAR", "HUD_REMOTE_SCAN", "HUD_CARGO"] -> Remote scanner
game: the titles' texts, visual feed, Remote scanner, cargo hold (i18n/en.po HUD_VISUAL_FEED, HUD_REMOTE_SCAN, HUD_CARGO), and the LIDAR's name (hud/HardwareLabel.gd)
-->

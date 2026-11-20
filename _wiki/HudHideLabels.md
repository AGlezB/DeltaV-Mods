Hides the titles on the screens of your ship's HUD, so they don't cover anything.

## What changes

Your ship's HUD, the displays around the view in a dive, has small titles on its screens: *visual feed*, the name of
your LIDAR (for example IRL-360 Infrared LIDAR), *Remote scanner* and *cargo hold*. With the mod, they are gone, and
everything else stays where it was. On some HUDs the titles covered a reading: on the OCP-209's, the *cargo hold*
title covered the cargo's mass.

Which titles you see depends on your HUD: the *Head-Up Display* you fit on the Equipment screen, on any ship.
*Remote scanner* only shows with the Obonto USV-D Microseismic Series as your *Reconnaissance Craft*, also fitted on
the Equipment screen.

The Eon Interstellar Model E HUD hides its screens, titles included, while their readings hold still. *Inactive
display visibility*, in the HUD's Tuning, keeps them on screen, dimmed: its pictures have it at 100 %. On that HUD,
*cargo hold* is the name of the row with the cargo's mass, under the ship: with the mod, the row shows only the mass.

The same titles on the station's Equipment and Tuning screens, and the cargo title in the Onboard Maintenance System,
stay as they are.

Open your HUD to see it without and with the mod. Every picture shows the same ship, a K37 TNTRL, in a dive.

<details>
<summary>HAL9000</summary>

**Without the mod:**

![The whole HAL9000 HUD, with visual feed twice at the top left, the LIDAR's name at the top right, cargo hold on the left and Remote scanner on the right](images/HudHideLabels-hal-without.png)

**With the mod:**

![The same HUD without those titles](images/HudHideLabels-hal-with.png)

</details>

<details>
<summary>Eagle Prospector, and Eagle Prospector (metric mod)</summary>

The metric mod only changes the units.

**Without the mod:**

![The panel at the bottom of the Eagle Prospector HUD, with visual feed on the left and the LIDAR's name above its radar](images/HudHideLabels-prospector-without.png)

**With the mod:**

![The same panel without those titles](images/HudHideLabels-prospector-with.png)

</details>

<details>
<summary>K37 TNTRL</summary>

**Without the mod:**

![The whole K37 TNTRL HUD, with the LIDAR's name at the top left, visual feed at the top right, cargo hold at the bottom left and Remote scanner at the bottom](images/HudHideLabels-tntrl-without.png)

**With the mod:**

![The same HUD without those titles](images/HudHideLabels-tntrl-with.png)

</details>

<details>
<summary>AT-K225</summary>

**Without the mod:**

![The whole AT-K225 HUD, with visual feed and the LIDAR's name at the top left and Remote scanner at the bottom right](images/HudHideLabels-at225-without.png)

**With the mod:**

![The same HUD without those titles](images/HudHideLabels-at225-with.png)

</details>

<details>
<summary>OCP-209</summary>

**Without the mod:**

![The whole OCP-209 HUD, with visual feed and the LIDAR's name at the top right, cargo hold at the bottom left and Remote scanner at the bottom](images/HudHideLabels-ocp209-without.png)

**With the mod:**

![The same HUD without those titles](images/HudHideLabels-ocp209-with.png)

</details>

<details>
<summary>MAD Cernunnos II</summary>

**Without the mod:**

![The top of the MAD Cernunnos II HUD, with visual feed at the left and the LIDAR's name at the right](images/HudHideLabels-cerf-without.png)

**With the mod:**

![The same part of the HUD without those titles](images/HudHideLabels-cerf-with.png)

</details>

<details>
<summary>Eon Interstellar Model E</summary>

**Without the mod:**

![The screens around the ship on the Eon Interstellar Model E HUD, dimmed, with visual feed at the top right and cargo hold under the ship](images/HudHideLabels-eime-without.png)

**With the mod:**

![The same screens without those titles](images/HudHideLabels-eime-with.png)

</details>

<details>
<summary>ND-LIS Kitsune</summary>

**Without the mod:**

![The two radar screens on the right of the ND-LIS Kitsune HUD, with the LIDAR's name between them](images/HudHideLabels-kitsune-without.png)

**With the mod:**

![The same screens without the LIDAR's name](images/HudHideLabels-kitsune-with.png)

</details>

<details>
<summary>Bald Eagle Racing HUD</summary>

**Without the mod:**

![The bottom of the Bald Eagle Racing HUD, with visual feed at the left and the LIDAR's name at the right](images/HudHideLabels-prospector-bald-without.png)

**With the mod:**

![The same part of the HUD without those titles](images/HudHideLabels-prospector-bald-with.png)

</details>

## Install

See [Installing mods](Home#installing-mods).

<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.93.1
HudHideLabels/Code.gd HIDDEN_KEYS = ["HUD_VISUAL_FEED", "HUD_LIDAR", "HUD_REMOTE_SCAN", "HUD_CARGO"] -> Remote scanner | images/HudHideLabels-hal-with.png, images/HudHideLabels-prospector-with.png, images/HudHideLabels-tntrl-with.png, images/HudHideLabels-at225-with.png, images/HudHideLabels-ocp209-with.png, images/HudHideLabels-cerf-with.png, images/HudHideLabels-eime-with.png, images/HudHideLabels-kitsune-with.png, images/HudHideLabels-prospector-bald-with.png
game: the titles' texts, visual feed, Remote scanner, cargo hold (i18n/en.po HUD_VISUAL_FEED, HUD_REMOTE_SCAN, HUD_CARGO), and the LIDAR's name (hud/HardwareLabel.gd; the K37 TNTRL's, IRL-360 Infrared LIDAR, SYSTEM_LIDAR_DOPPLER)
game: the HUDs, in the Equipment screen's Head-Up Display, in its order (enceladus/Upgrades.tscn; i18n/en.po SLOT_HUD, SYSTEM_HUD_*), each its own layout (hud/Hud.tscn Huds, hud/Display-*.tscn); the metric mod is the Eagle Prospector's layout (hud/Display-Prospector-Metric.tscn)
game: Remote scanner only with the Obonto USV-D Microseismic Series as Reconnaissance Craft (SYSTEM_RD_SPECTROMETER, SLOT_RECON_DRONE; hud/ShowWhenSystemInstalled.gd, Display-OCP209.tscn Remote)
game: 100 %, the most of Inactive display visibility (TUNE_HUD_HIDE, hud/FadeAwaySensor.gd), which keeps the Eon Interstellar Model E's screens dimmed when they would fade out; cargo hold names its cargo mass row (Display-EIME.tscn MassLabel)
-->

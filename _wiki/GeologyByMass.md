Your geologist judges chunks by how much of a mineral they hold, instead of by what they are worth.

## What changes

In a dive, your geologist puts an info box next to each chunk of ore they identify, with the kg of each mineral in it
and its value. The game shrinks the box, hiding the list and the value, when the chunk is worth less than the
*Minimum value* you set in the *Geologist* tab of the Onboard Maintenance System (press **J**), or holds none of the
minerals you switched on there.

With the mod, a new tab, **Ore mass**, sits right after the *Geologist* tab. Switch it on, and a chunk keeps its full
box when it holds enough kg of one of the minerals switched on in the *Geologist* tab, whatever the chunk is worth:
the *Minimum value* no longer counts. Use it when you are after one mineral: how much of it a chunk holds tells you
more than its price, which mixes every mineral in it and changes with the market.

How much is enough is the **Base** mass, plus an extra mass for each mineral, on top of the base. Moving the Base
slider raises or lowers every mineral together. The kg are the ones the info box shows, as your geologist estimates
them.

With the switch off, the game works as normal.

## Settings

In the **Ore mass** tab:

- The switch at the top, *Judge ore by mineral mass instead of the minimum value*: off at first.
- **Base**: the least mass for every mineral, from 0 kg to 5,000 kg. It starts at 0.
- One row for each mineral: its extra mass (+ kg), from 0 kg to 5,000 kg, starting at 0, and then the total that
  mineral needs (= kg).

The sliders work like the ones in the *Geologist* tab. While the switch is off they are dimmed, but you can still set
them. Each ship keeps its own settings, saved with your game.

## Changes how the game plays

Compared to the normal game, while the mod's switch is on, which chunks keep a full info box depends on how many kg of
your chosen minerals they hold, not on what they are worth. With the switch off, nothing changes.

If the info boxes or the *Geologist* tab do something wrong, try again without the mod before you report a bug to the
game's developers.

## Install

See [Installing mods](Home#installing-mods).

<!-- wiki-values (checked by wiki.ps1)
game-checked: 1.92.5
GeologyByMass/i18n/en.po GEOLOGYBYMASS_TAB = "Ore mass"
GeologyByMass/Settings.gd ENABLED.default = false -> off at first
GeologyByMass/i18n/en.po GEOLOGYBYMASS_ENABLED = "Judge ore by mineral mass instead of the minimum value"
GeologyByMass/Settings.gd BASE_MASS.default = 0
GeologyByMass/Settings.gd BASE_MASS.min = 0 -> 0 kg
GeologyByMass/Settings.gd BASE_MASS.max = 5000 -> 5,000 kg
GeologyByMass/i18n/en.po GEOLOGYBYMASS_BASE_MASS = "Base"
GeologyByMass/Settings.gd EXTRA_MASS.default = 0
GeologyByMass/Settings.gd EXTRA_MASS.min = 0 -> 0 kg
GeologyByMass/Settings.gd EXTRA_MASS.max = 5000 -> 5,000 kg
GeologyByMass/i18n/en.po GEOLOGYBYMASS_EXTRA_MASS = "Mass of this mineral needed on top of the base, as your geologist estimates it, for a chunk to keep its full info box." -> on top of the base
-->

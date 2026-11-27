# ShipCopyPaste - Changes

## 1.2.0
- On the Fleet screen, *Copy*, *Switch ship* and *Sell this ship* sit closer together, their icons
  `_SHIP_COPY_PASTE_ICON_GAP` apart instead of the game's wide spacing, so a long ship name has more room before it is
  cut short. The three buttons get copies of the game's button styles with narrower side margins; the game's own
  styles are left as they are, and so are the ship market's entries.
- Constants: new `_SHIP_COPY_PASTE_SELL`, `_SHIP_COPY_PASTE_ICON_GAP` (which a user may edit inside the zip) and
  `_SHIP_COPY_PASTE_TIGHT_STYLES`. Function: new `_shipCopyPasteTighten` (README, *For modders*).

## 1.1.1
- Licensed under the MIT License instead of the GNU GPLv3: the LICENSE in the zip and the README's *About* and
  *Disclaimer* say so.

## 1.1.0
- No more Paste button or copied template: *Copy*, on another ship of the model you fly, opens the confirmation at
  once, and its *OK* makes the ship you fly like that ship. The entry of the ship you fly has an empty spacer of Copy's
  size in its place (`_SHIP_COPY_PASTE_SPACER_NODE`), so every entry's details and buttons stay lined up.
- The confirmation has a row per part, with a switch where the two ships differ (on when it opens), and *Same* where
  they don't: *Ship settings* (the tuning, the mineral targeting and the slots' mineral filters, together), *Crew
  aboard* and *Equipment*. Only what is switched on is pasted. The settings read the same when the Tuning screen would
  show the same values; the crew, and lists of minerals, in any order.
- Under *Equipment*, each piece bought with its price, then the total and the repair time: a cost negative, in the
  Fleet screen's red, a refund positive, in its green; no list when the equipment is the same. When a piece can't be
  fitted (not sold here, or not available yet), the row reads *Incompatible equipment*, only those pieces are listed,
  each with *Not sold here*, and no equipment is copied (before, the rest was bought and that piece kept).
- *OK* reads *Insufficient funds*, disabled, only while the equipment is switched on and you can't pay for it.
- A copied ship without a crew list has no crew: copying its crew leaves nobody aboard (before, the crew aboard was
  left as it was).
- The confirmation is only as wide as it needs: the question on one line up to `_SHIP_COPY_PASTE_MAX_WIDTH_SHARE` of
  the screen, the rows and the list centered under it, `_SHIP_COPY_PASTE_COLUMN_GAP` between names and values. With a
  gamepad, the D-pad goes through the switches, then to *Cancel*.
- Texts: `SHIPCOPYPASTE_COPY` says what Copy does now; new `SHIPCOPYPASTE_SETTINGS`, `_EQUIPMENT`, `_INCOMPATIBLE`,
  `_COST`, `_GAIN` and `_TOTAL`; `SHIPCOPYPASTE_CREW`, `_SAME`, `_UNFIT`, `_REPAIRS` and `_NO_MONEY` hold new texts;
  the template's, Paste's, the two lists', their lines', the price summary's and the unknown crew's are removed.
- Constants: new `_SHIP_COPY_PASTE_SWITCH*` (the game's Tuning switch and its nodes), `_ROWS`, `_COLOR_MINUS`,
  `_COLOR_PLUS` and their fallbacks, `_MINERALS`, `_TRACE_MINERALS` and `_MINERALS_DEFAULT` (the mineral targeting
  the game gives a system without one), `_MAX_WIDTH_SHARE`, `_COLUMN_GAP`; `_COLUMN_SHARE`, `_PASTE_NODE`, `_TEMPLATE`,
  `_MARK` and the old texts' constants are removed. Members: `_shipCopyPastePaste`, `_shipCopyPasteLists` and
  `_shipCopyPasteSummary` are gone; the dialog's rows, states, list and choices have their own (README, *For
  modders*).

## 1.0.3
- A slot neither ship's config names reads as the Equipment screen's default item for it (the item it offers as the
  default, as for a hardpoint's None), so Paste no longer lists, or charges for, a change where both ships have that
  default.
- Paste puts aboard only the people on the copied ship's crew list who are still in your crew: someone fired stays on
  the list of a ship you weren't flying when you fired them.
- The Dealer's entries no longer get the extension's `_input`.

## 1.0.2
- The README's *Disclaimer* no longer names the author.

## 1.0.1
- The README has a new *Disclaimer*: the game belongs to Kodera Software, the author has no tie to it or to the
  company, and the mod is provided as is, for free, without warranty.
- Adds this CHANGES.md.

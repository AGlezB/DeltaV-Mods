extends "res://enceladus/Dealer.gd"

# The station's Dealer screen (enceladus/Dealer.gd). The game builds the dealer's stock anew on every refresh
# (CurrentGame.gd getShipsAvailableForSale, which only doAddShips calls: when the station loads, every in-game hour and
# when the screen opens) and tells nobody what changed. So once each refresh is done, this tells the settings model what
# the dealer has, read from the screen's entries, each ship new or used as the Dealer marks it; and when the screen
# opens, that the player has seen it all. The ships that marked the station menu's Dealer entry when the screen opened
# get a badge on their entry, until the station is left. Fleet (enceladus/Owned.tscn) is this script too, with
# showAvailable off: it is left alone.

# The stock, the ships seen and the rule: their model, shared with the station menu and the settings screen.
const DealerNotifier = preload("res://DealerNotifier/Settings.gd")

# Translation key of i18n/en.po: the badge's tooltip.
const _DN_BADGE_TOOLTIP = "DEALERNOTIFIER_BADGE_TOOLTIP"
# The badge's node name in an entry's name, so that a refresh finds the badge it made.
const _DN_BADGE = "DealerNotifierBadge"
# The age under which a Dealer entry marks its ship NEW, in seconds (enceladus/SystemBuyUI.gd checkPrice, with the ship
# not owned and pristine: a ship that young always is, as CurrentGame.gd ageToDamageWithSeed damages none under ten
# years).
const _DN_GAME_NEW_AGE = 24 * 3600 * 365

# The transponders of the ships that marked the Dealer entry when the screen was opened. The station's screens are
# built anew on every visit, so they last until the station is left.
var _dnFresh = {}

# The game's refresh, then the stock it shows. A refresh that waits for the player's ship or for idle physics frames
# (the screen hidden) yields: its end is when its first state completes. One called while another runs returns at once,
# with shipAddFlag still set: the running one tells the stock when it ends.
func doAddShips():
	var refresh = .doAddShips()
	if refresh is GDScriptFunctionState:
		yield(refresh, "completed")
	if not showAvailable or shipAddFlag or not is_inside_tree():
		return
	DealerNotifier.shared().setStock(_dnStock(), is_visible_in_tree())
	_dnMarkFresh()

# Opening the screen: the ships that mark the Dealer entry now get their badge, and everything the dealer has is seen.
# The game's show() then refreshes the stock, and the refresh, done while the screen is open, sees it again.
func show():
	.show()
	if not showAvailable:
		return
	var settings = DealerNotifier.shared()
	for ship in settings.newShips():
		_dnFresh[ship.transponder] = true
	settings.markSeen()
	_dnMarkFresh()

# The badge's tooltip holds translated text.
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and showAvailable and items != null:
		_dnMarkFresh()

# The ships the screen's entries (enceladus/SystemBuyUI.gd) offer, as Dealer.gd doAddShips lists them: one per ship for
# sale (the station's Dealer lists no owned ones: Enceladus.tscn sets its showOwned off).
func _dnStock() -> Array:
	var out = []
	for entry in items.get_children():
		if _dnIsOffer(entry):
			out.append({"model": entry.ship.model, "transponder": entry.ship.transponder, "used": not _dnIsNew(entry.ship)})
	return out

# New as the entry marks it: the dealer's weekly new ships, and a used one only when it was made less than a year ago.
# The ship's making time comes with the ship (Shipyard.gd createShipByConfig), before its entry has set it up.
func _dnIsNew(ship) -> bool:
	return CurrentGame.getInGameTimestamp() - ship.madeTimestamp < _DN_GAME_NEW_AGE

func _dnIsOffer(entry) -> bool:
	return "ship" in entry and "owned" in entry and not entry.owned and not entry.is_queued_for_deletion() \
			and Tool.ov(entry.ship)

# The game keeps an entry from one refresh to the next, and never touches the badge, so hiding it is enough.
func _dnMarkFresh():
	for entry in items.get_children():
		if not _dnIsOffer(entry):
			continue
		var badge = entry.get_node_or_null("HBox/ShipName/" + _DN_BADGE)
		if _dnFresh.has(entry.ship.transponder):
			badge = _dnBadge(entry)
			if badge != null:
				badge.hint_tooltip = tr(_DN_BADGE_TOOLTIP)
				badge.visible = true
		elif badge != null:
			badge.visible = false

# The entry's badge, made on first use, at the right end of the entry's name column (HBox/ShipName, a flat Button that
# fills the column between the picture and the specs), inside the right margin the button keeps around its text (its
# normal stylebox's, which it lays its text out in even when flat), centred on it from top to bottom. A Button doesn't
# lay out its children, so the badge hangs from it directly, anchored to the middle of its right side, and grows left,
# up and down to its minimum size. A name
# long enough to reach the column's end would run under it (the button clips its text at its own edge), but a ship's
# name is two words in a column many times wider.
# Drawn as CrewCheapHireNotifier's badge, with only the capitals of the mod's name, in a copy of the entry's Buy
# button frame (menu/ButtonRoundCorners.tres in the game). Its colour is that of the entry's Owned label, as
# ShipCopyPaste marks its template: the frame's border in it, and the letters in the button's font colour times it, as
# the label draws. The letters are in the font a Label gets in the entry's picture (HBox/Margin, whose theme,
# enceladus/Subwindow.theme, has a small one), as its own RepairTimeLeft label is: the name sets no theme, so a Label
# there would get the entry's, the menu's big font. It lets the mouse through, so the wheel still scrolls the list and a
# click is the name's (focusing it shows the ship, Dealer.gd), and still gets the mouse's enter and exit.
# The tooltip: the released game draws its own, with the entry's PlaySoundsOnTheseButtons
# (menu/sfx/PlaySoundsOnTheseButtons.gd), which registers only the buttons and sliders it finds when the entry is
# made. Its connectSounds registers the badge too: it takes over the badge's hint_tooltip, shows it below the badge on
# hover and reads it again on every hover, so _dnMarkFresh keeps setting it.
func _dnBadge(entry):
	var shipName = entry.get_node_or_null("HBox/ShipName")
	var buy = entry.get_node_or_null("HBox/Buy")
	if not shipName is Control or not buy is Control:
		return null
	var badge = shipName.get_node_or_null(_DN_BADGE)
	if badge != null:
		return badge
	var colour = Color(1, 1, 1, 1)
	var owned = entry.get_node_or_null("HBox/V/Owned")
	if owned is CanvasItem:
		colour = owned.modulate
	var right = 0.0
	var text = shipName.get_stylebox("normal")
	if text != null:
		right = text.get_margin(MARGIN_RIGHT)
	badge = PanelContainer.new()
	badge.name = _DN_BADGE
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	badge.margin_left = -right
	badge.margin_right = -right
	badge.margin_top = 0
	badge.margin_bottom = 0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame = buy.get_stylebox("normal").duplicate()
	if frame is StyleBoxFlat:
		frame.border_color = colour
	badge.add_stylebox_override("panel", frame)
	var label = Label.new()
	label.text = _dnInitials()
	label.add_color_override("font_color", buy.get_color("font_color") * colour)
	var picture = entry.get_node_or_null("HBox/Margin")
	if picture is Control:
		label.add_font_override("font", picture.get_font("font", "Label"))
	badge.add_child(label)
	shipName.add_child(badge)
	var tooltips = entry.get_node_or_null("PlaySoundsOnTheseButtons")
	if tooltips != null and tooltips.has_method("connectSounds"):
		tooltips.connectSounds(badge)
	return badge

# The capitals of the mod's name in Mod.manifest.
func _dnInitials() -> String:
	var initials = ""
	for c in DealerNotifier.shared().modName():
		if c != c.to_lower():
			initials += c
	return initials

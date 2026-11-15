extends PanelContainer

# Stub of the station's Equipment screen (enceladus/Upgrades.gd) for the fleet suite: its items (the game's
# SystemShipUpgradeUI.gd) found as Upgrades.gd getItems() finds them, and a count of the calls to
# updatePricesAndAvailability, whose prices the suite sets on the items itself (setValuesDiscount, as the game's does).

var repriced = 0

func getItemsFrom(where):
	var out = []
	for i in where.get_children():
		if "system" in i:
			out.append(i)
		else:
			out += getItemsFrom(i)
	return out

func getItems():
	return getItemsFrom(self)

func updatePricesAndAvailability():
	repriced += 1

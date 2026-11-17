# The users' wiki's screenshots of the station screens, by mod: what shots.ps1 runs, once without the mod and once
# with it, from the same fixture save (_shots\README.md). Only mods with a screen of their own, or that add to or change
# a game screen, have screenshots; mods that only reorder a list or change how the game plays have none. Steps are ShotRenderer's (_shots\ShotRenderer\ModMain.gd);
# {menu} is the station menu's entries, {screens} the screens they open. shot|<view>|x,y,w,h saves that part of the
# 1600x900 window as _wiki\images\<Mod>-<view>-without.png and -with.png. A step starting with with: runs only with the
# mod (its settings, its dialog), and a view shot that way is saved once, as <Mod>-<view>.png.
# Also: other mods loaded in both runs, when the view needs them.
@{
	CrewCheapHireNotifier = @{
		Steps = @(
			'load', 'wait|10'
			'shot|menu|0,115,340,457'
			'press|{menu}/Crew', 'wait|2'
			'tab|{screens}/Crew/TabHintContainer/Tabs|1', 'wait|2'
			'scroll|{screens}/Crew/TabHintContainer/Tabs/ENCELADUS_CREW_HIRE|700', 'wait|1'
			'shot|hire|950,100,622,235'
			'with:shiftclick|{menu}/Crew', 'wait|2'
			'with:shot|settings|545,15,1055,630'
		)
	}
	CrewHighlightJobAndSalary = @{
		Steps = @(
			'load', 'wait|10'
			'press|{menu}/Crew', 'wait|2'
			'shot|yourcrew|950,290,622,225'
			'tab|{screens}/Crew/TabHintContainer/Tabs|1', 'wait|2'
			'shot|hire|950,110,622,235'
		)
	}
	DiveSkipTransit = @{
		Steps = @(
			'load', 'wait|10'
			'with:shiftclick|{menu}/RingDive', 'wait|2'
			'with:shot|settings|545,15,1055,735'
		)
	}
	LidarLouderPing = @{
		Steps = @(
			'load', 'wait|10'
			'press|{menu}/ShipTuning', 'wait|3'
			'scroll|{screens}/Tuning|1300', 'wait|1'
			'shot|tuning|560,570,1020,315'
		)
	}
	ShipCopyPaste = @{
		Steps = @(
			'load', 'wait|10'
			'press|{menu}/OwnedShips', 'wait|4'
			'shot|fleet|560,470,1020,275'
			'with:clickfind|{screens}/Owned|ShipCopyPasteCopy|0', 'wait|1'
			'with:clickfind|{screens}/Owned|ShipCopyPastePaste|0', 'wait|2'
			'with:shot|dialog|355,295,890,307'
		)
	}
	ShipHighlightTypeAndPrice = @{
		Steps = @(
			'load', 'wait|10'
			'press|{menu}/ShipMarket', 'wait|4'
			'shot|dealer|560,505,1010,380'
			'press|{menu}/OwnedShips', 'wait|4'
			'shot|fleet|560,470,1020,275'
		)
	}
}

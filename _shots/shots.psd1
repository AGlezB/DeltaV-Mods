# The users' wiki's screenshots of the station screens, the OMS and the HUD, by mod: what shots.ps1 runs, once without
# the mod and once with it, from the same fixture save (_shots\README.md). Only mods with a screen of their own, or that
# add to or change a game screen, have screenshots; mods that only reorder a list or change how the game plays have
# none. Steps are ShotRenderer's (_shots\ShotRenderer\ModMain.gd); {menu} is the station menu's entries, {screens} the
# screens they open, {oms} the OMS's tabs (in a dive; ship: paths start at the player's ship, ship:. is the ship
# itself).
# shot|<view>|x,y,w,h saves that part of the 1600x900 window (without x,y,w,h, the whole window) as
# _wiki\images\<Mod>-<view>-without.png and -with.png. A step starting with with: runs only with the mod (its settings,
# its dialog), and a view shot that way is saved once, as <Mod>-<view>.png.
# Also: other mods loaded in both runs, when the view needs them. TimeoutSeconds: seconds before each of the mod's runs
# is stopped, where they take longer than shots.ps1's default.
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
	# The mod's OMS tab (GBM), in a dive (J opens the OMS), with an example set where it is stored (Settings.gd: the
	# HUD's mineralConfig, under the mod's id): the switch on, a base of 200 kg, and extra masses growing by 200 kg from
	# the dearest mineral to the cheapest by the game's base prices (CurrentGame.mineralPrices: Be, W, V, Pt, Pd, Fe).
	GeologyByMass = @{
		Steps = @(
			'load', 'wait|10'
			'dive', 'wait|5'
			'action|jury_rig', 'wait|2'
			'with:set|ship:Hud|mineralConfig/AGlezB.GeologyByMass|{"enabled": true, "baseMass": 200, "extraMass": {"Be": 200, "W": 400, "V": 600, "Pt": 800, "Pd": 1000, "Fe": 1200}}'
			'with:tab|{oms}|GEOLOGYBYMASS_TAB', 'wait|2'
			'with:shot|settings|320,2,965,372'
		)
	}
	# The HUD in a dive, once for each Head-Up Display of the Equipment screen (enceladus/Upgrades.tscn), in its
	# order: the HUD is equipment, not tied to a ship model, and each one is its own layout (hud/Hud.tscn Huds, a
	# hud/Display-*.tscn each; Eagle Prospector (metric mod) has Eagle Prospector's layout, only in other units, so it
	# has no pictures of its own). Each dive starts again from the save, and the ship gets its HUD at the station,
	# where the HUD isn't built yet (hud/Hud.gd instance(), once the player flies the ship), as the Equipment screen
	# sets it (hud.type). It also gets the Obonto USV-D Microseismic Series recon drone (drone.scanner), without which
	# no HUD shows its Remote scanner screen (hud/ShowWhenSystemInstalled.gd). The EIME's screens fade out while their
	# readings hold still (hud/FadeAwaySensor.gd), so its dive sets Inactive display visibility, in Tuning, to 100 %
	# (TUNE_HUD_HIDE), which keeps them dimmed instead. HUDs with titles all over the screen are shot whole; the
	# others, where the titles are.
	HudHideLabels = @{
		TimeoutSeconds = 480
		Steps = @(
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_HAL"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|hal'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_PROSPECTOR"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|prospector|170,645,1280,255'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_TNTRL"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|tntrl'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_AT225"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|at225'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_OCP209"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|ocp209'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_CERF"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|cerf|0,0,1600,295'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_EIME"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'set|ship:.|shipConfig/tuning/Hud/TUNE_HUD_HIDE|100'
			'dive', 'wait|5'
			'shot|eime|220,0,900,765'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_KITSUNE"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|kitsune|1200,180,400,410'
			'load', 'wait|5'
			'set|ship:.|shipConfig/hud/type|"SYSTEM_HUD_PROSPECTOR_BALD"'
			'set|ship:.|shipConfig/drone/scanner|"SYSTEM_RD_SPECTROMETER"'
			'dive', 'wait|5'
			'shot|prospector-bald|0,725,1600,175'
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

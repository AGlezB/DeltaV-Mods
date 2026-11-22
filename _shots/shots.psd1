# The users' wiki's screenshots of the station screens, the OMS and the HUD, by mod: what shots.ps1 runs, once without
# the mod and once with it, from the same fixture save (_shots\README.md). Only mods with a screen of their own, or that
# add to or change a game screen, have screenshots; mods that only reorder a list or change how the game plays have
# none. Steps are ShotRenderer's (_shots\ShotRenderer\ModMain.gd); {menu} is the station menu's entries, {screens} the
# screens they open, {oms} the OMS's tabs (in a dive; ship: paths start at the player's ship, ship:. is the ship
# itself).
# shot|<view>|x,y,w,h saves that part of the 1600x900 window (without x,y,w,h, the whole window) as
# _wiki\images\<Mod>-<view>-without.png and -with.png. A step starting with with: runs only with the mod (its settings,
# its dialog), and a view shot that way is saved once, as <Mod>-<view>.png. ship|<model>|<view> and
# weapon|<system>|<model>|<slots>|<view> draw a ship model, or a weapon mounted on one, alone, and are saved as shot's.
# Also: other mods loaded in both runs, when the view needs them. TimeoutSeconds: seconds before each of the mod's runs
# is stopped, where they take longer than shots.ps1's default.
@{
	# The Tuning screen's simulator button, in both runs: with the mod, its Shift badge. The dialog (Shift+Click on that
	# button), its first tab and its ship tab. Then, drawn alone (ShotRenderer's ship and weapon steps, which need no
	# screen): one ship per series of Shipyard.ships (its base model, Shipyard.gd configAlias; the variants' reactors sit
	# the same), but the habitat (OBONTO, no ship), with where hits damage its reactors; and every weapon, mounted on a
	# ship and hardpoint that take it (the TNTRL's high-stress main hardpoint, its side one for the SPC), with its cone
	# and reach; the Tsukuyomi's built-in turrets (ships/modules/PDT.tscn, never on a hardpoint) as its scene mounts them.
	CombatSimulator = @{
		TimeoutSeconds = 480
		Steps = @(
			'load', 'wait|10'
			'press|{menu}/ShipTuning', 'wait|3'
			'shot|button|570,412,1005,56'
			'with:shiftclick|{screens}/Tuning/VB/WindowMargin/Window/VBoxContainer/MarginContainer2/LaunchVR', 'wait|2'
			'with:shot|dialog|545,15,1055,875'
			'with:tab|CombatSimulatorDialog/Popup/Root/TabHintContainer/Tabs|1', 'wait|4'
			'with:shot|ships|545,15,1055,875'
			'with:ship|HYBRID|ship-hybrid'
			'with:ship|TRTL|ship-trtl'
			'with:ship|MADCERF|ship-madcerf'
			'with:ship|PROSPECTOR|ship-prospector'
			'with:ship|PROSPECTOR-BALD|ship-prospector-bald'
			'with:ship|TSUKUYOMI|ship-tsukuyomi'
			'with:ship|DRONE|ship-drone'
			'with:ship|ATLAS|ship-atlas'
			'with:ship|EIME|ship-eime'
			'with:ship|COTHON|ship-cothon'
			'with:ship|AT225|ship-at225'
			'with:ship|OCP209|ship-ocp209'
			'with:ship|KITSUNE|ship-kitsune'
			'with:weapon|SYSTEM_EMD14|TRTL|main|weapon-emd14'
			'with:weapon|SYSTEM_EMD17RF|TRTL|main|weapon-emd17rf'
			'with:weapon|SYSTEM_RAILTOR|TRTL|main|weapon-railtor'
			'with:weapon|SYSTEM_ACTEMD14|TRTL|main|weapon-actemd14'
			'with:weapon|SYSTEM_CL150|TRTL|main|weapon-cl150'
			'with:weapon|SYSTEM_CL600P|TRTL|main|weapon-cl600p'
			'with:weapon|SYSTEM_ACL200P|TRTL|main|weapon-acl200p'
			'with:weapon|SYSTEM_MWG|TRTL|main|weapon-mwg'
			'with:weapon|SYSTEM_PDMWG|TRTL|main|weapon-pdmwg'
			'with:weapon|SYSTEM_SYNCHRO-L|TRTL|left|weapon-synchro'
			'with:weapon|SYSTEM_PDT|TRTL|main|weapon-pdt'
			'with:weapon|SYSTEM_PDTL|TRTL|main|weapon-pdtl'
			'with:weapon|SYSTEM_EINAT|TRTL|main|weapon-einat'
			'with:weapon|SYSTEM_NANI|TRTL|main|weapon-nani'
			'with:weapon|SYSTEM_IROH|TRTL|main|weapon-iroh'
			'with:weapon|-|TSUKUYOMI|pdt,pdt-sec,pdt-emp|weapon-tsukuyomi'
		)
	}
	CrewCheapHireNotifier = @{
		Steps = @(
			'load', 'wait|10'
			'shot|menu|0,115,410,457'
			'press|{menu}/Crew', 'wait|2'
			'tab|{screens}/Crew/TabHintContainer/Tabs|1', 'wait|2'
			'scroll|{screens}/Crew/TabHintContainer/Tabs/ENCELADUS_CREW_HIRE|700', 'wait|1'
			'shot|hire|950,100,622,235'
			'with:shiftclick|{menu}/Crew', 'wait|2'
			'with:shot|settings|545,15,1055,750'
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
	# The station menu with its alert mark, the Dealer screen with its badge, and the settings, in a run where every model
	# is switched on (Select all) and then a day passes: the dealer's ship of the day comes up for sale. The settings
	# screen closes with Esc, and its third row (the first ship's) is focused with the keyboard, so its description
	# shows; the shot comes before the game's tooltip for the focused switch.
	DealerNotifier = @{
		Steps = @(
			'load', 'wait|10'
			'with:shiftclick|{menu}/ShipMarket', 'wait|2'
			'with:pressfind|{screens}/DealerNotifierSettings|SelectAll|0', 'wait|1'
			'with:action|ui_cancel', 'wait|2'
			'call|/root/CurrentGame|advanceTimeBySeconds|[86400]', 'wait|4'
			'shot|menu|0,115,410,457'
			'press|{menu}/ShipMarket', 'wait|4'
			'shot|dealer|560,505,1010,380'
			'with:shiftclick|{menu}/ShipMarket', 'wait|2'
			'with:action|ui_down', 'with:action|ui_down', 'wait|0.3'
			'with:shot|settings|545,15,1055,875'
		)
	}
	DiveSkipTransit = @{
		Steps = @(
			'load', 'wait|10'
			'with:shiftclick|{menu}/RingDive', 'wait|2'
			'with:shot|settings|545,15,1055,735'
		)
	}
	# The mod's OMS tab (DAP), in a dive (J opens the OMS), switched on where it is stored (Settings.gd: the HUD's
	# mineralConfig, under the mod's id), the sliders at their defaults.
	DroneAltPriorities = @{
		Steps = @(
			'load', 'wait|10'
			'dive', 'wait|5'
			'action|jury_rig', 'wait|2'
			'with:set|ship:Hud|mineralConfig/AGlezB.DroneAltPriorities|{"enabled": true}'
			'with:tab|{oms}|DRONEALTPRIORITIES_TAB', 'wait|2'
			'with:shot|settings|320,2,965,355'
		)
	}
	# The mod's OMS tab (GBM), in a dive (J opens the OMS), with an example set where it is stored (Settings.gd: the
	# HUD's mineralConfig, under the mod's id): the switch on, a base of 200 kg, and extra masses growing by 200 kg from
	# the dearest mineral to the cheapest by the game's base prices (CurrentGame.mineralPrices: Be, W, V, Pt, Pd, Fe,
	# H2O). Then the Geologist tab's rows, in both runs: with the switch on, their Minimum values and that column's title
	# are hidden (the fixture's ship has only the HUD's row).
	GeologyByMass = @{
		Steps = @(
			'load', 'wait|10'
			'dive', 'wait|5'
			'action|jury_rig', 'wait|2'
			'with:set|ship:Hud|mineralConfig/AGlezB.GeologyByMass|{"enabled": true, "baseMass": 200, "extraMass": {"Be": 200, "W": 400, "V": 600, "Pt": 800, "Pd": 1000, "Fe": 1200, "H2O": 1400}}'
			'with:tab|{oms}|GEOLOGYBYMASS_TAB', 'wait|2'
			'with:shot|settings|320,2,965,425'
			'tab|{oms}|CREW_OCCUPATION_GEOLOGIST', 'wait|2'
			'shot|geologist|320,2,965,105'
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
	# The station menu with its alert mark (the fixture's cash is above the default cash reserve's range), the Mineral
	# Market (its header, and the mod's row at the bottom with the Shift badge beside the Trade button), and the settings
	# (Shift+Click on the Trade button).
	MarketAdvisor = @{
		Steps = @(
			'load', 'wait|10'
			'shot|menu|0,115,410,457'
			'press|{menu}/MineralMarket', 'wait|3'
			'shot|market|545,15,1055,875'
			'with:shiftclick|{screens}/MineralMarket/Details/MarketAdvisor/Row/Trade', 'wait|2'
			'with:shot|settings|545,15,1055,774'
		)
	}
	# The station menu with its alert mark (the fixture's cash can buy Jameson's Insurance), and the settings.
	ServiceNotifier = @{
		Steps = @(
			'load', 'wait|10'
			'shot|menu|0,115,410,457'
			'with:shiftclick|{menu}/Services', 'wait|2'
			'with:shot|settings|545,15,1055,700'
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
	# The OMS Pilot tab (J opens the OMS) listing one object of each kind that carries a code, around the ship in a dive
	# (ShotRenderer's transponders step): a ship with a THI Cargo Container, an NT Mining Companion and a B8 Claim Beacon
	# out as drones, a lifepod floating alone, a destroyed ship's lifepod, an ATLAS's AI core, and three frozen bodies.
	TransponderAltCodes = @{
		Steps = @(
			'load', 'wait|10'
			'dive', 'wait|5'
			'transponders', 'wait|2'
			'action|jury_rig', 'wait|2'
			'tab|{oms}|CREW_OCCUPATION_PILOT', 'wait|2'
			'shot|pilot|320,2,965,535'
		)
	}
}

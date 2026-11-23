#Requires -Version 7
<#
.SYNOPSIS
	Runs the mods' test harness in a headless Godot 3.6 and reports the results.

.DESCRIPTION
	Assembles a Godot project in <WorkDir>\project from this folder's sources, the game's own scripts (copied from
	the decompiled game: DockingArm.gd, Arm.gd, CabinLight.gd, Boot.gd, LIDAR.gd, PitchAdjustedAudio.gd,
	HardwareLabel.gd, EnceladusMenu.gd, HidingMarginContainer.gd, AnalogControlSlider.gd, TuningFloatValue.gd,
	TuningBoolValue.gd, TuningItems.gd, Hud.gd, OMS.gd, TabsWithGamepadControl.gd, PriceLabel.gd, RepeatingHSlider.gd, MineralLabel.gd,
	MineralSystemToggle.gd, SystemMineralList.gd, HireableCrew.gd, CrewBio.gd, CurrentCrewManagement.gd,
	PlaySoundsOnTheseButtons.gd,
	SystemBuyUI.gd, SystemShipUpgradeUI.gd, Dealer.gd, Game.gd, Enceladus.gd, TransponderOnIntro.gd, ship-ctrl.gd,
	Reactor.gd, FusionReactor.gd, Tool.gd, gdunzip.gd, CurrentGame.gd, body.gd, ClaimOwner.gd, ClaimBeacon-1.gd,
	ClaimBeaconForeign.gd, NewGamePlus.gd, PauseLayer.gd, PDT.gd, Video.gd, GravimetricReadout.gd, massdriver.gd,
	TheRing.gd, MarginViewportUpscale.gd, ViewportWithProxy.gd, NoBulletTime.gd, CanvasHidding.gd, MouseLayer.gd,
	drone-plant.gd, MineralMarket.gd, MineralSellSlider.gd, MineralPriceChart.gd, MarketChartPrice.gd, InGameMoney.gd,
	ServiceUI.gd, ServiceUIInsurance.gd, ServiceUIFactionChange.gd, Repairs.gd, SystemShipRepairUI.gd,
	SpecificDamageLabel.gd, ScrollWithAnalog.gd, MessageLine.gd, Player.gd, ConversationPlayer.gd, Display-K37.gd,
	ShipOnOMSLabel.gd, ShipOnOMSBearingDistance.gd), the
	game's ship models (harness\transponder_models.gd, read from ships\Shipyard.gd), the game's Shower.tscn, audio buses
	(default_bus_layout.tres), the skill icons CrewBio.gd preloads and the Fleet entry's Use icon, a stub mineral scene
	carrying the chunk radius read from the game's, stubs of the two scenes LIDAR.gd preloads, of the Tuning parts
	CrewCheapHireNotifier's settings screen is built from, of a Hire screen entry (CrewBio.tscn), of the Geologist
	tab's parts (its rows', which GeologyByMass's OMS tab is built from too), and of a Fleet entry (SystemBuyUI.tscn, with the game's
	confirmation animations), an Equipment item (SystemShipUpgradeUI.tscn), the Dealer screen (Dealer.tscn, as the
	station and Owned.tscn instance it, with a Dealer entry that has the game's tooltip node), the ring scene
	(Game.tscn, with the game's root values and title cards, the asteroid field's masks and the cursor's fade), the two
	scenes ship-ctrl.gd preloads, the three the story claim beacons preload, the station's fade-in
	(harness\station_fadein.tres), and what CombatSimulator's arena builds and loads: the simulator's button
	(LaunchVRButton.tscn), the asteroid field, BulletTimer, the music and WESpace, a ship scene under ships\, the pirate
	event (story\PirateCombat.gd), the scene massdriver.gd preloads and stand-ins of the ring maps TheRing.gd preloads.
	For MarketAdvisor: the Mineral Market (MineralMarket.tscn, with its slider rows, their price charts and the charts'
	labels). For MarketAdvisor and ServiceNotifier: the rows of the Services screen (ServiceUI.tscn,
	ServiceUIInsurance.tscn, ServiceUIFactionChange.tscn). For ShipRepairAdvisor: the game's Repairs screen
	(Repairs.tscn, without its insurance row's sound), its rows (SystemShipRepairUI.tscn) and their damage labels
	(SpecificDamageLabel.tscn), and bare stubs of the four helper scenes they instance. For LidarContactCallout: the
	game's comms line (comms\MessageLine.tscn, with its theme, light, icon and sound, and bare stubs of the three scenes
	it instances) and the Pilot tab's label and bearing and distance (ShipOnOMSLabel.tscn,
	ShipOnOMSBearingOrDistance.tscn, ShipOnOMSBearingDistance.tscn).
	Packages each mod into <WorkDir>\build\<Mod>.zip
	(as a release zip), and runs every suite with its mods loaded from those zips, the way the game loads them:
	by an autoload, before the engine loads the main scene. Logs: <WorkDir>\logs. Nothing in the repo, the game folder
	or the decompiled game is changed. Godot, the decompiled game and <WorkDir> default to folders under the ones set in
	paths.local.psd1 at the repo root (git-ignored; copy paths.example.psd1 to it).

	Suites and the mods they load by default:
	- units, still, moving, hold: ArmAltPullBehavior + ArmAltTargetSelection (unit checks; the ship standing still, 9
	  cases; the ship held, cruising, turning, 16 cases; holding and feeding while the ship turns and accelerates).
	  still, moving and hold need ArmAltPullBehavior.
	- dive: DiveDisableAdrenalineBooster.
	- boot: BootSkipLogos. Runs with harness\boot.tscn, which holds the game's Boot.gd, as the main scene.
	- lidar: LidarLouderPing.
	- hud: HudHideLabels.
	- crew: CrewCheapHireNotifier.
	- geology: GeologyByMass. Builds a HUD from harness\geology_hud.tscn, which holds the game's Hud.gd, and ships of
	  the game's ship-ctrl.gd.
	- fleet: ShipCopyPaste.
	- skip: DiveSkipTransit. Instances the ring scene stub (Game.tscn), whose root has the game's Game.gd.
	- dealer: DealerNotifier. Instances the Dealer screen stub (Dealer.tscn), whose root has the game's Dealer.gd. Also
	  checks ShipSortByTypeAndPrice and ShipHighlightTypeAndPrice where -Mods loads them.
	- transponder: TransponderAltCodes. Instances the game's CurrentGame.gd (the CurrentGame autoload stays the stub).
	- combat: CombatSimulator. Builds a station around the game's Enceladus.gd, with the game's PauseLayer.gd and
	  TheRing.gd, and runs the arena on stub ships and a stub asteroid field.
	- drones: DroneAltPriorities + GeologyByMass (both add an OMS tab). Builds drone plants from
	  harness\drones_plant.tscn, which holds the game's drone-plant.gd, and HUDs as geology does.
	- market: MarketAdvisor. Instances the Mineral Market stub (MineralMarket.tscn), whose root has the game's
	  MineralMarket.gd, and rows of the game's ServiceUI.gd.
	- services: ServiceNotifier. Builds the station as market does, without the market, with rows of the game's
	  ServiceUI.gd and ServiceUIFactionChange.gd.
	- sale: ShipCopyPaste + ShipSaleAdvisor (both extend the Fleet entries' script). Builds the Fleet screen's entries as
	  fleet does, among the station's screens (the game's HidingMarginContainer.gd), with stored ships whose systems
	  can be damaged and fixed.
	- repairs: ShipRepairAdvisor. Instances the game's Repairs screen (Repairs.tscn, whose root has the game's
	  Repairs.gd, with its rows of SystemShipRepairUI.gd) among the station's screens (the game's
	  HidingMarginContainer.gd), beside stubs of the Equipment screen (with the game's SystemShipUpgradeUI.gd items) and
	  the Fleet screen, with ships whose systems can be damaged, fixed, replaced and bought.
	- callout: LidarContactCallout. Builds HUDs from harness\callout_hud.tscn, which holds the game's Hud.gd, with the
	  geology suite's OMS and the game's comms line (MessageLine.tscn), on stub ships among stub objects of the field.

.EXAMPLE
	pwsh _tests\run.ps1
	All suites, each with its mods in the game's load order.

.EXAMPLE
	pwsh _tests\run.ps1 -Matrix
	The claude.ai comparison: moving with ships of 109.29 and 330 t and chunks of 2.8 and 5 t, every load order.

.EXAMPLE
	pwsh _tests\run.ps1 -Suite moving -ModZip ArmAltPullBehavior-1.3.1.zip
	An older release in place of the ArmAltPullBehavior folder.
#>
[CmdletBinding()]
param(
	[ValidateSet('units', 'still', 'moving', 'dive', 'boot', 'lidar', 'hud', 'crew', 'geology', 'fleet', 'skip', 'dealer', 'transponder', 'combat', 'drones', 'market', 'services', 'sale', 'repairs', 'callout', 'hold')]
	[string[]] $Suite = @('units', 'still', 'moving', 'hold', 'dive', 'boot', 'lidar', 'hud', 'crew', 'geology', 'fleet', 'skip', 'dealer', 'transponder', 'combat', 'drones', 'market', 'services', 'sale', 'repairs', 'callout'),
	# Mod folders to load for every selected suite, in load order (the game's order: by path); @() = none.
	# Default: each suite's own mods (see the description).
	[string[]] $Mods,
	# Release zips to load instead of the folder of the same mod.
	[string[]] $ModZip = @(),
	# Run every load order of the mods.
	[switch] $AllOrders,
	# Ship and chunk mass (t) for the moving suite; 0 = the harness defaults (109.29 and 2.8).
	[double] $ShipMass = 0,
	[double] $ChunkMass = 0,
	# moving with every combination of 109.29 / 330 t ships and 2.8 / 5 t chunks, in every load order.
	[switch] $Matrix,
	# Print Godot's whole output, not only failures.
	[switch] $ShowOutput,
	# The folders below default to ones under this machine's folders, set in paths.local.psd1 at the repo root
	# (git-ignored; paths.example.psd1 is its template).
	# Godot 3.6. Default: GodotDir\Godot_v3.6-stable_win64.exe.
	[string] $GodotPath = '',
	# The decompiled game to take the game's scripts from. Default: the newest Delta-V-<version> folder in
	# $DecompiledRoot (by version number), so the tests always run against the latest game available.
	[string] $GameSource = '',
	# Default: TempDir\gdre.
	[string] $DecompiledRoot = '',
	# Where the project, the zips and the logs are built. Default: TempDir\tests.
	[string] $WorkDir = '',
	[int] $TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = Split-Path $PSScriptRoot -Parent
$localPathsFile = Join-Path $repo 'paths.local.psd1'
$localPaths = if (Test-Path -LiteralPath $localPathsFile) { Import-PowerShellDataFile -LiteralPath $localPathsFile } else { @{} }
# $Child under the folder $Key of paths.local.psd1, for the parameter $Parameter left empty.
function Get-LocalPath([string] $Key, [string] $Child, [string] $Parameter)
{
	if (-not $localPaths[$Key]) { throw "Pass -$Parameter, or set $Key in $localPathsFile (copy paths.example.psd1 to it)" }
	return [IO.Path]::Combine($localPaths[$Key], $Child)
}
if (-not $GodotPath) { $GodotPath = Get-LocalPath 'GodotDir' 'Godot_v3.6-stable_win64.exe' 'GodotPath' }
if (-not $GameSource -and -not $DecompiledRoot) { $DecompiledRoot = Get-LocalPath 'TempDir' 'gdre' 'DecompiledRoot' }
if (-not $WorkDir) { $WorkDir = Get-LocalPath 'TempDir' 'tests' 'WorkDir' }
$work = [IO.Path]::GetFullPath($WorkDir)
if ($work.Length -le 3 -or $work.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase))
{
	throw "WorkDir must be outside the repo and not a drive root: $work"
}
if (-not $GameSource)
{
	$latest = Get-ChildItem -LiteralPath $DecompiledRoot -Directory -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match '^Delta-V-\d+(\.\d+){1,3}$' } |
		Sort-Object { [version]($_.Name -replace '^Delta-V-', '') } -Descending |
		Select-Object -First 1
	if (-not $latest) { throw "No decompiled game (Delta-V-<version>) in $DecompiledRoot" }
	$GameSource = $latest.FullName
}
$gameVersion = (Split-Path $GameSource -Leaf) -replace '^Delta-V-', ''
Write-Host "Game scripts from $GameSource"
$vpData = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'harness\vp_data.gd') -Raw
if ($vpData -match 'const CHECKED_AGAINST = "([^"]+)"' -and $Matches[1] -ne $gameVersion)
{
	Write-Host "WARNING: harness\vp_data.gd was checked against game $($Matches[1]), not ${gameVersion}: re-check its values against the scenes it cites." -ForegroundColor Yellow
}
foreach ($path in $GodotPath, $GameSource)
{
	if (-not (Test-Path -LiteralPath $path)) { throw "Not found: $path" }
}

function Write-Utf8Lf([string] $Path, [string] $Text)
{
	[IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

# Root folder of a mod zip (the mod's name); refuses zips the game could not load.
function Get-ZipModName([string] $Path)
{
	$zip = [IO.Compression.ZipFile]::OpenRead($Path)
	try
	{
		$names = $zip.Entries | ForEach-Object { $_.FullName }
		if ($names | Where-Object { $_.Contains('\') }) { throw "$Path has '\' in its entry names: the game cannot load it" }
		$roots = $names | ForEach-Object { $_.Split('/')[0] } | Select-Object -Unique
		if (@($roots).Count -ne 1) { throw "$Path must hold exactly one folder at its root" }
		return $roots
	}
	finally
	{
		$zip.Dispose()
	}
}

function Get-Permutations([object[]] $Items)
{
	if ($Items.Count -le 1) { return , @($Items) }
	foreach ($i in 0..($Items.Count - 1))
	{
		$rest = @($Items | Select-Object -Index (@(0..($Items.Count - 1)) | Where-Object { $_ -ne $i }))
		foreach ($p in (Get-Permutations $rest)) { , (@($Items[$i]) + @($p)) }
	}
}

# 1. The project: harness sources + the game's scripts and audio buses + the stub scenes.
$project = Join-Path $work 'project'
$build = Join-Path $work 'build'
$logs = Join-Path $work 'logs'
foreach ($dir in $project, $build, $logs)
{
	if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
	New-Item -ItemType Directory -Force $dir | Out-Null
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'project.godot'), (Join-Path $PSScriptRoot 'main.tscn') -Destination $project
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'harness'), (Join-Path $PSScriptRoot 'suites') -Destination $project -Recurse
foreach ($file in 'ships\modules\DockingArm.gd', 'ships\modules\Arm.gd', 'ships\CabinLight.gd', 'Boot.gd', 'hud\LIDAR.gd', 'sfx\PitchAdjustedAudio.gd', 'hud\HardwareLabel.gd', 'enceladus\EnceladusMenu.gd', 'enceladus\HidingMarginContainer.gd', 'enceladus\AnalogControlSlider.gd', 'enceladus\Tuning\TuningFloatValue.gd', 'enceladus\Tuning\TuningBoolValue.gd', 'enceladus\Tuning\TuningItems.gd', 'hud\Hud.gd', 'hud\OMS.gd', 'menu\TabsWithGamepadControl.gd', 'hud\components\PriceLabel.gd', 'hud\components\RepeatingHSlider.gd', 'hud\components\MineralLabel.gd', 'hud\components\MineralSystemToggle.gd', 'hud\SystemMineralList.gd', 'enceladus\HireableCrew.gd', 'enceladus\CrewBio.gd', 'enceladus\CurrentCrewManagement.gd', 'menu\sfx\PlaySoundsOnTheseButtons.gd', 'enceladus\SystemBuyUI.gd', 'enceladus\SystemShipUpgradeUI.gd', 'enceladus\Dealer.gd', 'enceladus\Shower.tscn', 'Game.gd', 'enceladus\Enceladus.gd', 'TransponderOnIntro.gd', 'ships\ship-ctrl.gd', 'ships\Reactor.gd', 'ships\modules\FusionReactor.gd', 'Tool.gd', 'vendor\gdunzip.gd', 'default_bus_layout.tres', 'CurrentGame.gd', 'story\body.gd', 'ships\modules\ClaimOwner.gd', 'ships\WeaponSlot.gd', 'story\ClaimBeacon-1.gd', 'story\ClaimBeaconForeign.gd', 'menu\NewGamePlus.gd', 'PauseLayer.gd', 'ships\modules\PDT.gd', 'hud\Video.gd', 'hud\GravimetricReadout.gd', 'weapons\massdriver.gd', 'TheRing.gd', 'enceladus\MarginViewportUpscale.gd', 'enceladus\Simulator\ViewportWithProxy.gd', 'enceladus\NoBulletTime.gd', 'enceladus\CanvasHidding.gd', 'menu\MouseLayer.gd', 'weapons\drone-plant.gd', 'enceladus\MineralMarket.gd', 'enceladus\MineralSellSlider.gd', 'enceladus\MineralPriceChart.gd', 'enceladus\Minerals\MarketChartPrice.gd', 'enceladus\InGameMoney.gd', 'enceladus\ServiceUI.gd', 'enceladus\ServiceUIInsurance.gd', 'enceladus\ServiceUIFactionChange.gd', 'enceladus\Repairs.gd', 'enceladus\SystemShipRepairUI.gd', 'enceladus\SystemShipRepairUI.tscn', 'enceladus\SpecificDamageLabel.gd', 'enceladus\SpecificDamageLabel.tscn', 'enceladus\ScrollWithAnalog.gd', 'comms\MessageLine.gd', 'comms\MessageLine.tscn', 'comms\Player.gd', 'comms\ConversationPlayer.gd', 'hud\Display-K37.gd', 'hud\components\ShipOnOMSLabel.gd', 'hud\components\ShipOnOMSLabel.tscn', 'hud\components\ShipOnOMSBearingOrDistance.tscn', 'hud\components\ShipOnOMSBearingDistance.gd', 'hud\components\ShipOnOMSBearingDistance.tscn')
{
	$target = Join-Path $project $file
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item -LiteralPath (Join-Path $GameSource $file) -Destination $target
}
# The themes of a Fleet entry (enceladus\SystemBuyUI.tscn: menu\MenuTheme.tres for the entry, hud\TNTRL-theme.tres for
# its labels' grid) and of the comms line (comms\MessageLine.tscn: hud\TNTRL-theme-inventory.tres), and everything they
# load (fonts, styleboxes, images), found by following their res:// paths, so the entry's sizes and looks are the
# game's. Images go through the import step below.
$themeFiles = [Collections.Generic.List[string]]::new()
$pending = [Collections.Generic.Queue[string]]::new()
foreach ($t in 'menu\MenuTheme.tres', 'hud\TNTRL-theme.tres', 'hud\TNTRL-theme-inventory.tres') { $pending.Enqueue($t) }
# The entry's thumbnail margin has the Fleet screen's prose theme, a binary resource whose dependencies (a font,
# styleboxes and images) are all MenuTheme.tres's too.
$themeFiles.Add('enceladus\Subwindow.theme')
while ($pending.Count -gt 0)
{
	$file = $pending.Dequeue()
	if ($themeFiles.Contains($file)) { continue }
	$themeFiles.Add($file)
	if ($file -match '\.(tres|stylebox|theme)$')
	{
		foreach ($m in [regex]::Matches((Get-Content -LiteralPath (Join-Path $GameSource $file) -Raw), 'path="res://([^"]+)"'))
		{
			$pending.Enqueue($m.Groups[1].Value.Replace('/', '\'))
		}
	}
}
foreach ($file in $themeFiles | Where-Object { $_ -notmatch '\.png$' })
{
	$target = Join-Path $project $file
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item -LiteralPath (Join-Path $GameSource $file) -Destination $target
}
# Icons (and a sound) as the game ships them: their import files and the imported resources they point to, so they load
# without an import step. CrewBio.gd preloads the skill icons; a Fleet entry's Use button shows switch.png, whose size
# and colour ShipCopyPaste's icons take, and the Buy confirmation's OK shows buy.png.
$imports = @(Get-ChildItem -LiteralPath (Join-Path $GameSource 'enceladus\Crew') -Filter 'skill-*.png.import' | ForEach-Object { 'enceladus\Crew\' + $_.Name })
$imports += 'enceladus\Upgrades\switch.png.import', 'enceladus\Upgrades\buy.png.import'
# The comms line's light, control hint icon and incoming sound (comms\MessageLine.tscn), and the hang-up icon
# comms\ConversationPlayer.gd preloads.
$imports += 'lights\color-square.png.import', 'hud\comms.png.import', 'comms\radio_incoming.wav.import', 'hud\hangup.png.import'
$imports += @($themeFiles | Where-Object { $_ -match '\.png$' } | ForEach-Object { $_ + '.import' })
foreach ($import in $imports)
{
	$texture = [regex]::Match((Get-Content -LiteralPath (Join-Path $GameSource $import) -Raw), '(?m)^path="res://([^"]+)"')
	if (-not $texture.Success) { throw "No imported texture in $import" }
	foreach ($file in $import, $texture.Groups[1].Value.Replace('/', '\'))
	{
		$target = Join-Path $project $file
		New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
		Copy-Item -LiteralPath (Join-Path $GameSource $file) -Destination $target
	}
}
$mineral = Get-Content -LiteralPath (Join-Path $GameSource 'asteroids\mineral-fe-1.tscn') -Raw
$circle = [regex]::Match($mineral, '\[sub_resource type="CircleShape2D" id=(\d+)\]\s*\r?\nradius = ([0-9.eE+-]+)')
$collision = [regex]::Match($mineral, '\[node name="Collision"[^\]]*\][^\[]*?shape = SubResource\( (\d+) \)')
if (-not $circle.Success -or -not $collision.Success -or $circle.Groups[1].Value -ne $collision.Groups[1].Value)
{
	throw 'Cannot read the chunk radius from asteroids\mineral-fe-1.tscn'
}
New-Item -ItemType Directory -Force (Join-Path $project 'asteroids') | Out-Null
Write-Utf8Lf (Join-Path $project 'asteroids\mineral-fe-1.tscn') @"
[gd_scene load_steps=2 format=2]

[sub_resource type="CircleShape2D" id=1]
radius = $($circle.Groups[2].Value)

[node name="Fe1" type="RigidBody2D"]

[node name="Collision" type="CollisionShape2D" parent="."]
shape = SubResource( 1 )
"@
# LIDAR.gd preloads these two; the lidar suite never draws, so bare nodes do.
New-Item -ItemType Directory -Force (Join-Path $project 'hud\components') | Out-Null
foreach ($scene in 'LidarRangeMarker', 'LidarShipMarker')
{
	Write-Utf8Lf (Join-Path $project "hud\components\$scene.tscn") @"
[gd_scene format=2]

[node name="$scene" type="Node2D"]
"@
}
# ship-ctrl.gd preloads these two (the sparks of an energy hit, an EVA's sprite); the skip suite's ship never makes
# either, so bare nodes do.
foreach ($scene in 'sfx\WeldingSparks', 'ships\modules\EVAflight')
{
	$target = Join-Path $project "$scene.tscn"
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Write-Utf8Lf $target @"
[gd_scene format=2]

[node name="$(Split-Path $scene -Leaf)" type="Node2D"]
"@
}
# The story claim beacons (story\ClaimBeacon-1.gd, ClaimBeaconForeign.gd) preload these three; the transponder suite
# never spawns them, so bare nodes do.
foreach ($scene in 'ships\drone\ClaimBeacon', 'ships\drone\ClaimBeaconForeign', 'story\DummyBeacon')
{
	$target = Join-Path $project "$scene.tscn"
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Write-Utf8Lf $target @"
[gd_scene format=2]

[node name="$(Split-Path $scene -Leaf)" type="RigidBody2D"]
"@
}
# The ship models the game's Shipyard builds (ships\Shipyard.gd, the keys of `ships`), for the transponder suite: each
# needs a code of its own in TransponderAltCodes' MODEL_CODES.
$shipyard = (Get-Content -LiteralPath (Join-Path $GameSource 'ships\Shipyard.gd') -Raw) -replace "`r`n", "`n"
$shipsBlock = [regex]::Match($shipyard, '(?ms)^onready var ships = \{\n(.*?)^\}')
$models = @([regex]::Matches($shipsBlock.Groups[1].Value, '(?m)^\s*"([^"]+)": preload\(') | ForEach-Object { '"' + $_.Groups[1].Value + '"' })
if (-not $shipsBlock.Success -or $models.Count -eq 0) { throw 'Cannot read the ship models from ships\Shipyard.gd (onready var ships)' }
Write-Utf8Lf (Join-Path $project 'harness\transponder_models.gd') @"
# Generated by run.ps1: the keys of `ships` in the game's ships\Shipyard.gd ($gameVersion).
const MODELS = [$($models -join ', ')]
"@
# The Tuning parts CrewCheapHireNotifier's and DiveSkipTransit's settings screens are built from: the game's node paths,
# scripts and connections (enceladus\Tuning\TuningFloatValue.tscn, TuningBoolValue.tscn, TuningItems.tscn,
# enceladus\HeaderWithMoney.tscn, with your cash, enceladus\Money.tscn, and the hidden insurance row, both on the game's
# InGameMoney.gd: MarketAdvisor's parked row copies that row), without the theme, textures, sounds and smooth scrolling.
Write-Utf8Lf (Join-Path $project 'enceladus\Tuning\TuningFloatValue.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/Tuning/TuningFloatValue.gd" type="Script" id=1]
[ext_resource path="res://enceladus/AnalogControlSlider.gd" type="Script" id=2]

[node name="TuningFloatValue" type="VBoxContainer"]
size_flags_horizontal = 3
script = ExtResource( 1 )

[node name="HBoxContainer" type="HBoxContainer" parent="."]

[node name="Name" type="Button" parent="HBoxContainer"]
focus_mode = 1
size_flags_horizontal = 3
text = "SYSTEM_NAME"
flat = true
clip_text = true

[node name="Value" type="Label" parent="HBoxContainer"]
text = "0"

[node name="Unit" type="Label" parent="HBoxContainer"]
text = "m/s"

[node name="Reset" type="Button" parent="HBoxContainer"]
flat = true

[node name="HSlider" type="HSlider" parent="."]
scrollable = false
script = ExtResource( 2 )

[connection signal="pressed" from="HBoxContainer/Reset" to="." method="_on_Button_pressed"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\Tuning\TuningBoolValue.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://enceladus/Tuning/TuningBoolValue.gd" type="Script" id=1]

[node name="TuningBoolValue" type="VBoxContainer"]
size_flags_horizontal = 3
script = ExtResource( 1 )

[node name="HBoxContainer" type="HBoxContainer" parent="."]

[node name="Name" type="Button" parent="HBoxContainer"]
focus_mode = 1
size_flags_horizontal = 3
text = "SYSTEM_NAME"
flat = true

[node name="Value" type="CheckButton" parent="HBoxContainer"]
flat = true

[node name="Reset" type="Button" parent="HBoxContainer"]
flat = true

[connection signal="toggled" from="HBoxContainer/Value" to="." method="changed"]
[connection signal="pressed" from="HBoxContainer/Reset" to="." method="_on_Button_pressed"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\Tuning\TuningItems.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://enceladus/Tuning/TuningItems.gd" type="Script" id=1]

[node name="TuningItems" type="VBoxContainer"]
size_flags_horizontal = 3
script = ExtResource( 1 )

[node name="Label" type="Label" parent="."]
text = "SYSTEM_LABEL"
align = 1
'@
Write-Utf8Lf (Join-Path $project 'enceladus\Money.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://enceladus/InGameMoney.gd" type="Script" id=1]

[node name="Money" type="Label"]
size_flags_horizontal = 3
text = "0 E$"
align = 2
script = ExtResource( 1 )
'@
Write-Utf8Lf (Join-Path $project 'enceladus\HeaderWithMoney.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/Money.tscn" type="PackedScene" id=1]
[ext_resource path="res://enceladus/InGameMoney.gd" type="Script" id=2]

[node name="HeaderWithMoney" type="HBoxContainer"]
alignment = 1

[node name="MarketLabel" type="Label" parent="."]
size_flags_horizontal = 3
size_flags_vertical = 0
text = "PUT_HEADER_HERE"

[node name="VBoxContainer" type="VBoxContainer" parent="."]

[node name="Money" parent="VBoxContainer" instance=ExtResource( 1 )]

[node name="Insurence" type="HBoxContainer" parent="VBoxContainer"]
visible = false

[node name="InsuranceLabel" type="Label" parent="VBoxContainer/Insurence"]
size_flags_horizontal = 3
text = "ENCELADUS_INSURED_FOR"
align = 2

[node name="Insurance" type="Label" parent="VBoxContainer/Insurence"]
size_flags_horizontal = 3
text = "0 E$"
script = ExtResource( 2 )
type = 1

[node name="Pinger" type="AudioStreamPlayer" parent="VBoxContainer/Insurence/Insurance"]
volume_db = -5.0
pitch_scale = 0.8
bus = "UI"
'@
# The Geologist tab's parts (hud\components\MineralSystemToggle.tscn, MineralLabel.tscn, PriceLabel.tscn, as
# hud\SystemMineralList.gd uses them, and GeologyByMass's OMS tab is built from them; MineralSystemLabel.tscn and
# PercentLabel.tscn, which the list preloads too): the game's node paths, scripts, values and connections, without the
# theme, the toggle's click sound, the slider's smooth scrolling and button sounds.
Write-Utf8Lf (Join-Path $project 'hud\components\MineralSystemToggle.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://hud/components/MineralSystemToggle.gd" type="Script" id=1]

[node name="MineralSystemToggle" type="CheckButton"]
margin_right = 80.0
margin_bottom = 40.0
rect_min_size = Vector2( 0, 30 )
size_flags_horizontal = 4
size_flags_vertical = 3
pressed = true
flat = true
clip_text = true
align = 1
script = ExtResource( 1 )

[node name="Label" type="Label" parent="."]
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
margin_left = -60.0
margin_top = -8.0
margin_right = 60.0
align = 1
clip_text = true
'@
Write-Utf8Lf (Join-Path $project 'hud\components\MineralLabel.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://hud/components/MineralLabel.gd" type="Script" id=1]

[node name="MineralLabel" type="Button"]
margin_right = 40.0
margin_bottom = 14.0
text = "Be"
flat = true
align = 0
script = ExtResource( 1 )
'@
Write-Utf8Lf (Join-Path $project 'hud\components\PriceLabel.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://hud/components/PriceLabel.gd" type="Script" id=1]
[ext_resource path="res://hud/components/RepeatingHSlider.gd" type="Script" id=2]

[node name="PriceLabel" type="MarginContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource( 1 )

[node name="Box" type="HBoxContainer" parent="."]
alignment = 1

[node name="HSlider" type="HSlider" parent="Box"]
rect_min_size = Vector2( 120, 0 )
hint_tooltip = "HINT_FILTER_PRICE"
focus_mode = 0
size_flags_vertical = 4
max_value = 20000.0
step = 1000.0
scrollable = false
ticks_on_borders = true
script = ExtResource( 2 )

[node name="MarginContainer" type="MarginContainer" parent="Box"]
rect_min_size = Vector2( 100, 0 )

[node name="Label" type="Button" parent="Box/MarginContainer"]
rect_min_size = Vector2( 110, 0 )
size_flags_horizontal = 3
size_flags_vertical = 3
flat = true
align = 0

[connection signal="blur" from="Box/HSlider" to="." method="grab_focus"]
[connection signal="focus_exited" from="Box/HSlider" to="Box/HSlider" method="_on_HSlider_focus_exited"]
[connection signal="value_changed" from="Box/HSlider" to="." method="_on_HSlider_value_changed"]
[connection signal="pressed" from="Box/MarginContainer/Label" to="Box/HSlider" method="_on_Label_pressed"]
'@
Write-Utf8Lf (Join-Path $project 'hud\components\MineralSystemLabel.tscn') @'
[gd_scene format=2]

[node name="MineralSystemLabel" type="Label"]
margin_right = 40.0
margin_bottom = 14.0
align = 2
uppercase = true
'@
Write-Utf8Lf (Join-Path $project 'hud\components\PercentLabel.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://hud/components/PriceLabel.tscn" type="PackedScene" id=1]

[node name="PriceLabel" instance=ExtResource( 1 )]
format = "%s%%"

[node name="HSlider" parent="Box" index="0"]
hint_tooltip = "HINT_FILTER_ALBEDO"
max_value = 100.0
step = 5.0

[node name="MarginContainer" parent="Box" index="1"]
rect_min_size = Vector2( 50, 0 )

[node name="Label" parent="Box/MarginContainer" index="0"]
rect_min_size = Vector2( 60, 0 )
align = 2
'@
# A Hire screen entry (enceladus\CrewBio.tscn, as enceladus\HireableCrew.gd instances it): the game's node paths,
# script, values and connection, a stub of the portrait (faces\VideoComms.tscn), the hire animation's player without
# its animations, and the game's tooltip node (menu\sfx\PlaySoundsOnTheseButtons.tscn: its script, paths and nodes,
# without the sounds and theme); without the theme, the stat buttons' icons and smooth scrolling and the flicker.
Write-Utf8Lf (Join-Path $project 'enceladus\CrewBio.tscn') @'
[gd_scene load_steps=4 format=2]

[ext_resource path="res://enceladus/CrewBio.gd" type="Script" id=1]
[ext_resource path="res://harness/crew_video.gd" type="Script" id=2]
[ext_resource path="res://menu/sfx/PlaySoundsOnTheseButtons.gd" type="Script" id=3]

[node name="CrewBio" type="MarginContainer"]
anchor_right = 1.0
rect_clip_content = true
custom_constants/margin_right = 8
custom_constants/margin_top = 0
custom_constants/margin_left = 8
custom_constants/margin_bottom = 8
script = ExtResource( 1 )
showStats = true

[node name="Margin" type="MarginContainer" parent="."]

[node name="HBoxContainer" type="HBoxContainer" parent="Margin"]
size_flags_horizontal = 3

[node name="VBoxContainer" type="VBoxContainer" parent="Margin/HBoxContainer"]
size_flags_horizontal = 3
size_flags_vertical = 8
custom_constants/separation = 10

[node name="HBoxContainer" type="HBoxContainer" parent="Margin/HBoxContainer/VBoxContainer"]

[node name="StatGrid" type="GridContainer" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer"]
size_flags_horizontal = 3
size_flags_vertical = 8

[node name="Stat1" type="Button" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/StatGrid"]
size_flags_horizontal = 3
text = "STAT_1_HERE"
flat = true
align = 0

[node name="Stat2" type="Button" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/StatGrid"]
size_flags_horizontal = 3
text = "STAT_2_HERE"
flat = true
align = 0

[node name="GridContainer" type="GridContainer" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer"]
size_flags_horizontal = 3
columns = 2

[node name="FullNameLabel" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
text = "CREW_FULLNAME"

[node name="FullName" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
size_flags_horizontal = 3
text = "%s, %s"
align = 2

[node name="OccupationLabel" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
text = "CREW_OCCUPATION"

[node name="Occupation" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
size_flags_horizontal = 3
text = "OCCUPATION_HERE"
align = 2

[node name="EducationLabel" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
text = "CREW_EDUCATION"

[node name="Education" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
size_flags_horizontal = 3
text = "EDUCATION"
align = 2

[node name="ExperienceLabel" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
text = "CREW_EXPERIENCE"

[node name="Experience" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
size_flags_horizontal = 3
text = "EXPERIENCE"
align = 2

[node name="SalaryLabel" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
text = "CREW_SALARY"

[node name="Salary" type="Label" parent="Margin/HBoxContainer/VBoxContainer/HBoxContainer/GridContainer"]
size_flags_horizontal = 3
text = "%f"
align = 2

[node name="Hire" type="Button" parent="Margin/HBoxContainer/VBoxContainer"]
rect_min_size = Vector2( 320, 0 )
size_flags_horizontal = 3
disabled = true
text = "CREW_HIRE"

[node name="VideoComms" type="Control" parent="Margin/HBoxContainer"]
rect_min_size = Vector2( 216, 216 )
script = ExtResource( 2 )

[node name="HirePlayer" type="AnimationPlayer" parent="."]

[node name="PlaySoundsOnTheseButtons" type="Node" parent="."]
pause_mode = 2
script = ExtResource( 3 )
tooltipLabelPath = NodePath("Separation/Tooltip/MarginContainer/PanelContainer/TooltipLabel")
tooltipContainerPath = NodePath("Separation/Tooltip/MarginContainer")
tooltipPositionPath = NodePath("Separation/Tooltip")

[node name="focus" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="hover" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="select" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="Separation" type="Node" parent="PlaySoundsOnTheseButtons"]

[node name="Tooltip" type="Node2D" parent="PlaySoundsOnTheseButtons/Separation"]
visible = false

[node name="MarginContainer" type="MarginContainer" parent="PlaySoundsOnTheseButtons/Separation/Tooltip"]
mouse_filter = 2

[node name="PanelContainer" type="PanelContainer" parent="PlaySoundsOnTheseButtons/Separation/Tooltip/MarginContainer"]
mouse_filter = 2

[node name="TooltipLabel" type="Label" parent="PlaySoundsOnTheseButtons/Separation/Tooltip/MarginContainer/PanelContainer"]

[connection signal="pressed" from="Margin/HBoxContainer/VBoxContainer/Hire" to="." method="_on_Hire_pressed"]
'@
# A Fleet entry (enceladus\SystemBuyUI.tscn, as enceladus\Dealer.gd instances it): the game's node paths, script, values
# and connections, the Use and OK icons, the confirmation's frame and margins, and the confirmation animations read from
# the game's scene, and the game's themes (menu\MenuTheme.tres for the entry,
# hud\TNTRL-theme.tres for its labels' grid), so sizes and looks are the game's; the picture's sprite placed, scaled and
# flipped and the Buy button's margins as the game's scene has them (DealerNotifier's settings rows copy them); without
# the other textures, the lights and environment of the ship's view, the smooth scrolling (a bare node in its place
# under Use), the sounds and the flicker (harness\fleet_flicker.gd).
$buyUi = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\SystemBuyUI.tscn') -Raw) -replace "`r`n", "`n"
$animations = [regex]::Matches($buyUi, '(?ms)^\[sub_resource type="Animation" id=\d+\]\n.*?(?=^\[)')
$anims = [regex]::Matches($buyUi, '(?m)^anims/\w+ = SubResource\( \d+ \)$')
if ($animations.Count -lt 2 -or $anims.Count -ne $animations.Count) { throw 'Cannot read the confirmation animations from enceladus\SystemBuyUI.tscn' }
$spriteBlock = [regex]::Match($buyUi, '(?ms)^\[node name="Sprite" type="Sprite" parent="HBox/Margin"\]\n(.*?)(?=^\[)')
$buyBlock = [regex]::Match($buyUi, '(?ms)^\[node name="Buy" type="Button" parent="HBox"\]\n(.*?)(?=^\[)')
if (-not $spriteBlock.Success -or -not $buyBlock.Success) { throw 'Cannot read the picture sprite and the Buy button from enceladus\SystemBuyUI.tscn' }
$spriteLines = @($spriteBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^(position|scale|centered|offset|flip_h|flip_v) = ' }) -join "`n"
$buyLines = @($buyBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^margin_\w+ = ' }) -join "`n"
if (-not $spriteLines -or -not $buyLines) { throw 'enceladus\SystemBuyUI.tscn: no placement for the picture sprite or no margins for the Buy button' }
$entry = @'
[gd_scene load_steps=@@STEPS@@ format=2]

[ext_resource path="res://enceladus/SystemBuyUI.gd" type="Script" id=1]
[ext_resource path="res://enceladus/Upgrades/switch.png" type="Texture" id=2]
[ext_resource path="res://harness/fleet_flicker.gd" type="Script" id=3]
[ext_resource path="res://menu/MenuTheme.tres" type="Theme" id=4]
[ext_resource path="res://hud/TNTRL-theme.tres" type="Theme" id=5]
[ext_resource path="res://menu/PanelWithHugeShadow.tres" type="StyleBox" id=6]
[ext_resource path="res://enceladus/Upgrades/buy.png" type="Texture" id=7]
[ext_resource path="res://enceladus/Subwindow.theme" type="Theme" id=8]

@@ANIMATIONS@@
[node name="SystemBuyUi" type="MarginContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
size_flags_horizontal = 3
theme = ExtResource( 4 )
custom_constants/margin_right = 16
script = ExtResource( 1 )

[node name="BG" type="TextureRect" parent="."]
expand = true

[node name="HBox" type="HBoxContainer" parent="."]
size_flags_horizontal = 3
size_flags_vertical = 0
custom_constants/separation = 8

[node name="ViewportContainer" type="Node2D" parent="HBox"]
visible = false

[node name="Viewport" type="Viewport" parent="HBox/ViewportContainer"]
size = Vector2( 64, 64 )
own_world = true
render_target_update_mode = 0
gui_disable_input = true

[node name="Margin" type="MarginContainer" parent="HBox"]
rect_min_size = Vector2( 192, 64 )
rect_clip_content = true
theme = ExtResource( 8 )

[node name="Sprite" type="Sprite" parent="HBox/Margin"]
@@SPRITE@@

[node name="NewMark" type="Sprite" parent="HBox/Margin"]

[node name="Damaged" type="Sprite" parent="HBox/Margin"]

[node name="Repairs" type="Sprite" parent="HBox/Margin"]

[node name="RepairTimeLeft" type="Label" parent="HBox/Margin"]

[node name="ShipName" type="Button" parent="HBox"]
size_flags_horizontal = 3
disabled = true
flat = true
clip_text = true
align = 0

[node name="V" type="GridContainer" parent="HBox"]
size_flags_horizontal = 0
theme = ExtResource( 5 )

[node name="StickerPrice" type="Label" parent="HBox/V"]
visible = false
rect_min_size = Vector2( 96, 0 )
text = "%s E$"
align = 2

[node name="Owned" type="Label" parent="HBox/V"]
visible = false
modulate = Color( 0.5, 2, 0.5, 1 )
rect_min_size = Vector2( 96, 0 )
text = "GARAGE_OWNED"
align = 2

[node name="Registration" type="Label" parent="HBox/V"]
rect_min_size = Vector2( 96, 0 )
text = "xxx-yyyy"
align = 2

[node name="ShipModel" type="Label" parent="HBox/V"]
rect_min_size = Vector2( 96, 0 )
text = "name"
align = 2

[node name="MakeYear" type="Label" parent="HBox/V"]
rect_min_size = Vector2( 96, 0 )
text = "name"
align = 2

[node name="Use" type="Button" parent="HBox"]
visible = false
hint_tooltip = "GARAGE_SWITCH"
disabled = true
shortcut_in_tooltip = false
icon = ExtResource( 2 )
flat = true

[node name="SmoothScrollTo" type="Node" parent="HBox/Use"]

[node name="Buy" type="Button" parent="HBox"]
@@BUY@@
hint_tooltip = "UPGRADE_BUY"
disabled = true
flat = true

[node name="Sell" type="Button" parent="HBox"]
visible = false
hint_tooltip = "GARAGE_SELL"
disabled = true
shortcut_in_tooltip = false
flat = true

[node name="ConfirmationCenter" type="CenterContainer" parent="."]
size_flags_horizontal = 8

[node name="BuyPanel" type="PanelContainer" parent="ConfirmationCenter"]
visible = false
custom_styles/panel = ExtResource( 6 )

[node name="MarginContainer" type="MarginContainer" parent="ConfirmationCenter/BuyPanel"]
custom_constants/margin_right = 8
custom_constants/margin_top = 4
custom_constants/margin_left = 8
custom_constants/margin_bottom = 4

[node name="VBoxContainer" type="HBoxContainer" parent="ConfirmationCenter/BuyPanel/MarginContainer"]

[node name="BuyPrice" type="Label" parent="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer"]
text = "BUY_PRICE"
align = 1

[node name="HBoxContainer" type="HBoxContainer" parent="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer"]
custom_constants/separation = 16

[node name="BuyConfirm" type="Button" parent="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer/HBoxContainer"]
focus_neighbour_right = NodePath("../BuyCancel")
text = "OK"
icon = ExtResource( 7 )

[node name="BuyCancel" type="Button" parent="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer/HBoxContainer"]
focus_neighbour_left = NodePath("../BuyConfirm")
text = "CANCEL"

[node name="SellPanel" type="PanelContainer" parent="ConfirmationCenter"]
visible = false

[node name="MarginContainer" type="MarginContainer" parent="ConfirmationCenter/SellPanel"]

[node name="VBoxContainer" type="HBoxContainer" parent="ConfirmationCenter/SellPanel/MarginContainer"]

[node name="Label" type="Label" parent="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer"]
text = "SELL_PRICE"
align = 1

[node name="HBoxContainer" type="HBoxContainer" parent="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer"]
custom_constants/separation = 16

[node name="SellConfirm" type="Button" parent="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer/HBoxContainer"]
focus_neighbour_right = NodePath("../SellCancel")
text = "OK"

[node name="SellCancel" type="Button" parent="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer/HBoxContainer"]
focus_neighbour_left = NodePath("../SellConfirm")
text = "CANCEL"

[node name="Flicker" type="Node" parent="."]
script = ExtResource( 3 )
supress = true

[node name="ConfirmationPlayer" type="AnimationPlayer" parent="."]
@@ANIMS@@

[connection signal="focus_entered" from="HBox/ShipName" to="." method="_on_ShipName_focus_entered"]
[connection signal="focus_entered" from="HBox/Use" to="." method="_on_Use_focus_entered"]
[connection signal="pressed" from="HBox/Use" to="." method="_on_Use_pressed"]
[connection signal="focus_entered" from="HBox/Buy" to="." method="_on_Buy_focus_entered"]
[connection signal="pressed" from="HBox/Buy" to="." method="_on_Buy_pressed"]
[connection signal="focus_entered" from="HBox/Sell" to="." method="_on_Use_focus_entered"]
[connection signal="pressed" from="HBox/Sell" to="." method="_on_Sell_pressed"]
[connection signal="focus_entered" from="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer/HBoxContainer/BuyConfirm" to="." method="_on_Buy_focus_entered"]
[connection signal="pressed" from="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer/HBoxContainer/BuyConfirm" to="." method="_on_BuyConfirm_pressed"]
[connection signal="pressed" from="ConfirmationCenter/BuyPanel/MarginContainer/VBoxContainer/HBoxContainer/BuyCancel" to="." method="_on_BuyCancel_pressed"]
[connection signal="focus_entered" from="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer/HBoxContainer/SellConfirm" to="." method="_on_Buy_focus_entered"]
[connection signal="pressed" from="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer/HBoxContainer/SellConfirm" to="." method="_on_SellConfirm_pressed"]
[connection signal="pressed" from="ConfirmationCenter/SellPanel/MarginContainer/VBoxContainer/HBoxContainer/SellCancel" to="." method="_on_SellCancel_pressed"]
'@
$entry = $entry.Replace('@@STEPS@@', [string](9 + $animations.Count)).Replace('@@ANIMATIONS@@', (($animations | ForEach-Object { $_.Value.TrimEnd() + "`n" }) -join "`n")).Replace('@@ANIMS@@', (($anims | ForEach-Object { $_.Value }) -join "`n"))
$entry = $entry.Replace('@@SPRITE@@', $spriteLines).Replace('@@BUY@@', $buyLines)
Write-Utf8Lf (Join-Path $project 'enceladus\SystemBuyUI.tscn') $entry
# An Equipment item (enceladus\SystemShipUpgradeUI.tscn, as enceladus\Upgrades.tscn instances it): the game's node
# paths, script, labels and connections; without the theme, the icons, the system name's script, the smooth scrolling,
# the sounds and the flicker (harness\fleet_flicker.gd).
Write-Utf8Lf (Join-Path $project 'enceladus\SystemShipUpgradeUI.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/SystemShipUpgradeUI.gd" type="Script" id=1]
[ext_resource path="res://harness/fleet_flicker.gd" type="Script" id=2]

[node name="SystemShipUpgradeUI" type="MarginContainer"]
size_flags_horizontal = 3
script = ExtResource( 1 )

[node name="HBox" type="HBoxContainer" parent="."]

[node name="System" type="Button" parent="HBox"]
size_flags_horizontal = 3
flat = true

[node name="V" type="GridContainer" parent="HBox"]

[node name="Price" type="Label" parent="HBox/V"]
visible = false
text = "UPGRADE_PRICE"

[node name="StickerPrice" type="Label" parent="HBox/V"]
text = "%s E$ (x%d)"

[node name="Installed" type="Label" parent="HBox/V"]
text = "UPGRADE_INSTALLED"

[node name="Replace" type="Label" parent="HBox/V"]
text = "UPGRADE_REPLACE_BUY"

[node name="Refund" type="Label" parent="HBox/V"]
text = "UPGRADE_REPLACE_REFUND"

[node name="NetPrice" type="Label" parent="HBox/V"]
text = "%s E$"

[node name="Buy" type="Button" parent="HBox"]
disabled = true

[node name="Heat" type="Sprite" parent="HBox/Buy"]

[node name="Power" type="Sprite" parent="HBox/Buy"]

[node name="Flicker" type="Node" parent="."]
script = ExtResource( 2 )

[connection signal="visibility_changed" from="." to="." method="_on_SystemShipUpgradeUI_visibility_changed"]
[connection signal="focus_entered" from="HBox/System" to="." method="_on_System_focus_entered"]
[connection signal="pressed" from="HBox/System" to="." method="_on_System_pressed"]
[connection signal="focus_entered" from="HBox/Buy" to="." method="_on_Buy_focus_entered"]
[connection signal="pressed" from="HBox/Buy" to="." method="_on_Buy_pressed"]
'@
# A ship's hardpoint (weapons\WeaponSlot.tscn, which the ship scenes instance inline or as placeholders): the game's
# root, with its script (ships\WeaponSlot.gd) and the values it sets, without the systems' placeholders.
$slotScene = (Get-Content -LiteralPath (Join-Path $GameSource 'weapons\WeaponSlot.tscn') -Raw) -replace "`r`n", "`n"
$slotScript = [regex]::Match($slotScene, '(?m)^\[ext_resource path="res://ships/WeaponSlot\.gd" type="Script" id=(\d+)\]$')
$slotRoot = [regex]::Match($slotScene, '(?ms)^\[node name="WeaponSlot" type="Node2D"\]\n(.*?)(?=^\[)')
if (-not $slotScript.Success -or -not $slotRoot.Success) { throw 'Cannot read the hardpoint from weapons\WeaponSlot.tscn' }
$slotLines = @(foreach ($line in $slotRoot.Groups[1].Value -split "`n")
{
	if ($line -eq "script = ExtResource( $($slotScript.Groups[1].Value) )") { 'script = ExtResource( 1 )' }
	elseif ($line -match '^\w+ = ' -and $line -notmatch 'Resource\(') { $line }
})
if ($slotLines -notcontains 'script = ExtResource( 1 )') { throw 'The hardpoint in weapons\WeaponSlot.tscn has no ships\WeaponSlot.gd' }
New-Item -ItemType Directory -Force (Join-Path $project 'weapons') | Out-Null
Write-Utf8Lf (Join-Path $project 'weapons\WeaponSlot.tscn') ("[gd_scene load_steps=2 format=2]`n`n[ext_resource path=`"res://ships/WeaponSlot.gd`" type=`"Script`" id=1]`n`n[node name=`"WeaponSlot`" type=`"Node2D`"]`n" + ($slotLines -join "`n") + "`n")
# The Dealer screen (enceladus\Dealer.tscn, which enceladus\Enceladus.tscn instances as the station's Dealer and
# enceladus\Owned.tscn as Fleet): the root with the game's script, theme, anchors, size flags and the node paths it sets,
# the Shower, and a node at every path Dealer.gd reads and at their parents (the game's node type, or the root type of
# the scene the game instances there, without that scene's content), with the game's own sizes, margins, size flags,
# themes and frames where its scene sets them (DealerNotifier's settings screen copies the description window); without
# the scripts below the root, the viewports' contents, the texts, the tabs' hints, the simulator's button and the
# sounds. Its entries are a Dealer entry: the Fleet entry above, with the game's tooltip node
# (menu\sfx\PlaySoundsOnTheseButtons.tscn: its script, paths and nodes, without the sounds and theme), as the game's
# SystemBuyUI.tscn has it.
Write-Utf8Lf (Join-Path $project 'harness\dealer_entry.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/SystemBuyUI.tscn" type="PackedScene" id=1]
[ext_resource path="res://menu/sfx/PlaySoundsOnTheseButtons.gd" type="Script" id=2]

[node name="SystemBuyUi" instance=ExtResource( 1 )]

[node name="PlaySoundsOnTheseButtons" type="Node" parent="."]
pause_mode = 2
script = ExtResource( 2 )
tooltipLabelPath = NodePath("Separation/Tooltip/MarginContainer/PanelContainer/TooltipLabel")
tooltipContainerPath = NodePath("Separation/Tooltip/MarginContainer")
tooltipPositionPath = NodePath("Separation/Tooltip")

[node name="focus" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="hover" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="select" type="AudioStreamPlayer" parent="PlaySoundsOnTheseButtons"]

[node name="Separation" type="Node" parent="PlaySoundsOnTheseButtons"]

[node name="Tooltip" type="Node2D" parent="PlaySoundsOnTheseButtons/Separation"]
visible = false

[node name="MarginContainer" type="MarginContainer" parent="PlaySoundsOnTheseButtons/Separation/Tooltip"]
mouse_filter = 2

[node name="PanelContainer" type="PanelContainer" parent="PlaySoundsOnTheseButtons/Separation/Tooltip/MarginContainer"]
mouse_filter = 2

[node name="TooltipLabel" type="Label" parent="PlaySoundsOnTheseButtons/Separation/Tooltip/MarginContainer/PanelContainer"]
'@
$dealerScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Dealer.tscn') -Raw) -replace "`r`n", "`n"
$dealerScript = Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Dealer.gd') -Raw
$stationScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Enceladus.tscn') -Raw) -replace "`r`n", "`n"
$dealerPaths = [ordered]@{}
foreach ($m in [regex]::Matches($dealerScript, '(?m)^export \(NodePath\) var (\w+) = NodePath\("([^"]*)"\)')) { $dealerPaths[$m.Groups[1].Value] = $m.Groups[2].Value }
$dealerRoot = [regex]::Match($dealerScene, '(?ms)^\[node name="Dealer" type="PanelContainer"\]\n(.*?)(?=^\[)')
if ($dealerPaths.Count -eq 0 -or -not $dealerRoot.Success) { throw 'Cannot read the node paths of enceladus\Dealer.gd and enceladus\Dealer.tscn' }
$dealerExt = @{}
foreach ($m in [regex]::Matches($dealerScene, '(?m)^\[ext_resource path="res://([^"]+)" type="(\w+)" id=(\d+)\]$')) { $dealerExt[$m.Groups[3].Value] = @{ Path = $m.Groups[1].Value; Type = $m.Groups[2].Value } }
$dealerSubs = @{}
foreach ($m in [regex]::Matches($dealerScene, '(?ms)^\[sub_resource type="(\w+)" id=(\d+)\]\n(.*?)(?=^\[)')) { $dealerSubs[$m.Groups[2].Value] = "[sub_resource type=`"$($m.Groups[1].Value)`" id=$($m.Groups[2].Value)]`n" + $m.Groups[3].Value.TrimEnd() + "`n" }
# The stub's resources: each game resource it uses once, by its path, numbered in the order they are met.
$stubExt = [ordered]@{}
function Add-DealerExt([string] $Path, [string] $Type)
{
	if (-not (Test-Path -LiteralPath (Join-Path $project $Path.Replace('/', '\')))) { throw "The Dealer screen stub needs res://$Path, which the project lacks" }
	if (-not $stubExt.Contains($Path)) { $stubExt[$Path] = @{ Id = $stubExt.Count + 1; Type = $Type } }
	return $stubExt[$Path].Id
}
$stubSubs = [ordered]@{}
$scriptId = Add-DealerExt 'enceladus/Dealer.gd' 'Script'
$entryId = Add-DealerExt 'harness/dealer_entry.tscn' 'PackedScene'
$showerId = Add-DealerExt 'enceladus/Shower.tscn' 'PackedScene'
# The node's own values, then the script, then the script's: values of a script's variables set before it is are lost.
$rootLines = @()
$rootVars = @()
foreach ($line in $dealerRoot.Groups[1].Value -split "`n")
{
	if ($line -match '^(\w+Path) = NodePath\("([^"]*)"\)$') { $dealerPaths[$Matches[1]] = $Matches[2]; $rootVars += $line }
	elseif ($line -match '^theme = ExtResource\( (\d+) \)$') { $e = $dealerExt[$Matches[1]]; $rootLines += "theme = ExtResource( $(Add-DealerExt $e.Path $e.Type) )" }
	elseif ($line -match '^(anchor_\w+|size_flags_\w+) = ') { $rootLines += $line }
}
# The game's nodes by path, in the scene's order (parents first).
$dealerNodes = [ordered]@{}
foreach ($m in [regex]::Matches($dealerScene, '(?ms)^\[node name="([^"]+)"([^\]]*)\]\n(.*?)(?=^\[|\z)'))
{
	$attrs = $m.Groups[2].Value
	$parent = [regex]::Match($attrs, 'parent="([^"]*)"')
	if (-not $parent.Success) { continue }
	$path = if ($parent.Groups[1].Value -eq '.') { $m.Groups[1].Value } else { $parent.Groups[1].Value + '/' + $m.Groups[1].Value }
	$type = [regex]::Match($attrs, 'type="(\w+)"').Groups[1].Value
	$instance = [regex]::Match($attrs, 'instance=ExtResource\( (\d+) \)')
	if (-not $type -and $instance.Success)
	{
		$sub = Get-Content -LiteralPath (Join-Path $GameSource $dealerExt[$instance.Groups[1].Value].Path.Replace('/', '\')) -Raw
		$type = [regex]::Match($sub, '(?m)^\[node name="[^"]+" type="(\w+)"\]').Groups[1].Value
	}
	$dealerNodes[$path] = @{ Name = $m.Groups[1].Value; Parent = $parent.Groups[1].Value; Type = $type; Body = $m.Groups[3].Value }
}
$neededNodes = [Collections.Generic.HashSet[string]]::new()
foreach ($p in $dealerPaths.Values)
{
	if (-not $dealerNodes.Contains($p)) { throw "enceladus\Dealer.tscn has no node at $p, which Dealer.gd reads" }
	$parts = $p.Split('/')
	for ($i = 1; $i -le $parts.Count; $i++) { $null = $neededNodes.Add(($parts[0..($i - 1)] -join '/')) }
}
$dealerNodeText = foreach ($p in $dealerNodes.Keys)
{
	if (-not $neededNodes.Contains($p)) { continue }
	$n = $dealerNodes[$p]
	if (-not $n.Type) { throw "enceladus\Dealer.tscn: no node type for $p" }
	$lines = @("[node name=`"$($n.Name)`" type=`"$($n.Type)`" parent=`"$($n.Parent)`"]")
	foreach ($line in $n.Body -split "`n")
	{
		if ($line -match '^(theme|custom_styles/panel) = ExtResource\( (\d+) \)$') { $e = $dealerExt[$Matches[2]]; $lines += "$($Matches[1]) = ExtResource( $(Add-DealerExt $e.Path $e.Type) )" }
		elseif ($line -match '^custom_styles/panel = SubResource\( (\d+) \)$') { $stubSubs[$Matches[1]] = $dealerSubs[$Matches[1]]; $lines += $line }
		elseif ($line -match '^(custom_constants/\w+|rect_min_size|rect_clip_content|size_flags_\w+|autowrap|columns) = ') { $lines += $line }
	}
	($lines -join "`n") + "`n"
}
$dealerStub = "[gd_scene load_steps=$(1 + $stubExt.Count + $stubSubs.Count) format=2]`n`n"
$dealerStub += (($stubExt.Keys | ForEach-Object { "[ext_resource path=`"res://$_`" type=`"$($stubExt[$_].Type)`" id=$($stubExt[$_].Id)]" }) -join "`n") + "`n`n"
if ($stubSubs.Count -gt 0) { $dealerStub += ($stubSubs.Values -join "`n") + "`n" }
$dealerStub += "[node name=`"Dealer`" type=`"PanelContainer`"]`n" + (@($rootLines) + "script = ExtResource( $scriptId )" + @($rootVars) + "shipLineBlueprint = ExtResource( $entryId )" -join "`n") + "`n`n"
$dealerStub += "[node name=`"Shower`" parent=`".`" instance=ExtResource( $showerId )]`n`n"
$dealerStub += $dealerNodeText -join "`n"
Write-Utf8Lf (Join-Path $project 'enceladus\Dealer.tscn') $dealerStub
# Fleet (enceladus\Owned.tscn): the Dealer screen stub with the game's values for it (which lists it shows). The
# station's Dealer and Fleet (their nodes in enceladus\Enceladus.tscn, harness\station_dealer.tscn and
# station_owned.tscn): those stubs with the station's values for them (size, size flags, frame, lists).
$ownedScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Owned.tscn') -Raw) -replace "`r`n", "`n"
$ownedRoot = [regex]::Match($ownedScene, '(?ms)^\[node name="Owned" instance=ExtResource\( \d+ \)\]\n(.*?)(?=^\[)')
$ownedLines = @(if ($ownedRoot.Success) { $ownedRoot.Groups[1].Value -split "`n" | Where-Object { $_ -match '^show\w+ = ' } })
if ($ownedLines.Count -eq 0) { throw 'Cannot read which lists enceladus\Owned.tscn shows' }
Write-Utf8Lf (Join-Path $project 'enceladus\Owned.tscn') ("[gd_scene load_steps=2 format=2]`n`n[ext_resource path=`"res://enceladus/Dealer.tscn`" type=`"PackedScene`" id=1]`n`n[node name=`"Owned`" instance=ExtResource( 1 )]`n" + ($ownedLines -join "`n") + "`n")
$stationExt = @{}
foreach ($m in [regex]::Matches($stationScene, '(?m)^\[ext_resource path="res://([^"]+)" type="(\w+)" id=(\d+)\]$')) { $stationExt[$m.Groups[3].Value] = @{ Path = $m.Groups[1].Value; Type = $m.Groups[2].Value } }
foreach ($screen in @(@('Dealer', 'enceladus/Dealer.tscn', 'station_dealer'), @('Owned', 'enceladus/Owned.tscn', 'station_owned')))
{
	$block = [regex]::Match($stationScene, '(?ms)^\[node name="' + $screen[0] + '" parent="EnceladusMenu/MenuContainer/MarginContainer/CanvasLayer/MarginContainer" instance=ExtResource\( \d+ \)\]\n(.*?)(?=^\[)')
	if (-not $block.Success) { throw "Cannot read the $($screen[0]) screen from enceladus\Enceladus.tscn" }
	$stationLines = @()
	$stationRes = @("[ext_resource path=`"res://$($screen[1])`" type=`"PackedScene`" id=1]")
	foreach ($line in $block.Groups[1].Value -split "`n")
	{
		if ($line -match '^custom_styles/panel = ExtResource\( (\d+) \)$')
		{
			$e = $stationExt[$Matches[1]]
			if (-not (Test-Path -LiteralPath (Join-Path $project $e.Path.Replace('/', '\')))) { throw "The station's $($screen[0]) needs res://$($e.Path), which the project lacks" }
			$stationRes += "[ext_resource path=`"res://$($e.Path)`" type=`"$($e.Type)`" id=2]"
			$stationLines += 'custom_styles/panel = ExtResource( 2 )'
		}
		elseif ($line -match '^(rect_min_size|size_flags_\w+|show\w+) = ') { $stationLines += $line }
	}
	Write-Utf8Lf (Join-Path $project "harness\$($screen[2]).tscn") ("[gd_scene load_steps=$(1 + $stationRes.Count) format=2]`n`n" + ($stationRes -join "`n") + "`n`n[node name=`"$($screen[0])`" instance=ExtResource( 1 )]`n" + ($stationLines -join "`n") + "`n")
}
# The ring scene (Game.tscn, as enceladus\Enceladus.gd loads it): the game's root node with its script and values
# (totalCutsceneTime, initialCutsceneTime), the title card player with the game's autoplay, process mode and the
# "intro", "exit", "helpless", "gameover" and "fasttravel" animations, a node at every path those drive (the game's node
# type where the scene declares one; the Transponder label with its script, TransponderOnIntro.gd, whose
# copyTransponder "intro" calls), and the asteroid field the ship is added to, a stub that records the
# despawnAllAsteroids "exit" calls and the rescue ship's spawn (harness\skip_field.gd); without the asteroids, the HUD
# layers, the music and the demo's ending. The method keys on the root call Game.gd's own.
$gameScene = (Get-Content -LiteralPath (Join-Path $GameSource 'Game.tscn') -Raw) -replace "`r`n", "`n"
$rootBlock = [regex]::Match($gameScene, '(?ms)^\[node name="Game" type="Node"\]\n(.*?)(?=^\[)')
$titleBlock = [regex]::Match($gameScene, '(?ms)^\[node name="TitleAnimPlayer" type="AnimationPlayer" parent="\."\]\n(.*?)(?=^\[)')
if (-not $rootBlock.Success -or -not $titleBlock.Success) { throw 'Cannot read the ring scene from Game.tscn' }
$cardAnims = [ordered]@{}
foreach ($animName in 'intro', 'exit', 'helpless', 'gameover', 'fasttravel')
{
	$animId = [regex]::Match($titleBlock.Groups[1].Value, '(?m)^anims/' + $animName + ' = SubResource\( (\d+) \)$')
	$anim = [regex]::Match($gameScene, '(?ms)^\[sub_resource type="Animation" id=' + $animId.Groups[1].Value + '\]\n(.*?)(?=^\[)')
	if (-not $animId.Success -or -not $anim.Success) { throw "Cannot read the `"$animName`" animation from Game.tscn" }
	$cardAnims[$animName] = $anim.Groups[1].Value
}
$rootValues = @($rootBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^\w+ = ' -and $_ -notmatch '^script = ' })
$titleValues = @($titleBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^(autoplay|playback_process_mode) = ' })
$gameTypes = @{}
foreach ($m in [regex]::Matches($gameScene, '(?m)^\[node name="([^"]+)" type="(\w+)" parent="([^"]+)"'))
{
	$path = if ($m.Groups[3].Value -eq '.') { $m.Groups[1].Value } else { $m.Groups[3].Value + '/' + $m.Groups[1].Value }
	$gameTypes[$path] = $m.Groups[2].Value
}
$driven = @{}
$transponder = $null
foreach ($animName in $cardAnims.Keys)
{
	$body = $cardAnims[$animName]
	foreach ($t in [regex]::Matches($body, '(?m)^tracks/(\d+)/type = "(\w+)"$'))
	{
		$n = $t.Groups[1].Value
		$nodePath, $property = [regex]::Match($body, '(?m)^tracks/' + $n + '/path = NodePath\("([^"]*)"\)$').Groups[1].Value.Split(':', 2)
		$methods = @()
		if ($t.Groups[2].Value -eq 'method')
		{
			$keys = [regex]::Match($body, '(?ms)^tracks/' + $n + '/keys = \{(.*?)^\}').Groups[1].Value
			$methods = @([regex]::Matches($keys, '"method": "(\w+)"') | ForEach-Object { $_.Groups[1].Value })
		}
		if ($nodePath -eq '.') { continue }
		if ($nodePath -eq 'AsteroidField')
		{
			if (@($methods | Where-Object { $_ -ne 'despawnAllAsteroids' }).Count -gt 0) { throw "Game.tscn's $animName calls $methods on AsteroidField: give harness\skip_field.gd those" }
			continue
		}
		if (-not $nodePath.StartsWith('TitleAnimPlayer/')) { throw "Game.tscn's $animName drives $nodePath, outside TitleAnimPlayer: add that node to the stub" }
		if (-not $driven.ContainsKey($nodePath)) { $driven[$nodePath] = [Collections.Generic.List[string]]::new() }
		if ($property) { $driven[$nodePath].Add($property) }
		foreach ($method in $methods)
		{
			if ($method -ne 'copyTransponder') { throw "Game.tscn's $animName calls $method on ${nodePath}: give its node a script that has it" }
			$transponder = $nodePath
		}
	}
}
# Every node on those paths, parents first (a path sorts before the paths it is a prefix of).
$cardNodes = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($p in $driven.Keys)
{
	$parts = $p.Split('/')
	for ($i = 2; $i -le $parts.Count; $i++) { $null = $cardNodes.Add(($parts[0..($i - 1)] -join '/')) }
}
$nodeText = foreach ($p in $cardNodes)
{
	$slash = $p.LastIndexOf('/')
	$props = if ($driven.ContainsKey($p)) { $driven[$p] } else { @() }
	if ($p -eq $transponder) { $type = 'Label' }
	elseif ($gameTypes.ContainsKey($p)) { $type = $gameTypes[$p] }
	elseif ($props -contains 'color') { $type = 'ColorRect' }
	elseif ($props -contains 'percent_visible') { $type = 'Label' }
	else { $type = 'Control' }
	$line = '[node name="' + $p.Substring($slash + 1) + '" type="' + $type + '" parent="' + $p.Substring(0, $slash) + '"]'
	if ($p -eq $transponder) { $line += "`nscript = ExtResource( 2 )" }
	$line + "`n"
}
$subResources = @()
$animLines = @()
$subId = 0
foreach ($animName in $cardAnims.Keys)
{
	$subId++
	$subResources += "[sub_resource type=`"Animation`" id=$subId]`n" + $cardAnims[$animName].TrimEnd() + "`n"
	$animLines += "anims/$animName = SubResource( $subId )"
}
# CombatSimulator's arena reads two more things from the scene's state: the masks the scene gives its asteroid field,
# and the fade time it gives its cursor layer (an instance of menu\MouseLayer.tscn; here a CanvasLayer with the game's
# menu\MouseLayer.gd). skip_field.gd has no masks, so instancing drops them (a value for a property a node lacks is
# ignored); the state keeps them.
$fieldBlock = [regex]::Match($gameScene, '(?ms)^\[node name="AsteroidField" parent="\." instance=ExtResource\( \d+ \)\]\n(.*?)(?=^\[)')
$fieldMasks = @($fieldBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^\w+IntersectionTest = ' })
$mouseBlock = [regex]::Match($gameScene, '(?ms)^\[node name="MouseLayer" parent="\." instance=ExtResource\( \d+ \)\]\n(.*?)(?=^\[)')
$mouseFade = @($mouseBlock.Groups[1].Value -split "`n" | Where-Object { $_ -match '^fadeTime = ' })
if ($fieldMasks.Count -ne 2 -or $mouseFade.Count -ne 1) { throw "Cannot read the asteroid field's masks and the cursor's fade time from Game.tscn" }
$ringScene = @"
[gd_scene load_steps=$(5 + $subId) format=2]

[ext_resource path="res://Game.gd" type="Script" id=1]
[ext_resource path="res://TransponderOnIntro.gd" type="Script" id=2]
[ext_resource path="res://harness/skip_field.gd" type="Script" id=3]
[ext_resource path="res://menu/MouseLayer.gd" type="Script" id=4]

$($subResources -join "`n")
[node name="Game" type="Node"]
script = ExtResource( 1 )
$($rootValues -join "`n")

[node name="TitleAnimPlayer" type="AnimationPlayer" parent="."]
$($titleValues -join "`n")
$($animLines -join "`n")

$($nodeText -join "`n")
[node name="AsteroidField" type="Node2D" parent="."]
script = ExtResource( 3 )
$($fieldMasks -join "`n")

[node name="MouseLayer" type="CanvasLayer" parent="."]
script = ExtResource( 4 )
$($mouseFade -join "`n")
"@
Write-Utf8Lf (Join-Path $project 'Game.tscn') $ringScene
# The station's fade-in on arrival (enceladus\Enceladus.tscn: the root AnimationPlayer's "FadeInCRT"), as an Animation
# resource of its own; the skip suite drops the tracks whose nodes its station doesn't have.
$stationScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Enceladus.tscn') -Raw) -replace "`r`n", "`n"
$stationPlayer = [regex]::Match($stationScene, '(?ms)^\[node name="AnimationPlayer" type="AnimationPlayer" parent="\."\]\n(.*?)(?=^\[)')
$fadeId = [regex]::Match($stationPlayer.Groups[1].Value, '(?m)^anims/FadeInCRT = SubResource\( (\d+) \)$')
$fade = [regex]::Match($stationScene, '(?ms)^\[sub_resource type="Animation" id=' + $fadeId.Groups[1].Value + '\]\n(.*?)(?=^\[)')
if (-not $stationPlayer.Success -or -not $fadeId.Success -or -not $fade.Success) { throw 'Cannot read the "FadeInCRT" animation from enceladus\Enceladus.tscn' }
Write-Utf8Lf (Join-Path $project 'harness\station_fadein.tres') ("[gd_resource type=`"Animation`" format=2]`n`n[resource]`n" + $fade.Groups[1].Value.TrimEnd() + "`n")
# What CombatSimulator loads and builds (the combat suite). The simulator's button (enceladus\Simulator\LaunchVRButton.tscn,
# which every screen with one instances, and by whose path the mod finds them): the game's root, with its theme, its
# shortcut (the jury_rig action) and its values, without the key hint under it.
$vrScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Simulator\LaunchVRButton.tscn') -Raw) -replace "`r`n", "`n"
$vrTheme = [regex]::Match($vrScene, '(?m)^\[ext_resource path="res://menu/MenuTheme\.tres" type="Theme" id=\d+\]$')
$vrSubs = @([regex]::Matches($vrScene, '(?ms)^\[sub_resource type="\w+" id=\d+\]\n.*?(?=^\[)') | ForEach-Object { $_.Value.TrimEnd() + "`n" })
$vrRoot = [regex]::Match($vrScene, '(?ms)^\[node name="LaunchVR" type="Button"\]\n(.*?)(?=^\[|\z)')
if (-not $vrTheme.Success -or $vrSubs.Count -eq 0 -or -not $vrRoot.Success -or $vrRoot.Groups[1].Value -notmatch '(?m)^shortcut = SubResource') { throw 'Cannot read the simulator button from enceladus\Simulator\LaunchVRButton.tscn' }
$vrLines = @($vrRoot.Groups[1].Value -split "`n" | Where-Object { $_ -match '^\w+ = ' })
New-Item -ItemType Directory -Force (Join-Path $project 'enceladus\Simulator') | Out-Null
Write-Utf8Lf (Join-Path $project 'enceladus\Simulator\LaunchVRButton.tscn') ("[gd_scene load_steps=$(2 + $vrSubs.Count) format=2]`n`n" + $vrTheme.Value + "`n`n" + ($vrSubs -join "`n") + "`n[node name=`"LaunchVR`" type=`"Button`"]`n" + ($vrLines -join "`n") + "`n")
# The ring scene's parts the arena instances in its viewport: the asteroid field (AsteroidField.tscn, a stub,
# harness\combat_field.gd), BulletTimer (BulletTimer.tscn: a stub root, harness\combat_bullet_timer.gd, and the
# notifications layer the arena removes), the music (music\Music.tscn: the root, with the game's pause mode) and
# WESpace.tscn (a bare WorldEnvironment). A ship scene under ships\ (ships\CombatTestShip.tscn, harness\combat_ship.gd,
# in the ships group as the game's ship scenes are; without gravity, as the game's world has none): CombatSimulator
# offers only the models whose scene is there. The pirate event the arena builds a TRTL with (story\PirateCombat.gd,
# harness\combat_pirate.gd: the game's preloads its loot), and the projectile massdriver.gd preloads (a bare node).
$musicScene = (Get-Content -LiteralPath (Join-Path $GameSource 'music\Music.tscn') -Raw) -replace "`r`n", "`n"
$musicPause = [regex]::Match($musicScene, '(?ms)^\[node name="Music" type="Node"\]\n[^\[]*?^(pause_mode = \d+)$')
if (-not $musicPause.Success) { throw 'Cannot read the pause mode of music\Music.tscn' }
New-Item -ItemType Directory -Force (Join-Path $project 'music'), (Join-Path $project 'weapons\projectiles') | Out-Null
Write-Utf8Lf (Join-Path $project 'AsteroidField.tscn') "[gd_scene load_steps=2 format=2]`n`n[ext_resource path=`"res://harness/combat_field.gd`" type=`"Script`" id=1]`n`n[node name=`"AsteroidField`" type=`"Node2D`"]`nscript = ExtResource( 1 )`n"
Write-Utf8Lf (Join-Path $project 'BulletTimer.tscn') "[gd_scene load_steps=2 format=2]`n`n[ext_resource path=`"res://harness/combat_bullet_timer.gd`" type=`"Script`" id=1]`n`n[node name=`"BulletTimer`" type=`"Node`"]`nscript = ExtResource( 1 )`n`n[node name=`"NotificationsLayer`" type=`"CanvasLayer`" parent=`".`"]`n"
Write-Utf8Lf (Join-Path $project 'music\Music.tscn') "[gd_scene format=2]`n`n[node name=`"Music`" type=`"Node`"]`n$($musicPause.Groups[1].Value)`n"
Write-Utf8Lf (Join-Path $project 'WESpace.tscn') "[gd_scene format=2]`n`n[node name=`"WESpace`" type=`"WorldEnvironment`"]`n"
Write-Utf8Lf (Join-Path $project 'ships\CombatTestShip.tscn') "[gd_scene load_steps=2 format=2]`n`n[ext_resource path=`"res://harness/combat_ship.gd`" type=`"Script`" id=1]`n`n[node name=`"CombatTestShip`" type=`"RigidBody2D`" groups=[`"ships`"]]`ngravity_scale = 0.0`nscript = ExtResource( 1 )`nshipName = `"SHIP_TEST_COMBAT`"`n"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'harness\combat_pirate.gd') -Destination (Join-Path $project 'story\PirateCombat.gd')
Write-Utf8Lf (Join-Path $project 'weapons\projectiles\massdriverProjectile.tscn') "[gd_scene format=2]`n`n[node name=`"massdriverProjectile`" type=`"Node2D`"]`n"
# The game's tooltip node (menu\sfx\PlaySoundsOnTheseButtons.tscn), which CombatSimulator instances to show its
# buttons' tooltip: the game's script, paths and nodes, without the sounds and theme (as the Hire and Dealer entries'
# stubs have it inline).
Write-Utf8Lf (Join-Path $project 'menu\sfx\PlaySoundsOnTheseButtons.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://menu/sfx/PlaySoundsOnTheseButtons.gd" type="Script" id=1]

[node name="PlaySoundsOnTheseButtons" type="Node"]
pause_mode = 2
script = ExtResource( 1 )
tooltipLabelPath = NodePath("Separation/Tooltip/MarginContainer/PanelContainer/TooltipLabel")
tooltipContainerPath = NodePath("Separation/Tooltip/MarginContainer")
tooltipPositionPath = NodePath("Separation/Tooltip")

[node name="focus" type="AudioStreamPlayer" parent="."]

[node name="hover" type="AudioStreamPlayer" parent="."]

[node name="select" type="AudioStreamPlayer" parent="."]

[node name="Separation" type="Node" parent="."]

[node name="Tooltip" type="Node2D" parent="Separation"]
visible = false

[node name="MarginContainer" type="MarginContainer" parent="Separation/Tooltip"]
mouse_filter = 2

[node name="PanelContainer" type="PanelContainer" parent="Separation/Tooltip/MarginContainer"]
mouse_filter = 2

[node name="TooltipLabel" type="Label" parent="Separation/Tooltip/MarginContainer/PanelContainer"]
'@
# TheRing.gd preloads the ring's maps (ring\ring-map.png: chaos in red, size bias in green and density in blue, a pixel
# per km; ring\ring-veins.png), and CombatSimulator's CombatMap.gd extends it. The game's map is a 4 MB lossy texture;
# here each is a small ImageTexture in a text resource that the PNG's .import file points to, so it loads without an
# import step, as an imported texture does. The map's red grows across it (the depth), its blue down it (the way around
# the ring), and its green changes from pixel to pixel; the veins are a pattern. The combat suite reads what they hold.
function Write-StandInTexture([string] $Png, [int] $Width, [int] $Height, [scriptblock] $Pixel)
{
	$bytes = [Collections.Generic.List[string]]::new()
	for ($y = 0; $y -lt $Height; $y++)
	{
		for ($x = 0; $x -lt $Width; $x++) { foreach ($b in (& $Pixel $x $y)) { $bytes.Add([string]$b) } }
	}
	$tres = $Png -replace '\.png$', '.tres'
	Write-Utf8Lf (Join-Path $project $tres) "[gd_resource type=`"ImageTexture`" load_steps=2 format=2]`n`n[sub_resource type=`"Image`" id=1]`ndata = {`n`"data`": PoolByteArray( $($bytes -join ', ') ),`n`"format`": `"RGBA8`",`n`"height`": $Height,`n`"mipmaps`": false,`n`"width`": $Width`n}`n`n[resource]`nflags = 0`nimage = SubResource( 1 )`nsize = Vector2( $Width, $Height )`n"
	Write-Utf8Lf (Join-Path $project "$Png.import") "[remap]`n`nimporter=`"texture`"`ntype=`"StreamTexture`"`npath=`"res://$($tres.Replace('\', '/'))`"`n"
}
New-Item -ItemType Directory -Force (Join-Path $project 'ring') | Out-Null
Write-StandInTexture 'ring\ring-map.png' 64 48 { param($x, $y) @(($x * 4), (($x * 37 + $y * 53) % 256), ($y * 5), 255) }
Write-StandInTexture 'ring\ring-veins.png' 8 8 { param($x, $y) @((($x * 32) % 256), (($y * 32) % 256), ((($x + $y) * 16) % 256), 255) }
# For MarketAdvisor: the Mineral Market (enceladus\MineralMarket.tscn, with the header above), a slider row
# (enceladus\MineralSellSlider.tscn, as MineralMarket.gd instances one per mineral), its price chart
# (enceladus\Minerals\MineralPriceChart.tscn) and the chart's labels (MarketChartPrice.tscn): the game's node paths,
# scripts, values and connections, with the menu theme on the market (MarketAdvisor's settings screen copies it), and
# without the fonts, sounds, smooth scrolling and the label's animation. For MarketAdvisor and ServiceNotifier: a row
# of the Services screen (enceladus\ServiceUI.tscn), its insurance row (ServiceUIInsurance.tscn) and its compensation
# row (ServiceUIFactionChange.tscn): the game's node paths, scripts, texts and connections, without the theme, icons,
# sounds and flicker.
Write-Utf8Lf (Join-Path $project 'enceladus\MineralMarket.tscn') @'
[gd_scene load_steps=5 format=2]

[ext_resource path="res://menu/MenuTheme.tres" type="Theme" id=1]
[ext_resource path="res://enceladus/MineralMarket.gd" type="Script" id=2]
[ext_resource path="res://enceladus/HeaderWithMoney.tscn" type="PackedScene" id=3]
[ext_resource path="res://enceladus/Shower.tscn" type="PackedScene" id=4]

[node name="MineralMarket" type="PanelContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme = ExtResource( 1 )
script = ExtResource( 2 )

[node name="Details" type="VBoxContainer" parent="."]
grow_horizontal = 2
grow_vertical = 0
rect_min_size = Vector2( 256, 0 )
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="HeaderWithMoney" parent="Details" instance=ExtResource( 3 )]

[node name="MarketLabel" parent="Details/HeaderWithMoney" index="0"]
text = "ENCELADUS_MINERAL_MARKET"

[node name="MarginContainer" type="MarginContainer" parent="Details"]
size_flags_horizontal = 3
size_flags_vertical = 3
custom_constants/margin_right = -16
custom_constants/margin_top = 16
custom_constants/margin_bottom = 0

[node name="ScrollContainer" type="ScrollContainer" parent="Details/MarginContainer"]
size_flags_horizontal = 3
size_flags_vertical = 3
scroll_horizontal_enabled = false

[node name="MarginContainer" type="MarginContainer" parent="Details/MarginContainer/ScrollContainer"]
size_flags_horizontal = 3
custom_constants/margin_right = 8

[node name="Market" type="VBoxContainer" parent="Details/MarginContainer/ScrollContainer/MarginContainer"]
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Shower" parent="." instance=ExtResource( 4 )]

[editable path="Details/HeaderWithMoney"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\MineralSellSlider.tscn') @'
[gd_scene load_steps=4 format=2]

[ext_resource path="res://enceladus/MineralSellSlider.gd" type="Script" id=1]
[ext_resource path="res://enceladus/Minerals/MineralPriceChart.tscn" type="PackedScene" id=2]
[ext_resource path="res://enceladus/AnalogControlSlider.gd" type="Script" id=3]

[node name="MineralSellSlider" type="MarginContainer"]
anchor_right = 1.0
margin_bottom = 87.0
script = ExtResource( 1 )
format = "%.2f E$/t"

[node name="VBoxContainer" type="VBoxContainer" parent="."]
size_flags_horizontal = 3

[node name="MarginContainer" type="MarginContainer" parent="VBoxContainer"]
custom_constants/margin_bottom = 13

[node name="HBoxContainer" type="HBoxContainer" parent="VBoxContainer/MarginContainer"]
size_flags_horizontal = 3
size_flags_vertical = 8
custom_constants/separation = 16
alignment = 1

[node name="Mineral" type="Label" parent="VBoxContainer/MarginContainer/HBoxContainer"]
size_flags_horizontal = 3
text = "Fe"

[node name="H" type="HBoxContainer" parent="VBoxContainer/MarginContainer/HBoxContainer"]
size_flags_horizontal = 5
alignment = 1

[node name="Owned" type="Label" parent="VBoxContainer/MarginContainer/HBoxContainer/H"]
size_flags_horizontal = 3
text = "0"
align = 2

[node name="Dot" type="Label" parent="VBoxContainer/MarginContainer/HBoxContainer/H"]
self_modulate = Color( 1, 1, 1, 0.498039 )
size_flags_horizontal = 4
text = "."
align = 1

[node name="Reminder" type="Label" parent="VBoxContainer/MarginContainer/HBoxContainer/H"]
self_modulate = Color( 1, 1, 1, 0.498039 )
size_flags_horizontal = 3
text = "000"

[node name="Price" type="Label" parent="VBoxContainer/MarginContainer/HBoxContainer"]
size_flags_horizontal = 3
text = "0 E$/t"
align = 2

[node name="Chart" parent="VBoxContainer/MarginContainer" instance=ExtResource( 2 )]
show_behind_parent = true
time = 24
lookAhead = 4608

[node name="HSlider" type="HSlider" parent="VBoxContainer"]
hint_tooltip = "TOOLTIP_SELL_SLIDE"
scrollable = false
tick_count = 20
ticks_on_borders = true
script = ExtResource( 3 )

[node name="HBoxContainer2" type="HBoxContainer" parent="VBoxContainer"]
size_flags_horizontal = 3
custom_constants/separation = 16
alignment = 1

[node name="Min" type="Label" parent="VBoxContainer/HBoxContainer2"]
size_flags_horizontal = 3
text = "0"

[node name="Max" type="Label" parent="VBoxContainer/HBoxContainer2"]
size_flags_horizontal = 3
text = "0"
align = 2

[connection signal="visibility_changed" from="." to="." method="_on_MineralSellSlider_visibility_changed"]
[connection signal="value_changed" from="VBoxContainer/HSlider" to="." method="_on_HSlider_value_changed"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\Minerals\MineralPriceChart.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/MineralPriceChart.gd" type="Script" id=1]
[ext_resource path="res://enceladus/Minerals/MarketChartPrice.tscn" type="PackedScene" id=2]

[node name="Chart" type="TextureRect"]
rect_min_size = Vector2( 0, 64 )
size_flags_horizontal = 3
size_flags_vertical = 3
expand = true
stretch_mode = 1
script = ExtResource( 1 )
updateSeconds = 6
Text = ExtResource( 2 )
normal = 0.8
evenMonthHighlight = 1.5

[connection signal="visibility_changed" from="." to="." method="_on_Chart_visibility_changed"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\Minerals\MarketChartPrice.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://enceladus/Minerals/MarketChartPrice.gd" type="Script" id=1]

[node name="Price" type="Node2D"]
self_modulate = Color( 5, 5, 5, 1 )
script = ExtResource( 1 )

[node name="Label" type="Label" parent="."]
margin_left = -61.0
margin_top = -10.0
size_flags_horizontal = 4

[node name="AnimationPlayer" type="AnimationPlayer" parent="Label"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\ServiceUI.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://enceladus/ServiceUI.gd" type="Script" id=1]

[node name="ServiceUI" type="MarginContainer"]
script = ExtResource( 1 )

[node name="HBox" type="HBoxContainer" parent="."]

[node name="Service" type="Button" parent="HBox"]
text = "SERVICE_NAME"

[node name="V" type="VBoxContainer" parent="HBox"]

[node name="Price" type="Label" parent="HBox/V"]
text = "%s E$"

[node name="Cooldown" type="Label" parent="HBox/V"]
text = "SERVICE_IN_COOLDOWN"

[node name="Time" type="Label" parent="HBox/V"]
text = "3d 0h"

[node name="Buy" type="Button" parent="HBox"]

[connection signal="visibility_changed" from="." to="." method="_on_ServiceUI_visibility_changed"]
[connection signal="focus_entered" from="HBox/Service" to="." method="_on_Service_focus_entered"]
[connection signal="pressed" from="HBox/Service" to="." method="_on_Service_pressed"]
[connection signal="focus_entered" from="HBox/Buy" to="." method="_on_Buy_focus_entered"]
[connection signal="pressed" from="HBox/Buy" to="." method="_on_Buy_pressed"]
'@
Write-Utf8Lf (Join-Path $project 'enceladus\ServiceUIInsurance.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/ServiceUI.tscn" type="PackedScene" id=1]
[ext_resource path="res://enceladus/ServiceUIInsurance.gd" type="Script" id=2]

[node name="ServiceUIInsurance" instance=ExtResource( 1 )]
script = ExtResource( 2 )

[node name="Service" parent="HBox" index="0"]
text = ""
'@
Write-Utf8Lf (Join-Path $project 'enceladus\ServiceUIFactionChange.tscn') @'
[gd_scene load_steps=3 format=2]

[ext_resource path="res://enceladus/ServiceUI.tscn" type="PackedScene" id=1]
[ext_resource path="res://enceladus/ServiceUIFactionChange.gd" type="Script" id=2]

[node name="ServiceUIFactionChange" instance=ExtResource( 1 )]
script = ExtResource( 2 )

[node name="Service" parent="HBox" index="0"]
text = ""
'@
# For ShipRepairAdvisor: the game's Repairs screen (enceladus\Repairs.tscn) without the sound of its insurance row's
# Pinger, which would need an import step; its rows (SystemShipRepairUI.tscn and the SpecificDamageLabel.tscn they make,
# copied above) instance three helper scenes, and the screen a fourth: bare nodes here, the smooth scrolling with the
# focusAt the rows set on it and the scrollWhenEntering the comms line sets (SmoothScrollTo.tscn), the maintenance line
# with the game's key (MaintainenceLabel.tscn).
$repairsScene = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\Repairs.tscn') -Raw) -replace "`r`n", "`n"
$pingerSound = [regex]::Match($repairsScene, '(?m)^\[ext_resource path="res://menu/sfx/hover\.wav" type="AudioStream" id=(\d+)\]\n')
if (-not $pingerSound.Success -or -not $repairsScene.Contains("stream = ExtResource( $($pingerSound.Groups[1].Value) )`n"))
{
	throw 'Cannot find the Pinger''s sound in enceladus\Repairs.tscn'
}
$repairsScene = $repairsScene.Replace($pingerSound.Value, '').Replace("stream = ExtResource( $($pingerSound.Groups[1].Value) )`n", '')
Write-Utf8Lf (Join-Path $project 'enceladus\Repairs.tscn') $repairsScene
Write-Utf8Lf (Join-Path $project 'SmoothScrollTo.tscn') @'
[gd_scene load_steps=2 format=2]

[sub_resource type="GDScript" id=1]
script/source = "extends Node
export var scrollWhenEntering = false
export var focusAt = NodePath()
"

[node name="SmoothScrollTo" type="Node"]
script = SubResource( 1 )
'@
foreach ($scene in 'enceladus\Flicker', 'menu\MoveScrollerToMatchThese')
{
	Write-Utf8Lf (Join-Path $project "$scene.tscn") @"
[gd_scene format=2]

[node name="$(Split-Path $scene -Leaf)" type="Node"]
"@
}
Write-Utf8Lf (Join-Path $project 'enceladus\MaintainenceLabel.tscn') @'
[gd_scene format=2]

[node name="MaintainenceLabel" type="Label"]
text = "INSPECTION_MAINT"
'@
# For LidarContactCallout: the game's comms line (comms\MessageLine.tscn, with its MessageLine.gd and its animation
# player's Player.gd, copied above, its theme and its light, control hint icon and incoming sound) and the conversation
# the mod gives it (comms\ConversationPlayer.gd, copied above). Bare stubs of the three scenes the line instances: the
# reply line (never made: a callout has no replies), the speaker's face (faces\FaceSprite.tscn: the fullName and gender
# MessageLine.gd sets, and the nodes the line's scene edits), and the control hint
# (hud\components\ContextSensitiveControlDisplay.tscn: the members and the nodes the line's scene sets).
New-Item -ItemType Directory -Force (Join-Path $project 'faces') | Out-Null
Write-Utf8Lf (Join-Path $project 'comms\PlayerReply.tscn') @'
[gd_scene format=2]

[node name="PlayerReply" type="VBoxContainer"]
'@
Write-Utf8Lf (Join-Path $project 'faces\FaceSprite.tscn') @'
[gd_scene load_steps=2 format=2]

[sub_resource type="GDScript" id=1]
script/source = "extends Node2D
export var gender = 0.5
export var fullName = ''
"

[node name="Face" type="Node2D"]
script = SubResource( 1 )

[node name="Sprite" type="Sprite" parent="."]

[node name="Main light" type="Light2D" parent="."]

[node name="Side light" type="Light2D" parent="."]

[node name="Rim light" type="Light2D" parent="."]
'@
Write-Utf8Lf (Join-Path $project 'hud\components\ContextSensitiveControlDisplay.tscn') @'
[gd_scene load_steps=2 format=2]

[sub_resource type="GDScript" id=1]
script/source = "extends MarginContainer
export var action = ''
export var tutorial = false
"

[node name="ContextSensitiveControlDisplay" type="MarginContainer"]
script = SubResource( 1 )

[node name="Player" type="AnimationPlayer" parent="."]

[node name="Keys" type="HBoxContainer" parent="."]

[node name="CenterContainer" type="CenterContainer" parent="."]

[node name="C" type="Control" parent="CenterContainer"]
'@

# 2. The mods: each suite's own (or -Mods), packaged once each, or the release zip given for it.
$suiteMods = @{
	units = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	still = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	moving = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	hold = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	dive = @('DiveDisableAdrenalineBooster')
	boot = @('BootSkipLogos')
	lidar = @('LidarLouderPing')
	hud = @('HudHideLabels')
	crew = @('CrewCheapHireNotifier')
	geology = @('GeologyByMass')
	fleet = @('ShipCopyPaste')
	skip = @('DiveSkipTransit')
	dealer = @('DealerNotifier')
	transponder = @('TransponderAltCodes')
	combat = @('CombatSimulator')
	drones = @('DroneAltPriorities', 'GeologyByMass')
	market = @('MarketAdvisor')
	services = @('ServiceNotifier')
	sale = @('ShipCopyPaste', 'ShipSaleAdvisor')
	repairs = @('ShipRepairAdvisor')
	callout = @('LidarContactCallout')
}
$given = @{}
foreach ($z in $ModZip)
{
	$full = (Resolve-Path -LiteralPath $z).Path
	$given[(Get-ZipModName $full)] = $full
}
$packaged = @{}
function Get-ModEntry([string] $Name)
{
	if ($given.ContainsKey($Name)) { return [pscustomobject]@{ Name = $Name; Zip = $given[$Name] } }
	if (-not $packaged.ContainsKey($Name))
	{
		$folder = Join-Path $repo $Name
		if (-not (Test-Path -LiteralPath (Join-Path $folder 'ModMain.gd'))) { throw "No mod folder: $folder" }
		$zipPath = Join-Path $build "$Name.zip"
		Compress-Archive -Path $folder -DestinationPath $zipPath
		$null = Get-ZipModName $zipPath
		$packaged[$Name] = $zipPath
	}
	return [pscustomobject]@{ Name = $Name; Zip = $packaged[$Name] }
}

# 3. The runs: suite x load order x masses. (Plain assignments: an `if` used as an expression would unroll these
# arrays of arrays.)
if ($Matrix) { $masses = @(@(109.29, 2.8), @(109.29, 5.0), @(330.0, 2.8), @(330.0, 5.0)) }
else { $masses = @(, @($ShipMass, $ChunkMass)) }
$runs = [Collections.Generic.List[object]]::new()
$used = @{}
foreach ($s in $Suite)
{
	if ($PSBoundParameters.ContainsKey('Mods')) { $names = @($Mods | Where-Object { $_ }) } else { $names = $suiteMods[$s] }
	$entries = @($names | ForEach-Object { $used[$_] = $true; Get-ModEntry $_ })
	if (($AllOrders -or $Matrix) -and $entries.Count -gt 1) { $orders = @(Get-Permutations $entries) }
	else { $orders = @(, $entries) }
	if ($s -eq 'moving') { $combos = $masses } else { $combos = @(, @(0.0, 0.0)) }
	foreach ($order in $orders)
	{
		foreach ($m in $combos) { $runs.Add([pscustomobject]@{ Suite = $s; Order = $order; Ship = $m[0]; Chunk = $m[1] }) }
	}
}
foreach ($name in $given.Keys)
{
	if (-not $used.ContainsKey($name)) { throw "-ModZip: none of the selected suites loads $name" }
}

# Leaks reported at exit. installScriptExtension's throwaway instance is never freed (as in the game's loader); with
# LIDAR.gd it holds a PoolRealArray, hence the MemoryPool line.
$benign = '_first != nullptr|ObjectDB instances leaked|Resources still in use|MemoryPool allocs in use at exit|^\s+at: |^\s*$'
$failed = 0
$index = 0
foreach ($run in $runs)
{
	$index++
	$names = ($run.Order | ForEach-Object { $_.Name }) -join ' + '
	# --fixed-fps: physics steps of exactly 1/60 s, as fast as the machine allows; no rendering, no vsync wait.
	$godotArgs = @('--path', $project, '--no-window', '--disable-render-loop', '--audio-driver', 'Dummy', '--fixed-fps', '60', "--suite=$($run.Suite)", "--mod-zips=$(($run.Order | ForEach-Object { $_.Zip }) -join ';')")
	# A scene path on the command line replaces the project's main scene (main.tscn).
	if ($run.Suite -eq 'boot') { $godotArgs += 'res://harness/boot.tscn' }
	if ($run.Ship -gt 0) { $godotArgs += "--ship-mass=$($run.Ship)" }
	if ($run.Chunk -gt 0) { $godotArgs += "--chunk-mass=$($run.Chunk)" }
	$out = Join-Path $logs ('{0:D2}-{1}.out.txt' -f $index, $run.Suite)
	$err = Join-Path $logs ('{0:D2}-{1}.err.txt' -f $index, $run.Suite)
	$quoted = $godotArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
	$process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$null = $process.Handle
	$timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
	if ($timedOut) { $process.Kill() } else { $process.WaitForExit() }

	$lines = @(Get-Content -LiteralPath $out)
	$errors = @(Get-Content -LiteralPath $err)
	$summary = $lines | Where-Object { $_ -like 'SUMMARY *' } | Select-Object -Last 1
	$problems = @($lines + $errors | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|HARNESS ERROR|Node not found' })
	$warnings = @($errors | Where-Object { $_ -notmatch $benign -and $_ -notmatch 'SCRIPT ERROR|Parse Error|HARNESS ERROR|Node not found' })
	$fails = @($lines | Where-Object { $_ -like 'FAIL *' })
	$ok = -not $timedOut -and $summary -and $fails.Count -eq 0 -and $problems.Count -eq 0 -and $process.ExitCode -eq 0
	if (-not $ok) { $failed++ }

	$counts = if ($summary) { $summary -replace '^SUMMARY .*?: ', '' } else { 'no summary' }
	$massText = if ($run.Suite -eq 'moving') { ' ship=' + $(if ($run.Ship -gt 0) { $run.Ship } else { 'default' }) + ' chunk=' + $(if ($run.Chunk -gt 0) { $run.Chunk } else { 'default' }) } else { '' }
	Write-Host ('{0} {1} [{2}]{3}: {4}' -f $(if ($ok) { 'ok  ' } else { 'FAIL' }), $run.Suite, $names, $massText, $counts) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
	$details = [Collections.Generic.List[string]]::new()
	if ($ShowOutput) { $lines | ForEach-Object { $details.Add($_) } }
	else { $lines | Where-Object { $_ -like 'FAIL *' -or $_ -like 'NOTE *' } | ForEach-Object { $details.Add($_) } }
	$problems | ForEach-Object { $details.Add($_) }
	$warnings | Select-Object -First 5 | ForEach-Object { $details.Add("(stderr) $_") }
	if ($timedOut) { $details.Add("timed out after $TimeoutSeconds s") }
	if (-not $summary -or $problems.Count -gt 0) { $details.Add("log: $out") }
	$details | ForEach-Object { Write-Host "    $_" }
}

Write-Host ''
if ($failed -eq 0) { Write-Host "All $($runs.Count) runs passed. Logs: $logs" -ForegroundColor Green }
else { Write-Host "$failed of $($runs.Count) runs failed. Logs: $logs" -ForegroundColor Red }
exit $(if ($failed -eq 0) { 0 } else { 1 })

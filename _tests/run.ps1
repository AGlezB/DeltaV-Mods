#Requires -Version 7
<#
.SYNOPSIS
	Runs the mods' test harness in a headless Godot 3.6 and reports the results.

.DESCRIPTION
	Assembles a Godot project in <WorkDir>\project from this folder's sources, the game's own scripts (copied from
	the decompiled game: DockingArm.gd, Arm.gd, CabinLight.gd, Boot.gd, LIDAR.gd, PitchAdjustedAudio.gd,
	HardwareLabel.gd, EnceladusMenu.gd, HidingMarginContainer.gd, AnalogControlSlider.gd, TuningFloatValue.gd,
	TuningItems.gd, Hud.gd, OMS.gd, TabsWithGamepadControl.gd, PriceLabel.gd, RepeatingHSlider.gd, MineralLabel.gd,
	MineralSystemToggle.gd, HireableCrew.gd, CrewBio.gd, CurrentCrewManagement.gd, PlaySoundsOnTheseButtons.gd,
	SystemBuyUI.gd, SystemShipUpgradeUI.gd, Tool.gd, gdunzip.gd), the game's Shower.tscn, audio buses
	(default_bus_layout.tres), the skill icons CrewBio.gd preloads and the Fleet entry's Use icon, a stub mineral scene
	carrying the chunk radius read from the game's, stubs of the two scenes LIDAR.gd preloads, of the Tuning parts
	CrewCheapHireNotifier's settings screen is built from, of a Hire screen entry (CrewBio.tscn), of the Geologist
	tab's parts GeologyByMass's OMS tab is built from, and of a Fleet entry (SystemBuyUI.tscn, with the game's
	confirmation animations) and an Equipment item (SystemShipUpgradeUI.tscn). Packages each mod into <WorkDir>\build\<Mod>.zip
	(as a release zip), and runs every suite with its mods loaded from those zips, the way the game loads them:
	by an autoload, before the engine loads the main scene. Logs: <WorkDir>\logs. Nothing in the repo, the game folder
	or the decompiled game is changed. Godot, the decompiled game and <WorkDir> default to folders under the ones set in
	paths.local.psd1 at the repo root (git-ignored; copy paths.example.psd1 to it).

	Suites and the mods they load by default:
	- units, still, moving: ArmAltPullBehavior + ArmAltTargetSelection (unit checks; the ship standing still, 9
	  cases; the ship held, cruising, turning, 16 cases). still and moving need ArmAltPullBehavior.
	- dive: DiveDisableAdrenalineBooster.
	- boot: BootSkipLogos. Runs with harness\boot.tscn, which holds the game's Boot.gd, as the main scene.
	- lidar: LidarLouderPing.
	- hud: HudHideLabels.
	- crew: CrewCheapHireNotifier.
	- geology: GeologyByMass. Builds a HUD from harness\geology_hud.tscn, which holds the game's Hud.gd.
	- fleet: ShipCopyPaste.

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
	[ValidateSet('units', 'still', 'moving', 'dive', 'boot', 'lidar', 'hud', 'crew', 'geology', 'fleet')]
	[string[]] $Suite = @('units', 'still', 'moving', 'dive', 'boot', 'lidar', 'hud', 'crew', 'geology', 'fleet'),
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
foreach ($file in 'ships\modules\DockingArm.gd', 'ships\modules\Arm.gd', 'ships\CabinLight.gd', 'Boot.gd', 'hud\LIDAR.gd', 'sfx\PitchAdjustedAudio.gd', 'hud\HardwareLabel.gd', 'enceladus\EnceladusMenu.gd', 'enceladus\HidingMarginContainer.gd', 'enceladus\AnalogControlSlider.gd', 'enceladus\Tuning\TuningFloatValue.gd', 'enceladus\Tuning\TuningItems.gd', 'hud\Hud.gd', 'hud\OMS.gd', 'menu\TabsWithGamepadControl.gd', 'hud\components\PriceLabel.gd', 'hud\components\RepeatingHSlider.gd', 'hud\components\MineralLabel.gd', 'hud\components\MineralSystemToggle.gd', 'enceladus\HireableCrew.gd', 'enceladus\CrewBio.gd', 'enceladus\CurrentCrewManagement.gd', 'menu\sfx\PlaySoundsOnTheseButtons.gd', 'enceladus\SystemBuyUI.gd', 'enceladus\SystemShipUpgradeUI.gd', 'enceladus\Shower.tscn', 'menu\MenuFontAudiowide.tres', 'hud\Audiowide-Regular.ttf', 'hud\FontNoto.tres', 'hud\NotoMono-Regular.ttf', 'menu\PanelWithHugeShadow.tres', 'Tool.gd', 'vendor\gdunzip.gd', 'default_bus_layout.tres')
{
	$target = Join-Path $project $file
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item -LiteralPath (Join-Path $GameSource $file) -Destination $target
}
# Icons as the game ships them: their import files and the imported textures they point to, so they load without an
# import step. CrewBio.gd preloads the skill icons; a Fleet entry's Use button shows switch.png, whose size and colour
# ShipCopyPaste's icons take, and the Buy confirmation's OK shows buy.png.
$imports = @(Get-ChildItem -LiteralPath (Join-Path $GameSource 'enceladus\Crew') -Filter 'skill-*.png.import' | ForEach-Object { 'enceladus\Crew\' + $_.Name })
$imports += 'enceladus\Upgrades\switch.png.import', 'enceladus\Upgrades\buy.png.import'
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
# The Tuning parts CrewCheapHireNotifier's settings screen is built from: the game's node paths and scripts
# (enceladus\Tuning\TuningFloatValue.tscn, TuningItems.tscn, enceladus\HeaderWithMoney.tscn), without the theme,
# textures, sounds and money display. TuningItems.gd preloads TuningBoolValue.tscn too, which the mod doesn't use.
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
[gd_scene format=2]

[node name="TuningBoolValue" type="VBoxContainer"]
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
Write-Utf8Lf (Join-Path $project 'enceladus\HeaderWithMoney.tscn') @'
[gd_scene format=2]

[node name="HeaderWithMoney" type="HBoxContainer"]
alignment = 1

[node name="MarketLabel" type="Label" parent="."]
size_flags_horizontal = 3
size_flags_vertical = 0
text = "PUT_HEADER_HERE"

[node name="VBoxContainer" type="VBoxContainer" parent="."]
'@
# The Geologist tab's parts GeologyByMass's OMS tab is built from (hud\components\MineralSystemToggle.tscn,
# MineralLabel.tscn, PriceLabel.tscn, as hud\SystemMineralList.gd uses them): the game's node paths, scripts, values
# and connections, without the theme, the toggle's click sound, the slider's smooth scrolling and button sounds.
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
# the game's scene (ShipCopyPaste copies BuyShow and BuyHide); for its fonts, themes holding the default fonts of the
# game's (menu\MenuTheme.tres for the entry, hud\TNTRL-theme.tres for its labels' grid), so sizes are the game's;
# without the rest of the themes, the other textures, the lights and environment of the ship's view, the smooth
# scrolling (a bare node in its place under Use), the sounds and the flicker (harness\fleet_flicker.gd).
$buyUi = (Get-Content -LiteralPath (Join-Path $GameSource 'enceladus\SystemBuyUI.tscn') -Raw) -replace "`r`n", "`n"
$animations = [regex]::Matches($buyUi, '(?ms)^\[sub_resource type="Animation" id=\d+\]\n.*?(?=^\[)')
$anims = [regex]::Matches($buyUi, '(?m)^anims/\w+ = SubResource\( \d+ \)$')
if ($animations.Count -lt 2 -or $anims.Count -ne $animations.Count) { throw 'Cannot read the confirmation animations from enceladus\SystemBuyUI.tscn' }
$entry = @'
[gd_scene load_steps=@@STEPS@@ format=2]

[ext_resource path="res://enceladus/SystemBuyUI.gd" type="Script" id=1]
[ext_resource path="res://enceladus/Upgrades/switch.png" type="Texture" id=2]
[ext_resource path="res://harness/fleet_flicker.gd" type="Script" id=3]
[ext_resource path="res://menu/MenuFontAudiowide.tres" type="DynamicFont" id=4]
[ext_resource path="res://hud/FontNoto.tres" type="DynamicFont" id=5]
[ext_resource path="res://menu/PanelWithHugeShadow.tres" type="StyleBox" id=6]
[ext_resource path="res://enceladus/Upgrades/buy.png" type="Texture" id=7]

[sub_resource type="Theme" id=101]
default_font = ExtResource( 4 )

[sub_resource type="Theme" id=102]
default_font = ExtResource( 5 )

@@ANIMATIONS@@
[node name="SystemBuyUi" type="MarginContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
size_flags_horizontal = 3
theme = SubResource( 101 )
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

[node name="Sprite" type="Sprite" parent="HBox/Margin"]

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
theme = SubResource( 102 )

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
$entry = $entry.Replace('@@STEPS@@', [string](10 + $animations.Count)).Replace('@@ANIMATIONS@@', (($animations | ForEach-Object { $_.Value.TrimEnd() + "`n" }) -join "`n")).Replace('@@ANIMS@@', (($anims | ForEach-Object { $_.Value }) -join "`n"))
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

# 2. The mods: each suite's own (or -Mods), packaged once each, or the release zip given for it.
$suiteMods = @{
	units = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	still = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	moving = @('ArmAltPullBehavior', 'ArmAltTargetSelection')
	dive = @('DiveDisableAdrenalineBooster')
	boot = @('BootSkipLogos')
	lidar = @('LidarLouderPing')
	hud = @('HudHideLabels')
	crew = @('CrewCheapHireNotifier')
	geology = @('GeologyByMass')
	fleet = @('ShipCopyPaste')
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

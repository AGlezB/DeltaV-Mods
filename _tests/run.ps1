#Requires -Version 7
<#
.SYNOPSIS
	Runs the mods' test harness in a headless Godot 3.6 and reports the results.

.DESCRIPTION
	Assembles a Godot project in <WorkDir>\project from this folder's sources, the game's own scripts (copied from
	the decompiled game: DockingArm.gd, Arm.gd, CabinLight.gd, Boot.gd, LIDAR.gd, PitchAdjustedAudio.gd,
	HardwareLabel.gd, EnceladusMenu.gd, Tool.gd, gdunzip.gd), the game's audio buses (default_bus_layout.tres), a stub mineral scene carrying the chunk radius read
	from the game's and stubs of the two scenes LIDAR.gd preloads. Packages each mod into <WorkDir>\build\<Mod>.zip
	(as a release zip), and runs every suite with its mods loaded from those zips, the way the game loads them:
	by an autoload, before the engine loads the main scene. Logs: <WorkDir>\logs. Nothing in the repo, the game folder
	or the decompiled game is changed.

	Suites and the mods they load by default:
	- units, still, moving: ArmAltPullBehavior + ArmAltTargetSelection (unit checks; the ship standing still, 9
	  cases; the ship held, cruising, turning, 16 cases). still and moving need ArmAltPullBehavior.
	- dive: DiveDisableAdrenalineBooster.
	- boot: BootSkipLogos. Runs with harness\boot.tscn, which holds the game's Boot.gd, as the main scene.
	- lidar: LidarLouderPing.
	- hud: HudHideLabels.
	- crew: CrewCheapHireNotifier.

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
	[ValidateSet('units', 'still', 'moving', 'dive', 'boot', 'lidar', 'hud', 'crew')]
	[string[]] $Suite = @('units', 'still', 'moving', 'dive', 'boot', 'lidar', 'hud', 'crew'),
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
	[string] $GodotPath = '<GodotDir>\Godot_v3.6-stable_win64.exe',
	# The decompiled game to take the game's scripts from. Default: the newest Delta-V-<version> folder in
	# $DecompiledRoot (by version number), so the tests always run against the latest game available.
	[string] $GameSource = '',
	[string] $DecompiledRoot = '<TempDir>\gdre',
	[string] $WorkDir = '<TempDir>\tests',
	[int] $TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = Split-Path $PSScriptRoot -Parent
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
foreach ($file in 'ships\modules\DockingArm.gd', 'ships\modules\Arm.gd', 'ships\CabinLight.gd', 'Boot.gd', 'hud\LIDAR.gd', 'sfx\PitchAdjustedAudio.gd', 'hud\HardwareLabel.gd', 'enceladus\EnceladusMenu.gd', 'Tool.gd', 'vendor\gdunzip.gd', 'default_bus_layout.tres')
{
	$target = Join-Path $project $file
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item -LiteralPath (Join-Path $GameSource $file) -Destination $target
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

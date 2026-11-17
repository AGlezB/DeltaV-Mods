#Requires -Version 7
<#
.SYNOPSIS
	Takes the users' wiki's screenshots of the station screens, in an isolated copy of the game.

.DESCRIPTION
	For each mod in shots.psd1, runs the game twice from the same fixture save, without the mod and with it, and saves
	the views its steps capture as _wiki\images\<Mod>-<view>-without.png and -with.png (a view only the mod has:
	<Mod>-<view>.png). See _shots\README.md.

	The game runs from TempDir\shots (paths.local.psd1), never from the game folder: a copy of the stock Godot 3.6
	executable (never Delta-V.exe, whose GOG module would reach the player's account), a copy of Delta-V.pck with an
	override.cfg next to it that renames the game's user folder, and APPDATA pointed inside TempDir\shots, so the
	player's saves, settings and mods folder are never touched. ShotRenderer (_shots\ShotRenderer) stops the game if its
	user folder is anywhere else, and this script fails if anything in %APPDATA%\dV changes. It refuses to run while the
	game is running. BootSkipLogos is loaded in every run, to skip the logos.

.EXAMPLE
	.\_shots\shots.ps1
	Takes every mod's screenshots.

.EXAMPLE
	.\_shots\shots.ps1 -Mod CrewCheapHireNotifier -NewFixture
	Builds the fixture save again, then takes CrewCheapHireNotifier's screenshots.

.EXAMPLE
	.\_shots\shots.ps1 -Steps 'load', 'wait|10', 'press|{menu}/ShipTuning', 'wait|3', 'shot|tuning' -WithMods LidarLouderPing
	Runs these steps with LidarLouderPing, saving TempDir\shots\out\tuning.png: to find where a view is on screen.
#>
[CmdletBinding()]
param(
	# Only these mods' screenshots.
	[string[]] $Mod = @(),
	# Build the fixture save again (otherwise it is built only when missing).
	[switch] $NewFixture,
	# Run these steps once instead of shots.psd1; shot|<name> saves TempDir\shots\out\<name>.png.
	[string[]] $Steps = @(),
	# With -Steps: the mods to load (besides BootSkipLogos).
	[string[]] $WithMods = @(),
	# Seconds before a run is stopped.
	[int] $TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'


$repo = Split-Path $PSScriptRoot -Parent
$userDirName = 'dV-shots' # the game's user folder in the copy (override.cfg); the game's own is dV
$windowSize = 'Vector2( 1600, 900 )'
$imageMaxBytes = 2MB # as wiki.ps1 allows
$preflightSeconds = 30 # the check without a window before each run takes a few
$alwaysLoaded = @('BootSkipLogos')
# Placeholders in the steps: the station menu's entries and the screens they open (enceladus/Enceladus.tscn); in a
# dive, the OMS's tabs (the ship's Hud, ships/RA-TRTL.tscn; its Inventory, hud/OMS.tscn; that scene's tabsPath).
$placeholders = [ordered]@{
	'{menu}' = 'EnceladusMenu/MenuContainer/MarginContainer/HBoxContainer/Options'
	'{screens}' = 'EnceladusMenu/MenuContainer/MarginContainer/CanvasLayer/MarginContainer'
	'{oms}' = 'ship:Hud/Inventory/MarginContainer/VBoxContainer/TabHintContainer/TabContainer'
}


$pathsFile = Join-Path $repo 'paths.local.psd1'
if (-not (Test-Path -LiteralPath $pathsFile)) { throw "No ${pathsFile}: copy paths.example.psd1 to it and set your folders" }
$paths = Import-PowerShellDataFile -LiteralPath $pathsFile
foreach ($key in 'GameDir', 'GodotDir', 'TempDir') { if (-not $paths.$key) { throw "Set $key in $pathsFile" } }
$shots = Join-Path $paths.TempDir 'shots'
$bin = Join-Path $shots 'bin'
$modsDir = Join-Path $bin 'mods'
$appdata = Join-Path $shots 'appdata'
$userDir = Join-Path $appdata $userDirName
$out = Join-Path $shots 'out'
$images = Join-Path $repo '_wiki\images'
$realUserDir = Join-Path $env:APPDATA 'dV'

function Assert-GameNotRunning
{
	if (Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($paths.GameDir, [StringComparison]::OrdinalIgnoreCase) })
	{
		throw 'The game is running: close it first'
	}
}

# Copies a file unless the copy already has its size and time.
function Copy-IfChanged([string] $From, [string] $To)
{
	$source = Get-Item -LiteralPath $From
	$copy = Get-Item -LiteralPath $To -ErrorAction SilentlyContinue
	if (-not $copy -or $copy.Length -ne $source.Length -or $copy.LastWriteTimeUtc -ne $source.LastWriteTimeUtc)
	{
		Write-Host "Copying $From"
		Copy-Item -LiteralPath $From -Destination $To -Force
	}
}

# The player's own user folder: names, sizes and times only, never the contents.
function Get-Snapshot
{
	if (Test-Path -LiteralPath $realUserDir)
	{
		Get-ChildItem -LiteralPath $realUserDir -Recurse -Force -File | ForEach-Object { '{0}|{1}|{2:o}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc }
	}
}

# Starts the game copy with the mods in bin\mods and the job file, the user folder isolated, and these extra arguments;
# returns its output lines and whether it was stopped after $Seconds.
function Start-Copy([string[]] $ExtraArgs, [int] $Seconds)
{
	$psi = [Diagnostics.ProcessStartInfo]::new((Join-Path $bin 'Godot.exe'))
	foreach ($a in @('--main-pack', (Join-Path $bin 'Delta-V.pck'), '--enable-mods') + @($ExtraArgs)) { $psi.ArgumentList.Add($a) }
	foreach ($k in 'APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME') { $psi.Environment[$k] = $appdata }
	$psi.WorkingDirectory = $bin
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$proc = [Diagnostics.Process]::Start($psi)
	$stdout = $proc.StandardOutput.ReadToEndAsync()
	$stderr = $proc.StandardError.ReadToEndAsync()
	$timedOut = -not $proc.WaitForExit($Seconds * 1000)
	if ($timedOut) { $proc.Kill() ; $proc.WaitForExit() }
	return @{ Lines = @($stdout.Result -split "`r?`n") + @($stderr.Result -split "`r?`n"); TimedOut = $timedOut }
}

# Runs the game copy once with these mods and steps; throws if the run fails.
function Invoke-Game([string[]] $Mods, [string[]] $JobSteps)
{
	Assert-GameNotRunning
	Remove-Item -Path (Join-Path $modsDir '*') -Force -ErrorAction SilentlyContinue
	Compress-Archive -Path (Join-Path $PSScriptRoot 'ShotRenderer') -DestinationPath (Join-Path $modsDir 'ShotRenderer.zip') -Force
	foreach ($m in @($alwaysLoaded) + @($Mods) | Select-Object -Unique)
	{
		$folder = Join-Path $repo $m
		if (-not (Test-Path -LiteralPath (Join-Path $folder 'ModMain.gd'))) { throw "No mod folder with ModMain.gd: $folder" }
		Compress-Archive -Path $folder -DestinationPath (Join-Path $modsDir "$m.zip") -Force
	}
	$list = ($JobSteps | ForEach-Object { '"' + $_.Replace('\', '/').Replace('"', '\"') + '"' }) -join ', '
	"[job]`n`nsteps=[ $list ]`n" | Set-Content -LiteralPath (Join-Path $bin 'shotrenderer.cfg') -NoNewline

	# First without a window, for one frame: the mods are loaded then (ModLoader's _init), so a script that doesn't parse
	# shows here. Without ShotRenderer nothing would move the window off the main screen or stop the game.
	$check = Start-Copy @('--no-window', '--quit') $preflightSeconds
	$broken = @($check.Lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' })
	$broken | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
	if ($check.TimedOut) { throw "The check without a window took more than $preflightSeconds s and was stopped" }
	if ($broken) { throw 'A script of the run does not load (above): nothing was shown' }
	if (@($check.Lines | Where-Object { $_ -match '^SHOTRENDERER userdir=.*/shots/' }).Count -eq 0) { throw 'ShotRenderer did not start in the check without a window' }

	Write-Host "Run: $(@($Mods) -join ', ')" -ForegroundColor Cyan
	$run = Start-Copy @() $TimeoutSeconds
	$lines = $run.Lines
	$lines | Where-Object { $_ -match 'SHOTRENDERER' } | ForEach-Object { Write-Host "  $_" }
	$errors = @($lines | Where-Object { $_ -match '^SHOTRENDERER: |SCRIPT ERROR|Parse Error' })
	$errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
	if ($run.TimedOut) { throw "The run took more than $TimeoutSeconds s and was stopped" }
	if (@($lines | Where-Object { $_ -match '^SHOTRENDERER userdir=.*/shots/' }).Count -eq 0) { throw 'ShotRenderer never confirmed the isolated user folder' }
	if (@($errors | Where-Object { $_ -match '^SHOTRENDERER: ' }).Count) { throw 'ShotRenderer could not do every step (above)' }
}

# A step with its placeholders filled in, and a shot's view turned into its file.
function Resolve-Step([string] $Step, [string] $Prefix)
{
	foreach ($key in $placeholders.Keys) { $Step = $Step.Replace($key, $placeholders[$key]) }
	$parts = $Step.Split('|')
	if ($parts[0] -eq 'shot')
	{
		$parts[1] = (Join-Path $out "$Prefix$($parts[1]).png").Replace('\', '/')
	}
	return $parts -join '|'
}

Assert-GameNotRunning
New-Item -ItemType Directory -Force $bin, $modsDir, $userDir, $out | Out-Null
Copy-IfChanged (Join-Path $paths.GodotDir 'Godot_v3.6-stable_win64.exe') (Join-Path $bin 'Godot.exe')
Copy-IfChanged (Join-Path $paths.GameDir 'Delta-V.pck') (Join-Path $bin 'Delta-V.pck')
"[application]`n`nconfig/custom_user_dir_name=`"$userDirName`"`n" | Set-Content -LiteralPath (Join-Path $bin 'override.cfg') -NoNewline
# The copy's settings: a window of a fixed size (ShotRenderer puts it on another screen), no bloom (menu/Bloom.gd: 2 is
# No Bloom; the game's default is full bloom), no tutorial, English, no sound, and the game's streaming mode, without
# which it pauses whenever its window loses the focus (PauseLayer.gd _notification).
@"
[display]

windowed=true
fullscreen=false
windowSize=$windowSize
bloom=2

[gameplay]

tutorial=false
streaming=true

[locale]

language="en"

[audio]

master=-80
"@ | Set-Content -LiteralPath (Join-Path $userDir 'settings.cfg') -NoNewline

$before = @(Get-Snapshot)
try
{
	if ($NewFixture -or -not (Test-Path -LiteralPath (Join-Path $userDir 'savegame.dv')))
	{
		Invoke-Game @() @('newgame', 'wait|1')
	}
	if ($Steps)
	{
		Invoke-Game $WithMods @($Steps | ForEach-Object { Resolve-Step $_ '' })
	}
	else
	{
		$definitions = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'shots.psd1')
		$names = if ($Mod) { $Mod } else { @($definitions.Keys | Sort-Object) }
		foreach ($name in $names)
		{
			$def = $definitions[$name]
			if (-not $def) { throw "No shots for $name in shots.psd1" }
			foreach ($variant in 'without', 'with')
			{
				# with: steps run only with the mod.
				$runSteps = foreach ($step in $def.Steps)
				{
					if ($step -notmatch '^with:') { $step }
					elseif ($variant -eq 'with') { $step.Substring('with:'.Length) }
				}
				# A run with nothing to shoot (every view only the mod has) isn't started.
				if (-not @($runSteps | Where-Object { $_ -match '^shot\|' }).Count) { continue }
				$mods = if ($variant -eq 'with') { @($name) + @($def.Also) } else { @($def.Also) }
				Invoke-Game @($mods | Where-Object { $_ }) @($runSteps | ForEach-Object { Resolve-Step $_ "$name-" } | ForEach-Object {
					if ($_ -match '^shot\|') { $_ -replace '\.png(\||$)', "-$variant.png`$1" } else { $_ }
				})
			}
			foreach ($step in @($def.Steps | Where-Object { $_ -match '^(with:)?shot\|' }))
			{
				$view = $step.Split('|')[1]
				$targets = if ($step -match '^with:') { @(@{ From = 'with'; To = "$name-$view.png" }) } else { @(@{ From = 'without'; To = "$name-$view-without.png" }, @{ From = 'with'; To = "$name-$view-with.png" }) }
				foreach ($t in $targets)
				{
					$file = Join-Path $out "$name-$view-$($t.From).png"
					if (-not (Test-Path -LiteralPath $file)) { throw "No $file" }
					Copy-Item -LiteralPath $file -Destination (Join-Path $images $t.To) -Force
					$size = (Get-Item -LiteralPath $file).Length
					$note = if ($size -gt $imageMaxBytes) { " (over $($imageMaxBytes / 1KB) KB: crop it smaller)" } else { '' }
					Write-Host "  _wiki/images/$($t.To): $([math]::Ceiling($size / 1KB)) KB$note"
				}
			}
		}
	}
}
finally
{
	$after = @(Get-Snapshot)
	if (Compare-Object $before $after)
	{
		Write-Host "THE PLAYER'S USER FOLDER $realUserDir CHANGED DURING THE RUN:" -ForegroundColor Red
		Compare-Object $before $after | ForEach-Object { Write-Host "  $($_.SideIndicator) $($_.InputObject)" -ForegroundColor Red }
		throw "$realUserDir changed: check it"
	}
}
Write-Host 'Done; the player''s user folder is unchanged.' -ForegroundColor Green

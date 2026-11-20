#Requires -Version 7
<#
.SYNOPSIS
	Takes the users' wiki's screenshots of the station screens, and of the OMS and the HUD in a dive, in an isolated
	copy of the game.

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

	Every run is hidden: the game starts with --no-window, so nothing shows on screen or takes the focus, and a copy
	whose window becomes visible all the same is stopped at once, failing the run.

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
	# Run these steps once instead of shots.psd1; shot|<name> saves TempDir\shots\out\<name>.png (and so do ship and
	# weapon steps, whose last field is the name).
	[string[]] $Steps = @(),
	# With -Steps: the mods to load (besides BootSkipLogos).
	[string[]] $WithMods = @(),
	# Seconds before a run is stopped, unless shots.psd1 sets the mod's own TimeoutSeconds.
	[int] $TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'


$repo = Split-Path $PSScriptRoot -Parent
$userDirName = 'dV-shots' # the game's user folder in the copy (override.cfg); the game's own is dV
$windowSize = 'Vector2( 1600, 900 )'
$imageMaxBytes = 2MB # as wiki.ps1 allows
$preflightSeconds = 30 # the one-frame check before each run takes a few
$windowCheckMs = 50 # how often a running copy is checked for a visible window
$alwaysLoaded = @('BootSkipLogos')
# Placeholders in the steps: the station menu's entries and the screens they open (enceladus/Enceladus.tscn); in a
# dive, the OMS's tabs (the ship's Hud, ships/RA-TRTL.tscn; its Inventory, hud/OMS.tscn; that scene's tabsPath).
$placeholders = [ordered]@{
	'{menu}' = 'EnceladusMenu/MenuContainer/MarginContainer/HBoxContainer/Options'
	'{screens}' = 'EnceladusMenu/MenuContainer/MarginContainer/CanvasLayer/MarginContainer'
	'{oms}' = 'ship:Hud/Inventory/MarginContainer/VBoxContainer/TabHintContainer/TabContainer'
}
# The steps that save a picture, and the field of each that names its view (ShotRenderer's steps):
# shot|<view>[|x,y,w,h], ship|<model>|<view>, weapon|<system>|<model>|<slots>|<view>.
$viewField = @{ shot = 1; ship = 2; weapon = 4 }
$pictureStep = '^(shot|ship|weapon)\|'


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

# Starts the game copy with the mods in bin\mods and the job file, the user folder isolated, and these extra arguments,
# always without a window (--no-window: Godot 3 creates the window hidden, never shows it or gives it the focus, and
# still draws in it, so the pictures are the same); returns its output lines, whether it was stopped after $Seconds,
# and whether its window became visible all the same (then it is stopped at once).
function Start-Copy([string[]] $ExtraArgs, [int] $Seconds)
{
	$psi = [Diagnostics.ProcessStartInfo]::new((Join-Path $bin 'Godot.exe'))
	foreach ($a in @('--main-pack', (Join-Path $bin 'Delta-V.pck'), '--enable-mods', '--no-window') + @($ExtraArgs | Where-Object { $_ -ne '--no-window' })) { $psi.ArgumentList.Add($a) }
	foreach ($k in 'APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME') { $psi.Environment[$k] = $appdata }
	$psi.WorkingDirectory = $bin
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$proc = [Diagnostics.Process]::Start($psi)
	$stdout = $proc.StandardOutput.ReadToEndAsync()
	$stderr = $proc.StandardError.ReadToEndAsync()
	$started = Get-Date
	$timedOut = $false
	$shown = $false
	while (-not $proc.WaitForExit($windowCheckMs))
	{
		$proc.Refresh() # MainWindowHandle is a visible top-level window only
		if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $shown = $true }
		elseif (((Get-Date) - $started).TotalSeconds -gt $Seconds) { $timedOut = $true }
		if ($shown -or $timedOut) { $proc.Kill() ; $proc.WaitForExit() ; break }
	}
	return @{ Lines = @($stdout.Result -split "`r?`n") + @($stderr.Result -split "`r?`n"); TimedOut = $timedOut; Shown = $shown }
}

# Runs the game copy once with these mods and steps, stopping it after $Seconds; throws if the run fails.
function Invoke-Game([string[]] $Mods, [string[]] $JobSteps, [int] $Seconds)
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

	# First for one frame: the mods are loaded then (ModLoader's _init), so a script that doesn't parse shows here, in a
	# few seconds, instead of a run that would wait for its timeout (without ShotRenderer nothing stops the game).
	$check = Start-Copy @('--quit') $preflightSeconds
	$broken = @($check.Lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' })
	$broken | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
	if ($check.Shown) { throw 'The game showed its window in the one-frame check, and was stopped' }
	if ($check.TimedOut) { throw "The one-frame check took more than $preflightSeconds s and was stopped" }
	if ($broken) { throw 'A script of the run does not load (above)' }
	if (@($check.Lines | Where-Object { $_ -match '^SHOTRENDERER userdir=.*/shots/' }).Count -eq 0) { throw 'ShotRenderer did not start in the one-frame check' }

	Write-Host "Run: $(@($Mods) -join ', ')" -ForegroundColor Cyan
	$run = Start-Copy @() $Seconds
	$lines = $run.Lines
	$lines | Where-Object { $_ -match 'SHOTRENDERER' } | ForEach-Object { Write-Host "  $_" }
	$errors = @($lines | Where-Object { $_ -match '^SHOTRENDERER: |SCRIPT ERROR|Parse Error' })
	$errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
	if ($run.Shown) { throw 'The game showed its window, and was stopped' }
	if ($run.TimedOut) { throw "The run took more than $Seconds s and was stopped" }
	if (@($lines | Where-Object { $_ -match '^SHOTRENDERER userdir=.*/shots/' }).Count -eq 0) { throw 'ShotRenderer never confirmed the isolated user folder' }
	if (@($errors | Where-Object { $_ -match '^SHOTRENDERER: ' }).Count) { throw 'ShotRenderer could not do every step (above)' }
	if (@($lines | Where-Object { $_ -match '^SHOTRENDERER done' }).Count -eq 0) { throw 'The game ended before its last step' }
}

# A step with its placeholders filled in, and a picture's view turned into its file.
function Resolve-Step([string] $Step, [string] $Prefix)
{
	foreach ($key in $placeholders.Keys) { $Step = $Step.Replace($key, $placeholders[$key]) }
	$parts = $Step.Split('|')
	$field = $viewField[$parts[0]]
	if ($null -ne $field -and $parts.Count -gt $field)
	{
		$parts[$field] = (Join-Path $out "$Prefix$($parts[$field]).png").Replace('\', '/')
	}
	return $parts -join '|'
}

Assert-GameNotRunning
New-Item -ItemType Directory -Force $bin, $modsDir, $userDir, $out | Out-Null
Copy-IfChanged (Join-Path $paths.GodotDir 'Godot_v3.6-stable_win64.exe') (Join-Path $bin 'Godot.exe')
Copy-IfChanged (Join-Path $paths.GameDir 'Delta-V.pck') (Join-Path $bin 'Delta-V.pck')
"[application]`n`nconfig/custom_user_dir_name=`"$userDirName`"`n" | Set-Content -LiteralPath (Join-Path $bin 'override.cfg') -NoNewline
# The copy's settings: a window of a fixed size (never shown, but drawn at that size), no bloom (menu/Bloom.gd: 2 is
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
		Invoke-Game @() @('newgame', 'wait|1') $TimeoutSeconds
	}
	if ($Steps)
	{
		Invoke-Game $WithMods @($Steps | ForEach-Object { Resolve-Step $_ '' }) $TimeoutSeconds
	}
	else
	{
		$definitions = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'shots.psd1')
		$names = if ($Mod) { $Mod } else { @($definitions.Keys | Sort-Object) }
		foreach ($name in $names)
		{
			$def = $definitions[$name]
			if (-not $def) { throw "No shots for $name in shots.psd1" }
			$seconds = if ($def.TimeoutSeconds) { $def.TimeoutSeconds } else { $TimeoutSeconds }
			foreach ($variant in 'without', 'with')
			{
				# with: steps run only with the mod.
				$runSteps = foreach ($step in $def.Steps)
				{
					if ($step -notmatch '^with:') { $step }
					elseif ($variant -eq 'with') { $step.Substring('with:'.Length) }
				}
				# A run with nothing to shoot (every view only the mod has) isn't started.
				if (-not @($runSteps | Where-Object { $_ -match $pictureStep }).Count) { continue }
				$mods = if ($variant -eq 'with') { @($name) + @($def.Also) } else { @($def.Also) }
				# Pictures of an earlier run must not pass for this one's.
				Remove-Item -Path (Join-Path $out "$name-*-$variant.png") -Force -ErrorAction SilentlyContinue
				Invoke-Game @($mods | Where-Object { $_ }) @($runSteps | ForEach-Object { Resolve-Step $_ "$name-" } | ForEach-Object {
					if ($_ -match $pictureStep) { $_ -replace '\.png(\||$)', "-$variant.png`$1" } else { $_ }
				}) $seconds
			}
			foreach ($step in @($def.Steps | Where-Object { $_ -match '^(with:)?(shot|ship|weapon)\|' }))
			{
				$parts = ($step -replace '^with:', '').Split('|')
				$view = $parts[$viewField[$parts[0]]]
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

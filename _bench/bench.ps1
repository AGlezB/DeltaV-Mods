#Requires -Version 7
<#
.SYNOPSIS
	Runs the drone bench: deterministic simulations of the control scenario (unattended mining in an
	Antonoff-Titan K225), to tune how the haul and tug drones pick their chunks.

.DESCRIPTION
	Assembles a Godot project in <WorkDir>\project from this folder's scripts, the test harness's autoload stubs and
	mod loader (_tests\harness), and the game's own scripts and physics materials (copied from the newest decompiled
	game, never committed), then runs headless Godot 3.6 processes in parallel. The game's scenes and maps are read
	at run time from the decompiled game. Results: <WorkDir>\results\<time>-<mode>\ (CSV and pictures). See README.md.

	Modes:
	  Pdw       PDW tuning calibration: every Tuning of each -Pdw against roids of every class.
	  Speed     Course speed calibration: the scenario in vanilla at each of -Speeds, counting roids that hit the ship
	            ahead of its middle.
	  Run       The scenario for each -Pdw and -Seeds (and -Candidate with each of -Params, from Stage 2 on).
	  SelfTest  One ONMWG-650 run twice: both must give the same results (README.md *Determinism*).

	The scenario's settings (speeds and Tuning per PDW, minutes, seeds) default to scenario.psd1.

.EXAMPLE
	.\_bench\bench.ps1 -Mode Pdw
	.\_bench\bench.ps1 -Mode Speed -Speeds 2,3,4,5
	.\_bench\bench.ps1 -Mode Run -Seeds 1,2,3
#>
param(
	[ValidateSet('Pdw', 'Speed', 'Run', 'SelfTest')]
	[string] $Mode = 'Run',
	[ValidateSet('ONMWG', 'NDPT')]
	[string[]] $Pdw,
	[ValidateSet('densest', 'be', 'be-chaos')]
	[string[]] $Spots,
	[string] $Geologist,
	[int[]] $Seeds,
	[double[]] $Speeds,
	[double] $Minutes,
	[string] $Candidate = '',
	[string[]] $Params = @(''),
	# A mod's release zip, or a mod folder of the repo packaged as one, whose Code.gd runs over the game's drone plant
	# with its switch on and its default settings (Run mode).
	[string] $ModZip,
	[string] $Mod,
	[string] $ParamsFile,
	[int] $Steps = 1,
	[int] $Repeat = 1,
	[int] $Parallel = [Math]::Max(1, [Environment]::ProcessorCount / 2),
	[string] $GodotPath,
	[string] $GameSource,
	[string] $DecompiledRoot,
	[string] $WorkDir,
	[int] $TimeoutSeconds = 3600
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$localPathsFile = Join-Path $repo 'paths.local.psd1'
$localPaths = if (Test-Path -LiteralPath $localPathsFile) { Import-PowerShellDataFile -LiteralPath $localPathsFile } else { @{} }
function Get-LocalPath([string] $Key, [string] $Child, [string] $Parameter)
{
	if (-not $localPaths[$Key]) { throw "Pass -$Parameter, or set $Key in $localPathsFile (copy paths.example.psd1 to it)" }
	return [IO.Path]::Combine($localPaths[$Key], $Child)
}
if (-not $GodotPath) { $GodotPath = Get-LocalPath 'GodotDir' 'Godot_v3.6-stable_win64.exe' 'GodotPath' }
if (-not $GameSource -and -not $DecompiledRoot) { $DecompiledRoot = Get-LocalPath 'TempDir' 'gdre' 'DecompiledRoot' }
if (-not $WorkDir) { $WorkDir = Get-LocalPath 'TempDir' 'bench' 'WorkDir' }
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
foreach ($path in $GodotPath, $GameSource)
{
	if (-not (Test-Path -LiteralPath $path)) { throw "Not found: $path" }
}
Write-Host "Game from $GameSource"

$scenario = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'scenario.psd1')
if (-not $Seeds) { $Seeds = $scenario.Seeds }
if (-not $Pdw) { $Pdw = $scenario.Pdw }
if (-not $Spots) { $Spots = $scenario.Spots }
if (-not $Geologist) { $Geologist = $scenario.Geologist }
if ($ParamsFile) { $Params = @(Get-Content -LiteralPath $ParamsFile | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }) }
# A short, stable name for a parameter set (String.GetHashCode changes from one PowerShell process to the next).
function Get-ShortHash([string] $Text)
{
	$bytes = [Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($Text))
	return ([BitConverter]::ToString($bytes) -replace '-', '').Substring(0, 8).ToLower()
}
if (-not $Minutes) { $Minutes = $scenario.Minutes }
if ($Mod)
{
	$folder = Join-Path $repo $Mod
	if (-not (Test-Path -LiteralPath (Join-Path $folder 'ModMain.gd'))) { throw "No mod folder: $folder" }
	New-Item -ItemType Directory -Force (Join-Path $work 'build') | Out-Null
	$ModZip = Join-Path $work "build\$Mod.zip"
	Remove-Item -LiteralPath $ModZip -ErrorAction SilentlyContinue
	Compress-Archive -Path $folder -DestinationPath $ModZip
}
$modName = ''
if ($ModZip)
{
	$ModZip = (Resolve-Path -LiteralPath $ModZip).Path
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$zip = [IO.Compression.ZipFile]::OpenRead($ModZip)
	try { $modName = @($zip.Entries | ForEach-Object { $_.FullName.Split('/')[0] } | Select-Object -Unique)[0] }
	finally { $zip.Dispose() }
	if ($Candidate) { throw '-Candidate and -ModZip / -Mod exclude each other' }
}

function Write-Utf8Lf([string] $Path, [string] $Text)
{
	[IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

# 1. The project.
$project = Join-Path $work 'project'
if (Test-Path -LiteralPath $project) { Remove-Item -LiteralPath $project -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $project 'bench') | Out-Null
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.gd' | Copy-Item -Destination (Join-Path $project 'bench')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stubs') -Destination (Join-Path $project 'bench') -Recurse
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'candidates'))
{
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'candidates') -Destination (Join-Path $project 'bench') -Recurse
}
New-Item -ItemType Directory -Force (Join-Path $project 'harness') | Out-Null
Copy-Item -LiteralPath (Join-Path $repo '_tests\harness\stubs') -Destination (Join-Path $project 'harness') -Recurse
Copy-Item -LiteralPath (Join-Path $repo '_tests\harness\loader.gd') -Destination (Join-Path $project 'harness')
$gameFiles = @('Tool.gd', 'vendor\gdunzip.gd', 'weapons\drone-plant.gd', 'weapons\drones\DroneLaunchManager.gd',
	'asteroids\mineral.gd', 'asteroids\asteroid.gd', 'ships\modules\PDT.gd', 'weapons\emp.gd', 'weapons\massdriver.gd',
	'weapons\projectiles\projectile.gd', 'ships\Front Bumper.gd')
$gameFiles += Get-ChildItem -LiteralPath $GameSource -Recurse -Filter '*.phymat' | ForEach-Object { [IO.Path]::GetRelativePath($GameSource, $_.FullName) }
foreach ($rel in $gameFiles)
{
	$dest = Join-Path $project $rel
	New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
	Copy-Item -LiteralPath (Join-Path $GameSource $rel) -Destination $dest
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stubs\explosion.gd') -Destination (Join-Path $project 'weapons\projectiles\Explosion.gd')
$gameProject = Get-Content -LiteralPath (Join-Path $GameSource 'project.godot') -Raw
$physics = if ($gameProject -match '(?ms)^\[physics\]\s*$(.*?)(?=^\[)') { $Matches[1].Trim() } else { throw 'No [physics] in the game''s project.godot' }
Write-Utf8Lf (Join-Path $project 'project.godot') @"
; The drone bench (see _bench\README.md in the repo), assembled by bench.ps1. The autoloads keep the game's order;
; the physics settings are the game's.

config_version=4

[application]

config/name="dV drone bench"
run/main_scene="res://bench/main.tscn"

[autoload]

Tool="*res://Tool.gd"
Debug="*res://harness/stubs/Debug.gd"
ModLoader="*res://harness/loader.gd"
Settings="*res://harness/stubs/Settings.gd"
Loader="*res://harness/stubs/Loader.gd"
Shipyard="*res://harness/stubs/Shipyard.gd"
K2RGB="*res://harness/stubs/K2RGB.gd"
Factions="*res://harness/stubs/Factions.gd"
Namer="*res://harness/stubs/Namer.gd"
CurrentGame="*res://harness/stubs/CurrentGame.gd"
Agenda="*res://harness/stubs/Agenda.gd"
Achivements="*res://harness/stubs/Achivements.gd"

[display]

window/vsync/use_vsync=false

[logging]

file_logging/enable_file_logging=false
file_logging/enable_file_logging.pc=false

[physics]

$physics
"@
Write-Utf8Lf (Join-Path $project 'bench\main.tscn') @'
[gd_scene load_steps=2 format=2]

[ext_resource path="res://bench/main.gd" type="Script" id=1]

[node name="Bench" type="Node"]
script = ExtResource( 1 )
'@
$prepLog = Join-Path $work 'prepare.log'
$prepProcess = Start-Process -FilePath $GodotPath -ArgumentList @('--path', "`"$project`"", '--no-window', '--audio-driver', 'Dummy',
	'--script', 'res://bench/prepare.gd') -RedirectStandardOutput $prepLog -RedirectStandardError "$prepLog.err" -NoNewWindow -Wait -PassThru
$prep = (Get-Content -LiteralPath $prepLog -Raw) + (Get-Content -LiteralPath "$prepLog.err" -Raw)
if ($prepProcess.ExitCode -ne 0 -or $prep -match 'BENCH ERROR|SCRIPT ERROR|Parse Error') { Write-Host $prep; throw 'Preparing the project failed' }

# 2. The spots: the ring map's densest, the dense spot whose course crosses the most Be, and the high-chaos spot whose
# course crosses the most Be, found once per game version (and per course length) and kept in the work folder
# (scanning the whole map takes a while): "x,y" and the course's chaos.
$gameVersion = (Split-Path $GameSource -Leaf) -replace '^Delta-V-', ''
function Get-Spot([string] $Kind, [double] $Course)
{
	$file = if ($Kind -eq 'densest') { Join-Path $work "spot-$gameVersion.txt" } else { Join-Path $work "spot-$Kind-$gameVersion-$([int]$Course).txt" }
	if (-not (Test-Path -LiteralPath $file) -or (Get-Content -LiteralPath $file -Raw).Trim() -notmatch ' ')
	{
		$spotLog = Join-Path $work "spot-$Kind.log"
		Start-Process -FilePath $GodotPath -ArgumentList @('--path', "`"$project`"", '--no-window', '--disable-render-loop',
			'--audio-driver', 'Dummy', '--mode=spot', "--spot-kind=$Kind", "--course=$Course", "`"--game=$GameSource`"") `
			-RedirectStandardOutput $spotLog -RedirectStandardError "$spotLog.err" -NoNewWindow -Wait | Out-Null
		$found = Select-String -LiteralPath $spotLog -Pattern 'BENCH spot (\d+,\d+) chaos ([\d.]+)'
		if (-not $found) { throw "Finding the $Kind spot failed (see $spotLog)" }
		Write-Utf8Lf $file "$($found.Matches[0].Groups[1].Value) $($found.Matches[0].Groups[2].Value)"
	}
	$spot, $chaos = (Get-Content -LiteralPath $file -Raw).Trim() -split ' '
	return [pscustomobject]@{ Spot = $spot; Chaos = $chaos }
}

# 3. The runs.
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $work "results\$stamp-$($Mode.ToLower())"
New-Item -ItemType Directory -Force $out | Out-Null
$jobs = [Collections.Generic.List[object]]::new()
function Add-Job([string] $Label, [string[]] $BenchArgs)
{
	$jobs.Add([pscustomobject]@{ Label = $Label; Args = @('--path', $project, '--no-window', '--disable-render-loop',
		'--audio-driver', 'Dummy', '--fixed-fps', '60', "--game=$GameSource", "--out=$out", "--label=$Label") + $BenchArgs })
}
# key=value,key=value: Windows strips the quotes JSON would need on the command line.
function Get-Tuning([string] $Type) { return ($scenario.Tuning[$Type].GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ',' }
function Get-Speed([string] $Type) { return $scenario.Speed[$Type] }
# --spot and --spot-name for a run at that speed (m/s), and the geologist; a high-chaos spot also passes its course's
# chaos and the densest spot's density (the scenario's density is always the densest).
function Get-SpotArgs([string] $Kind, [double] $Speed)
{
	$s = Get-Spot $Kind ($Speed * 10 * 60 * $Minutes)
	Write-Host "Spot $Kind at ${Speed} m/s: $($s.Spot), chaos $($s.Chaos)"
	$a = @("--spot=$($s.Spot)", "--spot-name=$Kind", "--geologist=$Geologist")
	if ($Kind -eq 'be-chaos') { $a += @("--chaos=$($s.Chaos)", "--density-spot=$((Get-Spot 'densest' 0).Spot)") }
	return $a
}

switch ($Mode)
{
	'Pdw'
	{
		$a = Get-SpotArgs 'densest' 0
		foreach ($type in $Pdw)
		{
			foreach ($part in 0..($Parallel - 1))
			{
				Add-Job "pdw-$type-$part" (@('--mode=pdw', "--sweep=$type", "--part=$part", "--parts=$Parallel", "--steps=$Steps") + $a)
			}
		}
	}
	'Speed'
	{
		foreach ($type in $Pdw)
		{
			foreach ($speed in $Speeds)
			{
				$a = Get-SpotArgs $Spots[0] $speed
				foreach ($seed in $Seeds)
				{
					Add-Job "speed-$($Spots[0])-$type-$speed-s$seed" (@('--mode=run', "--pdw=$type", "--speed=$speed",
						"--seed=$seed", "--minutes=$Minutes", "--tuning=$(Get-Tuning $type)") + $a)
				}
			}
		}
	}
	'Run'
	{
		foreach ($spotKind in $Spots)
		{
			foreach ($type in $Pdw)
			{
				$a = Get-SpotArgs $spotKind (Get-Speed $type)
				foreach ($p in $Params)
				{
					foreach ($seed in $Seeds)
					{
						$name = if ($Candidate) { "$([IO.Path]::GetFileNameWithoutExtension($Candidate))-$(Get-ShortHash $p)" } elseif ($modName) { $modName } else { 'vanilla' }
						$b = @('--mode=run', "--pdw=$type", "--speed=$(Get-Speed $type)", "--seed=$seed", "--minutes=$Minutes",
							"--tuning=$(Get-Tuning $type)") + $a
						if ($Candidate) { $b += @("--candidate=res://bench/candidates/$Candidate", "--params=$p") }
						if ($modName) { $b += @("--mod-zip=$ModZip", "--mod-name=$modName") }
						foreach ($r in 1..$Repeat)
						{
							$suffix = if ($Repeat -gt 1) { "-r$r" } else { "" }
							Add-Job "$name-$spotKind-$type-s$seed$suffix" $b
						}
					}
				}
			}
		}
	}
	'SelfTest'
	{
		$type = 'ONMWG' # the scenario without bullets, whose runs repeat exactly (README.md *Determinism*)
		$a = Get-SpotArgs $Spots[0] (Get-Speed $type)
		foreach ($copy in 'a', 'b')
		{
			Add-Job "self-$copy" (@('--mode=run', "--pdw=$type", "--speed=$(Get-Speed $type)", "--seed=$($Seeds[0])",
				"--minutes=$Minutes", "--tuning=$(Get-Tuning $type)") + $a)
		}
	}
}

Write-Host "$($jobs.Count) runs, $Parallel at a time, into $out"
$running = @{}
$queue = [Collections.Generic.Queue[object]]::new($jobs)
$failed = @()
$started = Get-Date
while ($queue.Count -gt 0 -or $running.Count -gt 0)
{
	while ($queue.Count -gt 0 -and $running.Count -lt $Parallel)
	{
		$job = $queue.Dequeue()
		$log = Join-Path $out "$($job.Label).log"
		$p = Start-Process -FilePath $GodotPath -ArgumentList ($job.Args | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) `
			-RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
		$running[$job.Label] = [pscustomobject]@{ Process = $p; Started = Get-Date; Log = $log }
	}
	Start-Sleep -Milliseconds 500
	foreach ($label in @($running.Keys))
	{
		$r = $running[$label]
		if ($r.Process.HasExited)
		{
			$text = (Get-Content -LiteralPath $r.Log -Raw) + (Get-Content -LiteralPath "$($r.Log).err" -Raw -ErrorAction SilentlyContinue)
			if ($r.Process.ExitCode -ne 0 -or $text -match 'BENCH ERROR|SCRIPT ERROR|Parse Error')
			{
				$failed += $label
				Write-Host "FAIL $label (see $($r.Log))" -ForegroundColor Red
			}
			else
			{
				Write-Host "done $label"
			}
			$running.Remove($label)
		}
		elseif (((Get-Date) - $r.Started).TotalSeconds -gt $TimeoutSeconds)
		{
			Stop-Process -Id $r.Process.Id -Force
			$failed += $label
			Write-Host "TIMEOUT $label" -ForegroundColor Red
			$running.Remove($label)
		}
	}
}
Write-Host ("All runs finished in {0:N0} s" -f ((Get-Date) - $started).TotalSeconds)

# 4. One CSV for all the runs.
$rows = Get-ChildItem -LiteralPath $out -Filter '*.csv' | Where-Object { $_.Name -notmatch '-chunks\.csv$' -and $_.Name -ne 'all.csv' } |
	ForEach-Object { Import-Csv -LiteralPath $_.FullName }
if ($rows) { $rows | Export-Csv -LiteralPath (Join-Path $out 'all.csv') -NoTypeInformation -Encoding utf8NoBOM }
if ($Mode -eq 'SelfTest')
{
	# Every column but the label, read as CSV (the Tuning column holds commas).
	$rowA = Import-Csv -LiteralPath (Join-Path $out 'self-a.csv') | Select-Object -Property * -ExcludeProperty label
	$rowB = Import-Csv -LiteralPath (Join-Path $out 'self-b.csv') | Select-Object -Property * -ExcludeProperty label
	$same = ($rowA | ConvertTo-Json -Compress) -eq ($rowB | ConvertTo-Json -Compress)
	$chunksSame = (Get-Content -LiteralPath (Join-Path $out 'self-a-chunks.csv') -Raw) -eq (Get-Content -LiteralPath (Join-Path $out 'self-b-chunks.csv') -Raw)
	if ($same -and $chunksSame) { Write-Host 'SELFTEST PASS: both runs gave the same results' -ForegroundColor Green }
	else { Write-Host 'SELFTEST FAIL: the runs differ' -ForegroundColor Red; $failed += 'selftest' }
}
Write-Host "Results: $out"
if ($failed) { exit 1 }

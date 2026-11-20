#Requires -Version 7
<#
.SYNOPSIS
	Ranks the drone bench's runs: every parameter set (and vanilla) by PDW type and spot, on averages with their
	standard errors, invalid runs left out.

.DESCRIPTION
	Reads all.csv of each results folder given (default: the newest -Last folders of TempDir\bench\results) and prints:
	- for each parameter set, per PDW type and spot: runs, chunks in the hold and escaped, their ore value, Be in the
	  hold and escaped, drone parts, target switches, chunks stopped but never brought in, chunks in range on average;
	- the sets of -RankPdw ranked by the ore value they bring into the hold more than vanilla, paired by spot and seed
	  (each run against vanilla's run of the same spot and seed, which shares its field), with the escaped ore value's
	  difference the same way; the differences are means over the spots and seeds, with their standard errors.
	Include a folder with vanilla's runs of the same seeds for the paired columns.

.EXAMPLE
	.\_bench\analyze.ps1 -Last 2
	.\_bench\analyze.ps1 -Folders "$($paths.TempDir)\bench\results\20261118-001000-run"  # $paths from paths.local.psd1
#>
param(
	[string[]] $Folders,
	[int] $Last = 1,
	[string] $RankPdw = 'NDPT',
	[string] $WorkDir
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$localPaths = Import-PowerShellDataFile -LiteralPath (Join-Path $repo 'paths.local.psd1')
if (-not $WorkDir) { $WorkDir = Join-Path $localPaths.TempDir 'bench' }
if (-not $Folders)
{
	$Folders = Get-ChildItem -LiteralPath (Join-Path $WorkDir 'results') -Directory | Where-Object Name -like '*-run' |
		Sort-Object Name | Select-Object -Last $Last | ForEach-Object FullName
}
$rows = $Folders | ForEach-Object { Import-Csv -LiteralPath (Join-Path $_ 'all.csv') } | Where-Object valid -eq '1'
function Get-Stat([double[]] $Values)
{
	$m = ($Values | Measure-Object -Average).Average
	$var = if ($Values.Count -gt 1) { (($Values | ForEach-Object { ($_ - $m) * ($_ - $m) }) | Measure-Object -Sum).Sum / ($Values.Count - 1) } else { 0 }
	return [pscustomobject]@{ Mean = $m; Se = [math]::Sqrt($var / [math]::Max(1, $Values.Count)); N = $Values.Count }
}
function Get-Column([object[]] $Group, [string] $Column) { return Get-Stat @($Group | ForEach-Object { [double]$_.$Column }) }
function Get-SetName($Row) { if ($Row.candidate) { "$($Row.candidate) $($Row.params)" } else { 'vanilla' } }

$table = $rows | Group-Object { Get-SetName $_ }, pdw, spot | ForEach-Object {
	$g = $_.Group
	$cap = Get-Column $g 'captured'; $esc = Get-Column $g 'escaped'; $cv = Get-Column $g 'captured_value'; $ev = Get-Column $g 'escaped_value'
	[pscustomobject]@{
		Set = Get-SetName $g[0]; Pdw = $g[0].pdw; Spot = $g[0].spot; Runs = $g.Count
		InHold = '{0,5:N1} ±{1,4:N1}' -f $cap.Mean, $cap.Se; Escaped = '{0,5:N1} ±{1,4:N1}' -f $esc.Mean, $esc.Se
		InHoldK = '{0,5:N0} ±{1,3:N0}' -f ($cv.Mean / 1000), ($cv.Se / 1000); EscapedK = '{0,6:N0} ±{1,3:N0}' -f ($ev.Mean / 1000), ($ev.Se / 1000)
		BeIn = '{0:N1}' -f (Get-Column $g 'be_captured').Mean; BeOut = '{0:N1}' -f (Get-Column $g 'be_escaped').Mean
		DroneKg = '{0:N0}' -f (Get-Column $g 'drone_kg').Mean; Switches = '{0:N0}' -f (Get-Column $g 'target_switches').Mean
		StoppedOut = '{0:N1}' -f (Get-Column $g 'stopped_not_captured').Mean; InRange = '{0:N1}' -f (Get-Column $g 'in_range_mean').Mean
		Identified = if ($g[0].PSObject.Properties['identified']) { '{0:N0}' -f (Get-Column $g 'identified').Mean } else { '' }
		BeOutUnid = if ($g[0].PSObject.Properties['be_escaped_unidentified']) { '{0:N1}' -f (Get-Column $g 'be_escaped_unidentified').Mean } else { '' }
		CV = $cv.Mean
	}
}
$table | Sort-Object Pdw, Spot, { -$_.CV } |
	Format-Table Set, Pdw, Spot, Runs, InHold, Escaped, InHoldK, EscapedK, BeIn, BeOut, BeOutUnid, Identified, DroneKg, Switches, StoppedOut, InRange -AutoSize |
	Out-String -Width 300

# Ranking: each run of -RankPdw against vanilla's run of the same spot and seed.
$vanilla = @{}
$rows | Where-Object { -not $_.candidate -and $_.pdw -eq $RankPdw } | ForEach-Object { $vanilla["$($_.spot)|$($_.seed)"] = $_ }
if ($vanilla.Count -eq 0) { Write-Warning "No vanilla runs of $RankPdw among the folders: no ranking."; return }
$rows | Where-Object { $_.candidate -and $_.pdw -eq $RankPdw } | Group-Object { Get-SetName $_ } | ForEach-Object {
	$pairs = @($_.Group | Where-Object { $vanilla.ContainsKey("$($_.spot)|$($_.seed)") })
	$dc = Get-Stat @($pairs | ForEach-Object { ([double]$_.captured_value - [double]$vanilla["$($_.spot)|$($_.seed)"].captured_value) / 1000 })
	$de = Get-Stat @($pairs | ForEach-Object { ([double]$_.escaped_value - [double]$vanilla["$($_.spot)|$($_.seed)"].escaped_value) / 1000 })
	$dn = Get-Stat @($pairs | ForEach-Object { [double]$_.captured - [double]$vanilla["$($_.spot)|$($_.seed)"].captured })
	$db = Get-Stat @($pairs | ForEach-Object { [double]$_.be_captured - [double]$vanilla["$($_.spot)|$($_.seed)"].be_captured })
	$dbo = Get-Stat @($pairs | ForEach-Object { [double]$_.be_escaped - [double]$vanilla["$($_.spot)|$($_.seed)"].be_escaped })
	$bySpot = ($pairs | Group-Object spot | Sort-Object Name | ForEach-Object {
		$s = Get-Stat @($_.Group | ForEach-Object { ([double]$_.captured_value - [double]$vanilla["$($_.spot)|$($_.seed)"].captured_value) / 1000 })
		'{0} {1:+0;-0}' -f $_.Name, $s.Mean }) -join ', '
	[pscustomobject]@{
		Set = $_.Name; Pairs = $pairs.Count; GainK = $dc.Mean
		InHoldK = '{0:+0;-0} ±{1:N0}' -f $dc.Mean, $dc.Se; BySpot = $bySpot
		InHold = '{0:+0.0;-0.0} ±{1:N1}' -f $dn.Mean, $dn.Se
		EscapedK = '{0:+0;-0} ±{1:N0}' -f $de.Mean, $de.Se
		BeIn = '{0:+0.0;-0.0} ±{1:N1}' -f $db.Mean, $db.Se
		BeOut = '{0:+0.0;-0.0} ±{1:N1}' -f $dbo.Mean, $dbo.Se
		Se = '{0:+0.0;-0.0}' -f ($dc.Mean / [math]::Max(0.001, $dc.Se))
	}
} | Sort-Object { -$_.GainK } | Format-Table Set, Pairs, InHoldK, Se, BySpot, InHold, EscapedK, BeIn, BeOut -AutoSize | Out-String -Width 300

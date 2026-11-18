#Requires -Version 7
<#
.SYNOPSIS
	Builds a mod's release zip.

.DESCRIPTION
	Packages the mod folder <Mod> into <OutDir>\<Mod>-<version>.zip, the version read from [version] of its
	Mod.manifest: the mod folder at the zip's root, with a copy of the repository's LICENSE in it (the GPL asks for one
	with every copy given out). Refuses to overwrite a zip, refuses a mod whose CHANGES.md doesn't start with that
	version, and refuses a mod whose page in the users' wiki is missing or out of date (wiki.ps1 -Mod <Mod>), or, below
	1.0.0, a mod that has a page already (it gets one at 1.0.0). Checks that
	every entry is <Mod>/... with forward slashes, as the game needs for the res:// paths (Windows PowerShell 5.1's
	Compress-Archive writes '\', hence PowerShell 7). Prints the zip's path.

.EXAMPLE
	.\package.ps1 ShipCopyPaste
	Builds ShipCopyPaste-<version>.zip in TempDir of paths.local.psd1.

.EXAMPLE
	.\package.ps1 ShipCopyPaste -VersionOnly
	Prints the manifest's version, the one the zip would have, without checking CHANGES.md: between releases its top
	section is NEXT (release.ps1 reads every mod's version this way).
#>
[CmdletBinding()]
param(
	# The mod's folder, at the repo root.
	[Parameter(Mandatory)]
	[string] $Mod,
	# Where the zip goes. Default: TempDir of paths.local.psd1 (git-ignored; paths.example.psd1 is its template).
	[string] $OutDir = '',
	# Print the version and stop.
	[switch] $VersionOnly
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = $PSScriptRoot
$folder = Join-Path $repo $Mod
$manifest = Join-Path $folder 'Mod.manifest'
if (-not (Test-Path -LiteralPath (Join-Path $folder 'ModMain.gd')) -or -not (Test-Path -LiteralPath $manifest))
{
	throw "No mod folder with ModMain.gd and Mod.manifest: $folder"
}

# The version: version_major, version_minor and version_bugfix of the manifest's [version] section.
$section = [regex]::Match((Get-Content -LiteralPath $manifest -Raw), '(?ms)^\[version\][ \t]*$(.*?)(?=^\[|\z)')
if (-not $section.Success) { throw "No [version] section in $manifest" }
$numbers = foreach ($key in 'version_major', 'version_minor', 'version_bugfix')
{
	$value = [regex]::Match($section.Groups[1].Value, "(?m)^$key[ \t]*=[ \t]*`"?(\d+)`"?[ \t]*\r?$")
	if (-not $value.Success) { throw "No $key in the [version] section of $manifest" }
	$value.Groups[1].Value
}
$version = $numbers -join '.'
if ($VersionOnly) { return $version }

$changes = Join-Path $folder 'CHANGES.md'
if (Test-Path -LiteralPath $changes)
{
	$top = [regex]::Match((Get-Content -LiteralPath $changes -Raw), '(?m)^## (.+?)[ \t]*\r?$')
	if (-not $top.Success -or $top.Groups[1].Value -ne $version)
	{
		throw "The top section of $changes is '$($top.Groups[1].Value)', not the manifest's version $version"
	}
}

# The mod's page in the users' wiki must be there and up to date from 1.0.0 on, and absent before (MODDING.md, The
# users' wiki): wiki.ps1 throws if not.
& (Join-Path $repo 'wiki.ps1') -Mod $Mod

if (-not $OutDir)
{
	$localPathsFile = Join-Path $repo 'paths.local.psd1'
	$localPaths = if (Test-Path -LiteralPath $localPathsFile) { Import-PowerShellDataFile -LiteralPath $localPathsFile } else { @{} }
	if (-not $localPaths.TempDir) { throw "Pass -OutDir, or set TempDir in $localPathsFile (copy paths.example.psd1 to it)" }
	$OutDir = $localPaths.TempDir
}
$zip = Join-Path $OutDir "$Mod-$version.zip"
if (Test-Path -LiteralPath $zip) { throw "Not overwritten, already there: $zip" }
New-Item -ItemType Directory -Force $OutDir | Out-Null

# A staged copy of the folder with the license in it, zipped by Compress-Archive as a folder, as every release so far.
$stage = Join-Path $OutDir ".stage-$Mod-$version"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
try
{
	New-Item -ItemType Directory $stage | Out-Null
	Copy-Item -LiteralPath $folder -Destination $stage -Recurse
	Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $stage $Mod)
	Compress-Archive -LiteralPath (Join-Path $stage $Mod) -DestinationPath $zip
}
finally
{
	Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}

$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try
{
	$bad = @($archive.Entries | Where-Object { $_.FullName.Contains('\') -or -not $_.FullName.StartsWith("$Mod/") } | ForEach-Object { $_.FullName })
}
finally
{
	$archive.Dispose()
}
if ($bad)
{
	Remove-Item -LiteralPath $zip
	throw "Entries the game can't load, so the zip was removed: $($bad -join ', ')"
}
$zip

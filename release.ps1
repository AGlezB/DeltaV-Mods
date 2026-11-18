#Requires -Version 7
<#
.SYNOPSIS
	Publishes on GitHub every mod whose version hasn't been released yet, and the All mods release: what
	.github\workflows\release.yml runs.

.DESCRIPTION
	For each mod folder at the repo root, reads the version of its Mod.manifest (package.ps1 -VersionOnly) and compares
	it with origin's tags, one per release:
	- below 1.0.0: skipped, since a mod's first release is its 1.0.0;
	- below the mod's newest tag: an error, since a pushed version is never rolled back;
	- a tag <Mod>-<version> exists: skipped, already released;
	- otherwise: released. package.ps1 builds the zip, with all its checks (CHANGES.md, the wiki page), and a GitHub
	  Release named "<Mod> <version>" gets the zip and, as notes, links to the mod's page in the users' wiki and to
	  Home's Installing mods, then the version's section of CHANGES.md ("First release." for 1.0.0, which has none).
	  The release creates the tag at the commit being run (GITHUB_SHA), and is never marked Latest.
	Then the All mods release, the only one marked Latest (so .../releases/latest leads to it): the newest published zip
	of every mod still in the repo, downloaded from its release (never rebuilt: a mod with changes under NEXT must not
	ship them), with a list of the mods. When the Latest release isn't an All mods release holding exactly those zips,
	a new one is made, tagged all-mods-<commit>, and every other all-mods-* release is deleted with its tag.
	One mod failing doesn't stop the others. Prints a line per mod and one for All mods; exit code 1 if any failed.
	Publishing (gh) runs only in the workflow. -DryRun does everything else, builds the zips and prints the notes: it
	shows what the next push to main would release.

.EXAMPLE
	.\release.ps1 -DryRun
	Shows what the next push would release, building its zips in a new release-<time> folder in TempDir of
	paths.local.psd1.
#>
[CmdletBinding()]
param(
	# Where the zips and notes go. Default: a new release-<time> folder in TempDir of paths.local.psd1.
	[string] $OutDir = '',
	# Build and print, publish nothing.
	[switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = $PSScriptRoot
$package = Join-Path $repo 'package.ps1'

if (-not $DryRun -and -not $env:GITHUB_ACTIONS)
{
	throw 'Publishing runs only in .github/workflows/release.yml: use -DryRun here.'
}
if (-not $OutDir)
{
	$localPathsFile = Join-Path $repo 'paths.local.psd1'
	$localPaths = if (Test-Path -LiteralPath $localPathsFile) { Import-PowerShellDataFile -LiteralPath $localPathsFile } else { @{} }
	if (-not $localPaths.TempDir) { throw "Pass -OutDir, or set TempDir in $localPathsFile (copy paths.example.psd1 to it)" }
	$OutDir = Join-Path $localPaths.TempDir "release-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}
New-Item -ItemType Directory -Force $OutDir | Out-Null

# The repository's web address, for the notes' links, and its owner/name, for the API: the workflow's, or here
# origin's.
if ($env:GITHUB_SERVER_URL -and $env:GITHUB_REPOSITORY)
{
	$repoPath = $env:GITHUB_REPOSITORY
	$repoUrl = "$($env:GITHUB_SERVER_URL)/$repoPath"
}
else
{
	$origin = git -C $repo remote get-url origin
	if ($LASTEXITCODE -ne 0) { throw 'No remote named origin.' }
	$repoUrl = $origin -replace '^git@([^:]+):', 'https://$1/' -replace '^https://[^@/]+@', 'https://' -replace '\.git$', ''
	$repoPath = ([uri] $repoUrl).AbsolutePath.Trim('/')
}
$apiUrl = if ($env:GITHUB_API_URL) { $env:GITHUB_API_URL } else { 'https://api.github.com' }

# origin's tags: every release made its own.
$refs = @(git -C $repo ls-remote --tags --refs origin)
if ($LASTEXITCODE -ne 0) { throw "Couldn't read origin's tags." }
$tags = @($refs | ForEach-Object { ($_ -split '\s+', 2)[1] -replace '^refs/tags/', '' })

# A mod's newest released version, from its tags; $null if it has none.
function Get-NewestRelease([string] $Name)
{
	$tags |
		ForEach-Object { if ($_ -cmatch "^$([regex]::Escape($Name))-(\d+\.\d+\.\d+)$") { [version] $Matches[1] } } |
		Sort-Object | Select-Object -Last 1
}

# The notes of a mod's release: links for players, then what changed.
function Get-Notes([string] $Name, [string] $Version)
{
	$links = "What the mod does, with pictures: [its page in the wiki]($repoUrl/wiki/$Name). " +
		"How to install it: [Installing mods]($repoUrl/wiki/Home#installing-mods)."
	$changes = Join-Path $repo $Name 'CHANGES.md'
	$section = if (Test-Path -LiteralPath $changes)
	{
		[regex]::Match((Get-Content -LiteralPath $changes -Raw), "(?ms)^## $([regex]::Escape($Version))[ \t]*\r?\n(.*?)(?=^## |\z)")
	}
	if ($section -and $section.Success) { return "$links`n`n## What changed`n`n$($section.Groups[1].Value.Trim())`n" }
	if ($Version -eq '1.0.0') { return "$links`n`nFirst release.`n" }
	throw "No section for $Version in $changes"
}

# The notes of the All mods release: what it is, then one line per mod, with the description of its Mod.manifest.
function Get-BundleNotes($Entries)
{
	$lines = foreach ($entry in $Entries)
	{
		$manifest = Get-Content -LiteralPath (Join-Path $repo $entry.Name 'Mod.manifest') -Raw
		$description = [regex]::Match($manifest, '(?m)^description[ \t]*=[ \t]*"(.*)"[ \t]*\r?$').Groups[1].Value
		"- [$($entry.Name)]($repoUrl/wiki/$($entry.Name)) [$($entry.Version)]($repoUrl/releases/tag/$($entry.Tag))" +
			$(if ($description) { ": $description" })
	}
	"The newest version of every mod. Download the zips of the mods you want from *Assets* below, and follow " +
		"[Installing mods]($repoUrl/wiki/Home#installing-mods). Each mod's page in the wiki says what it does, with " +
		"pictures, and each mod's own release says what changed in it.`n`n" + ($lines -join "`n") + "`n"
}

$results = [Collections.Generic.List[string]]::new()
$failed = $false
# What All mods holds: per mod, the version released now (or that would be, in a dry run), else its newest release.
$bundle = [Collections.Generic.List[object]]::new()
$mods = Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
	$_.Name -notmatch '^[_.]' -and
	(Test-Path -LiteralPath (Join-Path $_.FullName 'ModMain.gd')) -and
	(Test-Path -LiteralPath (Join-Path $_.FullName 'Mod.manifest'))
} | Sort-Object Name

foreach ($name in $mods.Name)
{
	$newest = $null
	$released = $null
	try
	{
		$version = & $package -Mod $name -VersionOnly
		$tag = "$name-$version"
		$newest = Get-NewestRelease $name
		if ([version] $version -lt [version] '1.0.0')
		{
			$results.Add("${name} ${version}: skipped, below 1.0.0")
		}
		elseif ($newest -and $newest -gt [version] $version)
		{
			throw "$version is below its newest release, ${newest}: a pushed version is never rolled back"
		}
		elseif ($tags -ccontains $tag)
		{
			$results.Add("${name} ${version}: skipped, already released")
		}
		else
		{
			$zip = & $package -Mod $name -OutDir $OutDir
			$notes = Get-Notes $name $version
			$notesFile = Join-Path $OutDir "$tag.md"
			Set-Content -LiteralPath $notesFile -Value $notes -NoNewline
			if ($DryRun)
			{
				Write-Host "--- The notes of $tag ---`n$notes"
				$results.Add("${name} ${version}: would be released, $zip")
			}
			else
			{
				gh release create $tag $zip --target $env:GITHUB_SHA --title "$name $version" --notes-file $notesFile --latest=false
				if ($LASTEXITCODE -ne 0) { throw "gh release create failed with exit code $LASTEXITCODE" }
				$results.Add("${name} ${version}: released")
			}
			$released = [version] $version
		}
	}
	catch
	{
		$failed = $true
		$results.Add("${name}: FAILED, $($_.Exception.Message)")
		if ($env:GITHUB_ACTIONS) { Write-Host "::error::${name}: $($_.Exception.Message)" }
	}
	$shipped = if ($released) { $released } else { $newest }
	if ($shipped) { $bundle.Add([pscustomobject] @{ Name = $name; Version = "$shipped"; Tag = "$name-$shipped" }) }
}

# The All mods release, the only one marked Latest.
try
{
	$expected = @($bundle | ForEach-Object { "$($_.Tag).zip" } | Sort-Object)
	# With curl, not Invoke-RestMethod: pwsh's own web access trips some machines' firewalls. PowerShell 7 has no curl
	# alias, so this is the curl program on Windows and Linux alike.
	$headers = @('-H', 'Accept: application/vnd.github+json')
	if ($env:GH_TOKEN) { $headers += '-H', "Authorization: Bearer $($env:GH_TOKEN)" }
	$body = Join-Path $OutDir 'latest-release.json'
	$status = curl -sS -o $body -w '%{http_code}' @headers "$apiUrl/repos/$repoPath/releases/latest"
	if ($LASTEXITCODE -ne 0) { throw "Couldn't read the latest release: curl exit code $LASTEXITCODE" }
	$latest = switch ($status)
	{
		'200' { Get-Content -LiteralPath $body -Raw | ConvertFrom-Json }
		'404' { $null }
		default { throw "Couldn't read the latest release: HTTP $status" }
	}

	if (-not $expected)
	{
		$results.Add('All mods: no mod released yet')
	}
	elseif ($latest -and $latest.tag_name -clike 'all-mods-*' -and
		((@($latest.assets.name) | Sort-Object) -join '|') -ceq ($expected -join '|'))
	{
		$results.Add("All mods: up to date ($($latest.tag_name))")
	}
	else
	{
		$notes = Get-BundleNotes $bundle
		if ($DryRun)
		{
			Write-Host "--- The notes of All mods ---`n$notes"
			$results.Add("All mods: would be made anew, with $($expected.Count) zips")
		}
		else
		{
			$bundleTag = "all-mods-$($env:GITHUB_SHA.Substring(0, 7))"
			$dir = Join-Path $OutDir 'all-mods'
			New-Item -ItemType Directory -Force $dir | Out-Null
			foreach ($entry in $bundle)
			{
				gh release download $entry.Tag --pattern "$($entry.Tag).zip" --dir $dir
				if ($LASTEXITCODE -ne 0) { throw "Couldn't download $($entry.Tag).zip: gh exit code $LASTEXITCODE" }
			}
			$notesFile = Join-Path $OutDir 'all-mods.md'
			Set-Content -LiteralPath $notesFile -Value $notes -NoNewline
			$bundleTags = @($tags | Where-Object { $_ -clike 'all-mods-*' })
			# A rerun on the same commit: its All mods goes first, so that the tag can be made again.
			if ($bundleTags -ccontains $bundleTag)
			{
				gh release delete $bundleTag --cleanup-tag --yes
				if ($LASTEXITCODE -ne 0) { throw "Couldn't delete $bundleTag before making it anew: gh exit code $LASTEXITCODE" }
			}
			$zips = @($bundle | ForEach-Object { Join-Path $dir "$($_.Tag).zip" })
			gh release create $bundleTag @zips --target $env:GITHUB_SHA --title 'All mods' --notes-file $notesFile --latest
			if ($LASTEXITCODE -ne 0) { throw "gh release create failed with exit code $LASTEXITCODE" }
			foreach ($old in $bundleTags | Where-Object { $_ -cne $bundleTag })
			{
				gh release delete $old --cleanup-tag --yes
				if ($LASTEXITCODE -ne 0) { throw "$bundleTag is out, but $old couldn't be deleted: gh exit code $LASTEXITCODE" }
			}
			$results.Add("All mods: released as $bundleTag, with $($zips.Count) zips")
		}
	}
}
catch
{
	$failed = $true
	$results.Add("All mods: FAILED, $($_.Exception.Message)")
	if ($env:GITHUB_ACTIONS) { Write-Host "::error::All mods: $($_.Exception.Message)" }
}

$results
if ($failed) { exit 1 }

#Requires -Version 7
<#
.SYNOPSIS
	Checks the users' wiki (_wiki\) against the mods.

.DESCRIPTION
	Every mod page of _wiki\ ends with a hidden values block (<!-- wiki-values ... -->) listing what the page shows
	that can go stale: the mods' constants and on-screen texts, and the base game's values (MODDING.md, The users'
	wiki). This script checks that:
	- every constant and text listed still has the value written there;
	- every number in a page's text is listed, and every listed value is shown, in the text or an image;
	- every setting a mod describes (its Settings.gd, a Tuning entry it registers) is listed;
	- every mod has a page, linked from Home and the sidebar, and every page a mod; a page explains how the mod changes
	  the game exactly when its README has a Warning;
	- links between pages resolve, and every image exists, is used, and is a PNG of at most 2 MB.
	It reads only the repository, so it also runs in CI (.github\workflows\wiki.yml), and package.ps1 runs it for the
	mod it packages. Problems are listed, then thrown as one error; nothing is written to the output stream.

.EXAMPLE
	.\wiki.ps1
	Checks the whole wiki.

.EXAMPLE
	.\wiki.ps1 -Mod DiveSkipTransit
	Checks only DiveSkipTransit's page, and that Home and the sidebar link it.
#>
[CmdletBinding()]
param(
	# Check only this mod's page.
	[string] $Mod = ''
)

$ErrorActionPreference = 'Stop'

#region The GDScript literals the wiki can cite

# A parsed value: a literal (dict, array, string, number, bool, null), a constant's name (ref), a call such as
# Color(1, 0.5, 0) (call), or anything else, kept as its text (expr).
class GdNode
{
	[string] $Kind
	[object] $Value
	[string] $Name
	[string] $Text
}

# Parses the values of GDScript constants: literals, possibly over several lines, with comments and trailing commas.
class GdParser
{
	static [regex] $Number = [regex]::new('\G[-+]?(?:0x[0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)')
	static [regex] $Ident = [regex]::new('\G[A-Za-z_]\w*')

	[string] $S
	[int] $P

	GdParser([string] $s, [int] $p)
	{
		$this.S = $s
		$this.P = $p
	}

	[char] Peek()
	{
		if ($this.P -ge $this.S.Length) { return [char]0 }
		return $this.S[$this.P]
	}

	# Skips blanks and comments, and line breaks too inside brackets.
	[void] Skip([bool] $newlines)
	{
		while ($this.P -lt $this.S.Length)
		{
			$c = $this.S[$this.P]
			if ($c -eq [char]'#')
			{
				while ($this.P -lt $this.S.Length -and $this.S[$this.P] -ne [char]"`n") { $this.P++ }
			}
			elseif ($c -eq [char]' ' -or $c -eq [char]"`t" -or $c -eq [char]"`r" -or ($newlines -and $c -eq [char]"`n"))
			{
				$this.P++
			}
			elseif ($c -eq [char]'\' -and $this.P + 1 -lt $this.S.Length -and ($this.S[$this.P + 1] -eq [char]"`n" -or $this.S[$this.P + 1] -eq [char]"`r"))
			{
				$this.P += 2
			}
			else
			{
				break
			}
		}
	}

	# One value, up to the next , ] } ) or : and, outside brackets, the end of the line. A value followed by anything
	# else (an operator) is an expression, kept as its text.
	[GdNode] Element([bool] $inBrackets)
	{
		$this.Skip($inBrackets)
		$start = $this.P
		$node = $null
		try
		{
			$node = $this.Primary()
		}
		catch
		{
			$node = $null
		}
		if ($null -ne $node)
		{
			$this.Skip($inBrackets)
			$c = $this.Peek()
			if ($c -eq [char]0 -or ',])}:'.Contains($c) -or (-not $inBrackets -and ($c -eq [char]"`n" -or $c -eq [char]';')))
			{
				$node.Text = $this.S.Substring($start, $this.P - $start).Trim()
				return $node
			}
		}
		$this.P = $start
		$this.SkipExpression($inBrackets)
		$expr = [GdNode]::new()
		$expr.Kind = 'expr'
		$expr.Text = $this.S.Substring($start, $this.P - $start).Trim()
		return $expr
	}

	[void] SkipExpression([bool] $inBrackets)
	{
		$depth = 0
		while ($this.P -lt $this.S.Length)
		{
			$c = $this.S[$this.P]
			if ($c -eq [char]'"' -or $c -eq [char]"'")
			{
				$null = $this.ReadString()
				continue
			}
			if ($c -eq [char]'#')
			{
				$this.Skip($false)
				continue
			}
			if ('([{'.Contains($c))
			{
				$depth++
			}
			elseif (')]}'.Contains($c))
			{
				if ($depth -eq 0) { return }
				$depth--
			}
			elseif ($depth -eq 0 -and ($c -eq [char]',' -or (-not $inBrackets -and ($c -eq [char]"`n" -or $c -eq [char]';'))))
			{
				return
			}
			$this.P++
		}
	}

	[GdNode] Primary()
	{
		$c = $this.Peek()
		$node = [GdNode]::new()
		if ($c -eq [char]'{')
		{
			$this.P++
			$node.Kind = 'dict'
			$items = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
			while ($true)
			{
				$this.Skip($true)
				if ($this.Peek() -eq [char]'}')
				{
					$this.P++
					break
				}
				$key = $null
				$k = $this.Peek()
				if ($k -eq [char]'"' -or $k -eq [char]"'")
				{
					$key = $this.ReadString()
					$this.Skip($true)
					if ($this.Peek() -ne [char]':') { throw 'expected :' }
				}
				else
				{
					$m = [GdParser]::Ident.Match($this.S, $this.P)
					if (-not $m.Success) { throw 'expected a key' }
					$key = $m.Value
					$this.P += $m.Length
					$this.Skip($true)
					if ($this.Peek() -ne [char]'=' -and $this.Peek() -ne [char]':') { throw 'expected = or :' }
				}
				$this.P++
				$items[$key] = $this.Element($true)
				$this.Skip($true)
				if ($this.Peek() -eq [char]',') { $this.P++ }
				elseif ($this.Peek() -ne [char]'}') { throw 'expected , or }' }
			}
			$node.Value = $items
			return $node
		}
		if ($c -eq [char]'[')
		{
			$this.P++
			$node.Kind = 'array'
			$node.Value = $this.Items([char]']')
			return $node
		}
		if ($c -eq [char]'"' -or $c -eq [char]"'")
		{
			$node.Kind = 'string'
			$node.Value = $this.ReadString()
			return $node
		}
		$m = [GdParser]::Number.Match($this.S, $this.P)
		if ($m.Success)
		{
			$this.P += $m.Length
			$node.Kind = 'number'
			$hex = [regex]::Match($m.Value, '^([-+]?)0x([0-9a-fA-F]+)$')
			if ($hex.Success)
			{
				$v = [double][Convert]::ToInt64($hex.Groups[2].Value, 16)
				$node.Value = if ($hex.Groups[1].Value -eq '-') { -$v } else { $v }
			}
			else
			{
				$node.Value = [double]::Parse($m.Value, [Globalization.CultureInfo]::InvariantCulture)
			}
			return $node
		}
		$m = [GdParser]::Ident.Match($this.S, $this.P)
		if ($m.Success)
		{
			$this.P += $m.Length
			$name = $m.Value
			if ($name -ceq 'true' -or $name -ceq 'false')
			{
				$node.Kind = 'bool'
				$node.Value = $name -ceq 'true'
				return $node
			}
			if ($name -ceq 'null')
			{
				$node.Kind = 'null'
				return $node
			}
			$after = $this.P
			$this.Skip($false)
			if ($this.Peek() -eq [char]'(')
			{
				$this.P++
				$node.Kind = 'call'
				$node.Name = $name
				$node.Value = $this.Items([char]')')
				return $node
			}
			$this.P = $after
			$node.Kind = 'ref'
			$node.Value = $name
			return $node
		}
		throw 'unexpected character'
	}

	# The items of an array or a call's arguments, up to the closing bracket.
	[System.Collections.Generic.List[object]] Items([char] $close)
	{
		$list = [System.Collections.Generic.List[object]]::new()
		while ($true)
		{
			$this.Skip($true)
			if ($this.Peek() -eq $close)
			{
				$this.P++
				break
			}
			$list.Add($this.Element($true))
			$this.Skip($true)
			if ($this.Peek() -eq [char]',') { $this.P++ }
			elseif ($this.Peek() -ne $close) { throw "expected , or $close" }
		}
		return $list
	}

	[string] ReadString()
	{
		$quote = $this.S[$this.P]
		$this.P++
		$sb = [Text.StringBuilder]::new()
		while ($this.P -lt $this.S.Length)
		{
			$c = $this.S[$this.P]
			if ($c -eq $quote)
			{
				$this.P++
				return $sb.ToString()
			}
			if ($c -eq [char]'\' -and $this.P + 1 -lt $this.S.Length)
			{
				$n = $this.S[$this.P + 1]
				$this.P += 2
				if ($n -ceq [char]'n') { $null = $sb.Append("`n") }
				elseif ($n -ceq [char]'t') { $null = $sb.Append("`t") }
				elseif ($n -ceq [char]'r') { $null = $sb.Append("`r") }
				elseif ($n -ceq [char]'u' -and $this.P + 4 -le $this.S.Length)
				{
					$null = $sb.Append([char][Convert]::ToInt32($this.S.Substring($this.P, 4), 16))
					$this.P += 4
				}
				else { $null = $sb.Append($n) }
				continue
			}
			$null = $sb.Append($c)
			$this.P++
		}
		throw 'unterminated string'
	}
}

$script:constants = @{}

# The top-level constants of a .gd file, by name.
function Get-Constants([string] $File)
{
	if (-not $script:constants.ContainsKey($File))
	{
		$text = Get-Content -LiteralPath $File -Raw
		$found = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
		foreach ($m in [regex]::Matches($text, '(?m)^const[ \t]+([A-Za-z_]\w*)[ \t]*(?::[ \t]*[A-Za-z_]\w*[ \t]*)?=(?!=)'))
		{
			$found[$m.Groups[1].Value] = [GdParser]::new($text, $m.Index + $m.Length).Element($false)
		}
		$script:constants[$File] = $found
	}
	return $script:constants[$File]
}

# A value with the constants it names followed.
function Resolve-Ref($Node, $Consts)
{
	$seen = 0
	while ($Node.Kind -ceq 'ref')
	{
		if (++$seen -gt 32) { throw "constants that name each other in a loop: $($Node.Value)" }
		if (-not $Consts.ContainsKey($Node.Value)) { throw "$($Node.Value) is not a constant of the file" }
		$Node = $Consts[$Node.Value]
	}
	return $Node
}

# The value at a constant path: NAME, NAME.key, NAME[0], and so on.
function Get-PathValue($Consts, [string] $Path)
{
	# A key may have dashes (the game's ship model keys, such as TRTL-LCB).
	$m = [regex]::Match($Path, '^([A-Za-z_]\w*)((?:\.[A-Za-z_][\w-]*|\[\d+\])*)$')
	if (-not $m.Success) { throw "'$Path' is not a constant path (NAME, NAME.key or NAME[0])" }
	$name = $m.Groups[1].Value
	if (-not $Consts.ContainsKey($name)) { throw "no constant $name" }
	$node = Resolve-Ref $Consts[$name] $Consts
	$where = $name
	foreach ($step in [regex]::Matches($m.Groups[2].Value, '\.([A-Za-z_][\w-]*)|\[(\d+)\]'))
	{
		if ($step.Groups[1].Success)
		{
			$key = $step.Groups[1].Value
			if ($node.Kind -cne 'dict' -or -not $node.Value.Contains($key)) { throw "no key $key in $where" }
			$node = Resolve-Ref $node.Value[$key] $Consts
		}
		else
		{
			$i = [int]$step.Groups[2].Value
			if ($node.Kind -cne 'array' -or $i -ge $node.Value.Count) { throw "no item [$i] in $where" }
			$node = Resolve-Ref $node.Value[$i] $Consts
		}
		$where += $step.Value
	}
	return $node
}

# Whether a value of the code ($Code, constants followed) equals one written in the wiki ($Wiki).
function Test-SameValue($Code, $Wiki, $Consts)
{
	$Code = Resolve-Ref $Code $Consts
	if ($Code.Kind -ceq 'expr' -or ($Code.Kind -ceq 'call' -and $Code.Name -cnotmatch '^[A-Z]'))
	{
		throw "not a value the wiki can cite: $($Code.Text) (make it a literal or a constant)"
	}
	if ($Code.Kind -cne $Wiki.Kind) { return $false }
	switch -CaseSensitive ($Code.Kind)
	{
		'number'
		{
			$scale = [math]::Max(1, [math]::Max([math]::Abs($Code.Value), [math]::Abs($Wiki.Value)))
			return [math]::Abs($Code.Value - $Wiki.Value) -le 1e-9 * $scale
		}
		'string' { return $Code.Value -ceq $Wiki.Value }
		'bool' { return $Code.Value -eq $Wiki.Value }
		'null' { return $true }
		'dict'
		{
			if ($Code.Value.Count -ne $Wiki.Value.Count) { return $false }
			foreach ($key in $Code.Value.Keys)
			{
				if (-not $Wiki.Value.Contains($key) -or -not (Test-SameValue $Code.Value[$key] $Wiki.Value[$key] $Consts)) { return $false }
			}
			return $true
		}
		default
		{
			# array, call
			if ($Code.Name -cne $Wiki.Name -or $Code.Value.Count -ne $Wiki.Value.Count) { return $false }
			for ($i = 0; $i -lt $Code.Value.Count; $i++)
			{
				if (-not (Test-SameValue $Code.Value[$i] $Wiki.Value[$i] $Consts)) { return $false }
			}
			return $true
		}
	}
}

# A value written back as GDScript, constants followed.
function Format-Value($Node, $Consts)
{
	$Node = Resolve-Ref $Node $Consts
	switch -CaseSensitive ($Node.Kind)
	{
		'number' { return ([double]$Node.Value).ToString('R', [Globalization.CultureInfo]::InvariantCulture) }
		'string' { return '"' + $Node.Value.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n') + '"' }
		'bool' { return $Node.Value ? 'true' : 'false' }
		'null' { return 'null' }
		'array' { return '[' + (@($Node.Value | ForEach-Object { Format-Value $_ $Consts }) -join ', ') + ']' }
		'call' { return $Node.Name + '(' + (@($Node.Value | ForEach-Object { Format-Value $_ $Consts }) -join ', ') + ')' }
		'dict' { return '{' + (@($Node.Value.Keys | ForEach-Object { "`"$_`": " + (Format-Value $Node.Value[$_] $Consts) }) -join ', ') + '}' }
		default { return $Node.Text }
	}
}

$script:poTexts = @{}

# The texts of a .po file, by key.
function Get-PoTexts([string] $File)
{
	if (-not $script:poTexts.ContainsKey($File))
	{
		$texts = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
		$id = $null
		$str = $null
		$field = ''
		foreach ($line in Get-Content -LiteralPath $File)
		{
			$t = $line.Trim()
			$m = [regex]::Match($t, '^(msgid|msgstr)\s+(".*")$')
			if ($m.Success)
			{
				$part = [GdParser]::new($m.Groups[2].Value, 0).ReadString()
				if ($m.Groups[1].Value -eq 'msgid')
				{
					if ($null -ne $id -and $null -ne $str) { $texts[$id] = $str }
					$id = $part
					$str = $null
					$field = 'id'
				}
				else
				{
					$str = $part
					$field = 'str'
				}
			}
			elseif ($t.StartsWith('"'))
			{
				$part = [GdParser]::new($t, 0).ReadString()
				if ($field -eq 'id') { $id += $part } elseif ($field -eq 'str') { $str += $part }
			}
		}
		if ($null -ne $id -and $null -ne $str) { $texts[$id] = $str }
		$script:poTexts[$File] = $texts
	}
	return $script:poTexts[$File]
}

#endregion

#region The pages

$repo = $PSScriptRoot
$wiki = Join-Path $repo '_wiki'
$imagesDir = Join-Path $wiki 'images'
$specialPages = @('Home', '_Sidebar', '_Footer')
$imageMaxBytes = 2MB # the wiki repository keeps every version of every image
$script:problems = [System.Collections.Generic.List[string]]::new()
$inActions = $env:GITHUB_ACTIONS -eq 'true'

function Add-Problem([string] $File, [int] $Line, [string] $Message)
{
	$rel = [IO.Path]::GetRelativePath($repo, $File).Replace('\', '/')
	$where = if ($Line -gt 0) { "${rel}:$Line" } else { $rel }
	$script:problems.Add("${where}: $Message")
	Write-Host "${where}: $Message" -ForegroundColor Red
	if ($inActions)
	{
		$text = $Message.Replace('%', '%25').Replace("`r", '').Replace("`n", '%0A')
		$at = if ($Line -gt 0) { "file=$rel,line=$Line" } else { "file=$rel" }
		Write-Host "::error ${at}::$text"
	}
}

# Whether a path relative to $Root exists with exactly that spelling, as on GitHub's case-sensitive servers.
function Test-ExactPath([string] $Root, [string] $Relative)
{
	$dir = $Root
	foreach ($part in $Relative.Split('/'))
	{
		if (-not $part -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return $false }
		$match = Get-ChildItem -LiteralPath $dir -Force | Where-Object { $_.Name -ceq $part }
		if (-not $match) { return $false }
		$dir = $match.FullName
	}
	return $true
}

# GitHub's anchor for a heading.
function Get-Slug([string] $Heading)
{
	return ([regex]::Replace($Heading.ToLowerInvariant(), '[^\p{L}\p{N} _-]', '')).Replace(' ', '-')
}

# Numbers as the wiki writes them: 10, 4.5, -50, 1,000. Not the digits of names (OCP-209, K37) or versions (1.92.5).
$numberPattern = '(?<![\p{L}\d.,\-/−])[-+−]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?(?!\d)(?!\.\d)(?!,\d{3})'

function Get-Numbers([string] $Text)
{
	foreach ($m in [regex]::Matches($Text, $numberPattern))
	{
		[math]::Round([double]::Parse($m.Value.Replace(',', '').Replace([string][char]0x2212, '-').TrimStart('+'), [Globalization.CultureInfo]::InvariantCulture), 9)
	}
}

# A page's lines, its values block and its prose (the lines outside the block, without code, link targets, URLs and
# HTML), each prose line with its number.
function Read-Page([string] $File)
{
	$lines = @(Get-Content -LiteralPath $File)
	$page = [pscustomobject]@{ File = $File; Lines = $lines; Entries = [System.Collections.Generic.List[object]]::new(); Prose = [System.Collections.Generic.List[object]]::new(); HasBlock = $false }
	$inBlock = $false
	for ($i = 0; $i -lt $lines.Count; $i++)
	{
		$n = $i + 1
		$line = $lines[$i]
		if (-not $inBlock -and $line -match '^\s*<!--\s*wiki-values\b')
		{
			$inBlock = $true
			$page.HasBlock = $true
			continue
		}
		if ($inBlock)
		{
			if ($line -match '-->') { $inBlock = $false; continue }
			$t = $line.Trim()
			if (-not $t) { continue }
			$entry = Read-Entry $t
			if ($entry -is [string]) { Add-Problem $File $n $entry; continue }
			$entry | Add-Member -NotePropertyName Line -NotePropertyValue $n
			$page.Entries.Add($entry)
			continue
		}
		$p = $line -replace '<!--.*?-->', '' -replace '`[^`]*`', '' -replace '\]\([^)]*\)', ']' -replace 'https?://\S+', '' -replace '<[^>]+>', '' -replace '^\s*\d+\.\s+', '' -replace '\\([\\`*_{}\[\]()#+\-.!|])', '$1'
		$page.Prose.Add([pscustomobject]@{ Line = $n; Text = $p })
	}
	if ($inBlock) { Add-Problem $File 0 'the values block is never closed (-->)' }
	return $page
}

# Splits $Text at the first (or last) $Separator outside quotes.
function Split-Outside([string] $Text, [string] $Separator, [switch] $Last)
{
	$found = -1
	$quote = [char]0
	for ($i = 0; $i -lt $Text.Length; $i++)
	{
		$c = $Text[$i]
		if ($quote -ne [char]0)
		{
			if ($c -eq [char]'\') { $i++ }
			elseif ($c -eq $quote) { $quote = [char]0 }
			continue
		}
		if ($c -eq [char]'"' -or $c -eq [char]"'") { $quote = $c; continue }
		if ([string]::CompareOrdinal($Text, $i, $Separator, 0, $Separator.Length) -eq 0)
		{
			$found = $i
			if (-not $Last) { break }
		}
	}
	if ($found -lt 0) { return @($Text, $null) }
	return @($Text.Substring(0, $found).Trim(), $Text.Substring($found + $Separator.Length).Trim())
}

# One line of a values block, or the reason it can't be read.
function Read-Entry([string] $Text)
{
	$m = [regex]::Match($Text, '^(game-checked|game|note):\s*(.*)$')
	if ($m.Success)
	{
		return [pscustomobject]@{ Kind = $m.Groups[1].Value; Text = $m.Groups[2].Value }
	}
	$m = [regex]::Match($Text, '^(\S+)\s+(\S+)\s+=\s+(.+)$')
	if (-not $m.Success)
	{
		return "can't read this values line; expected '<file> <constant or text key> = <value> [-> <as shown>] [| <images>]', 'game: …', 'note: …' or 'game-checked: <version>'"
	}
	$value, $images = Split-Outside $m.Groups[3].Value ' | ' -Last
	$value, $shown = Split-Outside $value ' -> '
	return [pscustomobject]@{
		Kind = 'value'
		File = $m.Groups[1].Value
		Path = $m.Groups[2].Value
		Value = $value
		Shown = $shown
		Images = @(if ($images) { $images.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } })
	}
}

# The link targets of a page's images, with their line numbers.
function Get-ImageLinks($Page)
{
	for ($i = 0; $i -lt $Page.Lines.Count; $i++)
	{
		foreach ($m in [regex]::Matches($Page.Lines[$i], '!\[[^\]]*\]\(\s*([^)\s]+)'))
		{
			[pscustomobject]@{ Line = $i + 1; Target = $m.Groups[1].Value }
		}
	}
}

$script:usedImages = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

# An image a page shows or a values line names: images/<file> of _wiki.
function Test-ImageTarget([string] $File, [int] $Line, [string] $Target)
{
	if ($Target -cnotmatch '^images/[^/]+$')
	{
		Add-Problem $File $Line "image '$Target': a page's images are images/<file>.png, in _wiki"
		return
	}
	$path = "_wiki/$Target"
	if (-not (Test-ExactPath $repo $path))
	{
		Add-Problem $File $Line "image '$Target': no file $path (spelling counts)"
		return
	}
	$null = $script:usedImages.Add($path)
}

# Links to other pages ([text](Page), [text](Page#anchor), [text](#anchor)): the page and the heading must exist.
function Test-PageLinks($Page)
{
	for ($i = 0; $i -lt $Page.Lines.Count; $i++)
	{
		foreach ($m in [regex]::Matches($Page.Lines[$i], '(?<!!)\[[^\]]*\]\(\s*([^)\s]*)\s*\)'))
		{
			$target = $m.Groups[1].Value
			$t = [regex]::Match($target, '^([A-Za-z_][\w-]*)?(?:#([\w-]+))?$')
			if (-not $t.Success -or $target -match '^[a-z]+:') { continue }
			$name = if ($t.Groups[1].Success) { $t.Groups[1].Value } else { [IO.Path]::GetFileNameWithoutExtension($Page.File) }
			if (-not (Test-ExactPath $wiki "$name.md"))
			{
				Add-Problem $Page.File ($i + 1) "link to '$target': no page $name"
				continue
			}
			if ($t.Groups[2].Success)
			{
				$slugs = @(Get-Content -LiteralPath (Join-Path $wiki "$name.md") | Where-Object { $_ -match '^#{1,6}\s' } | ForEach-Object { Get-Slug ($_ -replace '^#{1,6}\s+', '').Trim() })
				if ($slugs -cnotcontains $t.Groups[2].Value) { Add-Problem $Page.File ($i + 1) "link to '$target': $name has no heading with that anchor" }
			}
		}
	}
}

# What a mod's page must list: each setting its Settings.gd describes (default, range, the text of its label) and
# each Tuning entry it registers (the constants of its default and range, the text of its key).
function Get-Required([string] $ModName)
{
	$required = [System.Collections.Generic.List[object]]::new()
	$po = "$ModName/i18n/en.po"
	$settings = "$ModName/Settings.gd"
	if (Test-ExactPath $repo $settings)
	{
		$consts = Get-Constants (Join-Path $repo $settings)
		$described = foreach ($name in $consts.Keys)
		{
			$node = Resolve-Ref $consts[$name] $consts
			if ($node.Kind -cne 'dict') { continue }
			if ($node.Value.Contains('label'))
			{
				[pscustomobject]@{ Path = $name; Node = $node }
				continue
			}
			foreach ($key in $node.Value.Keys)
			{
				$item = Resolve-Ref $node.Value[$key] $consts
				if ($item.Kind -ceq 'dict' -and $item.Value.Contains('label')) { [pscustomobject]@{ Path = "$name.$key"; Node = $item } }
			}
		}
		foreach ($setting in $described)
		{
			foreach ($field in 'default', 'min', 'max')
			{
				if ($setting.Node.Value.Contains($field)) { $required.Add([pscustomobject]@{ File = $settings; Path = "$($setting.Path).$field" }) }
			}
			$label = Resolve-Ref $setting.Node.Value['label'] $consts
			if ($label.Kind -ceq 'string') { $required.Add([pscustomobject]@{ File = $po; Path = $label.Value }) }
		}
	}
	foreach ($gd in Get-ChildItem -LiteralPath (Join-Path $repo $ModName) -Filter '*.gd' -File)
	{
		$file = "$ModName/$($gd.Name)"
		$text = Get-Content -LiteralPath $gd.FullName -Raw
		$consts = Get-Constants $gd.FullName
		foreach ($m in [regex]::Matches($text, 'registerSubsystem\s*\('))
		{
			$parser = [GdParser]::new($text, $m.Index + $m.Length)
			$key = $parser.Element($true)
			$parser.Skip($true)
			if ($parser.Peek() -ne [char]',') { continue }
			$parser.P++
			$entry = $parser.Element($true)
			if ($entry.Kind -cne 'dict' -or -not $entry.Value.Contains('default')) { continue }
			foreach ($field in 'default', 'min', 'max')
			{
				if (-not $entry.Value.Contains($field)) { continue }
				$v = $entry.Value[$field]
				if ($v.Kind -ceq 'ref') { $required.Add([pscustomobject]@{ File = $file; Path = $v.Value }) }
				else { Add-Problem $gd.FullName 0 "the Tuning entry's $field is written inline ($($v.Text)): make it a constant, so the wiki can list it" }
			}
			try
			{
				$k = Resolve-Ref $key $consts
				if ($k.Kind -ceq 'string') { $required.Add([pscustomobject]@{ File = $po; Path = $k.Value }) }
			}
			catch
			{
				Add-Problem $gd.FullName 0 "can't tell the key of a Tuning entry ($($key.Text)): $($_.Exception.Message)"
			}
		}
	}
	return , $required
}

# Checks one mod's page; returns it, read, or $null when it's missing.
function Test-ModPage([string] $ModName)
{
	$file = Join-Path $wiki "$ModName.md"
	if (-not (Test-ExactPath $wiki "$ModName.md"))
	{
		Add-Problem $file 0 "$ModName has no wiki page: every mod needs one before it can be packaged"
		return $null
	}
	$page = Read-Page $file
	if (-not $page.HasBlock) { Add-Problem $file 0 'no values block (<!-- wiki-values ... -->) at the end of the page' }

	# The prose's numbers, and its text for the texts that must be shown.
	$proseNumbers = [System.Collections.Generic.HashSet[double]]::new()
	foreach ($p in $page.Prose) { foreach ($n in Get-Numbers $p.Text) { $null = $proseNumbers.Add($n) } }
	$proseText = (($page.Prose | ForEach-Object { $_.Text }) -join ' ') -replace '\s+', ' '

	$listed = [System.Collections.Generic.HashSet[double]]::new()
	$cited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
	$gameChecked = $null
	foreach ($e in $page.Entries)
	{
		if ($e.Kind -ne 'value')
		{
			if ($e.Kind -eq 'game-checked')
			{
				if ($e.Text -notmatch '^\d+(\.\d+)+$') { Add-Problem $file $e.Line "game-checked: '$($e.Text)' is not a game version" }
				$gameChecked = $e.Text
			}
			else
			{
				foreach ($n in Get-Numbers $e.Text) { $null = $listed.Add($n) }
			}
			continue
		}
		$null = $cited.Add("$($e.File) $($e.Path)")
		$shownText = if ($null -ne $e.Shown) { $e.Shown } else { $e.Value }
		foreach ($n in Get-Numbers $shownText) { $null = $listed.Add($n) }
		foreach ($image in $e.Images) { Test-ImageTarget $file $e.Line $image }

		if (-not (Test-ExactPath $repo $e.File))
		{
			Add-Problem $file $e.Line "no file $($e.File) (spelling counts)"
			continue
		}
		$full = Join-Path $repo $e.File
		$wikiValue = $null
		try
		{
			$parser = [GdParser]::new($e.Value, 0)
			$wikiValue = $parser.Element($false)
			if ($wikiValue.Kind -in 'ref', 'expr') { throw 'write the value itself, as a literal' }
		}
		catch
		{
			Add-Problem $file $e.Line "can't read the value '$($e.Value)': $($_.Exception.Message)"
			continue
		}
		$same = $false
		$now = $null
		try
		{
			if ($e.File.EndsWith('.po'))
			{
				$texts = Get-PoTexts $full
				if (-not $texts.ContainsKey($e.Path)) { throw "no text $($e.Path) in $($e.File)" }
				if ($wikiValue.Kind -cne 'string') { throw 'a text is written as a string, in quotes' }
				$same = $texts[$e.Path] -ceq $wikiValue.Value
				$now = Format-Value ([GdNode]@{ Kind = 'string'; Value = $texts[$e.Path] }) $null
			}
			elseif ($e.File.EndsWith('.gd'))
			{
				$consts = Get-Constants $full
				$code = Get-PathValue $consts $e.Path
				$same = Test-SameValue $code $wikiValue $consts
				$now = Format-Value $code $consts
			}
			else
			{
				throw 'values come from a .gd or .po file'
			}
		}
		catch
		{
			Add-Problem $file $e.Line "$($e.File) $($e.Path): $($_.Exception.Message)"
			continue
		}
		if (-not $same)
		{
			# Where the page shows the old value: the lines with its numbers, or with its text as shown.
			$hint = ''
			$old = @(Get-Numbers $shownText)
			$oldText = if ($null -ne $e.Shown) { $e.Shown } elseif ($wikiValue.Kind -ceq 'string') { $wikiValue.Value } else { $null }
			$lines = @($page.Prose | Where-Object {
				$p = $_
				($old.Count -and @(Get-Numbers $p.Text | Where-Object { $old -contains $_ }).Count) -or ($oldText -and -not $old.Count -and $p.Text.Contains($oldText))
			} | ForEach-Object { $_.Line })
			if ($lines) { $hint += "; it shows on lines $($lines -join ', ')" }
			if ($e.Images) { $hint += "; re-take $($e.Images -join ', ')" }
			Add-Problem $file $e.Line "$($e.File) $($e.Path) is now $now, the page lists $($e.Value): update this line and the page$hint"
			continue
		}

		# A listed value must show: in an image, or in the text (its numbers, or the text as shown).
		if ($e.Images) { continue }
		$numbers = @(Get-Numbers $shownText)
		if ($numbers)
		{
			if (-not @($numbers | Where-Object { $proseNumbers.Contains($_) }).Count) { Add-Problem $file $e.Line "listed but not in the text or an image: $shownText" }
		}
		elseif ($null -ne $e.Shown -or $e.File.EndsWith('.po'))
		{
			$expected = (($null -ne $e.Shown) ? $e.Shown : $wikiValue.Value) -replace '\s+', ' '
			if ($proseText.IndexOf($expected, [StringComparison]::OrdinalIgnoreCase) -lt 0) { Add-Problem $file $e.Line "listed but not in the text or an image: $expected" }
		}
	}
	if ($page.HasBlock -and -not $gameChecked) { Add-Problem $file 0 'no game-checked: line in the values block (the game version its game values and images were checked against)' }

	# Every number in the text is listed.
	foreach ($p in $page.Prose)
	{
		foreach ($n in Get-Numbers $p.Text)
		{
			if (-not $listed.Contains($n)) { Add-Problem $file $p.Line "the number $n isn't in the values block (list its constant, or add a game: or note: line)" }
		}
	}

	# Every setting is covered.
	$required = Get-Required $ModName
	foreach ($r in $required)
	{
		if (-not $cited.Contains("$($r.File) $($r.Path)")) { Add-Problem $file 0 "missing from the values block: $($r.File) $($r.Path) (a setting the page must cover)" }
	}

	# The section on how it changes the game, exactly when the README has a Warning.
	$readme = Join-Path $repo "$ModName/README.md"
	$warning = (Test-Path -LiteralPath $readme) -and ((Get-Content -LiteralPath $readme -Raw) -match '(?m)^## Warning\s*$')
	$section = @($page.Lines | Where-Object { $_ -match '^## Changes how the game plays\s*$' }).Count -gt 0
	if ($warning -and -not $section) { Add-Problem $file 0 "the README has a Warning, so the page needs a '## Changes how the game plays' section" }
	if ($section -and -not $warning) { Add-Problem $file 0 "'## Changes how the game plays', but the README has no Warning" }

	foreach ($link in Get-ImageLinks $page) { Test-ImageTarget $file $link.Line $link.Target }
	Test-PageLinks $page

	# The README's pictures live in _wiki/images too, so the mod's zip carries none.
	if (Test-Path -LiteralPath $readme)
	{
		$readmeLines = @(Get-Content -LiteralPath $readme)
		for ($i = 0; $i -lt $readmeLines.Count; $i++)
		{
			foreach ($m in [regex]::Matches($readmeLines[$i], '!\[[^\]]*\]\(\s*([^)\s]+)'))
			{
				$target = $m.Groups[1].Value
				$inWiki = [regex]::Match($target, '^\.\./_wiki/(images/[^/]+)$')
				if ($inWiki.Success) { Test-ImageTarget $readme ($i + 1) $inWiki.Groups[1].Value }
				elseif ($target -notmatch '^https?://') { Add-Problem $readme ($i + 1) "image '$target': a README's pictures go in _wiki/images, linked as ../_wiki/images/<file>" }
			}
		}
	}
	return $page
}

# Whether a special page (Home, the sidebar) links a page.
function Test-LinksTo([string] $Special, [string] $Name)
{
	$file = Join-Path $wiki "$Special.md"
	if (-not (Test-Path -LiteralPath $file)) { return }
	if ((Get-Content -LiteralPath $file -Raw) -cnotmatch "\]\(\s*$([regex]::Escape($Name))(#[\w-]+)?\s*\)")
	{
		Add-Problem $file 0 "no link to $Name"
	}
}

#endregion

#region The check

$mods = @(Get-ChildItem -LiteralPath $repo -Directory | Where-Object { $_.Name -notmatch '^[_.]' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'ModMain.gd')) } | ForEach-Object { $_.Name })
$checked = [System.Collections.Generic.List[object]]::new()
if ($Mod)
{
	if ($mods -cnotcontains $Mod) { throw "No mod folder with ModMain.gd: $Mod" }
	$page = Test-ModPage $Mod
	if ($page) { $checked.Add($page) }
	foreach ($special in 'Home', '_Sidebar') { Test-LinksTo $special $Mod }
}
else
{
	foreach ($special in $specialPages)
	{
		$file = Join-Path $wiki "$special.md"
		if (-not (Test-ExactPath $wiki "$special.md")) { Add-Problem $file 0 "missing: the wiki needs $special.md"; continue }
		$page = Read-Page $file
		foreach ($link in Get-ImageLinks $page) { Test-ImageTarget $file $link.Line $link.Target }
		Test-PageLinks $page
	}
	foreach ($name in $mods)
	{
		$page = Test-ModPage $name
		if ($page) { $checked.Add($page) }
		foreach ($special in 'Home', '_Sidebar') { Test-LinksTo $special $name }
	}
	foreach ($item in Get-ChildItem -LiteralPath $wiki -Force)
	{
		if ($item.PSIsContainer)
		{
			if ($item.Name -cne 'images') { Add-Problem $item.FullName 0 "only images/ goes in _wiki/: everything there is published to the wiki" }
			continue
		}
		$name = [IO.Path]::GetFileNameWithoutExtension($item.Name)
		if ($item.Extension -cne '.md') { Add-Problem $item.FullName 0 "only pages (.md) and images/ go in _wiki/: everything there is published to the wiki" }
		elseif ($specialPages -cnotcontains $name -and $mods -cnotcontains $name) { Add-Problem $item.FullName 0 "a page for $name, which isn't a mod folder" }
	}
	if (Test-Path -LiteralPath $imagesDir)
	{
		foreach ($image in Get-ChildItem -LiteralPath $imagesDir -Force)
		{
			$rel = "_wiki/images/$($image.Name)"
			if ($image.PSIsContainer -or $image.Extension -cne '.png') { Add-Problem $image.FullName 0 'images are PNG files (.png)'; continue }
			if ($image.Length -gt $imageMaxBytes) { Add-Problem $image.FullName 0 "$([math]::Ceiling($image.Length / 1KB)) KB: an image is at most $($imageMaxBytes / 1KB) KB (crop it, or reduce its colours)" }
			if (-not $script:usedImages.Contains($rel)) { Add-Problem $image.FullName 0 'not used by any page' }
		}
	}
}

# The game version the pages were checked against, compared with the newest decompiled game (only where this machine
# has one: never in CI).
$pathsFile = Join-Path $repo 'paths.local.psd1'
if (Test-Path -LiteralPath $pathsFile)
{
	$localPaths = Import-PowerShellDataFile -LiteralPath $pathsFile
	$gdre = if ($localPaths.TempDir) { Join-Path $localPaths.TempDir 'gdre' } else { $null }
	if ($gdre -and (Test-Path -LiteralPath $gdre))
	{
		$newest = Get-ChildItem -LiteralPath $gdre -Directory | Where-Object { $_.Name -match '^Delta-V-\d+(\.\d+){1,3}$' } |
			ForEach-Object { $_.Name -replace '^Delta-V-', '' } | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
		foreach ($page in $checked)
		{
			$stamp = $page.Entries | Where-Object Kind -eq 'game-checked' | Select-Object -First 1
			if ($newest -and $stamp -and $stamp.Text -ne $newest)
			{
				Write-Warning "$([IO.Path]::GetFileName($page.File)) was checked against game $($stamp.Text), the newest decompiled is ${newest}: re-check its game: lines and images, then its game-checked line"
			}
		}
	}
}

if ($script:problems.Count)
{
	throw "The wiki has $($script:problems.Count) problem(s), listed above (MODDING.md, The users' wiki)"
}
$what = if ($Mod) { "the page of $Mod is" } else { "all $($checked.Count) mod pages are" }
Write-Host "wiki: $what up to date" -ForegroundColor Green

#endregion

# The folders outside the repo, which differ per machine. Copy this file to paths.local.psd1 (git-ignored) and set
# them there: _tests\run.ps1, package.ps1, release.ps1, wiki.ps1, _shots\shots.ps1, _bench\bench.ps1 and
# _bench\analyze.ps1 read it, MODDING.md names these folders by their keys, and CLAUDE.md asks Claude to read it.
@{
	# The game's folder: Delta-V.exe and mods\.
	GameDir = 'C:\path\to\dV Rings of Saturn'
	# Generated and temporary files: zips being deployed, test runs, the decompiled game (gdre\), the wiki's screenshot
	# runs (shots\). Never the repo.
	TempDir = 'C:\path\to\temp\delta-v'
	# Godot 3.6 (Godot_v3.6-stable_win64.exe) and GDRE Tools.
	GodotDir = 'C:\path\to\godot'
}

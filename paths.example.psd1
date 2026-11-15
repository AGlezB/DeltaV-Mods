# The folders outside the repo, which differ per machine. Copy this file to paths.local.psd1 (git-ignored) and set
# them there: _tests\run.ps1 reads it, and CLAUDE.md imports it and names these folders by their keys.
@{
	# The game's folder: Delta-V.exe and mods\.
	GameDir = 'C:\path\to\dV Rings of Saturn'
	# Generated and temporary files: zips being deployed, test runs, the decompiled game (gdre\). Never the repo.
	TempDir = 'C:\path\to\temp\delta-v'
	# Godot 3.6 (Godot_v3.6-stable_win64.exe) and GDRE Tools.
	GodotDir = 'C:\path\to\godot'
}

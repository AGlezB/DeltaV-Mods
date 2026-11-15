# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The repository's documentation is imported below: `README.md` (the mods, for players) and `MODDING.md` (the folders
outside the repo, how the game loads a mod and how these mods hook in, packaging and releasing, the conventions and
the game's terms). The test harness's documentation, `_tests\README.md`, loads with `_tests\CLAUDE.md` when working in
`_tests\`; read it before running the tests to compare with its baseline. Follow the conventions in every change, and
keep these docs up to date as they ask.

[@README.md](README.md)

[@MODDING.md](MODDING.md)

## For Claude

- This machine's folders outside the repo (MODDING.md *Folders outside the repo*) are in the git-ignored
  `paths.local.psd1`: read it before using any of them. It can't be imported here, because Claude Code doesn't import
  `.psd1` files.
- Imports in the repo's `CLAUDE.md` files are written as links, `[@README.md](README.md)`: Claude Code imports the
  link text, and GitHub shows a link instead of a bare `@` line.
- Don't read outside the repo and those folders without asking first.
- Find field names and game behaviour in the newest decompiled game; don't ship a logging-only build to discover
  them.
- A game term in a request means what MODDING.md's *Glossary* says, with no further explanation; check a term's
  English text in the game's `i18n/en.po`, not from memory. When a request uses a game term that isn't there, find it
  in the decompiled game and add it; an entry explains every game term it uses, or that term has its own entry.

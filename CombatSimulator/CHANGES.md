# CombatSimulator - Changes

## 1.0.2
- Fixes a crash the game could have the first time the dialog's ship list drew its pictures in a game session: each
  picture's viewport is now freed with its ship still in it (`_drawPicture()`), which avoids a Godot 3 bug.

## 1.0.1
- The README's *Disclaimer* no longer names the author.
- Adds this CHANGES.md.

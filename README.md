# ACOTAR: Book 1 (personal fan game)

A personal, non-distributed fan RPG of *A Court of Thorns and Roses*, Book 1.
Top-down exploration with painted pop-up portraits, a turn-based deckbuilder
for fights, and power that grows with canon. Saves carry into later books.

Not for distribution. The book itself is not in this repo; the data files hold
a chapter index, character descriptions and short quotes only.

## Status

Milestone 1, the vertical slice: Chapters 1 to 5 (the winter hunt and the wolf,
the cottage, the village, the Beast at the door, the ride to the Wall). All art
is labelled placeholder. See `docs/DESIGN.md` for scope, pushback and guesses.

## Run it

1. Install Godot 4.7.2 (standard build, not .NET): https://godotengine.org/download
2. Open `project.godot` in Godot and press F5.

Or from a terminal: `godot --path . res://scenes/main.tscn`

Controls: WASD or arrows to move, Shift to hurry, E or Space to interact,
J journal, Tab deck, Enter to advance dialogue, 1 to 4 to choose. In battle,
click a card to play it, R ends the turn.

## Build for Windows

Install export templates once (Editor > Manage Export Templates), then:

```
godot --headless --path . --export-release "Windows Desktop" build/windows/ACOTAR.exe
```

The pack is embedded, so the result is one .exe. The Web preset exports to
`build/web/` and uses the Compatibility renderer (softer lighting).

## Tests

```
godot --headless --path . res://tests/test_runner.tscn
```

Checks every data cross-reference, the battle rules, the wolf gimmick, balance
(a greedy bot must win 60 to 97 percent, a random bot must do worse), the save
round trip, schema migration and carry-over export.

Mouse test (needs a display; clicks New Game, then clicks a card in the wolf fight):

```
godot --path . --script res://tests/title_click_test.gd
```

Screenshot tour (plays the slice automatically and saves a screenshot per beat):

```
godot --path . --rendering-method gl_compatibility res://scenes/main.tscn -- --shots /some/folder
```

## Art pipeline

- `tools/gen_placeholders.py` makes every labelled placeholder and its normal map.
- `tools/build_manifest.py` writes `data/assets/manifest.json` and
  `docs/ASSET_MANIFEST.md`: one entry per asset, with the prompt built from the
  book descriptions and `docs/STYLE_GUIDE.md`, and a credit estimate.
- Final art goes in `assets/final/` at the same relative path as the
  placeholder. The game prefers it automatically. Then run
  `python3 tools/make_normals.py --all` for lit sprites.

## Layout

```
data/            cards, enemies, relics, items, statuses, tiers, shops
data/book1/      chapters, characters, locations, quotes, lore, dialogue
data/assets/     art manifest
scripts/autoload DB, GameState, SaveSystem, Router, Dialogue, UI
scripts/battle   battle rules (pure logic) and the battle scene
scripts/world    region base class, player, regions
shaders/         god rays, fog, post grade, Wall seam, Fae glow, hearth
tools/           placeholder, manifest and normal-map generators
tests/           test runner and screenshot tour
docs/            design notes, style guide, asset manifest
```

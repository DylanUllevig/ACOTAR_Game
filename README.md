# ACOTAR: Book 1 (personal fan game)

A personal, non-distributed fan RPG of *A Court of Thorns and Roses*, Book 1.
Top-down exploration and real-time hunting with a bow and a knife, painted
pop-up portraits for dialogue, fights that stop for story scenes, and power
that grows with canon. Saves carry into later books.

Not for distribution. The book itself is not in this repo; the data files hold
a chapter index, character descriptions and short quotes only.

## Status

Milestone 1, the vertical slice: Chapters 1 to 5 (the winter hunt and the wolf,
the cottage, the village, the Beast at the door, the ride to the Wall). Every
image in the art manifest has final painted art (87 files in `assets/final/`);
the labelled placeholders stay as fallbacks. Every sound is generated in code
until final audio replaces it. See `docs/DESIGN.md` for scope, decisions and
guesses.

## Run it

1. Install Godot 4.7.2 (standard build, not .NET): https://godotengine.org/download
2. Open `project.godot` in Godot and press F5.

Or from a terminal: `godot --path .`

## Controls

| Action | Keys |
|---|---|
| Move | WASD or arrow keys; hold Shift to run (running is noisy on a hunt) |
| Use the selected item | Left click, aimed at the cursor: slash with the knife, hold to draw the bow and release to loose, click food to eat. F does the same, aimed where Feyre faces |
| Choose a hotbar slot | Mouse wheel, number keys 1 to 0, or click the slot |
| Interact, talk | E, Space or right click (right click also lowers a drawn bow) |
| Satchel (inventory) | Tab or I. Click to pick up, click to place; drag works too; right click takes half a stack |
| Map, journal | M, J |
| Pause menu | Esc (resume, save, options, quit) |
| Dialogue | Enter, Space, E or click to continue; 1 to 4 or click to choose; hold Shift to type faster |

## Build for Windows

Install export templates once (Editor > Manage Export Templates), then:

```
godot --headless --path . --export-release "Windows Desktop" build/windows/ACOTAR.exe
```

The pack is embedded, so the result is one .exe next to nothing else. The Web
preset exports to `build/web/` and uses the Compatibility renderer.

## Tests

Headless suite (about 40 seconds):

```
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- --only story
```

Unit tests cover compilation, every data cross-reference, the inventory,
power tiers, the save round trip, schema migration from the card-battle saves,
map discovery and the clock. Scenario tests play Chapter 1 with a bot (stealth,
the ash arrow, the doe), defeat and retry, the whole slice from the forest to
the Wall and the carry-over export, and a seeded balance run of 24 fights per
bot: a careful bot that reads 85% of the wolf's tells must win at least 85% of
them with about half its health left, and a careless one that reads 25% must
lose some and finish at least 5 HP worse. Every dialogue line must also show
in a visible box.

Mouse test, needs a display (`xvfb-run` on Linux). It clicks New Game, clicks
the hotbar, slashes and shoots with the mouse, drags in the satchel and clicks
Resume. Run it at more than one window size:

```
godot --path . --resolution 1600x900 --script res://tests/title_click_test.gd
```

Screenshot tour: plays the whole slice by itself and saves a screenshot per
beat (about 6 minutes). `--autotest` instead of `--shots` plays it without
saving images and exits non-zero if it does not reach the end.

```
godot --path . --resolution 1920x1080 -- --shots /some/folder
```

One region, for checking art and lighting:

```
godot --path . --resolution 1920x1080 -- --scene-shot cottage --chapter 2 --hour 17.4 --out shot.png
```

## Art and sound

- `tools/gen_placeholders.py` makes every labelled placeholder and its normal map.
- `tools/build_manifest.py` writes `data/assets/manifest.json` and
  `docs/ASSET_MANIFEST.md`: one entry per image with a prompt built from the
  book descriptions and `docs/STYLE_GUIDE.md`, its size, and a credit estimate.
- Final art goes in `assets/final/` at the same relative path as the
  placeholder. The game prefers it automatically. The fitting tools write it at
  more pixels than its layout size, record the ratio in
  `assets/final/density.json`, and make the normal maps for lit art:
  `tools/fit_art.py` (portraits, props, icons, effects, ground tiles, rooms),
  `tools/make_sheet.py` (character sheets from a turnaround and walk strips),
  `tools/make_strip.py` (paths, the brook, roads) and `tools/cut_sheet.py`
  (splits a sheet of separate objects). After `godot --headless --import`,
  run `python3 tools/final_mipmaps.py` and import again.
- `data/assets/generated.json` lists every generated image by file name and
  Higgsfield job id; a job id can be reused as a reference image.
  `docs/STYLE_GUIDE.md` has the rules each kind of art follows.
- `tools/gen_audio.py` synthesises every sound effect, ambience bed and music
  cue into `assets/audio/` (77 files; needs numpy, scipy and ffmpeg with
  libvorbis). A file with the same name under `assets/final/audio/<kind>/`
  replaces it.

## Layout

```
data/            items, enemies, power tiers, shops
data/book1/      chapters, characters, locations, objects, quotes, lore, dialogue
data/assets/     art manifest, generation log
scripts/autoload DB, GameState, SaveSystem, Router, Dialogue, UI, Audio, Settings
scripts/combat   creatures (wolf, hare, doe), the hunt, arrows, pickups, effects
scripts/ui       HUD, game menu (satchel, map, journal, options), shop
scripts/world    region base class, player, interactables, regions
shaders/         post grade, god rays, fog, vignette, Wall seam, Fae glow, hearth,
                 frayed ground patches, ground tiling without a visible repeat,
                 Feyre's outline through a creature that stands in front of her
tools/           placeholder, manifest, art fitting, normal-map and audio tools
tests/           test runner, hunt bot, mouse test, screenshot tour, scene shot
docs/            design notes, style guide, asset manifest
```

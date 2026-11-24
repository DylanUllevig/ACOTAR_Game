# Design notes: Milestone 1

What the vertical slice contains, how the systems work, where the build differs
from the original spec and why, and every guess made along the way.

## Scope of the slice

Chapters 1 to 5 of Book 1, playable start to finish:

1. Ch 1, the winter forest: explore, forage, find the doe, and the wolf hunt (stealth, then a real-time fight).
2. Ch 2, the cottage: the family, dinner and the first power tier, Elain's paint tins (a keepsake).
3. Ch 3, the village: the mercenary buys the hides, the charm stall (a shop), Isaac, the Children of the Blessed, Elain at the market.
4. Ch 4, the Beast at the door: a dialogue confrontation with canon-locked choices. He burns the ash arrow.
5. Ch 5, the night ride north and the Wall: a short playable ride, then a cinematic crossing. Ends the slice and offers the carry-over export.

## Systems

| System | Where | Notes |
|---|---|---|
| Content | `data/*.json`, `data/book1/*.json` | Items, enemies, power tiers, shops, chapters, characters, locations, objects, quotes, lore, dialogue. No story text is hard-coded in scripts. `DB.validate()` cross-checks every reference and runs on boot in debug builds and in the tests. |
| Player | `scripts/world/player.gd` | Accelerating movement with friction, Shift to run. The hotbar item is used on the left mouse button, aimed at the cursor. Knockback and a moment of invulnerability on a hit. Footprints in snow, footsteps by surface, the nearest-interactable prompt, camera look-ahead while aiming. |
| Inventory | `game_state.gd`, `scripts/ui/inventory_view.gd` | 30 slots; the first 10 are the hotbar. Stacks, click to pick up and place, drag, right click for half a stack, eat from the satchel. |
| Combat | `scripts/combat/` | `creature.gd` is the base: health, knockback, hit flash, drops, and its own random generator so fights replay exactly from a seed. `wolf.gd`, `hare.gd`, `doe.gd`; `arrow.gd` flies, sticks, can be picked up again or breaks; `fx.gd` holds the slash arcs, sparks, blood and floating numbers. |
| The hunt | `scripts/combat/hunt.gd` | One fight from the first stalk to the last breath: stealth and noise, the mid-fight story beats, the boss bar, victory and defeat. |
| World | `scripts/world/region.gd` + `regions/*.gd` | Each region builds itself in code: ground, y-sorted props, lights, occluders, colour grade per hour, projected sun shadows, fog, god rays, snow, triggers, NPCs. |
| Dialogue | `scripts/autoload/dialogue.gd` | Portrait pop-ups that slide in, typewriter text, choices (keys 1 to 4 or click), and actions (`do`) that drive the story: items, flags, tiers, the hunt, shops, region changes. Barks are single lines over the action that do not stop play. |
| UI | `ui.gd`, `scripts/ui/` | HUD (health, coin, clock, objective, hotbar, prompts, boss bar, stealth eye), the game menu (satchel, map, journal, options, pause), shop and popups, toasts, chapter cards, fades. |
| Map | `scripts/ui/map_view.gd` | Each region's map starts hidden and is uncovered where Feyre walks; landmarks appear once found. A second tab shows Prythian. |
| Sound | `scripts/autoload/audio.gd`, `tools/gen_audio.py` | Music and ambience crossfade per region; positional effects; buses for master, music, effects, ambience and interface. |
| Progression | `game_state.gd`, `power_tiers.json` | Tiers follow canon, not experience points. See below. |
| Save | `save_system.gd` | Versioned JSON with a carry-over block that later games import. |

### The wolf hunt

In the book Feyre kills the wolf from hiding, so the fight starts with her in
the brambles and the wolf stalking the doe. Each shot makes noise and so does
running; at three noise, if she leaves cover within his sight, or if she comes
within a few strides, he hunts her instead. The first hit from hiding deals
double damage and gives her away. If he reaches the doe first he eats, and the
hide is torn (it sells for 3 coin instead of 12).

Once he hunts her: he chases, then lunges after a clear tell (0.62 seconds,
0.42 when he is desperate below 35% health), bites when close (at most two in a
row), and circles to reset. He heals 2.5 HP a second after 1.2 seconds without
being hurt, until the ash arrow strikes him. A heavy hit staggers him.

Mid-fight story beats, each once per fight: a bark on the start, a full scene
when he finds her, when the doe dies and when the ash arrow strikes, barks when
his wounds close, when he slows at half health, when she is badly hurt and when
the quiver is empty, and the victory scene. A full scene freezes the fight; a
bark plays over it, and a scene that starts while a bark is showing ends it.
Losing offers Try again, which restarts the hunt at full health, hidden again.

Balance, enforced by the test suite over 24 seeded fights per bot: a careful
bot that reads 85% of his tells won 24 of 24 with 19.0 of 30 HP left on
average; a careless bot that reads 25% won 18 of 24 with 6.6 left.

### Weapons and food

| Item | Numbers |
|---|---|
| Hunting knife | 7 damage, 82 px reach, 130 degree arc, 0.34 s between slashes |
| Bow | 0.8 s to full draw; 6 to 18 damage and 700 to 1350 px/s by draw; a draw under 20% does not loose |
| Arrows | Two at the start. They stick where they land and can be picked up unless they break. 3 for 6 coin at the stall |
| Ash arrow | One. +8 damage and stops the wolf healing |
| Food | Rose hips 5 HP (forage, 3 per bush), bread 8, venison strip 12 |

### Power tiers

| Tier | Name | Chapter | Max HP | Damage | Speed | Draw |
|---|---|---|---|---|---|---|
| 0 | Starving Mortal | 1 | 30 | x1.0 | x1.0 | x1.0 |
| 1 | Fed Huntress | 2 | 36 | x1.1 | x1.04 | x1.08 |
| 2 | Guest of the Spring Court | 8 | 44 | x1.2 | x1.08 | x1.15 |
| 3 | Suriel Hunter | 15 | 50 | x1.35 | x1.1 | x1.2 |
| 4 | Fire Night | 21 | 52 | x1.4 | x1.12 | x1.25 |
| 5 | Prisoner Under the Mountain | 35 | 38 | x1.2 | x1.0 | x1.1 |
| 6 | Trial Survivor | 40 | 46 | x1.5 | x1.12 | x1.3 |
| 7 | Made Fae | 46 | 90 | x2.4 | x1.5 | x1.8 |

Only tiers 0 and 1 are reachable in the slice. The dip at tier 5 is
deliberate: she is weaker Under the Mountain in canon, and it sets up the Made
Fae spike. Relics and spells arrive with later tiers, as you asked.

### Save and carry-over

`user://saves/<slot>.json`, format `acotar-save`, schema 2. Split into
`carry_over` (tier, stats, inventory, journal, canon choices) and `progress`
(chapter, region, flags, HP). The game saves itself on entering each area,
before the hunt and after the wolf; the pause menu saves by hand except during
a hunt. `SaveSystem.migrate()` upgrades old schemas step by step: a schema 1
save from the card-battle build drops the deck, turns relics into keepsakes,
keeps the knife and bow, keeps the ash arrow before Chapter 4, and restores
unsold hides from the story flags. The end of the slice writes an
`acotar-carryover` file; Book 2 reads it with `SaveSystem.read_carryover(path)`
and ignores `progress`.

### Rendering and lighting

- Windows uses Forward+; the web build uses Compatibility.
- HDR 2D and glow are off. Under Forward+, HDR 2D rendered the regions about
  four times darker than Compatibility (the cottage interior went nearly
  black), and glow without HDR hazed the snow. The forest's evening mood is
  kept with a per-hour exposure gain in the post shader instead, so both
  renderers now look the same.
- The vertical lines you saw: the fog and snow noise used a float hash that
  keeps only a few bits when a driver evaluates it at reduced precision, which
  turns it into vertical streaks. It is now an integer hash
  (`shaders/noise.gdshaderinc`) that gives the same value on every GPU. The
  lines never appeared in the renderers available here, so whether they are
  gone on your machine is unconfirmed until you run the build.

### Sound

Everything is synthesised by `tools/gen_audio.py`: 54 effect files (bow draw and
release, arrow hits on snow, wood and flesh, knife swings and hits, the wolf's
growls, snarls, lunges, bites and yelp, footsteps on snow, wood and mud, eating,
foraging, the Beast's roar), 13 interface sounds, 4 ambience beds and 6 music
cues. Real recordings or generated audio replace any of them by name.

### Interface rules

- While a window is open the HUD steps back, the game pauses, and toasts drop
  to the strip below the window, newest only.
- The dialogue box clears its text when a scene closes, so a chapter card at
  the start of the next scene cannot reveal the last scene's line or leave the
  box invisible. (It did, in every chapter arrival from 2 to 5, before this
  fix; a test now fails if any line shows in an invisible box.)
- A chapter card clears the last chapter's objective, and the chapter's
  opening scene sets the new one.

## Pushback on the spec

1. Chapter range. The spec said the slice is "Chapters 1 to 3: the winter hunt
   and the wolf battle, the village and family cottage, Tamlin's arrival and
   crossing the Wall". In the book Tamlin arrives in Ch 4 and they cross in
   Ch 5, so the slice covers Ch 1 to 5.
2. The Wall crossing is not playable. Feyre is magically asleep for it in
   canon. It is a cinematic after a short playable night ride.
3. The Beast at the door is dialogue, not a fight. In canon she cannot win and
   does not try; a fight there would teach the player that losing is a bug.
4. Combat. The first build used a turn-based card battle. You asked for
   real-time combat in the style of a cozy farm sim instead (2026-11-23), with
   the mid-fight scenes kept, so cards and card relics are gone and old saves
   migrate.
5. AI art and lighting pull against each other. World lighting needs normal
   maps and a consistent top-down angle; image models give neither reliably.
   `tools/make_normals.py` derives approximate normals and the style guide pins
   the angle, but expect rerolls and some hand cleanup on props.
6. Walk cycles. The manifest has prompts for 4 x 4 walk sheets, but frames
   drift between generations, so each sheet will need its frames aligned by
   hand. Single-image creatures (the wolf, the Beast, the doe) are easier.
7. No grind in a canon-locked story. The loop comes from the hunt, foraging,
   the hotbar and satchel, the shop, map discovery and the journal. Optional
   fights fit best in the Spring Court woods from Ch 7.
8. Art budget. The manifest lists 82 images: about 239 generations with
   rerolls, about 179 credits at 0.75 each. The real cost is the cleanup.

## Guesses I made

Each of these is my call, not canon or spec. All are data or one-line changes.

- Tamlin's beast form is "the Beast" in the slice; his name is not revealed (canon).
- The wolf is Andras, but the game shows only "The Wolf" until the lore unlocks after the fight.
- Wolf numbers (130 HP, 2.5 HP a second healing, lunge 10 damage, bite 8, desperate below 35%) come from balance runs, not canon.
- Feyre starts with 30 HP, a hunting knife, a bow, two plain arrows and one ash arrow ("two arrows, a third I never..." in the opening line).
- The Beast finds and burns the ash arrow in Ch 4 (canon), so it leaves the inventory there.
- Snare wire and the iron bracelet are game inventions with canon flavour. Snow hares are small game in the forest.
- The charm stall sells arrows (3 for 6), bread (3), venison strips (4) and the iron bracelet (12), and buys hares and snare wire. The mercenary pays 18 for the wolf pelt, 12 for a clean doe hide and 3 for a torn one.
- Coin comes only from selling at the market (canon: she sells the pelt).
- Before she leaves with the Beast in Ch 4 she leaves all her coin for her
  family, so she crosses the Wall with none and Book 2 starts at 0 coin.
- Healing values for rose hips, bread and venison are mine.
- Time of day runs only outdoors (1 game hour per 3 real minutes), and story beats set the hour.
- The Prythian map is a schematic drawn from coordinates taken from your map image. The image itself is not in the repo.
- Region layouts (forest paths, village square, cottage rooms) are invented; the book gives mood, not floor plans.
- Dialogue lines are short canon quotes where they exist, otherwise written to match the voice, and kept short.
- Content: violence shown, sex scenes fade to black (none in the slice).

## Known gaps

- All art is labelled placeholder. Lighting, layout and feel can be judged; looks cannot.
- Higgsfield art and audio are blocked from this build's environment until the
  project uses the `acotar_game` environment (Project settings); the hand-off
  folder and its instructions are ready.
- Sound is synthesised; there is no voice acting.
- No key rebinding.
- The web export is configured but not yet tested in a browser.

# Design notes

What each milestone contains, how the systems work, where the build differs
from the original spec and why, and every guess made along the way. The newest
milestone comes first; the older notes follow unchanged except where marked.

## Milestone 3: home across the Wall (Chapters 28 to 32)

Chapter 27 no longer ends the game: she wakes on the morning Tamlin sends her
home, crosses the Wall asleep in his carriage, and plays on through her
family's new life, the ride back and the empty manor, to Alis's tale in the
burned kitchen. The end window closes Milestone 3 at "As you wish". Next is
Chapter 33, Under the Mountain.

| Ch | Where | What happens |
|---|---|---|
| 28 | her room, the hall, the grounds, the new house | Alis dresses her for the mortal world; Lucien at the foot of the stairs; goodbye at the gilded carriage; she wakes at her father's new house, and the glamour's story of a rich dead aunt |
| 29 | the garden and lawn, Father's study, the old cottage | Elain among her tulips, Nesta under the mulberry tree, four purses of silver; the cottage, so small now, and the forest that is only trees |
| 30 | the village, the glasshouse, the morning room, the stairs | four purses left at four doors in the poor lane; Tomas Mandray at the fountain; Isaac and his bride; digging Elain's new bed, and what Nesta knew; three painting lessons; Nesta on the stairs: "Yes. I would have." |
| 31 | the ballroom, the dining room, the forest, the Wall, the grounds | the ball and the fifth suitor; lunch, and the Beddor fire; riding clothes, knives and a bow; Elain's saddled horse; the ride north, the night by the fire, the standing stones; the manor's doors hang open |
| 32 | the wrecked hall, the dining room, the kitchens | the signs read; the prints in the glass; hiding behind the door; Alis, and the whole truth told over paintings (the curse, the masks, the wolves); "As you wish" |

### How it is built

| Part | Where | Notes |
|---|---|---|
| The new house, outside | `regions/chateau.gd` | White house, green roofs, a long gravel drive between hedges clipped into green flames; Elain's walled garden under the study window, the glasshouse, the lawn down to the mulberry tree, the road west to the cottage. |
| The new house, inside | `regions/chateau_in.gd` | Runs on the manor's machinery (`manor_in.gd`): every `chateau_*` region id is a room (hall, ballroom, dining, study, studio, landing, bedroom), with its own beat table (`C_BEATS`). |
| The old cottage | `regions/cottage_yard.gd` | Mossy thatch with a hole in it, Elain's bed run wild, the ward-marks still on the doorstep, a new door; her old path south to the tree line. |
| The village in summer | `regions/village_summer.gd` | The winter village's square and roads, green now, with the poor lane at the bottom where the purses go. |
| The Wall | `regions/summer_wall.gd` | The ride north until the horse refuses; the Wall is an invisible band that stops a hand like glass and shimmers where she touches it. She leads the horse east along it, camps by a fire (feed it three times to reach dawn), and finds the stones. |
| The empty manor | `spring_manor.gd`, `manor_in.gd` | From the end of Chapter 31: silent grounds, the doors open, the wrecked hall and dining room, and the burned kitchen (`manor_kitchen`). |
| Tale paintings | `> panel <id>` in the dialogue script | A painting fills the screen behind the speakers while a story is told, and cross-fades to the next (`assets/final/panels/`). `> panel none` clears it. |
| Clothes | `GameState.outfit` | Mortal finery, garden clothes, the ball gown and riding clothes, each with its own walking sheet and portraits. A `goto` can change them (`outfit=`) so the next room builds her dressed. |
| Music | `tools/gen_audio.py` | Kept light, in line with the ask for less dark music: the house in G major with a pianoforte, flute and fiddle; a waltz in F for the ball; the empty manor sparse but not grim. |
| Own words | `tools/dialogue/overlap.py` | Lists every story line or lore entry that shares nine or more words in a row with the book (read from the user's own EPUB, never committed). About 260 lines from Chapters 6 to 32 were rewritten until it listed none. |

Drawing fixes that came with it, for every region: a tall prop (a tree, a
hedge, a house) now fades by its painted shape when Feyre or a horse is behind
it, not by a rough box; ground edges can trim one-tile spikes
(`terrain.smooth_edges`, on in the Milestone 3 regions) so roads read as
smooth curves; and indoor rooms use barrels, buckets and crates without the
snow or grass of the outdoor ones.

### Guesses and pushback (Milestone 3)

- The way through the Wall is two mossy standing stones with spirals cut in
  them, so the player has something to look for on the ride east.
- Six moments offer a choice (the carriage, Elain's garden, Tomas, Isaac,
  Nesta's confession, the worktable); as before, choices change lines, not
  the story. The ball, the lunch and the painting lessons play straight
  through.
- Alis's tale is told in the game's own words over six paintings, rather than
  as a long block of text.
- The horse is hobbled at the camp so it stays by the fire if the game is
  saved and loaded there.

## Milestone 2: the Spring Court (Chapters 6 to 27)

Chapter 5 no longer ends the game: she wakes at the Spring Court's gate in
Chapter 6 and plays on to the night before Tamlin sends her home, where the end
window closes Milestone 2. Next is Chapter 28, home across the Wall.

| Ch | Where | What happens |
|---|---|---|
| 6 to 8 | the gate, the hall, the dining room, her room, the grounds | the Beast at the gate, the feast, the bath and spring clothes, the first dinner, the rose garden; she maps the fountain, the pool, the stables and the gate, and steals a table knife (tier 2) |
| 9 to 11 | the stables, the woods, the gate at night | the ride with Lucien and her bow back; the Bogge; the thing in her father's shape at the gate (the puca) |
| 12 to 15 | the hall, the library, the birch grove | the wounded beast at night; learning to read, the mural of the courts; Lucien's knife and bait; the snare, the Suriel, the naga (tier 3) |
| 16 to 19 | the house, the willow glen, the gallery, the painting room, the rose garden | faeries can lie; the faerie in the hall; the pool of starlight and a jeweled knife; she paints; the Attor |
| 20 to 21 | the woods at night, the upper hall | Fire Night: the drums, the three faeries, the stranger; the bite in the hall (tier 4) |
| 22 to 24 | the house, the glen, the heron fountain | "faerie pig", the gown, the table that shrinks, her paintings; faerie sight at the willow; the court without its glamour; the head on the heron |
| 25 | the lawn, the meadow, the hill | Midsummer: the wine, the fiddler, the will-o'-the-wisps, the kiss, the dawn |
| 26 to 27 | the dining room, her room | Rhysand at lunch; he sends her home; thorns and all (fades to black) |

### How it is built

| Part | Where | Notes |
|---|---|---|
| The grounds | `regions/spring_manor.gd` | Rose garden, reflecting pool, heron fountain among the irises, stables, gate, the rise behind the east wing, the meadow. Who is about and what waits there depends on the chapter, its flags and the hour. Midsummer adds the bonfire, the dancers, the musicians' corner and the food tables. |
| The house | `regions/manor_in.gd` | One script for every room: hall, dining room, library, gallery, painting room, upper hall, her room. `BEATS` lists the scene waiting in each room per chapter: [room, chapter, flag needed, flag that marks it played, scene]. The scene sets that flag first, so it plays once. Interiors do not pass time. |
| The woods | `regions/spring_woods.gd` | The trail from the manor, the footbridge, the birch grove, the willow glen and the Calanmai hollow. |
| The Bogge | `regions/bogge_watch.gd` | Not a fight. Its voice drags her gaze one way; push the other way inside 1.2 seconds. Eight pulls; failing fills the dread, and full dread means she looked. |
| The Attor | `regions/attor_watch.gd` | Not a fight. Seven seconds to get behind a hedge on the garden's north side, then keep still while it is near; stepping into the open is the end of her. |
| The puca and the naga | `scripts/combat/encounter.gd` | Stand-up fights she cannot finish alone, as in the book. She holds on until Tamlin arrives (32 seconds for the puca, 58 for the naga), or wins outright. |
| Dialogue | `tools/dialogue/` | Chapters 6 on are written in a compact script (`src/*.txt`) and compiled to `data/book1/dialogue` by `dlgc.py`; `check.py` cross-checks speakers, items, lore, regions, region methods, fights, scene links, room beats and portrait expressions. Chapters 1 to 5 stay hand-edited JSON. |
| Clothes | `GameState.outfit` | Her walking sheet and portraits follow what she wears: her own clothes until the bath in Chapter 6, spring clothes after. From Chapter 24 Alis's portraits show her without the glamour. |
| Weapons | `data/items.json` | Table knife (4 damage), Lucien's knife (9), the jeweled hunting knife (12). The bow comes back on the Chapter 9 ride. |

### Guesses and pushback (Milestone 2)

- The puca and naga fights end with Tamlin's rescue on a timer rather than on
  her winning, because in the book she survives them only because he comes.
  Beating them before he arrives also ends the fight.
- The Bogge and the Attor are tests of nerve, not fights. In the book looking
  at the Bogge or being found by the Attor is death, so they have no health
  bars; failing ends with a Try again.
- Choices change lines, not the story: she always gives Rhysand a false name,
  and the Midsummer wine only changes how the night reads (the end window
  records whether she drank it). The night in Chapter 27 can go further or
  stay a held embrace; the further version fades to black.
- She wakes at the gate without her bow and knife and gets the bow back for
  the ride in Chapter 9. Her walking sprite still shows a bow on her back
  until the bath, a known mismatch.
- Rhysand's Fire Night scene uses his portrait under the name "The
  Stranger", since she does not know him yet.
- Trees are drawn about five times Feyre's height, so their crowns cover a
  lot of ground. Where a scene needs to be seen, the trees stand back: the
  birch grove is an arc open to the south rather than a closed ring (from
  above, the southern birches roofed over the whole clearing and hid the
  naga), and the grounds keep an open lawn south of the pool for Midsummer
  and a wide meadow south of the rose garden for the will-o'-the-wisps.
  The trees left out still count as placed, so the rest of the woods and
  grounds keep the layout they had.
- A tree or a house fades while anyone stands behind it, people included,
  not only Feyre and creatures.

## Milestone 1: the vertical slice (Chapters 1 to 5)

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
bot that reads 85% of his tells won 22 of 24 with 17.5 of 30 HP left on
average; a careless bot that reads 25% won 18 of 24 with 7.0 left. Over 60
seeded runs the careful bot wins about 90% with about 17 HP left. (Trees are
obstacles, so moving them in the art pass, off the brook and out from in
front of the rose bushes and the thicket, changed these by a fight or two.)

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
  (`shaders/noise.gdshaderinc`) that gives the same value on every GPU. You
  confirmed on 2026-11-24 that the lines are gone on your machine.
- The cottage is one painting. Collisions, lights and people are placed on
  measurements of it, and the table, benches, dresser and door posts are cut
  out of it and sorted with the people, so Feyre can stand behind the table
  with her legs hidden. The firelight is a real light: the partition between
  the rooms blocks it, so the bedroom gets only what comes through the doorway.
- Rooms smaller than the screen sit in its middle on a dark ground, and the
  camera comes in closer indoors (2x, against 1.15x outside), so the painting
  and the people are shown large. Character sheets are painted at four times
  their layout size so they stay sharp there.
- The painted pines stand up to four times Feyre's height, so trees and
  buildings fade to about 40% while she or a creature stands behind one, and
  the forest keeps trees from standing just in front of the bramble thicket, a
  rose bush or a place to search.
- The wolf is drawn taller than Feyre and about eight times her width, so in a
  close fight he can hide her completely. Where a creature in front of her covers her, her outline shows
  through him (`shaders/ghost.gdshader`): a copy of her sprite above the world,
  masked by his painting, so it marks exactly the covered part of her and
  nothing else. It is a faint fill with a pale rim, not a glow, and it does not
  appear while he is hidden in the brush or standing behind her. Fading the
  wolf instead would hide his tells, which the fight is built on.

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
   `tools/make_normals.py` derives approximate normals from the paint and the
   style guide pins the angle. In practice 6 of the 74 generated targets needed
   a reroll; the cottage took two paintings and three edit passes, and its
   bedroom doorway was patched by hand.
6. Walk cycles. Image models do not keep a walk cycle consistent, so each
   character is a turnaround (front, side, back) generated from their portrait,
   and Feyre alone has walk strips; `tools/make_sheet.py` puts every figure on
   one scale with its feet on the frame bottom. Her walk is two steps per
   direction, which reads well at game size; everyone else stands still.
7. No grind in a canon-locked story. The loop comes from the hunt, foraging,
   the hotbar and satchel, the shop, map discovery and the journal. Optional
   fights fit best in the Spring Court woods from Ch 7.
8. Art budget. The manifest lists 87 images. The estimate said about 0.75
   credits an image; the real price was 1.25 at 1k, 2 at 2k and 3.25 at 4k.
   The whole set took 80 generations and 150 credits, leaving 1,058 of the
   1,210. The real cost was the cleanup.

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
- Region layouts (forest paths, village square) are invented; the book gives mood, not floor plans. The cottage follows its painting: a main room with the hearth, table and settle, and a bedroom through a doorway in the partition.
- Dialogue lines are short canon quotes where they exist, otherwise written to match the voice, and kept short.
- Content: violence shown, sex scenes fade to black (none in the slice).

## Known gaps

- Animation is light: Feyre walks in four directions; everyone else breathes
  in place and does not walk. Creatures move as whole sprites.
- The night ride and the Wall are lit and graded but have no painted
  background beyond the snow, the pines and the riders.
- This build's network can generate on Higgsfield but cannot reach its upload
  and download hosts, so files move through a helper thread on the
  `acotar_game` environment (the `art_pipeline` folder in the project files).
  Running this project on that environment (Project settings) removes the step.
- Sound is synthesised; there is no voice acting.
- No key rebinding.
- The web export is configured but not yet tested in a browser.

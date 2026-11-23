# Design notes: Milestone 1

What the vertical slice contains, how the systems work, where the build differs
from the spec and why, and every guess made along the way.

## Scope of the slice

Chapters 1 to 5 of Book 1, playable start to finish:

1. Ch 1, the winter forest: explore, find the doe, the wolf battle (gimmick fight).
2. Ch 2, the cottage: family dinner, Elain's paint tins (first relic), first power tier.
3. Ch 3, the village: market, Isaac, the mercenary, the Children of the Blessed, the charm stall (shop, card removal, selling hides).
4. Ch 4, the Beast at the door: dialogue confrontation with canon-locked choices.
5. Ch 5, the night ride north and the Wall: ride, then a cinematic crossing. Ends the slice and offers the carry-over export.

## Systems

| System | Where | Notes |
|---|---|---|
| Content | `data/*.json`, `data/book1/*.json` | Cards, enemies, relics, items, statuses, tiers, shops, chapters, characters, locations, quotes, lore, dialogue. No story text is hard-coded in scripts. `DB.validate()` cross-checks every reference and runs on boot in debug and in the tests. |
| Battle rules | `scripts/battle/battle_core.gd` | Pure logic, no nodes. Emits events that the scene animates, which is what lets the bots play thousands of fights in the tests. |
| Battle scene | `scripts/battle/battle_scene.gd` | Arena, lit portraits, intent, hand, piles, energy, items, hit feedback (flash, knockback, sparks, hit stop, shake, floating numbers), mid-battle dialogue. |
| World | `scripts/world/region.gd` + `regions/*.gd` | Each region builds itself in code: ground, y-sorted props, lights, occluders, colour grade per hour, projected sun shadows, fog, god rays, snow, triggers, NPCs. |
| Dialogue | `scripts/autoload/dialogue.gd` | Portrait pop-ups that slide in, typewriter text, choices (keys 1 to 4), actions (`do`) that drive the whole story: items, relics, flags, tiers, battles, shops, region changes. |
| Progression | `game_state.gd`, `power_tiers.json` | Tiers follow canon, not XP. See below. |
| Save | `save_system.gd` | Versioned JSON with a carry-over block that later games import. |

### The wolf fight ("The Hunt")

In the book Feyre kills the wolf from hiding. So the fight starts with Feyre
Hidden: attacks from hiding deal double damage, and the wolf stalks the doe
instead of her. Shots and movement make Noise; at 3 Noise the wolf finds her.
If it reaches the doe first, the doe is ruined (less meat, a worse hide price
in Ch 3). Ash arrows stop its regeneration. Mid-battle lines fire on start,
first ash hit, being found, the doe dying, both sides at low HP, turn 4 and
victory.

Balance target, enforced by the test suite: a simple greedy bot wins 60 to 97
percent of the time and finishes with about half HP, and a random bot loses
almost always. Last run: greedy 97 percent, 14.1 of 30 HP left; random 7 percent.

### Power tiers

| Tier | Name | Chapter | Max HP | Change |
|---|---|---|---|---|
| 0 | Starving Mortal | 1 | 30 | start |
| 1 | Fed Huntress | 2 | 36 | power cards unlocked, Survivor's Resolve |
| 2 | Guest of Spring | 7+ | 44 | |
| 3 | Suriel Hunter | 15+ | 50 | |
| 4 | Fire Night | 20s | 52 | |
| 5 | Prisoner | Under the Mountain | 38 | deliberate dip |
| 6 | Trial Survivor | trials | 46 | |
| 7 | Made Fae | end | 90 | 5 energy, 7 card hand, +4 strength |

Only tiers 0 and 1 are reachable in the slice. The dip at tier 5 is intentional:
she is weaker Under the Mountain in canon, and it sets up the Made Fae spike.

### Save and carry-over

`user://saves/<slot>.json`, format `acotar-save`, schema 1. Split into
`carry_over` (tier, stats, deck, relics, items, journal, canon choices) and
`progress` (chapter, region, flags, HP). `SaveSystem.migrate()` upgrades old
schemas step by step. The end of the slice (and of Book 1 later) writes an
`acotar-carryover` file; Book 2 calls `SaveSystem.read_carryover(path)` and
ignores `progress`. Saves are written at checkpoints (after the wolf, after
dinner, before the Wall).

## Pushback on the spec

1. Chapter range. The spec says the slice is "Chapters 1 to 3: the winter hunt
   and the wolf battle, the village and family cottage, Tamlin's arrival and
   crossing the Wall". In the book Tamlin arrives in Ch 4 and they cross in
   Ch 5. I built Ch 1 to 5 so the slice covers everything listed.
2. The Wall crossing is not playable. Feyre is magically asleep for it in
   canon. It is a cinematic after a short playable night ride. Making it a
   level would break canon for a set piece.
3. The Beast at the door is dialogue, not a fight. In canon she cannot win and
   does not try; a battle there would teach the player that losing is a bug.
   The choices are canon-locked with flavour differences.
4. AI art and lighting pull against each other. The world lighting needs normal
   maps and consistent top-down angles; image models give neither reliably.
   `tools/make_normals.py` derives approximate normals, and the style guide
   pins the angle, but expect rerolls and some hand cleanup on props.
5. Expression sets and walk cycles. Consistent faces across 8 expressions need
   a reference-image workflow (built into the manifest). Walk-cycle sheets are
   not realistic to generate and are left as placeholders.
6. Windows first, web second costs lighting. The web build uses the
   Compatibility renderer: shadows are softer, glow is weaker and the HDR 2D
   path is off. The screenshots in the PR are from the Compatibility renderer
   (headless capture), so the Windows Forward+ build looks better than them.
7. "Addictive loop" in a canon-locked story. The slice gets its loop from the
   deck (rewards, upgrades, removal, shop), collection progress and the journal.
   There is no grind and no random battles; that would fight the pacing of the
   book. If you want optional fights, the natural place is hunts in the Spring
   Court woods (Ch 7 onward).
8. Art budget. Generating the whole slice is about 73 kept images, roughly 195
   generations with rerolls, about 146 credits at 0.75 credits each. Your
   balance covers it many times over; the real cost is the hand cleanup.

## Guesses I made

Each of these is my call, not canon or spec. All are data or one-line changes.

- Tamlin's beast form is "the Beast" in the slice; his name is not revealed (canon).
- The wolf is Andras, but the game only shows "The Wolf" until the lore unlocks after the fight.
- Wolf HP 68, regen 4, Lunge 13, Maul 6 x 2, Desperate Fangs 16 (from balance runs, not canon).
- Feyre starts with 30 HP, 3 energy, a 12-card starter deck and one ash arrow.
- The ash arrow is Innate, Exhausts, and deals 10 damage plus Ash-Struck. In Ch 4 the Beast snaps the remaining ash arrow and throws it in the fire (canon), so the card is removed from the deck there. Treating it as a single reusable card until then is my call.
- Silverspring snare wire (relic) and the iron bracelet (shop relic) are game inventions with canon flavour.
- The charm stall in the village is the shop. Prices: cards 6 to 10 coins, card removal 8, wolf pelt sells for 18, doe hide 12, damaged hide 3.
- Coins come only from selling hides in Ch 3 (canon: she sells the pelt for silver).
- Card rewards come from the wolf fight and from story beats; rare chance 15 percent.
- Time of day runs only outdoors (about 1 game hour per real minute in the forest), and story beats set the hour.
- The Prythian map in the journal is a schematic drawn from coordinates I took from your map image. The image itself is not in the repo.
- Region layouts (forest paths, village square, cottage rooms) are invented; the book gives mood, not floor plans.
- Card names not taken from the book (Sidestep, Brace, and so on) are mine.
- Dialogue lines are short canon quotes where they exist, otherwise written to match the voice, and kept short.
- Content: violence shown, sex scenes fade to black (none in the slice).

## Known gaps

- All art is labelled placeholder. Lighting, layout and feel can be judged; looks cannot.
- No audio. The engine falls back cleanly; music and sound are a later milestone.
- No settings menu (volume, key rebinding, resolution).
- Web export is configured but not yet tested in a browser.

# Style guide

One look for every piece of art, so placeholders, AI generations and anything
hand-made sit together. `tools/build_manifest.py` prepends the style block below
to every prompt; change it there, not per asset.

## The look in one line

Painted dark fairytale. Hand-painted portraits and battle art with visible brush
strokes, set against a stylised top-down world that is mostly lit, not drawn:
the light and colour grading carry the mood.

## Palette by region

| Region | Base | Accent | Light |
|---|---|---|---|
| Winter forest (Ch 1) | snow `#e2e8f4`, shadow `#aab8d2`, pine `#3a4a5c`, bark `#1e2a34` | low sun gold `#c9a46a` | cold low sun, blue shadows, dusk to deep blue |
| Archeron cottage (Ch 2, 4) | soot brown, worn plank, ash grey | ember orange | one hearth, everything else falls to dark |
| Mortal village (Ch 3) | mud, slush, grey plaster | faded stall cloth: red, blue | flat overcast day, warm windows |
| The Wall (Ch 5) | night blue, black pine | Fae gold, green eye-glow | moon behind, a shimmer at the seam |
| Spring Court (later) | green, rose, cream | gold | eternal late spring afternoon |
| Under the Mountain (later) | black stone, red | sickly gold | torches, no sky |

Mortal lands stay desaturated. Colour saturation is a story signal: it rises as
Feyre crosses into Prythian, so do not let mortal-side art get lush.

## Portraits (dialogue and battle pop-ups)

- 2:3, waist up, three-quarter view. Feyre faces right (she sits on the left of
  the screen); everyone else faces left.
- Transparent background. Generate on flat mid-grey, then remove the background.
- Rim light from behind, key light from the side the character faces.
- One base image per character (neutral). Every other expression is generated
  from that base as a reference image so the face stays the same. If the face
  drifts, reroll; do not ship a drifted face.
- Book looks are in `data/book1/characters.json` (`look`). Canon details that
  must survive: Feyre's gold-brown hair, gaunt winter frame, threadbare cloak,
  bow and knife; the sisters' iron bracelets; the father's cane and ruined knee;
  the Beast's horns, golden fur and green eyes.

## Battle art

- 4:3, enemy faces left toward Feyre. Transparent background; the arena is
  drawn by the game (sky, treeline, snow, fog, lights).
- Silhouette first: it must read at a glance against a pale snow field.

## Card art

- 3:2 landscape, one bold subject, readable at 250 px wide.
- No text in the image. The frame, cost and name are drawn by the game.

## World sprites (props, terrain)

- High three-quarter top-down view, light from the upper left.
- Props: base of the object at the bottom centre of the image, transparent
  background. The game places the sprite by its base and casts a projected
  shadow from the silhouette, so do not paint a ground shadow.
- Terrain: seamless 512 px tiles, no painted shadows, even light.
- Every lit sprite needs a `_n.png` normal map: `python3 tools/make_normals.py --all`.

## Characters walking in the world

48 x 64 frames, 4 directions x 4 frames. Image models cannot keep a walk cycle
consistent, so these stay placeholders until they are hand-drawn or made with a
sprite tool.

## Typography

- Display: Cinzel (titles, names, chapter cards).
- Body: Cormorant Garamond, italic for narration.
- Both OFL, bundled in `assets/fonts`.

## UI

Deep navy and oxblood panels, thin gold borders, no glossy gradients. Gold is
for things that matter (relics, tier ups, rare cards); do not spend it on
ordinary buttons.

## Lighting rules (the top priority)

- Each region defines its own colour grade per hour (`grade_for_hour`) and sun
  shadow (`sun_shadow`). Night must be dark enough that a lantern matters.
- Interiors: one dominant source. The hearth wins; windows add a cold edge.
- Fae things glow (eyes, the Wall). Mortal things never do.
- Fog and god rays are seasoning. If you notice them first, they are too strong.

# Style guide

One look for every piece of art, so placeholders, AI generations and anything
hand-made sit together. `tools/build_manifest.py` prepends the style block below
to every prompt; change it there, not per asset.

## The look in one line

Painted dark fairytale. Hand-painted portraits and world art with visible brush
strokes, seen from above at a slant, and lit in the game: the light and colour
grading carry the mood.

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

## Size and sharpness

Final art has more pixels than the size the game lays it out at, so it stays
sharp when the camera comes close. `assets/final/density.json` records layout
size over pixel size for every file, and the game multiplies sprite scales by it
(`Art.density`). After importing, `python3 tools/final_mipmaps.py` turns on
mipmaps for those files, or fine detail shimmers when it is drawn smaller. The
project's default canvas filter is linear with mipmaps, so a sprite given a plain
texture (an arrow, a pickup) uses them too, not only the lit ones.

## World sprites (props, creatures, effects)

- High three-quarter top-down view, light from the upper left.
- Props and creatures: base of the object at the bottom centre of the image,
  transparent background. The game places the sprite by its base and casts a
  projected shadow from the silhouette, so do not paint a ground shadow.
- Effects and weapons (arrows, bow, knife, the slash): one sheet of separate
  objects on a clear background, cut apart with `tools/cut_sheet.py`. Arrows
  and the knife point right; the bow stands upright, string on the left.
- Fit everything with `tools/fit_art.py`. Every lit sprite needs a `_n.png`
  normal map (`tools/make_normals.py`); the fitting tools make them.

## Ground

- Tiles (snow, trodden mud, cobbles): square, even light, no painted shadows.
  `fit_art.py --seam cut` makes them wrap by stitching the edges along the
  cheapest seam (`tools/seams.py`) rather than blending, which would double
  every cobble.
- A patch of one ground on another (the cobbled square in the mud) frays at
  its edges in a shader (`Region.add_ground_patch`), so do not paint edges.
- Paths, the brook and roads: a 21:9 image running left to right across the
  middle, fading to plain ground at the top and bottom. `tools/make_strip.py`
  makes it wrap and fades its edges, and the game lays it along a curve
  (`Region.add_strip`).

## Painted rooms

An interior is one painting (`rooms/cottage.png`), 3:2, seen from above at a
slant with the front wall folded down so the room is open to the camera. Paint
it in even, fairly bright light; the game adds the firelight. Walls, furniture
and doors are measured on a 1500 x 1000 grid of the painting, and the region
script lays collisions, lights and people on those numbers. Furniture someone
can stand behind (the table, the benches, the dresser, the door posts) is cut
out of the painting along its outline and sorted with the people, so it hides
their legs. People are scaled so a standing figure is about 0.6 of the bed's
length; the camera comes in closer indoors.

## Characters walking in the world

4 x 4 sheets: rows face down, left, right and up; columns are a walk (stand,
step, stand, step). Each character is generated as a turnaround (front, side,
back) with their portrait as the reference, and Feyre also as three walk
strips; `tools/make_sheet.py` sets every figure on the same scale with its feet
on the bottom of the frame. Left is the right view mirrored. Frames are 192 x
256 pixels for a 48 x 64 layout, sharp at the interior camera.

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

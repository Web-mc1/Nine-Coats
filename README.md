# Nine Coats

*The last warm room on the pass.*

A small, calm game about an inn at the top of a mountain pass, where the road
closes for weeks and everyone who climbs it is either running from something or
going back to it. You inherit the only warm room for a long way in any
direction. Nine tables. One hearth. A pantry with five things in it, and a pot.

Built with Godot 4.7. The art is generated in code, so there are no image files
to lose.

## Running it

Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET),
open this folder as a project, and press **F5**.

From a terminal:

```sh
godot --path .
```

## Playing it

| Key | Does |
| --- | --- |
| `W A S D` / arrows | walk |
| `E` / `Space` / `Enter` | do the thing the prompt says |

An evening runs from 17:00 to 23:00 and takes about four real minutes:

1. A traveller comes in out of the rain, hangs up their coat and sits down.
2. Ask them what they are hoping for. They say it out loud.
3. Go left through the doorway into the kitchen. Take two things off the shelf.
4. Put both in the pot, then press E again to cook them.
5. Carry the bowl back out and serve it.
6. Sit with them afterwards and listen. They have three lines each, and nothing
   they say is a puzzle.
7. Feed the fire if it gets low.
8. At 23:00 the ledger opens, you get one drafted line about the night, and you
   sleep.

Five things keep in the pantry -- mushroom, potato, onion, thyme, cheese -- and
any two of them make a dish. Five choose two is ten, so the whole menu is the
whole pantry. There is no recipe book; the guests tell you what they want by
name and you learn the pairs by cooking them. Serve the wrong bowl and they eat
it anyway, for a little less.

Three guests a night. Nobody is ever angry with you, nothing is on a timer, and
you cannot lose money. If you serve nobody, the game writes that down as its own
small story.

## What is in the slice

- Two rooms you can walk between: the taproom with nine tables and a chair at
  every seat, and the kitchen behind it with a shelf, a chopping table and a
  stove.
- A hearth that needs feeding, a coat rack, a window with rain on it, and a cat
  that does not move.
- A day clock with dusk falling into a warm amber night.
- Three animal guests (a badger cartographer, a heron courier, a mole who cannot
  sleep) who arrive, sit, talk and leave.
- Coats, which are the whole title: they appear on the rack as guests arrive and
  come down as they go.
- Ten dishes out of five ingredients, cooked two at a time in the pot.
- Guests who sit down on chairs rather than standing at the table, breathe, and
  lift a spoon while they eat.
- Speech: each guest talks out loud through your system's speech engine, at
  their own pitch. Without one, they fall back to a synthesised voice blip.
- Carrying, serving, coins, a fire to keep, a ledger, and a saved game in
  `user://ninecoats_save.json`.
- Sound, all synthesised in code: a slow piano loop for the evening, boots on
  the boards as you walk, a ping when a bowl is paid for, and a small voice for
  each animal when they speak to you.

Deliberately not in it: farming, fishing, seasons, romance, combat, weather
simulation. Each of those is a second game.

## The art

Everything visual is drawn by `scripts/Art.gd`: the stone wall, the floorboards,
the window and its curtains, the hearth, the door, the rack, the furniture, the
animals, the fire, and a hand-built 5x7 bitmap font. Sprites are 12x16 at a
320x180 internal resolution, scaled up by whole numbers so pixels stay square.

Real hand-drawn art can replace any of it later by swapping the function that
returns that image — nothing else in the game knows how a sprite is made.

## Layout

```
project.godot         320x180, integer scaling, nearest filtering
scenes/Main.tscn      one node; the world is built in code
scripts/Art.gd        every pixel in the game
scripts/Main.gd       the evening: clock, guests, serving, ledger, save
scripts/PixelText.gd  bitmap text rendering
scripts/Atmosphere.gd rain on the glass, steam off the pot
scripts/Audio.gd      synthesised music, footsteps, voices (no audio files)
scripts/Recipes.gd    the five ingredients and the ten dishes they make
tools/smoke.gd        headless test that drives a whole night
tools/preview.gd      composites preview.png from the art code, no GPU needed
```

## Testing

There is no display in the build environment, so the game is checked headlessly:

```sh
godot --headless --path . -s tools/smoke.gd
```

It floods the floor of both rooms to prove every jar, the pot and every seat
can be walked to, then drives a full evening: taking two ingredients, cooking
them, carrying the dish out, serving it, a wrong dish being eaten anyway, the
order line, the three dialogue lines, the coat coming off the rack, feeding the
fire, the ledger at 23:00, and the next night starting clean. 63 checks.

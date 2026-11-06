# Nine Coats

*The last warm room on the pass.*

A small, calm game about an inn at the top of a mountain pass, where the road
closes for weeks and everyone who climbs it is either running from something or
going back to it. You inherit the only warm room for a long way in any
direction. Nine tables. One hearth.

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

1. A traveller comes in out of the rain and hangs up their coat.
2. Take a bowl of stew from the counter behind you.
3. Carry it to their table and serve it.
4. Sit with them afterwards and listen. They have three lines each, and nothing
   they say is a puzzle.
5. Feed the fire if it gets low.
6. At 23:00 the ledger opens, you get one drafted line about the night, and you
   sleep.

Three guests a night. Nobody is ever angry with you, nothing is on a timer, and
you cannot lose money. If you serve nobody, the game writes that down as its own
small story.

## What is in the slice

- A walkable inn: nine tables, a counter, a hearth that needs feeding, a coat
  rack, a window with rain on it, and a cat that does not move.
- A day clock with dusk falling into a warm amber night.
- Three animal guests (a badger cartographer, a heron courier, a mole who cannot
  sleep) who arrive, sit, talk and leave.
- Coats, which are the whole title: they appear on the rack as guests arrive and
  come down as they go.
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
tools/smoke.gd        headless test that drives a whole night
tools/preview.gd      composites preview.png from the art code, no GPU needed
```

## Testing

There is no display in the build environment, so the game is checked headlessly:

```sh
godot --headless --path . -s tools/smoke.gd
```

It drives a full evening (arrival, walking, taking a bowl, serving, coins, the
three dialogue lines, the guest leaving, the coat coming off the rack, feeding
the fire, the ledger at 23:00, and the next night starting clean) and reports
each check.

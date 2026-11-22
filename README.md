# Adventure

A third-person puzzle adventure with a cartoon look and a spooky sense of humour,
built in [Godot 4](https://godotengine.org).

You are a health and safety inspector, sent to sign off Wyrmhollow Dragon Park the
night before it opens. The staff are gone. The enclosures are not as closed as they
should be. And something is narrating everything you do.

**Chapter One: Sign Here** is playable from start to finish: three rooms, a handful
of puzzles, eleven achievements and a cliffhanger.

## Playing

1. Install Godot 4.7 or newer.
2. Open Godot, choose **Import**, and select `project.godot`.
3. Press **F5**.

| Control | What it does |
|---|---|
| Left click | Walk there, or use the thing you clicked |
| Right click | Look at something (and put away the item in hand) |
| Inventory buttons | Pick an item, then click something to use it on |
| Tab | Open the clipboard: your notes, score and achievements |
| Space | Next line of narration |
| M | Mute |

Progress saves automatically.

## How it is put together

Everything on screen is built in code from simple shapes with cartoon shading and
ink outlines, and all sound is synthesised at startup, so the project contains no
art or audio files.

| Path | What is in it |
|---|---|
| `scripts/main.gd` | Runs the game: input, walking, moving between rooms |
| `scripts/game.gd` | Story flags, inventory, notes, achievements, saving |
| `scripts/room.gd` | Base class every room builds on |
| `scripts/rooms/` | The rooms themselves: set, hotspots and story text |
| `scripts/kit.gd` | The art kit: shapes, signs, cave glyphs, the hatchling |
| `scripts/ui.gd`, `keypad.gd`, `breakers.gd` | Interface and close-up puzzle panels |
| `scripts/sfx.gd` | Synthesised sound |
| `shaders/outline.gdshader` | The ink outlines |
| `tests/` | An automated playthrough of the whole chapter |

## Testing

```
godot --path . res://tests/smoke_test.tscn
```

This plays Chapter One from the title screen to the ending, checks that every
hotspot can be clicked and walked to, and exits with the number of failed checks.
Set the `SMOKE_OUT` environment variable to a folder to save screenshots along the way.

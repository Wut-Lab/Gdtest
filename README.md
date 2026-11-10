# Square Hop (Godot)

A small platformer: run, jump, bounce and teleport a red square through a 100-tile level to the green goal.

- **Play it:** https://claude.ai/artifact/2gMkwUS3qg2sqVGHM762Cw
- **Level editor (works on a phone):** https://claude.ai/artifact/8As8FYAdjdxrbhuugZhsWZ
Built for Godot 4.6 (works in 4.4+; standard build, not .NET).

## Open and run

1. In Godot's Project Manager choose **Import** and select `project.godot` in this folder.
2. Press **F5** (Run Project).

## Project layout

```
scenes/main.tscn            The game: background, world, HUD and touch controls. Run this.
scenes/player.tscn          The player square, its collision shape and the following camera.
scenes/goal.tscn            The goal square.
scenes/hud.tscn             Timer, fall counter, start and win menus.
scenes/touch_controls.tscn  On-screen buttons for phones and tablets.
levels/level_01.txt         Level 1's layout as a text map (see "Edit a level").
levels/level_01.tscn        The level scene: loads the text map into its Ground tile map.
scripts/                    One script per scene.
art/tiles.png               The four tiles. art/tileset.tres sets up collision and marks rubber.
scripts/tuning_panel.gd     The in-game Tune panel.
web/                        Pages for playing and editing in a browser (see web/README.md).
tools/                      Build scripts and the auto-play test bot (see tools/README.md).
prototype/                  The original single-file browser version.
art/ui_theme.tres           Colors, fonts and button styles for every menu.
```

## Common changes

**Edit a level.** The easiest way is the level editor page (link above): tap tiles onto the grid,
press Play to try it in the real game, then use Level > Copy level text and paste it to Claude.
Levels are plain text, one character per 32 px tile, 17 rows tall:

| Character | Tile |
|---|---|
| `.` | empty |
| `#` | ground |
| `=` | floating platform (you can jump up through it) |
| `R` | rubber: bounces you back up, keeping your sideways speed. Hold jump as you land for a big bounce. |
| `1` `2` `3` | red, yellow and blue teleporters. Touching one sends you to the other pad of its color, keeping your speed. The pad you arrive on stays off until you step away. Put arrival pads off the main path, or players walking past get sent back. |
| `P` | player start |
| `G` | goal |

You can also edit `levels/level_01.txt` directly, for example in the GitHub app. In the Godot
editor you can instead clear the level's *Map File* and paint the Ground tile map by hand.

**Tune the movement.** In the game, tap **Tune** (top right) and drag the sliders while you play.
Your values are saved on that device. **Copy settings** gives a line of text; paste it to Claude to
make those the game's defaults. In Godot, the same values are on the Player scene under *Running*,
*Jumping*, *Rubber* and *Look*.

**Change the controls.** Project > Project Settings > **Input Map**. The actions are
`move_left`, `move_right`, `jump` and `restart`. Keyboard and gamepad are both set up.

**Restyle the menus.** Open `art/ui_theme.tres` in the Inspector.

**Add a level.** Duplicate `levels/level_01.tscn`, repaint it, then select **Main** in
`scenes/main.tscn` and drag the new file into *Level Scene*.

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | ← → or A D | D-pad or left stick | Left and right buttons, bottom-left |
| Jump (hold for higher) | Space, ↑, W or Z | A / Cross | JUMP button, bottom-right |
| Restart | R | | |

Touch buttons appear on touchscreens. To try them on a PC, turn on
**Project Settings > Input Devices > Pointing > Emulate Touch From Mouse**.

## Export to PC or mobile

Install export templates once: **Editor > Manage Export Templates > Download and Install**.
Then use **Project > Export**:

- **Web:** a preset is included, with thread support off so it runs on normal web hosts
  (itch.io works well). It exports to `export/web/index.html`.
- **Windows / macOS / Linux:** add the preset and click **Export Project**.
- **Android:** install the Android SDK and a JDK 17, set their paths in
  **Editor Settings > Export > Android**, then add the Android preset. **Remote Debug** runs it
  on a phone plugged in over USB.
- **iOS:** needs a Mac with Xcode.

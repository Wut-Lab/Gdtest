# Square Hop (Godot)

A small platformer: run and jump a red square through a 100-tile level to the green goal.
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
levels/level_01.tscn        The level: a Ground tile map, a Start marker and a Goal.
scripts/                    One script per scene.
art/tiles.png               The three tiles. art/tileset.tres sets up their collision.
art/ui_theme.tres           Colors, fonts and button styles for every menu.
```

## Common changes

**Edit the level.** Open `levels/level_01.tscn`, select **Ground**, and open the **TileMap**
panel at the bottom. Paint with the tiles:
- Tile 1 is a ground surface, tile 2 is ground fill underneath.
- Tile 3 is a floating platform you can jump up through from below (one-way collision).

Drag **Start** to move where the player begins, and **Goal** to move the finish. The camera
limits and the fall line follow whatever you paint.

**Tune the movement.** Open `scenes/player.tscn`, select **Player**, and change the values in
the Inspector under *Running* and *Jumping*. Hover any value for an explanation.

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

# Tools

Godot is told to ignore this folder (`.gdignore`). To run a tool, copy it into the project root first.

- `make_art.gd` writes `art/*.png` (tiles and touch buttons).
- `build_scenes.gd` regenerates the Input Map, tile set, UI theme and every scene.
  **This overwrites edits made in the editor**, so only use it to rebuild from scratch.
- `make_audio.py` (Python 3 + numpy + ffmpeg, run from anywhere) writes `audio/music.ogg` and the
  sound effects. Everything is synthesized; edit and rerun it, then import.
- `bot.gd` plays level 1 automatically (hold right, jump at walls and ledges) and prints the result.

    godot --headless --path . --script res://bot.gd

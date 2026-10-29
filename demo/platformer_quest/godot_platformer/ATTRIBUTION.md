# Godot 2D Platformer Demo

Source: https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer
(commit b761b4c, October 2026). Also on the Godot Asset Store as "Platformer 2D Demo".

Code, art and sound effects are by the Godot Engine contributors, released under
the MIT licence in `LICENSE.md` beside this file. That licence covers everything
in this folder. The demo's music is not included.

Changes made for the NPC TalkKit quest demo:

- Moved under `demo/platformer_quest/godot_platformer/` and repointed every path.
- Removed `class_name` from every script, so they cannot clash with classes in
  the project you copy them into. Scripts that need another's type preload it.
- Player and enemies use a fixed gravity of 2100 instead of the demo project's
  physics setting.
- The player has `input_enabled` (a conversation holds it still) and `can_shoot`
  (the gun is a quest reward).
- Enemies emit `destroyed`.
- Left out: the music, the pause menus, split screen, the level camera script
  and the project settings.

Outside this folder, `demo/platformer_quest/dialogue/portraits/` holds crops of
`player/robot.webp`, tinted, used as the travellers' portraits. They are under
the same licence.

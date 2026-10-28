# Platformer showcase

Open `platformer_showcase.tscn` in Godot to inspect the complete demo scene.
The level has a `CharacterBody2D` player (Darwin, a fox), a ground collider, a
following `Camera2D`, three characters — Haru, Ren and Jin, who walk the
level as a frog, an eagle and an opossum and talk with the portraits in
`demo/characters/` — each with its own `NPCTalkKit` node, and a HUD. The script handles movement, sprite animation
and host-game callbacks — it owns no dialogue content.

## Content lives on the nodes

Every conversation is authored **inline on its `NPCTalkKit` node** and saved in
the scene file. Select `Haru/BottomTalkKit` and open the **TalkKit**
main screen to read and edit it.

The `dialogue/` folder holds what is shared: speakers, dialogue boxes, the
placement for Ren's bubble, each speaker's portrait and the voice blips.

## The three checkpoints

1. Haru on the lower trail uses the **Demo Box**, a Classic Panel variant.
2. Ren above the trail uses the **Speech Bubble** and asks a
   question that pauses on a **blocking event**.
3. Jin near the old shrine uses a box with a **custom renderer** scene.

Completing each conversation emits a checkpoint event, printed to Output.

## What the demo demonstrates

| Feature | Where |
| --- | --- |
| Inline authoring | All three nodes; no `.tres` file per conversation |
| Text parameters | `{{player_name}}` in every welcome line, filled at `play()` |
| Blocking events | Ren's `canopy_offer` — playback pauses, the host answers, then `resume()` |
| Dialogue boxes | Same node type, three different looks |
| Narration with `say()` | Falling into the river; nothing authored |
| Host-owned logic | Player lock, facing and checkpoint events are handled in `platformer_showcase.gd` |

## Controls

- Left/right arrows: move
- Space: jump; reveal or advance while dialogue is open
- `E`: talk; also reveal or advance the active conversation
- Left click: reveal or advance dialogue
- Escape: cancel

## Artwork

Third-party artwork and its licence and attribution notes are stored beside the
files under `assets/third_party/`. All of it is CC0 or released for commercial
use and redistribution.

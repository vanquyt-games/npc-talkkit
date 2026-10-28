# Built-in dialogue box templates

A template is everything about a dialogue box: which parts it has, how they are
painted, and how it animates. Add one to a node in the TalkKit workspace's
**Dialogue Boxes** section and pick it as a conversation's default box. A
conversation with no box falls back to `classic_panel`.

| Template | Look |
| --- | --- |
| `classic_panel` | The default. Dark panel across the bottom, portrait, gold speaker name. |
| `speech_bubble` | Cream bubble with a tail, no portrait, pops in. |
| `terminal` | Square corners, green on near-black, no transition. |

The same renderer draws all of them. A panel and a bubble differ by settings —
one has a portrait and a continue marker, the other a tail — not by scene.

**None of them bundle a font or a texture**, so they inherit whatever font your
project already uses.

To make your own: in **Dialogue Boxes**, choose **+ New** and start from the
closest preset, change what you like, and use **Save as Shared…** when other
NPCs should reuse it. For a hand-drawn frame, set the Panel's Appearance to
Nine-slice Texture. Name boxes, portrait frames and ornaments are layers. For a
structure the settings and layers cannot describe, point `renderer` at a scene
of your own — see [the example](../box/custom_renderer_example.tscn).

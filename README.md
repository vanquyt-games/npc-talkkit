# NPC TalkKit for Godot

> **NPCTalkKit lets you play named NPC conversations the way AnimationPlayer plays named animations.**
>
> **Game owns the logic. TalkKit owns the conversation playback and presentation.**

A non-invasive dialogue kit for Godot 4.6 and 4.7.x. Add one node to an NPC you
already have, type the lines in the TalkKit workspace, and call `play()`. Your player
controller, quests, and saves keep working exactly as before.

It does not own quests, player control, inventory, saves, NPC AI, or branching
dialogue logic.

## Quick start

1. Copy `addons/npc_talkkit` into your project.
2. Enable **NPC TalkKit** in Project Settings → Plugins.
3. Add an **NPCTalkKit** node to an NPC.
4. Select the node and press **Open** beside Conversations in the Inspector, or
   switch to the **TalkKit** main screen.
5. Press **+** to create the first conversation, then type. TalkKit prepares the
   first line and a local Classic Panel; no resource files are created.
6. Play it:

```gdscript
$NPCTalkKit.play(&"greeting", {"player_name": "Alex"})
```

Or say something with nothing authored at all — a node with zero conversations
is a working node:

```gdscript
$NPCTalkKit.say("[color=#ff6b6b]Stop right there![/color]")
```

Opt into as much coupling as you want, and no more:

```gdscript
$NPCTalkKit.request_player_lock.connect(set_player_locked)
$NPCTalkKit.event_triggered.connect(handle_talk_event)
```

## The box, and where it goes

Four things stay separate, so each can change without touching the others:

| | Decides | Chosen by |
| --- | --- | --- |
| **Conversation** | what is said | `play()` |
| **Speakers** | who says it | the conversation, or one line |
| **Dialogue Box** | how it is presented | the conversation, or one line |
| **Placement** | where it appears | the conversation, or one line |

The node holds the **collections** these are picked from — its speakers, its
boxes, its conversations. It is a library, not a set of defaults:

```
line override  →  conversation default
```

Two levels, and nothing underneath them.

A Classic Panel can follow an NPC's head and a Speech Bubble can pin to a screen
corner — the box no longer decides placement.

Three templates ship with the addon: a panel with a portrait, a speech bubble
with a tail, and a text-only terminal. None bundle a font or a texture, so they
inherit your project's font. In the **Dialogue Boxes** workspace:
- create from a visual preset;
- give the Panel a flat style, a nine-slice frame or any `StyleBox`;
- add layers for a name box, a portrait frame or corner ornaments;
- turn on the Anatomy Map to see which setting draws which part;
- use **Save as Shared…** when other NPCs should reuse the box.

The workspace also includes a **Script · Coming soon** teaser for a future
writer-friendly text view. It is not a second data model and is not editable yet.

## 3D

Anchors project through the active `Camera3D`, with the usual traps handled:
points behind the camera are hidden rather than mirrored, the head offset is a
`Vector3` applied before projection (a screen offset alone drifts as the camera
moves), and there is an optional distance limit, distance scaling, and
occlusion raycast. `TalkInteractionArea3D` mirrors the 2D trigger.

```
demo/showcase_3d/showcase_3d.tscn
```

Built entirely from Godot primitives — no imported art.

## Several speakers, one conversation

A conversation says once who normally speaks. A line says so only when it is
the exception, and the line after it goes back on its own. There is no cast to
declare.

```
Defaults    Haru              Classic Panel

1   Default (Haru)      Default (Classic)   Who are you?
2   Guard               Speech Bubble       Step away.
3   Default (Haru)      Default (Classic)   Let him go.
4   None · narrator     Default (Classic)   The gate opens.
```

A speaker is a **dialogue identity**, not a gameplay character: a name, a face
for the box, and a voice. It carries no NodePath and no animation, so a
narrator, a radio voice or a character who is nowhere in the scene are all
ordinary speakers — and TalkKit never animates, faces, or otherwise drives
anything in your game. If you want the character to move while it talks, your
game says so:

```gdscript
$NPCTalkKit.play(&"greeting")
$AnimationPlayer.play("talk")
```

Dialogue visuals are independent of world nodes but free to reuse the same
assets: point a speaker at the very `SpriteFrames` your player already uses.

## Branching, without a branching engine

Tick `event_blocking` on a line and playback pauses until your game answers:

```gdscript
func _on_blocked(event_id: StringName, payload: Variant) -> void:
    var accepted: bool = await choice_ui.ask(payload["options"])
    $NPCTalkKit.play(&"quest_accepted" if accepted else &"quest_declined")
```

`play()` is accepted while blocked and refused while a line is being read, so a
branch works but a second interact press cannot restart what the player is
already reading.

There is no condition language and no variable store, because your game already
has both.

## Demo

```
demo/platformer_showcase/platformer_showcase.tscn
```

Walk along the trail and press `E` near each of the three characters. Each demonstrates
a different dialogue box — Classic Panel, Speech Bubble, a custom renderer — and
Ren asks a question through a blocking event.

Three more things are in there because they are easy to claim and harder to
show:

- **Two speakers in one conversation.** Haru's greeting is interrupted by Ren
  calling down from the canopy. Ren's line is the same conversation, but it is
  painted in the Speech Bubble and floats over *Ren's* body on the far side of
  the level — one speaker entry on the conversation, no override on any line.
- **A TalkKit node that is nobody.** `Narrator` has no speaker and no saved
  conversations at all. Fall off the trail and it speaks a line written at the
  moment it is needed, through `say()`. With no speaker to resolve, the box
  draws no name and no face.
- **Rich text**, in both of the above.

### Quest demo

```
demo/platformer_quest/platformer_quest.tscn
```

A small quest on top of the Godot 2D Platformer Demo. Ada asks for coins and
pays with a blaster, Volt answers from a menu that loops until you say bye, an
old archive prints its log in a terminal box, and the crabs mutter as you pass.
The choices use the game's own menu: a blocking line carries its options and
the conversation each one leads to, and the script answers with `play()`. Which
conversation an NPC starts is a plain `match` on the quest state. Ten
travellers around the level each talk in a different box from the
[box gallery](https://talkkit.vanquyt.com/guide/box-gallery), with the robot's
face as their portrait. See
[`demo/platformer_quest/README.md`](demo/platformer_quest/README.md).

## Links

- Product page: https://vanquyt.com/talkkit
- Documentation, in English and Vietnamese: https://talkkit.vanquyt.com
- Support: support@vanquyt.com, or https://vanquyt.com/support

## Documentation

The full documentation, in English and Vietnamese, is at
https://talkkit.vanquyt.com. Release notes are in [`CHANGELOG.md`](CHANGELOG.md).
[`addons/npc_talkkit/docs/architecture.md`](addons/npc_talkkit/docs/architecture.md)
is a short map of the internals.

## Support policy

- GDScript-first runtime API, with a compiled C# wrapper.
- Verified on Godot 4.6 stable and 4.7.2 stable.
- Missing optional portrait, animation, or audio resources degrade gracefully.
- No telemetry, network requests, API keys, AI service, MCP, or Godot AI
  dependency exists in the customer addon.

## License

MIT. See [`LICENSE`](LICENSE). Use it, change it, ship it in your games, commercial
or not.

The demos are a separate download, `npc-talkkit-demos-<version>.zip`, so the
addon stays small. The forest demo's third-party artwork — the ground tiles from
Ansimuz's SunnyLand Forest of Illusion and the Sunny Land characters — is CC0 or
public domain, and stays under its creators' terms rather than the MIT licence.
Each pack's licence and attribution sit beside it under
`demo/platformer_showcase/assets/third_party/`. The quest demo is built on the
Godot 2D Platformer Demo, MIT licensed by the Godot Engine contributors; its
licence and the list of changes are in `demo/platformer_quest/godot_platformer/`.

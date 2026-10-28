# Changelog

All notable changes to NPC TalkKit. Versions follow the addon, not the JSON
schema — `SCHEMA_VERSION` is tracked separately and is now `4.0`.

## 2.1.0

### Changed

- **NPC TalkKit is free and open source under the MIT licence.** The
  commercial licence is gone: use it, change it, share it, publish it.

### Added

- **Lines are translated.** A line goes through Godot's translation system
  before its `{{placeholders}}` are filled in, with the line as written as the
  key. A key such as `Hello {{player_name}}.` matches, and the translated text
  keeps its placeholders. A line with no translation plays as written.
  Covered by `tests/headless_translation.gd`.

### Fixed

- The 2.0.4 notes and the docs changelog no longer describe the demo portraits
  as hand-painted.

## 2.0.6

### Changed

- **The licence covers free copies.** A copy picked up at no cost, such as
  during a sale, carries the same licence and limits as a paid one.
- The demo credits say that the forest pack now provides only the ground tiles.

## 2.0.5

### Changed

- **The 2D demo sits on a plain backdrop.** The forest layers behind the level
  are gone, so the boxes and portraits are what you see. The ground, the
  characters and every conversation are unchanged.

### Fixed

- **No seams between the demo's ground tiles**, and no grey band under the
  level on tall windows.

## 2.0.4

### Added

- **Clip to Frame** for the Dialogue Visual. The portrait is cut to its
  frame's rounded corners, so a round frame shows a round portrait. Off by
  default, so a character can still reach past the frame.
- **Box gallery** on the docs site: ten free dialogue boxes made of flat styles
  and open-licence fonts, each a zip to unzip into `talkkit_presets/`.

### Changed

- **The continue glyph takes the text colour.** It was always white, so on a
  light box it could not be seen. A Theme still decides it when one is set.
- **The demo's portraits** are new faces in `demo/characters/`, smooth
  rather than pixel art.

## 2.0.3

### Changed

- **Tail Width shows Auto.** A tick box replaces the bare `0`; with it on, the
  slider shows the width Auto draws, and turning it off starts from there.
- **Tail Overlap hides on a bordered flat Panel**, where the tail covers the
  border by itself and the setting did nothing.

## 2.0.2

### Added

- **Head offset in the Placement editor.** Advanced 3D has **Head offset
  X/Y/Z**, the world-space point on the character the box points at. Before,
  it could only be set from a script.
- **Tail Width.** The tail's width at the Panel is set apart from its length.
  `0` keeps the old proportions.
- **Tail Aim.** **Speaker** leans the tip toward whoever is talking;
  **Straight** points it straight out on whole pixels, for pixel art.

### Changed

- **A flat Panel's border runs on around the tail**, so a bordered bubble's
  tail reads as part of the bubble instead of a bare triangle under it. The
  tail covers exactly the border, whatever **Tail Overlap** says.
- **The tail leans instead of turning.** Its base stays on the Panel's edge
  and only the tip moves toward the speaker, so the base never lifts off the
  edge when the speaker is far to one side.
- **The tail keeps clear of rounded corners.** It used to stop 20 px from the
  side, whatever the corner radius.
- **The Placement editor scrolls**, so Advanced 3D fits on a small screen.

## 2.0.1

### Fixed

- **The Live preview follows typing.** Text typed in a line's row now shows in
  the preview beside it straight away. Before, the preview kept the old text
  until another line was selected.

## 2.0.0

The authoring rebuild. 1.0.0 fixed *who* a speaker is; this fixes *where every
answer comes from*.

### Why

Resolution was four levels deep — line, participant, conversation, node — and
the node sat underneath every authored conversation deciding what it had not
said. Two costs followed:

- an Inspector field could look live and do nothing, because something three
  steps away outranked it;
- "where did Ren come from?" had no answer on any one screen. The node showed
  one speaker; the conversation that gave Ren four lines showed none.

### Changed — the model

- **The node is a library, not a default.** `speaker` → `speakers`,
  `dialogue_box` → `dialogue_boxes`: collections of what this NPC can use.
  They are where conversations and lines *pick from*. They are not a tier.
- **The conversation carries the defaults.** `default_speaker`,
  `default_dialogue_box`, `default_placement`. A scene where Haru speaks twelve
  times in the Classic Panel says so once; only the line where Ren interrupts
  says anything at all.
- **Resolution is two levels:**

      line override  →  conversation default

  and nothing underneath. `resolve_*` now take an optional conversation, so a
  question can be asked about content that is not currently playing.
- **`TalkLine.speaker_mode`** — `INHERIT`, `NONE`, or `SPEAKER`. Three states,
  not two: *"say nothing and inherit"* and *"say that nobody speaks this line"*
  are different instructions, and a narrator line inside Haru's conversation
  needs the second. A null speaker cannot express both.
- **Lines gained `placement`**, alongside the box override they already had.
- **Quick Say Defaults** — `quick_say_speaker`, `quick_say_dialogue_box`,
  `quick_say_placement`, filed under **Advanced** because a node that plays
  saved conversations never needs them. They serve `say()` and **never** reach a saved
  conversation; letting them would be the node-wide fallback this release
  removed, wearing a different name.
- **`say()` takes options:** `say(text, params, {"speaker": &"ren"})`. An
  option may be a resource or an id from the node's collections. The *key* is
  what counts — `{"speaker": null}` means narrator, omitting it means fall
  through — because a null that meant both makes a narrator unaskable. Options
  only ever select; `say()` cannot build a speaker or restyle a box.

### Removed

- **`TalkParticipant`, entirely.** What it expressed — a different box or place
  for one speaker — is a line override, which is where a reader already looks.
  It was a configuration layer that had to be opened to answer a question the
  line list should have answered.
- **`TalkBoxTemplate.visual_mode`** and the visual slot. Keeping a cast on
  screen is a renderer concern; `TalkContext.visible` stays an array so such a
  renderer remains writable, but there is nothing to configure.
- **`NPCTalkKit.anchor`.** Placement belongs to the conversation and the line,
  like everything else.
- **The `visual_novel`, `soft_light` and `comic_bubble` templates.** They were
  colour variants of a panel and a bubble. Three templates remain, each a
  different kind of box: `classic_panel`, `speech_bubble` and `terminal`.

### Added

- **Speakers and Dialogue Boxes are managed where they are listed.** **Manage**
  on the Inspector row opens the collection in place: one entry per line, each
  with Edit and a menu for Duplicate, Save as Shared, Make Unique and Remove,
  plus New and Load at the bottom.

  Removing says how much content still points at the resource, because it keeps
  playing rather than breaking.

  Not a tab on the bottom panel, and not a window: the panel's width belongs to
  writing dialogue, and the names are already on the Inspector row — so that is
  where clicking one should take you.
- **A box dropdown on every line**, beside the speaker one, both naming what
  Default would actually resolve to.
- **Override slots pick, they do not edit.** Godot's default editor for a
  Resource property unfolds the whole resource under the picker, so a line's
  Speaker slot was a complete speaker editor — and typing in it edited the
  shared `.tres`, changing Ren for every other NPC, under a heading reading
  **Overrides**. These slots now carry a list to pick from (
  the node's own collection in the dropdown — Godot's picker offers New, Load
  and Clear and never mentions it, so choosing Ren over Haru meant going to the
  filesystem for a resource the node was already holding), **Edit ↗** to the one
  place the resource is edited, and a line saying how far that edit reaches: *"npc_ren.tres — shared. Used in
  2 places here; Edit ↗ changes all of them, and any other scene using it."*
- **The conversation's defaults sit above its lines**, so the screen reads as
  "Haru in the Classic Panel, except line 3".
- **The Inspector names the collections** — *3 speakers · Haru · Ren · Player* —
  rather than showing one slot that implies there is only one.
- **`NPCTalkKit._set()` rejects the removed properties loudly.** GDScript
  silently accepts assigning a property that no longer exists: it falls back to
  a dynamic set that does nothing. Four such assignments in
  `examples/speakers.gd` survived a fully green build. The error names the
  replacement.

### Added — the dialogue box's look

- **The box fits the screen.** A forced `box_size` is a floor, so a long line
  grows the box instead of running off the bottom. Text wraps at about 440 px
  when nothing sets a width, never wider than the screen, and a long name is
  trimmed. Ornaments, a top-edge name and the tail count toward the room the
  box needs. `HIDE` keeps a visible box on screen; a box the edge would push
  over its speaker moves to their other side, with the tail turned to follow.
- **Settings show what they say.** A box reused for the next line drops the
  previous box's font and sizes; a line change no longer flashes the next line
  whole; the continue indicator keeps its room so the box does not jump; a
  textured Panel honours its Image Filter; scale reaches a StyleBox's content
  margins; a frame's padding sits around the portrait; `continue_filter` sets
  the indicator image's filter; an Image look with no image draws nothing.
  The editor preview lays the box out on the project's own screen size.
- **Your own presets.** **Actions → Save as Preset…** copies a box into the
  project's preset folder (`res://talkkit_presets`, set in Project Settings),
  and **+ New** lists every box found there under **Your presets**.
- **Removing a box says where it is used** and switches those conversations
  and lines to a replacement in one undo step.
- **One Appearance editor for every box.** The Panel's look is now `base`, a
  `TalkBoxLayer`, so the Panel, a name box, a portrait frame and every layer
  share one editor: Flat Style (`StyleBoxFlat`), Nine-slice Texture
  (`StyleBoxTexture`), Image (`Texture2D`) or an Existing Godot Resource (any
  `StyleBox` or `Texture2D`), with the same controls for the same choice.
  `background`, `border_color`, `corner_radius`, `padding`, `panel_style` and
  the other flat-panel fields on `TalkBoxTemplate` are gone; the shipped
  templates carry them in `base`.
  - A nine-slice frame has patch margins drawn as guide lines on the image,
    Stretch / Tile / Tile Fit, and a whole-number **Scale** that keeps pixel art
    crisp.
- **One padding per box.** A flat or image box pads with its own values; a
  nine-slice or StyleBox resource uses its margins, shown read-only, unless set
  to **Custom**. Padding is the layer's own and is never written into a
  StyleBox.
- **Visual Layers** (`TalkBoxLayer`) decorate the Panel, the Speaker Name and the
  Dialogue Visual:
  - name boxes, portrait frames, corner ornaments, edge strips and extra
    backgrounds;
  - each with a Position (Fill, edge or corner), a Depth (behind or above the
    content), offset, size, scale, fit, edge inset, filter and tint;
  - any `StyleBox` or `Texture2D`, including `AtlasTexture` regions.

  Overhang is never clipped and is kept on screen by placement.
- **Name placement:** inline, or on the top edge with alignment and offset.
- **Tail on a textured panel:** a chosen colour (with **Sample panel colour**)
  or an image that turns toward the speaker; plus **Tail Overlap**.
- **Continue Indicator:**
  - a glyph or an image, with an optional idle Bounce or Blink;
  - it now shows only once the player can advance.
- **Theme precedence:** a Theme governs fonts, sizes and text colours, which
  turn read-only while it is set. The Panel, padding and layers always apply.
  Before this, assigning a Theme also dropped the generated panel.
- **Settings grouped by slot:** Panel, Text, Speaker Name, Dialogue Visual,
  Tail, Continue Indicator, Transitions, Advanced. Decorations, Name Box and
  Frame rows add layers without leaving the settings.
- **Layers view:**
  - a drill-in listing every layer by slot and depth, with drag to reorder,
    enable, duplicate and remove;
  - the selected layer's settings sit beside the list;
  - every edit is undoable;
  - a layer a custom renderer cannot draw is marked.
- **Anatomy Map:** labels every part of the box on the live preview.
  - Hover explains a part; click opens its settings, or adds a decoration at a
    Position.
  - **Expand** opens a larger map with callouts.
  - Editing a setting or selecting a layer briefly outlines its area.
- **A following box with a forced `box_size` is placed and clamped by that
  size**, not by its natural one, so it no longer runs off the screen edge.

### Package

- **The forest demo has a cast of its own.** Darwin the fox meets a frog, an
  eagle and an opossum from Ansimuz's Sunny Land, which matches the forest's
  art; each speaker's portrait is their own sprite. The DezrasDragons samurai
  and shieldmaiden are gone.

- **The demos ship in the release zip**, beside `addons/`. Their artwork is
  now all CC0 — SunnyLand Forest of Illusion by Ansimuz and two DezrasDragons
  sprite sheets — so it may travel with a paid product; each pack's licence
  and attribution sit beside it. `tools/verify_package.sh` opens both demos
  from the package in an empty project and plays the first conversation.

### Validation

`MISSING_SPEAKER_REFERENCE` (a line that says it names someone and names
nobody), `MISSING_DIALOGUE_BOX` (a conversation with no default box — the
runtime still falls back so it cannot crash, but that is a crash guard, not a
tier), and `SPEAKER_NOT_IN_COLLECTION` / `BOX_NOT_IN_COLLECTION` (content
pointing at a resource its node no longer carries: it still plays, but it has
stopped appearing in any dropdown).

`PARTICIPANT_WITHOUT_SPEAKER` and `DUPLICATE_PARTICIPANT` are gone with the
concept.

### Schema

`SCHEMA_VERSION` is `4.0`. A conversation serialises `default_speaker`,
`default_dialogue_box`, `default_placement` and each line's `speaker_mode`; the
mode decides what the `speaker` key holds, so a stale reference left by an
earlier edit cannot come back and re-promote the line to naming it.

## 1.0.0

The speaker rebuild, and the version the API is meant to hold at.

This is the largest breaking change the addon has had, and there are no
compatibility shims: nothing had shipped to a customer, so the model was
replaced outright rather than layered over. That freedom ends here. From 1.0.0
onwards a removed export or a renamed method is a breaking change with a
customer on the other side of it, and the next one of those costs a major
version.

### Why

A speaker was two things at once. `TalkCharacterProfile` carried
`talk_animation` and `idle_animation`, and the node carried
`animation_player_path` and `animated_sprite_path`, so playing a line drove a
sprite in your scene. That coupling had two costs:

- a conversation with two speakers could not be expressed, because the second
  speaker would have been asked to animate this NPC's body;
- a narrator, a radio voice, or a character standing in a level that is not
  loaded needed a gameplay character that does not exist.

0.9.0 patched the symptom with a `_body_profile()` that deliberately resolved
*differently* from `resolve_speaker()`. Two answers to "who is this" is the
defect, not the fix.

### Changed — the model

- **`TalkCharacterProfile` → `TalkSpeaker`.** Identity, dialogue visual and
  voice. No NodePath, no animation, no world reference of any kind.
  `npc_id` → `speaker_id`.
- **`TalkDialogueVisual` is new.** A texture or `SpriteFrames` plus named
  variants, independent of any node but free to reuse the game's own assets —
  pointing a speaker at the player's existing `SpriteFrames` is the intended
  way to make the player a speaker.
- **`TalkParticipant` is new.** How one speaker takes part in one conversation:
  box, visual slot, placement, follow target. These live here rather than on the
  speaker because the same Haru is on the left in one conversation and on the
  right in another. Configuring one is optional — a speaker with no entry plays
  with the defaults, so a two-line greeting never asks you to declare a cast.
- **`TalkConversation.npc_id` → `default_speaker`,** plus `participants`.
- **`TalkLine.speaker_name` → `display_name_override`,** which now changes the
  *name only*: the face and the voice stay whoever is speaking. It used to build
  a whole synthetic character, which is how a line could end up with one
  character's name and another's voice.
- **`TalkLine.visual_variant` is new** — a named face, resolved to an actual
  visual, falling back when the speaker does not have it. This is deliberately
  not the `emotion` string that 0.9.0 deleted: that one resolved to nothing.
- **Voice moved to the speaker.** `NPCTalkKit.voice_enabled` →
  `TalkSpeaker.voice_enabled`, next to the blip it switches.
- **Dialogue visual naming on the box.** `portrait_*` → `visual_*`, and
  `get_portrait_rect()` → `get_visual_rect()`.

### Removed

- **World-character ownership, entirely.** `NPCTalkKit.animation_player_path`,
  `animated_sprite_path`, `TalkSpeaker.talk_animation`, `idle_animation`,
  `TalkLine.animation_override`, and the internal `_play_animation()`,
  `_play_idle()` and `_body_profile()`. TalkKit no longer plays an animation,
  and a game that wants one plays it itself:

      $NPCTalkKit.play(&"greeting")
      $AnimationPlayer.play("talk")

  The only relationship left with a node in your scene is positional — somewhere
  to put the box, and something to hand to a host that asked to be told.
- **`NPCTalkKit.speaker_name`, `portrait`, `voice_blip`, `profile`** — one
  `speaker` slot replaces all four, and the synthesised profile they needed is
  gone with them.

### Added

- **Several speakers in one conversation.** A line names who says it; a line
  that names nobody falls back to the conversation's default speaker, then to
  the node's. There is no mode to switch on and no roster to set up. It is still
  one straight sequence — several speakers change the name on the box, not what
  runs next.
- **A speaker dropdown on every line in the panel**, listing the people already
  in reach — this conversation's, this NPC's, the library's — plus **Browse…**
  and **New speaker…**. Showing who speaks each line without being able to
  change it was half the job: a four-speaker conversation otherwise meant
  opening each line in the Inspector and dragging a resource per line, which is
  the nested-array workflow the panel exists to replace. The inherit entry names
  who would actually speak rather than reading as unset.
- **No speaker is a valid state.** The line still types, events still fire; the
  name row and the visual stay empty. That is a sign, a narrator, a system
  message.
- **Rich text.** `TalkLine.text` and `say()` are BBCode, and the typewriter
  reveals the parsed characters, so a half-typed line never exposes `[colo`.
  The body label is now a `RichTextLabel` — a custom renderer's
  `get_text_label()` must return one.
- **`say()` takes more than strings:** a `String`, a `TalkLine`, a
  `TalkConversation`, or an array mixing strings and lines. It is not a second
  engine — the content becomes a conversation that is never saved and runs
  through the pipeline `play()` uses, so boxes, placement, events and blocking
  behave identically. A node with zero conversations is a working node.
- **One resolution system.** `resolve_speaker`, `resolve_participant`,
  `resolve_dialogue_visual`, `resolve_display_name`, `resolve_dialogue_box`,
  `resolve_typing_speed`, `resolve_placement`, `resolve_follow_target`,
  `resolve_voice`, `resolve_visible_speakers` — all on the node, each the only
  place that answers its question. The renderer consumes the result and invents
  no precedence.
- **`TalkBoxTemplate.visual_mode`.** Both built-in boxes are `ACTIVE_ONLY`:
  whoever speaks is who is shown. `PERSISTENT_CAST` asks the runtime for
  everyone who has spoken so far. The built-in box draws one visual and ignores
  the extra; the setting exists so a visual-novel renderer can be written later
  without rebuilding the speaker model underneath it. `TalkContext` therefore
  carries `active` **and** `visible`.
- **Participant box override.** `line.dialogue_box` → the speaker's participant
  box → `conversation.dialogue_box` → `node.dialogue_box` → Classic Panel. A
  guard can speak in red for a whole conversation without the override being
  repeated on every line, and one of those lines can still override it again.

### Fixed

- **Substituting `{{params}}` cloned the line's resources.** The copy made to
  avoid rewriting shared text was a *deep* one, so it also cloned the speaker,
  the dialogue box and the voice clip. A host doing `line.speaker == guard` in a
  `line_started` handler got false, silently, because it had been handed a clone
  of the guard. The copy is shallow now: only the line's own fields are copied.
- **An inline speaker was lost on JSON export.** A speaker with no `speaker_id`
  — one created on a line, which is the ordinary way and the only way
  **New speaker…** makes them — has nothing to be referenced by, so the exported
  `speaker` field came out empty and the imported line had nobody talking.
  Speakers without an id now travel inside the conversation under a local key
  (`#0`, `#1`), which cannot collide with a real id because `#` is not legal in
  one. Two lines sharing a speaker still share one after a round trip, and the
  keys are assigned in a fixed order so exporting twice gives the same bytes.
- **An inline speaker no longer fails validation.** `speaker_id` was required
  of every speaker, but it is a *filing key* — a speaker created on a line is
  pointed at directly and needs none. The rule made **Validate scene** go red
  on a setup that played perfectly, and it would have made the new
  **New speaker…** action produce an invalid scene every time. An id is now
  required only where it is the key: in a library, in `upsert_speaker()`, and
  in JSON. A present id must still be well formed.
- **The Speaker row hid the cast.** The slot is the *default* speaker, but the
  row said only "Speaking as Haru" — so an NPC whose conversation also gives
  lines to Ren read, at the one place a person looks to ask, as having a single
  speaker. It now says how many others the content names, and that they live in
  Conversations.
- **The panel resolved speakers differently from playback.** `speaker_label()`
  read `line.speaker` but not `line.speaker_id`, so a line naming its speaker
  by id — the JSON-authored case — showed the inherited name instead. Two
  answers to "who is talking" is the exact defect this release set out to
  remove, reintroduced in the editor.
- **A conversation's default speaker now outranks the node's.** It is the more
  specific statement: this node speaks as Haru, except in the conversation that
  says otherwise.
- **`Array[TalkSpeaker]` returned from an array literal.** Godot 4.7 infers the
  type; 4.6 raises a runtime error, which compiles clean and only fails on a
  customer's 4.6. Caught by running both.
- **`enum Side` shadowed Godot's global `Side`** and stopped the property
  type-checking. It is `VisualSide` now.
- **Two placeholder conversations in the demo** held a single blank line each,
  so `play()` refused them. Inspector leftovers, not content.

### Schema

`SCHEMA_VERSION` is `3.0`. A 2.0 document is refused with
`UNSUPPORTED_SCHEMA_VERSION` rather than half-read. Speakers travel as ids — the
only reference another project can resolve — and come back joined to resources
when a library is supplied, with the id preserved either way. Dialogue visuals
are written inline. Validator codes `MISSING_NPC`, `UNKNOWN_NPC` and
`DUPLICATE_NPC_ID` become `MISSING_SPEAKER`, `UNKNOWN_SPEAKER` and
`DUPLICATE_SPEAKER_ID`; `PARTICIPANT_WITHOUT_SPEAKER`, `DUPLICATE_PARTICIPANT`,
`EMPTY_DIALOGUE_VISUAL` and `MISSING_VISUAL_ANIMATION` are new.

### Demo

- Haru's greeting is interrupted by Ren calling down from the canopy: two
  speakers in one conversation, Ren's line painted in the Speech Bubble and
  anchored over Ren's own body across the level, configured once as a speaker
  entry rather than overridden on the line.
- A `Narrator` node with no speaker and no saved conversations speaks through
  `say()` when the player falls off the trail, and dismisses itself — the key
  that would close a box is the key that jumps, so the game closes it.
- The two placeholder conversations that held a single blank line each are gone.

### Tests

- `tests/headless_v03.gd` gained multi-speaker, participant override, visible
  participants, display-name override, visual variants, rich text, `say()`
  pipeline parity, zero-conversation, and a guard that the removed world-animation
  API stays removed.
- `tests/headless_presentation.gd` → `tests/headless_positioning.gd`; the file
  tested positioning and was named after a concept deleted two releases ago.
- `examples/speakers.gd` is new and runs in CI, so every snippet on the new
  Speakers page is executable.
- Voice and typing speed are now proved independent: changing the speaker
  changes the blips and nothing else; changing the box changes the pace and
  nobody's voice.
- An animated dialogue visual is covered frame by frame, including the loop and
  the non-looping hold, so `sprite_frames` is not a field that exports and does
  nothing.

## 0.10.0

### Removed

- **`NPCTalkKit.typewriter_speed`.** 0.8.0 put the typing speed on the dialogue
  box template and kept a node-level override as well. That was a second knob on
  the same object for the same outcome — the node's value overrode a value
  inside the template the node itself had selected, which is not a scope chain
  like `line → conversation → node`, just a duplicate. The speed now lives only
  where the rest of the look lives:

      line.characters_per_second  →  the dialogue box template

  The cost is real and worth stating: an NPC that uses a **shipped** template
  can no longer be given its own pace without owning a copy of that template.
  The demo hit this immediately — two of its NPCs use `speech_bubble.tres`
  directly, so their `typewriter_speed = 46` was dropped and they now use the
  template's own default. Turning typing off for a scripted run means handing
  the node a box whose `typewriter_speed` is `0`.

### Tests

- **`tests/headless_scripts.gd` compiles everything under `tools/`.** Migrating
  the call sites above put a non-static helper in `tools/csharp_check/builder.gd`
  and called it from a static function. Nothing caught it: `--import` does not
  compile a script until something loads it, no suite loads that file, and the
  only symptom was a null node several minutes into the C# harness, reported as
  a native Godot crash. The new suite loads each tooling script and calls
  `reload(true)` — `load()` alone returns a GDScript object even when the source
  failed to parse.

## 0.9.0

### Fixed

- **A line's speaker no longer drives this NPC's sprite.** The speaker is who
  talks inside the box; the body on screen is always this node. 0.6.0 crossed
  the two: a line with a bare `speaker_name` built a synthetic profile whose
  `talk_animation` was the default `talk`, so an NPC with a named animation
  looked one up that did not exist and warned once per line. Talk and idle
  animations now both come from `_body_profile()` — this node, never the line.

### Changed

- **`NPCTalkKit.voice_blips` is now `voice_enabled`, and sits in Speaker.** It
  differed from `voice_blip` by a single letter, sat in a different group, and
  had a different type, so `node.voice_blip` and `node.voice_blips` both
  compiled and one of them quietly did nothing. The switch now sits directly
  under the sound it switches. The old name is gone outright — the addon has not
  shipped, so there is nothing to keep a compatibility alias for.
- `TalkContext.voice_blips` is renamed to `voice_enabled` to match.

### Removed

- **The empty `Presentation` category on `TalkCharacterProfile`.** A section
  header with no fields under it, left behind when `default_presentation` was
  deleted in 0.5.0 — and carrying the one word that refactor retired.

## 0.8.0

### Changed

- **Typing speed belongs to the dialogue box.** The pace is part of the look,
  which is the same argument that already put `transition_duration`,
  `transition_curve` and `transition_easing` in the template. A terminal types
  slowly and deliberately; a comic bubble snaps in. `TalkBoxTemplate` now
  carries `typewriter_speed`, and the shipped **Terminal** template is slower
  than the rest on purpose.

  `NPCTalkKit.typewriter_speed` stays as an override and now defaults to `-1`,
  meaning inherit. It is not folded into the template because a global
  text-speed setting — the kind a player changes in an options menu — has to
  live somewhere that is not a shared resource: writing into a template would
  change every NPC using it, including the ones shipped with the addon. `0`
  still means "show the whole line at once" at every level.

      line.characters_per_second  →  this node  →  the dialogue box template

  Resolved by `resolve_typing_speed()` on the node, beside `resolve_template()`,
  `resolve_anchor()` and `resolve_speaker()`. The box no longer runs its own
  half of the chain.

## 0.7.0

### Changed

- **`NPCTalkKit.dialogues` is now `NPCTalkKit.conversations`.** Every other part
  of the addon already called this concept a conversation — `TalkConversation`,
  `conversation_id`, `list_conversations()`, the three `conversation_*` signals,
  and the bottom panel tab literally named **Conversations**. The Inspector
  property was the only place that said "dialogues", and it sat directly above
  **Dialogue Box**, so the two rows that share a stem were the two concepts
  hardest to tell apart: content and look. One row even disagreed with itself —
  label *Dialogues*, button *Edit conversations*, summary *3 conversations*.

  The old name is gone outright rather than kept as an alias: the addon has not
  shipped to anyone, so there are no saved scenes to protect, and a shim would
  have made the API surface larger than the product it describes. Scenes inside
  this repository were all updated.

## 0.6.0

### Fixed

- **A line can name its own speaker again.** `TalkLine.speaker_name` is
  documented as "a second character speaking inside one conversation". It lost
  to the node's `profile`, so on any NPC that had a profile — the setup the
  documentation recommends — the guard who interrupts was rendered as the
  shopkeeper, silently. The line now wins, as it does in every other chain.

### Changed

- **One speaker resolution chain, in one place.** There were two, in two files:
  `NPCTalkKit` picked the profile, and the box separately picked the displayed
  name. They disagreed, which is what caused the bug above. `resolve_speaker()`
  now sits beside `resolve_template()` and `resolve_anchor()` and is the only
  thing that decides; the box renders whoever it is handed.

      line.speaker → line.speaker_id → line.speaker_name → this node → conversation.npc_id

  The node still outranks `conversation.npc_id`: in a node-first addon the node
  is the character, and `npc_id` is a library filing key. That order is
  unchanged from 0.5.
- **`TalkLine.speaker` hands over the whole character, not just a name.** An
  interruption brings its own portrait and voice, mirroring how
  `TalkLine.dialogue_box` overrides the box for one line. A bare `speaker_name`
  now shows **no** portrait rather than borrowing this NPC's face — if someone
  else is talking, this NPC's face is the wrong one. It serializes as
  `speaker_profile`, since `speaker` has meant `speaker_id` since schema 1.0.

### Removed

- **`TalkLine.emotion` and `TalkCharacterProfile.default_emotion`.** Exported on
  two resources, written to JSON, listed in the API reference — and read by no
  code at all. The demo even authored `calm` and `focused` values that did
  nothing. Their rows in the API table had empty description cells, because
  there was nothing to say. Old JSON carrying `emotion` still parses; the key is
  ignored.

## 0.5.9

### Changed

- **The documented class list is checked against the code.** The installation
  page's list of global classes named two classes that had been deleted and
  omitted eight that shipped, `TalkBoxTemplate` among them. `check-api-names`
  skipped fenced blocks on the grounds that they are compiled elsewhere; this
  one was maintained by hand. It is now verified in both directions against
  `class_name`, located by a `<!-- class-list -->` marker so the check does not
  depend on the heading's language.
- **Save as Template is back, on a save button on the row.** 0.5.7 removed it on
  the reading that a loose action button beside a property is not how Godot does
  things. The placement was the problem, not the action: `ResourceSaver.save()`
  leaves `resource_path` empty even with `FLAG_CHANGE_PATH` (verified), so
  Godot's generic **Save As…** writes the file and leaves the node on its inline
  copy. **Customize** and **Save as Template…** now live behind a save-icon
  button on the row — the same per-row menu convention the Conversations panel
  already uses — with each greyed out when it has nothing to do. The Placement
  row carries a copy icon, since it can only be cloned, never saved. The inline-copy row now reads *Only on
  this NPC*.

### Fixed

- **A freed target no longer throws once per frame.** If the followed node was
  freed while its line was still on screen — the NPC dies mid-line, the room
  unloads — `apply_anchor()` passed the dead pointer to `TalkAnchor.resolve()`
  every frame. A freed Object compares equal to `null` while still carrying the
  pointer, so the null check waved it through; `is_instance_valid()` is the only
  check that sees it. The box now stops placing itself instead.

### Tests

- **The serializer and database layer is covered headlessly at last.**
  `tests/test_talkkit_*.gd` used a test runner that could not be executed
  here and had been referencing deleted APIs — `presentations/`,
  `conversation.presentation`, `TalkValidator.validate_custom_presentation` —
  since 0.5.0. The ten real import/export tests are ported to
  `tests/headless_database.gd` (plus the renderer contract, now
  `validate_renderer`); the three stale files are gone. `run_tests.sh` fails if
  any test file sits outside the suites it runs, which is how those rotted.
- Two gaps the port exposed are now covered: `play()` with an unknown id, and
  `finish_line()` revealing the whole line rather than freezing it part-typed.

- **`tools/run_tests.sh`, which treats a runtime script error as failure.** A
  `SCRIPT ERROR` aborts the test function it occurs in, so every assertion below
  it silently never runs — while the suite still prints its PASS token. Seven
  tests had been dead since the 0.5.0 merge this way, including the two
  regression guards for the speech-bubble freeze and the killed-tween hang.
  They have been ported to the current API and each was reverse-verified to go
  red against the bug it guards.

## 0.5.8

### Changed

- **The box row reports whether the template is a file yet.** Saving a
  customized box is now Godot's own **Save As…** on the slot, but whether that
  also re-points the node at the saved file is editor behaviour this addon
  cannot verify from script — `ResourceSaver.save()` does not do it, even with
  `FLAG_CHANGE_PATH`. Rather than promise the outcome, the row reports it:

  | State | Row says |
  | --- | --- |
  | nothing assigned | *Default: Classic Panel* |
  | a copy living in the scene | *Customized for this NPC — Save As… in the slot to reuse it* |
  | a file | nothing; the slot names it |

  So a save that does not take hold on this node stays on screen instead of
  passing silently.

## 0.5.7

### Removed

- **The "Save as Template…" button.** Every resource slot in Godot already
  carries **Save As…** in its dropdown; a second button beside it was this
  addon reaching past the editor to redo work the editor does — and doing it in
  a place Godot never puts such a control.

  **Customize** stays, because it does something the editor cannot: clone the
  default you are currently looking at, rather than hand you a blank resource
  and a box that has changed appearance. Its tooltip now points at the slot's
  own menu for saving.

- With it went the addon's only `EditorFileDialog`. Saving, loading, Make
  Unique and Show in FileSystem are all Godot's, on the slot itself.

## 0.5.6

Inspector wording: every row says what it is actually doing.

### Changed

- **An empty slot now names its default instead of reading as unconfigured.**
  `<empty>` under Placement looked like a setting nobody had filled in; it means
  "use the renderer's own placement", which is a complete, working answer. The
  row above it says which: *Default: Screen · Bottom*, *Default: Classic Panel*.
  **Customize** turns that default into something editable.
- **The dialogue box stopped being named twice.** A summary row read
  *Template: demo_box* directly above a slot reading `demo_box.tres` — two rows
  for one thing. The summary now only speaks when the slot is empty and has
  something the slot cannot say.
- **The speaker is a person, not a file.** With a profile assigned, the only
  thing on screen was `npc_haru.tres`. It now reads *Speaking as Haru*, falling
  back to the npc id when there is no display name.
- `NPCTalkKit.resolve_anchor()` — the effective placement, whether or not the
  node overrides it. The Inspector needs it to name a default it does not own.

### Notes

- The resource pickers stay visible rather than being replaced by the summary.
  Assigning a template someone already made is a primary action, and hiding the
  picker would cost it.
- A node still defaults to *null* rather than being pre-assigned
  `classic_panel.tres`. Pre-assigning would remove the `<empty>` entirely, but it
  would also let someone expand the shipped template inline and edit the file
  every other NPC in the project shares.

## 0.5.5

Auditing the documentation's *claims*, not its names.

### Added

- **`tests/headless_claims.gd`** — the documentation's behavioural promises as
  executable assertions, each quoted from the page it comes from. Names and
  includes were already checked; a sentence was not, which is how "C# interop
  is possible but untested" outlived the verification and how the README once
  described a `play()` call the code refused. Fourteen claims, green on 4.6 and
  4.7.2.

### Fixed

- **"It returns `false` for four reasons"** — the table lists three, and three
  is right. The Vietnamese page already said three.
- **"Every code sample on this site is a real GDScript file the test suite
  compiles and runs"** was overstated: 60 samples are included from files, but
  39 inline blocks are not. The home page now says what is actually guaranteed —
  worked examples come from real files, and a checker verifies every API name
  the prose mentions.

### Verified unchanged

Checked against the code and found accurate: the resolution chain, the `play()`
matrix, the `enum Mode` and nine screen spots, the six template names, every
`res://` and `demo/` path, the three warning strings quoted in Troubleshooting,
the four-method renderer contract, and "no telemetry, no network requests, no
API keys" — there is no HTTP, socket or `OS.execute` call anywhere in the addon.

## 0.5.4

### Fixed

- **The docs still said C# was untested.** 0.5.1 verified it and updated three
  files; a fourth — the Installation requirements table — kept the old claim in
  both locales, as did the wrapper's own doc comment and the C# page's warning
  box. All corrected.

### Added

- **`docs-site/scripts/check-claims.mjs`.** Symbol checking cannot catch a claim
  going stale: "C# interop is possible but untested" names nothing that stops
  existing, which is how it outlived the thing it described. Every such phrase
  is now listed in `claims-allow.json`; a new one fails until someone confirms
  it is true, and a listed one that disappears fails too, which is what forces
  the list to be revisited. Two remain, both accurate.

## 0.5.3

Documentation audit, against the code rather than by reading.

### Added

- **`docs-site/scripts/check-api-names.mjs`** — every TalkKit symbol the prose
  mentions must exist in the addon. Twice this project shipped docs describing
  behaviour the code did not have; prose cannot be compiled, and this is the
  nearest thing. It runs before `docs:dev` and `docs:build` alongside the
  snippet check.

### Fixed

- **`resolve_template()` and `default_template()` were undocumented** — the one
  entry point to box resolution, missing from the API page in both locales.
- **`TalkCharacterProfile` was summarised, not documented.** `default_emotion`,
  `talk_animation`, `idle_animation`, `voice_pitch_min` and `voice_pitch_max`
  are now a table like every other resource.
- **The Vietnamese API page still listed `apply_style` and `effective_style`**,
  renamed in 0.5.0, and was missing `freeze`.
- **The docs told you to open a panel called "NPC TalkKit".** It is named
  **Conversations**, and only appears while an NPCTalkKit is selected.
- **The home page still said "pick a preset"**, in both locales. Presets became
  templates in 0.5.0.
- The Vietnamese Quick start said the table covered "four things" after it had
  been cut to three.

## 0.5.2

### Fixed

- **A broken snippet include killed the dev server with an ENOENT stack trace.**
  The snippet check now runs automatically before `docs:dev` and `docs:build`
  and names the file and the include instead:

  ```
  docs-site/guide/x.md: missing file ../../examples/style.gd
  1 broken snippet include(s). Fix these before the docs will build.
  ```

  A missing *region* was worse: VitePress renders an empty code block and builds
  clean. That is caught too.

### Changed

- The check moved from `tools/check_doc_snippets.py` to
  `docs-site/scripts/check-snippets.mjs`, so it runs on the toolchain the docs
  already use rather than needing a Python the machine may not have.

## 0.5.1

### Fixed

- **`play()` from `_ready()` on a startup scene drew nothing.** The scene tree
  is still being built then, so `add_child()` is refused — the box was created,
  left unparented, and the conversation ran on invisibly. A silent failure, and
  the obvious way to write an intro conversation. The box is now picked up on
  the next frame instead. Found by running C# against the addon for the first
  time; it was never C#-specific.
  - Regression fixture: `tests/fixtures/autostart.tscn`, which has to run as a
    main scene rather than through `--script`, because that is the only place
    the bug exists.
- **The C# wrapper did not compile.** `using Godot.Collections` beside
  `using System` makes `Array` ambiguous — CS0104. The Godot collection types
  are fully qualified now.

### Added

- **`tools/verify_csharp.sh`** — builds the shipped wrapper against the real
  Godot .NET SDK in an otherwise empty project, then runs it: C# starts a
  conversation with parameters, receives a blocking event, branches from inside
  the handler, and reads the player lock back. The documentation's C# sample is
  compiled by it too, for the same reason the GDScript samples are run.

### Changed

- C# is **verified**, not "expected to work". Docs updated in both locales.
  Checked on Godot 4.7.2 .NET with .NET SDK 8.0.425.

## 0.5.0

Presentation and Style are gone. There is one concept where there were two.

### The mental model

Conversation (what is said) · **Dialogue Box** (what the box is and how it
looks) · **Placement** (where it goes). Pick a template, customize it, save it.

### Added

- **`TalkBoxTemplate`** — one resource describing a whole dialogue box: which
  parts it has, how they are painted, how it animates, and optionally a renderer
  scene of its own. Saving one as a `.tres` makes it a template; there is no
  separate preset concept.
- **One configurable renderer**, `box/talk_box.tscn`. A classic panel and a
  speech bubble are the same scene with different settings — one has a portrait
  and a continue marker, the other a tail.
- **Six built-in templates**: `classic_panel`, `speech_bubble`, `visual_novel`,
  `terminal`, `soft_light`, `comic_bubble`. None bundle a font or a texture.
- `portrait_side`, `portrait_spacing`, `tail_size`, `shadow_size` /
  `shadow_color` — the settings the two scenes used to express structurally.
- **Conditional Inspector on the template**: a box with no portrait does not
  show portrait settings, and the same for the tail, the continue marker, the
  speaker name and the shadow.
- `tests/headless_template.gd` — the acceptance suite: default box, switching
  template, conversation override, line override, Customize cloning what is on
  screen, isolation from the shipped file, saving and reusing, placement
  independence in 2D and 3D, a renderer of your own, and the data model.

### Changed

- **One resolution chain** where there were two near-identical ones:
  `line.dialogue_box` → `conversation.dialogue_box` → `node.dialogue_box` →
  the addon's Classic Panel.
- `TalkPresentationBase` → **`TalkBoxRenderer`**, and it is now explicitly the
  advanced escape hatch rather than something normal use meets.
- **Breaking: the JSON schema is `2.0`.** `presentation`, `style`,
  `presentation_override` and `style_override` are one `dialogue_box` key.

### Removed

- `TalkBoxStyle`, the `presentation` enum, `custom_presentation`,
  `conversation.presentation`, `line.presentation_override`,
  `BUILTIN_PRESENTATIONS`, the `PRESENTATION_*` constants,
  `_resolve_presentation`, and the `bottom_box` / `speech_bubble` scenes.
- The `presets/` folder, replaced by `templates/`.

  The split was never architectural: the two built-in scenes shared one base
  class, and `bottom_box.gd` was five accessors with no behaviour at all. Two
  resolution chains were being maintained for something users think of as one
  thing.

## 0.4.10

### Removed

- **`TalkAnchor.Mode.WORLD`**, along with `world_space_3d`, `world_position_2d`
  and `world_position_3d`. Anchoring is now the two things it was always
  describing: pinned to the screen, or following a node.
  - A fixed world point is a `Marker2D` / `Marker3D` plus node-follow. That is
    the same result with one fewer mode, and it is *draggable* — typing
    `(400, 300)` into a resource means guessing where that is, while a marker in
    the viewport can be seen.
  - It was used nowhere — not in the demo, not in a test, not in any shipped
    resource — and had just proved to be surface where a bug could hide.

### Fixed

- **Settings that were hidden while still doing something.** 0.4.9 hid `pivot`,
  `follow_offset`, `when_offscreen` and `viewport_margin` outside node-follow,
  but `_place()` applied all four to world anchors too — so the box obeyed
  values the Inspector refused to show. They are now shown wherever they act.

## 0.4.9

### Changed

- **The Presentation dropdown describes shape, not position.** It now reads
  *Panel with portrait* / *Speech bubble* / *Custom scene*. The value
  `bottom_box` contains a position word, so a setting named "Presentation" was
  offering positional-sounding choices and teaching the wrong model on sight —
  placement is the anchor's job. The stored values are unchanged, so nothing
  breaks.
- **`TalkAnchor` shows only the settings its mode uses.** Screen placement and
  node following have nothing to say to each other, and listing both at once
  asks the user to work out which half is live. Three knobs that do nothing
  until their switch is on — the distance-scaling clamps and the occlusion mask
  — are hidden the same way, as is the absolute screen position while one of the
  nine preset spots is chosen.

## 0.4.8

### Fixed

- **The Presentation dropdown did nothing on any NPC with a profile.** A shared
  `TalkCharacterProfile` sat *above* the node in the resolution order, so
  changing the setting in the Inspector had no effect and gave no sign why. The
  node now wins: a control on the instance should beat a default on a resource
  shared between instances.
  - Resolution is now `line.presentation_override` → `conversation.presentation`
    → `node.presentation`, which matches how style resolves.

### Removed

- **`TalkCharacterProfile.default_presentation`.** With the node ahead of it and
  `presentation` never empty, the field could no longer be reached — a setting
  that silently does nothing is worse than no setting. The demo's two profiles
  used it; their nodes now say which presentation they use, which is clearer in
  a demo anyway.

## 0.4.7

### Fixed

- **Renaming a conversation could silently make it unreachable.** `+` and
  Duplicate both pick a free name, but Rename accepted anything — so two
  conversations on one node could end up sharing an id, and since
  `find_conversation()` returns the first match, the second could never be
  played. Rename now refuses a name the node already uses and says so.
  - Refused rather than quietly made unique: silently renaming what someone
    typed is its own kind of surprise.
- **A duplicate that already exists is now visible.** Content imported from JSON
  or a hand-edited `.tres` could carry one. The shadowed entry is marked
  *unreachable — name already used* in the list, instead of looking identical to
  the one that actually runs.

## 0.4.6

### Changed

- **The preview transport is two controls that say what they do.** One button
  carries both states — `▶ Play` becomes `■ Stop` while running — and `↓ Next`
  steps a line, wrapping to the first at the end.
  - Bare SpriteFrames glyphs read fine across its five symmetrical buttons. Cut
    down to a couple they stop being legible: `|▶` beside `■` was taken for a
    play/stop pair rather than next/stop, which is a fair reading of it.
  - Stepping still cancels playback, so the two cannot fight each other.
  - Playback does not loop. Reaching the end leaves the last line on screen to
    be looked at and returns the button to `▶ Play`; `■ Stop` is what clears and
    rewinds.

## 0.4.5

### Fixed

- **Stop could not clear the preview.** `clear()` used `queue_free()`, which is
  deferred — the box kept its node name until the end of the frame, so stopping
  and replaying immediately made Godot rename the new one to
  `__TalkKitPreview2`. Stop then looked for the original name, found nothing,
  and the orphan stayed in the scene permanently. The node is now taken out of
  the tree at once, which releases the name, and any orphans left by the old
  behaviour are swept by prefix.

### Changed

- **Three transport buttons, not five.** Play, Next line, Stop — enough to watch
  a conversation, step to the line being styled, and clear it away. Stop also
  rewinds, so Play afterwards means "from the top".
- **The sidebar is actually distinguishable.** Two `PanelContainer`s sat on a
  panel of nearly the same colour and read as one surface. The conversation
  column now has an explicit tint and a right-hand edge, both derived from the
  editor's own base colour so they still follow the user's theme.

## 0.4.4

### Changed

- **The preview walks the conversation.** It showed one frozen line, which told
  you almost nothing about a conversation. It now carries the same transport the
  SpriteFrames editor uses — first, previous, stop, next, play — with `▶`
  running from the current line to the end, typewriter and transitions included,
  and a `Line 2 of 5` counter beside it.
  - Stepping by hand cancels playback, so the two cannot fight each other.
  - The cursor clamps rather than wraps: running off the end stops, the way
    playback does.
  - A queued advance is cancelled by Stop or by a manual step, so an old wait
    cannot wake up and move the line out from under you.
- **The two columns read as two areas.** Each sits in a `PanelContainer`, which
  takes the editor's own panel style — so the separation follows whatever theme
  you are on rather than a hardcoded colour that would look wrong on half of
  them.

## 0.4.3

Editor polish. No runtime change.

### Changed

- **The bottom tab is named `Conversations`**, like every other tab down there —
  Output, Debugger, Animation, Shader Editor. It only appears for an NPCTalkKit,
  so the product name was branding in a place context already covers. The panel
  itself now says which NPC: *Conversations — BottomTalkKit*.
- **Conversation actions moved onto the conversation.** `+` sits in the column
  header and Rename / Duplicate / Save to Library / Delete are one `⋮` menu,
  replacing four buttons parked at the bottom of the column away from the thing
  they acted on.
- **Line rows carry two controls instead of four.** Reordering and the Inspector
  jump are rare next to typing, so they moved behind the row's `⋮`; `⋮` and `✕`
  are what is left.
- The preview checkbox reads **Show preview**, because it is a mode — the box
  stays drawn and follows the line being edited — not a one-off action.
- **The style row offers exactly one button, always pressable.** A disabled
  button reading "Style is yours to edit" was a status line wearing a button's
  clothes. `Customize style` before, `Save as preset…` after.
- The dialogues summary row carries its property name, so it reads as a row
  rather than a sentence floating among labelled ones.

## 0.4.2

The editor stopped describing the addon's data structure and started describing
the NPC.

### Changed

- **The nested array is gone from the Inspector.** Godot unfolded `dialogues`
  into Array[TalkConversation] → TalkConversation → Lines → Array[TalkLine] →
  TalkLine → Advanced → Resource. That is the storage format shown to someone
  who only wants an NPC to talk. It is now one line — `3 conversations, 7 lines`
  — with a button that opens the panel. The array is still what gets saved; it
  is just not what gets shown.
- **The panel behaves like a built-in Godot panel.** `_handles` / `_edit` /
  `_make_visible` are implemented, so the tab appears and raises when an
  NPCTalkKit is selected and gets out of the way otherwise — the same contract
  the SpriteFrames and Animation editors use.
- **The runtime state machine left the Inspector.** `IDLE` / `OPENING` /
  `DISPLAYING` / `BLOCKED` / `FINISHING` / `CANCELLING` were six radio buttons.
  Those names keep the implementation honest; nobody buys a dialogue addon to
  look at `FINISHING`. Preview is now a checkbox in the panel, showing the line
  you are editing.
- **Actions moved to what they act on.** *Save to Library* is a conversation
  action in the panel; *Validate* is a panel-level action; the style buttons sit
  with `box_style` instead of below Script and Add Metadata, where they read as
  a second product bolted on.
- **Inspector order follows how often things are touched**: Dialogues,
  Presentation, Box Style at the top; Speaker, Placement, Typing and Advanced
  grouped below. `box_style` was buried inside a "Dialogue box" group that also
  held the typewriter speed, voice blips and the custom scene — the same grab
  bag that `TalkPresentationProfile` was deleted for.
- **Fields that cannot act are hidden.** `custom_presentation` only appears when
  the presentation is `custom`; the inline speaker fields disappear when a
  profile replaces them.

### Removed

- **The right-hand `TalkKitDock` tab.** It was the v0.2 database browser, still
  hardcoded to `res://talkkit_database.tres`, and it gave the editor two places
  to do the same job.

## 0.4.1

Closing the gaps found by auditing the product against what it claims.

### Added

- **Style resolves in a chain, like presentation does.**
  `line.style_override` → `conversation.style` → `node.box_style` → the
  presentation scene's own look. Presentation could already be overridden at
  three levels while style only existed on the node, so "this NPC talks
  normally but the flashback looks different" was not expressible. It takes
  effect mid-conversation without a restart.
- **A C# wrapper**, `addons/npc_talkkit/csharp/TalkKit.cs` — typed `Play`,
  `Say`, `Advance`, `Resume`, `Stop`, `IsRunning`, `IsBlocked`,
  `ListConversations`, and C# events for the signals, so a .NET project is not
  littered with `Call("play", ...)`. **Never compiled** — this project has no
  .NET toolchain; the folder's README says how to verify it in two minutes. A
  `.cs` file is inert in a standard Godot build, verified by importing on 4.7.2
  with it present.
- `TalkPresentationBase.freeze()` — holds a deterministic still frame. The
  editor preview needs one, and transitions had started animating underneath it.
- A **Refresh** button on the Inspector preview: editing a style or an anchor
  does not re-parse the Inspector, so the frame used to keep showing the look it
  was built with.

### Fixed

- The Inspector preview read `box_style` directly, so it could not show a line
  or conversation style override. It now uses the same resolution the runtime
  does.
- `TalkKitSerializer` carries `style` and `style_override` through JSON. A
  GDScript `class_name` is not a native class, so the existing `is_class()`
  check would have silently dropped every style on import.

## 0.4.0

Presentation gains the structure content got in 0.3. Four orthogonal concepts:
**Conversation** says what, **Presentation** picks which box, **Style** paints
it, **Anchor** places it.

### Added

- **`TalkAnchor`** — placement as its own axis, on the node. A Bottom Box can
  follow an NPC and a Speech Bubble can pin to a screen corner; before, the
  scene you picked decided where the box sat and that was that.
  - `SCREEN` (nine spots, margin, absolute position, horizontal stretch),
    `NODE_FOLLOW` (Node2D, Node3D, Control), `WORLD`.
  - `pivot` places any part of the box on the target, so above / below / left /
    right is one field instead of four modes.
  - `when_offscreen`: clamp, hide, or let it travel.
- **3D support.** `Camera3D.unproject_position` with an `is_position_behind`
  guard, a world-space `follow_offset_3d` applied **before** projection and a
  screen-space `follow_offset` after, `max_distance`, optional
  `scale_with_distance` with clamps, and an optional occlusion raycast (off by
  default, run in the physics frame).
- **`TalkInteractionArea3D`**, so 3D is a complete path rather than just a
  floating bubble.
- **`TalkBoxStyle`** — appearance as a shareable resource: background, border,
  radius, padding, fonts, text and name sizing and colour, portrait, continue
  indicator, transitions, plus `panel_style` and `theme` escape hatches.
  `apply_to()` is a plain function over plain controls so the whole mapping is
  headless-tested.
- **Six presets** — `classic_dark`, `parchment`, `visual_novel`, `terminal`,
  `soft_light`, `comic`. **No bundled fonts or textures**: they differ by
  colour, border, radius, padding, sizing and transition only, and carry no
  third-party licensing.
- **Inspector buttons.** *Customize style* clones the style **currently in
  effect**, so changing one colour changes one colour instead of dropping the
  user onto bare defaults they then have to rebuild. *Save as preset* writes it
  to a `.tres` and repoints the node at it.
- **`TalkTransition`** — open, close and line-change animations: none, fade,
  slide, scale-pop, with duration and easing. Subclass it for anything else;
  the enum is convenience, not a ceiling.
- **A presentation state machine** (`HIDDEN`, `OPENING`, `SHOWN`, `CHANGING`,
  `CLOSING`), because closing became a coroutine and `play()` can now arrive
  mid-animation.
- **A 3D showcase** built entirely from Godot primitives — no imported art.
- Four new headless suites: `headless_anchor`, `headless_style`,
  `headless_transition`, `headless_presentation`.

### Fixed

- **`play()` while blocked now works.** The README and the v0.3 design both
  showed a host answering a blocking event by calling `play("branch")`, but
  `play()` required `IDLE` and `BLOCKED` is not `IDLE`, so the documented
  branch silently returned `false`. A host had to call `stop()` first.
- **A following box no longer freezes when the text finishes.** Processing was
  gated on the typewriter, so a speech bubble stopped tracking its NPC the
  instant the last character appeared — and was never positioned at all when
  the typewriter was switched off.
- Starting a conversation while the previous box is still fading out now
  revives that box instead of stacking a second one on top of it.
- **A refused branch no longer strands the player.** `play()` while blocked
  abandoned the running conversation *before* validating the replacement, so a
  branch that failed validation left nothing running and the player lock never
  released — no conversation, no controls, no way back. Validation now happens
  first.
- A transition whose tween is killed mid-flight returns to its caller. A killed
  `Tween` never emits `finished`, so awaiting it suspended the coroutine for
  good; the wait is now on a timer.
- **The dialogue panel edited and deleted the wrong conversation.** An empty
  element in the Dialogues array — one click of "Add Element" in the Inspector
  — shifted every row below it, because rows were built skipping nulls while
  selection indexed straight into the array. The row said "beta" and Delete
  removed "alpha". Rows now carry their array index.
- **Overriding a library conversation is no longer reported as an error.**
  `find_conversation` documents node-over-library as the way to override shared
  content for one NPC, while the scene validator called the same thing a
  duplicate id — the two contradicted each other. Conversation ids are per
  node, so the rules are now: the library declaring an id twice is an error,
  one node declaring an id twice is an error (the second can never play), the
  same id on two different nodes is a **warning** (normal, but promotion would
  collide), and a node shadowing a library id is not reported at all.
- The example custom presentation implements `get_box_control()` and ships a
  default anchor. Without it, anchoring and transitions are silently inert —
  which made the shipped example a misleading template for the escape hatch
  it exists to demonstrate.

### Changed

- **Breaking: `TalkPresentationProfile` is removed.** Its appearance fields are
  `TalkBoxStyle`, its geometry is `TalkAnchor`, and its behaviour moved to the
  node (`typewriter_speed`, `voice_blips`, `custom_presentation`). Keeping it
  would have left a resource whose fields silently did nothing. To migrate:
  delete the `.tres`, set `typewriter_speed` on the node, and move anything
  visual into a `TalkBoxStyle`.
- `theme_override_*` is gone from the shipped presentation scenes. Overrides
  beat both a `Theme` and runtime styling, so the escape hatch could not have
  worked while they were there. The default look is unchanged.
- `TalkValidator.validate_presentation_profile` → `validate_custom_presentation`,
  which takes the scene directly.

### Notes

- `play()` is still refused while a conversation is being read, so a second
  interact press cannot restart what the player is in the middle of.
- The opening transition runs underneath the first line rather than delaying
  it; only a line change holds the typewriter back, because text appearing
  under a fade is unreadable.

## 0.3.5

### Added

- `tools/verify_package.sh` — builds the release zip, extracts it into an
  otherwise empty Godot project, and exercises the addon there. The repo's own
  suites run against the working tree, so this is the only check that proves the
  package is self-contained.
- **`LICENSE`** — a commercial EULA. Copyright (c) 2026 vanquyt. Perpetual use in
  unlimited projects you own; no redistribution or public publication of the
  addon or its source. It ships inside the release package.

### Changed

- **The demo is no longer packaged.** It bundles artwork from Mattz Art and
  Merakintsugi, whose licences forbid redistributing their work as game assets —
  which a paid package would do. The release zip is now the addon alone: 77
  files, none of them third-party. The showcase is published separately.
- `plugin.cfg` author is now `vanquyt`.

### Notes

- `plugin.cfg` has no `license` field — Godot only reads `name`, `description`,
  `author`, `version`, and `script`. The `LICENSE` file at the package root is
  the right place, and is included.
- **Verified on Godot 4.6 stable** (`4.6.stable.official.89cea1439`) as well as
  4.7.2: the clean-install package check, all three headless suites, and the
  demo scene all pass. The docs previously said "4.6.3", which was a v0.2
  figure and not a version v0.3 had been run on.

## 0.3.4

### Removed

- **`TalkKitComponent` is gone.** It was kept as a deprecated alias of
  `NPCTalkKit`, but nothing outside the addon's own tests ever used it — the
  addon has no released users to protect. All it did was put a confusing
  near-duplicate in the Create New Node dialog next to the real node.
- **`start()` is gone.** Same reasoning: two names for `play()` is exactly the
  duplication this release set out to remove.

The addon now registers exactly two nodes a user adds to a scene: `NPCTalkKit`
and the optional `TalkInteractionArea2D`.

## 0.3.3

### Fixed

- **Create New Node showed "No description available"** for every class the
  addon registers. The doc comments sat below `extends`, but Godot only reads a
  class doc comment placed directly above `class_name`. `NPCTalkKit`,
  `TalkKitComponent`, `TalkInteractionArea2D`, and `TalkPresentationBase` now
  describe themselves where it matters — `TalkKitComponent` says plainly that it
  is deprecated, so it cannot be picked by mistake.

## 0.3.2

### Fixed

- **The dialogue panel never appeared.** Its bottom-panel tab started hidden and
  was only revealed by `selection_changed`, which does not fire when the plugin
  is enabled with a node already selected — the usual case. The tab is now
  always visible, explains itself when nothing is selected, and syncs with the
  current selection on enable.

### Added

- `tests/headless_panel.gd` — covers the panel's add/rename/move/delete actions,
  row building, unique naming, and that panel-authored content passes the same
  validator. The panel's editor-only side effects now no-op outside the editor,
  which is what makes this testable.

## 0.3.1

Simplification pass. v0.3.0 moved complexity rather than removing it: saying one
line meant facing ~31 Inspector fields across three levels of nesting, and about
twelve clicks. This release attacks that directly.

### Added

- **A bottom panel editor.** Select an `NPCTalkKit` and type lines straight into
  rows, the way the Animation editor works. Enter adds the next line. Rare
  per-line fields open in the Inspector from a ⋮ button, so each field still
  lives in exactly one place.
- `say()` — speaks a string or an array of strings with nothing authored
  anywhere, for barks, prototypes, and generated text.
- `speaker_name`, `portrait`, and `voice_blip` directly on the node, so a single
  NPC never has to create a `TalkCharacterProfile`.
- `typewriter_speed` on the node, so the common case needs no
  `TalkPresentationProfile` either.

### Changed

- `TalkLine` shows **text** and **speaker_name**; the other ten fields moved into
  collapsed Event and Advanced groups.
- `TalkConversation` shows **conversation_id** and **lines**; the rest is in
  Advanced.
- `NPCTalkKit` shows **dialogues** and **presentation** at the top level; the
  other eleven properties are grouped.
- Saying one line now means **6 visible fields** instead of 31.
- `TalkLine.line_id` is **optional**. It only exists for `get_line_by_id()`, so
  an empty one is no longer `MISSING_STABLE_ID`, and duplicates are only checked
  among ids that are actually set.

## 0.3.0

**Node-first.** Conversations are authored on the node, in the Inspector. A
database is now an optional shared library rather than a required first step.

> NPCTalkKit lets you play named NPC conversations the way AnimationPlayer plays
> named animations. Game owns the logic. TalkKit owns playback and presentation.

### Added

- `dialogues: Array[TalkConversation]` on the node. An NPC that says two lines
  now needs **zero** resource files.
- `play(name, params)` with lookup order `dialogues` → `library`.
- **Blocking events**: `TalkLine.event_blocking`, the `BLOCKED` state, the
  `event_blocked` signal, and `resume()` / `is_blocked()`. This is how branching
  works without a branching engine.
- **Text parameters**: `{{placeholders}}` filled at `play()`, merged over
  `default_params` on the node.
- `TalkLine.speaker_name` — an inline display name, so a line needs no profile.
- `TalkLine.characters_per_second` — per-line typewriter speed, `0` inherits.
- `TalkConversation.event_id` / `event_payload`, fired on completion.
- `NPCTalkKit.presentation` — a node-level presentation default.
- `TalkKitSceneCollector`, so the validator and JSON API cover inline content.
- **Promote to Library** and **Validate scene** buttons in the Inspector.
- `BLOCKED` in the Inspector state preview.
- `tests/headless_v03.gd` — standalone coverage that runs without the editor.
- `tools/check_doc_anchors.py` — verifies every documentation anchor resolves.

### Changed

- `TalkKitComponent` is now `NPCTalkKit`. The old name remains as a deprecated
  subclass, with `database` forwarding to `library`, so v0.2 scenes keep loading.
- `database` renamed to `library` and is optional everywhere.
- Speaker resolution: library profile → node profile → `speaker_name` → hide the
  name row. The raw `speaker_id` is no longer shown to players.
- Presentation resolution gained the node-level tier: line → conversation →
  profile → node → `bottom_box`.
- The editor dock is now a library browser and promotion target; day-to-day
  authoring happens in the Inspector.
- Demo rebuilt on inline content — the `dialogue/` folder went from 20 files to
  10, none of which is dialogue.

### Removed

- `MISSING_NPC_REFERENCE` is no longer emitted. An empty `speaker_id` is valid
  in node-first authoring; a *named but unresolvable* speaker is still
  `UNKNOWN_NPC`.

### Notes

- `start()` is kept as an alias of `play()`.
- JSON gained `speaker_name`, `characters_per_second`, `event_blocking`, and
  conversation-level events. All additive, so `SCHEMA_VERSION` stays `1.0`.
- Verified on Godot 4.7.2 stable.

## 0.2.0

The first public shape of the addon, database-first: `TalkKitComponent`, the
Bottom Box and Speech Bubble presentations, the custom presentation contract,
deterministic validation, JSON import/export, the editor dock, and the
Inspector state preview.

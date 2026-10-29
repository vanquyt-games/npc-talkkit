# Platformer quest

A small quest built on the [Godot 2D Platformer Demo](godot_platformer/ATTRIBUTION.md).
Open `platformer_quest.tscn` and press F6.

Ada, a mechanic at the bottom of the valley, asks you to bring back 12 coins.
She pays with a blaster, then asks you to chase three crabs off her cables.
Volt, on the east cliff, answers questions from a menu that loops until you say
bye. ARCHIVE-7, an old robot on the west cliff, prints a log in a terminal box.
The crabs mutter when you get close.

Ten travellers stand around the level, each talking in a different box from the
[box gallery](https://talkkit.vanquyt.com/guide/box-gallery). The corner of the
screen names the box while one of them talks, and the counter under the coins
tracks how many you have met.

## Where things are

| | |
| --- | --- |
| Conversations | Inline on `NPCs/Ada/TalkKit`, `NPCs/Volt/TalkKit` and `NPCs/Archive/TalkKit`. Select one and open the **TalkKit** tab. |
| Speakers and boxes | `dialogue/`. Ada, Volt and ARCHIVE-7 use the built-in panel, bubble and terminal, set to the demo's pixel font. The travellers' portraits are in `dialogue/portraits/`, cut from the robot sprite and tinted. |
| Gallery boxes | `boxes/`, the ten boxes from the docs' gallery. See [boxes/README.md](boxes/README.md). |
| Travellers | `NPCs/Travellers/*/TalkKit`, two conversations each: `<name>_hello` and `<name>_again`. |
| Game logic | `platformer_quest.gd`: quest state, which conversation each NPC plays, events, and the crabs' barks. |
| Choice menu | `choice_menu.gd`, the game's own UI. |

## What it shows

| Feature | Where |
| --- | --- |
| Branching in GDScript | `_conversation_for()` picks a conversation from the quest state with plain `if`/`match`. |
| Choices | A blocking line carries `{"options": [...], "branches": [...]}` in its event payload. The game shows its menu and calls `play()` with the chosen branch. |
| A menu that loops | Volt's answers end on the same blocking event, so the menu comes back until "Bye." |
| Placeholders | `{{coins_have}}`, `{{coins_left}}`, `{{crabs_left}}` and `{{player_name}}`, filled at `play()`. |
| Events | `quest_started`, `give_blaster`, `crab_quest`, `quest_complete` and `archive_read` change the game. |
| One-off lines | The narrator and the crabs use `say()`. Each crab's TalkKit node is created in code. |
| Thirteen boxes | A panel for Ada, a bubble that follows Volt, a terminal for ARCHIVE-7, and the ten gallery boxes on the travellers: at the bottom of the screen, at the top (SCOUT-3), or as a bubble that follows (Pop). |
| Portraits | Each traveller's speaker has a portrait, so the gallery boxes show their portrait frames. |
| Player lock | The player stands still while a conversation is open, through `request_player_lock`. |

## Controls

The demo adds these actions when your project does not define them.

- A/D or arrows: move
- Space, W or up: jump, and advance dialogue
- E: talk, and advance dialogue
- J or Z: shoot, once Ada gives you the blaster
- Escape: close the conversation or the menu

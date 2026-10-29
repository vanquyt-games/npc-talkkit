extends Node2D
## A small quest on top of the Godot 2D platformer demo.
##
## Every line is authored on an NPCTalkKit node in this scene (select Ada/TalkKit
## and open the TalkKit tab). This script is the game: it decides which
## conversation an NPC starts, keeps the quest state, answers blocking events
## with its own choice menu, and reacts to events. TalkKit stores none of that.
##
## The ten travellers each talk in one box from the docs' box gallery (boxes/).

enum Stage { NOT_STARTED, COLLECTING, CRABS, DONE }

## Passed into {{player_name}} at play() time.
const PLAYER_NAME := "Pip"
const COINS_NEEDED := 12
const TALK_DISTANCE := 70.0
const BARK_DISTANCE := 170.0
const BARK_COOLDOWN := 5.0
## The demo art is drawn for a 480 pixel tall screen.
const ART_HEIGHT := 480.0

const PlayerScript = preload("res://demo/platformer_quest/godot_platformer/player/player.gd")
const CoinsCounterScript = preload("res://demo/platformer_quest/godot_platformer/gui/coins_counter.gd")
const ChoiceMenu = preload("res://demo/platformer_quest/choice_menu.gd")

const BARKS := ["Click-clack!", "Shiny coins. Mine!", "Snip, snip.", "Who goes there?"]
const BARKS_ARMED := ["Is that a blaster?!", "Run! Sideways!", "We were only borrowing the cables!"]

@onready var player: PlayerScript = %Player
@onready var ada: Node2D = %Ada
@onready var volt: Node2D = %Volt
@onready var archive: Node2D = %Archive
@onready var narrator: NPCTalkKit = %Narrator
@onready var choice_menu: ChoiceMenu = %ChoiceMenu
@onready var coins_counter: CoinsCounterScript = %CoinsCounter
@onready var quest_label: Label = %QuestLabel
@onready var hint: Label = %Hint
@onready var box_label: Label = %BoxLabel
var travellers: Array[Node2D] = []

var stage := Stage.NOT_STARTED
var coins := 0
var crabs_left := 0
var archive_read := false
var archive_mentioned := false
## Travellers spoken to, by lower-case node name.
var met := {}
## The NPC whose conversation is open, or null.
var talking_to: Node2D = null
var _npcs: Array[Node2D] = []
var _barks := {}
var _bark_ready_at := {}


func _ready() -> void:
	_add_input_actions()
	for traveller in %Travellers.get_children():
		travellers.append(traveller)
	_npcs = [ada, volt, archive]
	_npcs.append_array(travellers)
	for npc in _npcs:
		var talkkit := _talkkit(npc)
		talkkit.request_player_lock.connect(_on_player_lock)
		talkkit.request_face_target.connect(_on_face_target.bind(npc))
		talkkit.event_triggered.connect(_on_event)
		talkkit.event_blocked.connect(_on_event_blocked.bind(talkkit))
		talkkit.conversation_finished.connect(_on_conversation_finished)
		talkkit.conversation_cancelled.connect(_on_conversation_cancelled)
	player.coin_collected.connect(_on_coin_collected)
	_setup_crabs()
	_update_quest_label()
	_narrate("The valley is quiet. Someone down there is waving at you.")


func _process(_delta: float) -> void:
	var camera: Camera2D = player.get_node(^"Camera")
	camera.zoom = Vector2.ONE * (get_viewport_rect().size.y / ART_HEIGHT)
	hint.visible = talking_to == null
	var nearest := _nearest_npc()
	for npc in _npcs:
		npc.get_node(^"Prompt").visible = npc == nearest and talking_to == null
	_update_barks()


func _unhandled_input(event: InputEvent) -> void:
	if choice_menu.visible:
		if event.is_action_pressed(&"ui_cancel"):
			choice_menu.cancel()
		return
	var advance: bool = event.is_action_pressed(&"talk") or event.is_action_pressed(&"jump") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if talking_to != null:
		if event.is_action_pressed(&"ui_cancel"):
			_talkkit(talking_to).stop()
		elif advance:
			_talkkit(talking_to).advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"talk"):
		var npc := _nearest_npc()
		if npc != null:
			_talk_to(npc)
			get_viewport().set_input_as_handled()


#region Talking

## The branching lives here, as ordinary GDScript reading the game's own state.
func _conversation_for(npc: Node2D) -> StringName:
	if npc == ada:
		match stage:
			Stage.NOT_STARTED:
				return &"ada_intro"
			Stage.COLLECTING:
				if coins >= COINS_NEEDED:
					return &"ada_coins_done"
				if archive_read and not archive_mentioned:
					return &"ada_archive"
				return &"ada_waiting"
			Stage.CRABS:
				return &"ada_done" if crabs_left == 0 else &"ada_crabs_waiting"
			_:
				return &"ada_after"
	if npc == volt:
		return &"volt_after" if stage == Stage.DONE else &"volt_hub"
	if npc in travellers:
		var key := _traveller_key(npc)
		return StringName(key + ("_again" if met.has(key) else "_hello"))
	return &"archive_log"


func _talk_to(npc: Node2D) -> void:
	talking_to = npc
	if npc in travellers:
		box_label.text = "Box: " + _talkkit(npc).dialogue_boxes[0].resource_name
	if not _talkkit(npc).play(_conversation_for(npc), _params()):
		_end_talk()


func _end_talk() -> void:
	talking_to = null
	box_label.text = ""


func _traveller_key(npc: Node2D) -> String:
	return String(npc.name).to_lower()


## Values for the {{placeholders}} in the lines.
func _params() -> Dictionary:
	return {
		"player_name": PLAYER_NAME,
		"coins_needed": COINS_NEEDED,
		"coins_have": coins,
		"coins_left": maxi(COINS_NEEDED - coins, 0),
		"crabs_left": crabs_left,
	}


## A blocking line carries its options and the conversation each one leads to
## in its event payload. The game shows its own menu, then branches with play().
func _on_event_blocked(event_id: StringName, payload: Variant, talkkit: NPCTalkKit) -> void:
	if not (payload is Dictionary and payload.has("options")):
		talkkit.resume()
		return
	var choice: int = await choice_menu.ask(payload["options"])
	if not talkkit.is_blocked():
		return
	if choice < 0:
		talkkit.stop()
		return
	print("[TalkKit] %s → %s" % [event_id, payload["options"][choice]])
	talkkit.play(StringName(payload["branches"][choice]), _params())


func _on_event(event_id: StringName, _payload: Variant) -> void:
	match event_id:
		&"quest_started":
			stage = Stage.COLLECTING
		&"give_blaster":
			player.can_shoot = true
			hint.text = "A/D  MOVE     SPACE  JUMP     E  TALK     J  SHOOT"
		&"crab_quest":
			stage = Stage.CRABS
		&"quest_complete":
			stage = Stage.DONE
		&"archive_read":
			archive_read = true
		&"archive_mentioned":
			archive_mentioned = true
		&"traveller_met":
			if talking_to != null:
				met[_traveller_key(talking_to)] = true
	_update_quest_label()


func _on_conversation_finished(conversation_id: StringName) -> void:
	var was_new_traveller := talking_to in travellers and not String(conversation_id).ends_with("_again")
	_end_talk()
	if conversation_id == &"ada_done":
		await get_tree().create_timer(0.6).timeout
		_narrate("Thanks for playing. Every line here comes from an NPCTalkKit node: open this scene and look in the TalkKit tab.", 5.0)
	elif was_new_traveller and met.size() == travellers.size():
		_narrate("You met all %d travellers, and saw every box in the gallery." % travellers.size(), 3.0)


func _on_conversation_cancelled(_conversation_id: StringName) -> void:
	_end_talk()
	choice_menu.cancel()


func _on_player_lock(locked: bool) -> void:
	if locked:
		player.input_enabled = false
		return
	# Wait a frame, so the key that closed the box does not also make the player jump.
	await get_tree().physics_frame
	player.input_enabled = true


func _on_face_target(target: Node, npc: Node2D) -> void:
	if target == npc:
		(npc.get_node(^"Sprite2D") as Sprite2D).flip_h = player.global_position.x < npc.global_position.x


func _nearest_npc() -> Node2D:
	var nearest: Node2D = null
	var best := TALK_DISTANCE
	for npc in _npcs:
		var distance := player.global_position.distance_to(npc.global_position)
		if distance < best:
			best = distance
			nearest = npc
	return nearest


func _talkkit(npc: Node2D) -> NPCTalkKit:
	return npc.get_node(^"TalkKit") as NPCTalkKit

#endregion


#region Quest

func _on_coin_collected() -> void:
	coins += 1
	coins_counter.collect_coin()
	if stage == Stage.COLLECTING and coins == COINS_NEEDED:
		_narrate("That's %d coins. Ada will be pleased." % COINS_NEEDED)
	_update_quest_label()


func _on_crab_destroyed(crab: Node) -> void:
	var bark: NPCTalkKit = _barks.get(crab)
	if bark != null and bark.is_running():
		bark.stop()
	_barks.erase(crab)
	crabs_left -= 1
	if stage == Stage.CRABS and crabs_left == 0:
		_narrate("The last crab scuttles off. Ada is waiting.")
	_update_quest_label()


func _update_quest_label() -> void:
	var text := ""
	match stage:
		Stage.COLLECTING:
			text = "Coins for Ada: %d / %d" % [mini(coins, COINS_NEEDED), COINS_NEEDED]
		Stage.CRABS:
			text = "Crabs left: %d" % crabs_left if crabs_left > 0 else "Back to Ada"
		Stage.DONE:
			text = "Quest complete"
	if not met.is_empty():
		text += ("\n" if text else "") + "Travellers met: %d / %d" % [met.size(), travellers.size()]
	quest_label.text = text

#endregion


#region Barks and narration

## Each crab gets an NPCTalkKit made in code, with no conversations: it only
## speaks one-off lines through say(), in a bubble that follows it.
func _setup_crabs() -> void:
	var bubble: TalkBoxTemplate = load("res://demo/platformer_quest/dialogue/quest_bubble.tres")
	var follow := TalkAnchor.new()
	follow.mode = TalkAnchor.Mode.NODE_FOLLOW
	follow.follow_offset = Vector2(0.0, -40.0)
	for crab in get_node(^"Level/Enemies").get_children():
		var bark := NPCTalkKit.new()
		bark.name = "Bark"
		bark.conversation_target = crab
		bark.quick_say_dialogue_box = bubble
		bark.quick_say_placement = follow
		bark.request_lock_on_start = false
		crab.add_child(bark)
		_barks[crab] = bark
		_bark_ready_at[crab] = 0.0
		crab.connect(&"destroyed", _on_crab_destroyed.bind(crab))
		crabs_left += 1


func _update_barks() -> void:
	if talking_to != null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for crab: Node2D in _barks:
		var bark: NPCTalkKit = _barks[crab]
		if bark.is_running() or now < _bark_ready_at[crab]:
			continue
		if player.global_position.distance_to(crab.global_position) > BARK_DISTANCE:
			continue
		_bark_ready_at[crab] = now + BARK_COOLDOWN
		var lines: Array = BARKS_ARMED if player.can_shoot else BARKS
		bark.say(lines.pick_random())
		_close_when_read(bark, 1.2)


## Speaks a one-off line through say(), with nothing authored.
func _narrate(text: String, linger := 1.8) -> void:
	if narrator.is_running():
		narrator.stop()
	narrator.say(text)
	_close_when_read(narrator, linger)


## One-off lines close by themselves: the player keeps moving, and the advance
## key also jumps.
func _close_when_read(talkkit: NPCTalkKit, linger: float) -> void:
	await talkkit.speech_finished
	await get_tree().create_timer(linger).timeout
	if is_instance_valid(talkkit) and talkkit.is_running():
		talkkit.stop()

#endregion


## The demo brings its own controls, so it runs in a project that has none.
## Actions the project already defines are left alone.
func _add_input_actions() -> void:
	var keys := {
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"jump": [KEY_SPACE, KEY_W, KEY_UP],
		&"shoot": [KEY_J, KEY_Z],
		&"talk": [KEY_E],
	}
	var buttons := {
		&"move_left": JOY_BUTTON_DPAD_LEFT,
		&"move_right": JOY_BUTTON_DPAD_RIGHT,
		&"jump": JOY_BUTTON_A,
		&"shoot": JOY_BUTTON_X,
		&"talk": JOY_BUTTON_Y,
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for keycode: Key in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.button_index = buttons[action]
		InputMap.action_add_event(action, button)

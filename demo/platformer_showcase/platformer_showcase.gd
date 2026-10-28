extends Node2D

const MOVE_SPEED := 260.0
const JUMP_VELOCITY := -620.0
const GRAVITY := 1450.0
const INTERACT_DISTANCE := 190.0
const LEVEL_END := 1850.0
## Passed into {{player_name}} at play() time. TalkKit never reads this itself.
const PLAYER_NAME := "Darwin"
const GROUND_TOP := 433.0
const GROUND_TILE_WIDTH := 86.4
# The grass tips in tiles.png sit above the solid surface, so the artwork is
# raised by that much above the collision top.
const GRASS_TIP_OFFSET := 8.1
# Two ground chunks from tiles.png, alternated and mirrored to hide the repeat.
const GROUND_CHUNKS: Array[Rect2] = [Rect2(16.0, 11.0, 64.0, 69.0), Rect2(96.0, 11.0, 64.0, 69.0)]

const GROUND_TILES := preload("res://demo/platformer_showcase/assets/third_party/ansimuz/forest/tiles.png")

@onready var player: CharacterBody2D = %Player
@onready var player_sprite: AnimatedSprite2D = %PlayerSprite
@onready var npcs: Array[Node2D] = [%Haru, %Ren, %Jin]
@onready var npc_sprites: Array[AnimatedSprite2D] = [%BottomSprite, %BubbleSprite, %CustomSprite]
@onready var prompts: Array[Label] = [%BottomPrompt, %BubblePrompt, %CustomPrompt]
@onready var talkkits: Array[NPCTalkKit] = [%BottomTalkKit, %BubbleTalkKit, %CustomTalkKit]
@onready var hint: Label = %Hint
## A TalkKit node with no speaker and no saved conversations. Narration is
## spoken through say(), and with no speaker the box shows no name or face.
@onready var narrator: NPCTalkKit = %Narrator

var player_locked := false
var active_npc := -1
var completed: Array[bool] = [false, false, false]


func _ready() -> void:
	_build_ground()
	_connect_talkkits()
	_fade_hint()
	_update_prompts()


func _physics_process(delta: float) -> void:
	if player_locked:
		player.velocity.x = move_toward(player.velocity.x, 0.0, MOVE_SPEED * 6.0 * delta)
		if not player.is_on_floor():
			player.velocity.y += GRAVITY * delta
		player.move_and_slide()
		_update_player_animation(0.0)
		_update_prompts()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	player.velocity.x = move_toward(player.velocity.x, direction * MOVE_SPEED, MOVE_SPEED * 8.0 * delta)
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("ui_accept"):
		player.velocity.y = JUMP_VELOCITY

	player.move_and_slide()
	player.position.x = clampf(player.position.x, 48.0, LEVEL_END)
	if player.position.y > 760.0:
		player.position = Vector2(150.0, 390.0)
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		_narrate("[i]The river carries you back to the trailhead.[/i]")
	_update_player_animation(direction)
	_update_prompts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_talk()
		elif event.keycode == KEY_ESCAPE:
			_stop_all_dialogue()


func _connect_talkkits() -> void:
	for index in talkkits.size():
		var talkkit := talkkits[index]
		talkkit.request_player_lock.connect(_on_player_lock.bind(index))
		talkkit.request_face_target.connect(_on_face_target.bind(index))
		talkkit.event_triggered.connect(_on_event.bind(index))
		talkkit.event_blocked.connect(_on_event_blocked.bind(index))
		talkkit.conversation_finished.connect(_on_finished.bind(index))
		talkkit.conversation_cancelled.connect(_on_cancelled.bind(index))


func _try_talk() -> void:
	if active_npc >= 0 and talkkits[active_npc].is_running():
		if not talkkits[active_npc].is_blocked():
			talkkits[active_npc].advance()
		return
	var nearest := -1
	var nearest_distance := INF
	for index in npcs.size():
		var distance := player.global_position.distance_to(npcs[index].global_position)
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	if nearest < 0 or nearest_distance > INTERACT_DISTANCE:
		return
	active_npc = nearest
	talkkits[nearest].play(
		StringName("forest_checkpoint_%d" % (nearest + 1)),
		{"player_name": PLAYER_NAME},
	)


## Speaks a one-off line through say(), with nothing authored. Skipped while
## an NPC is talking. The game closes the bark itself, since the player keeps
## moving and the advance key also jumps.
func _narrate(text: String) -> void:
	for talkkit in talkkits:
		if talkkit.is_running():
			return
	if narrator.is_running():
		narrator.stop()
	narrator.say(text)
	_dismiss_bark_when_read()


func _dismiss_bark_when_read() -> void:
	await narrator.speech_finished
	await get_tree().create_timer(1.6).timeout
	if narrator.is_running():
		narrator.stop()


func _stop_all_dialogue() -> void:
	for talkkit in talkkits:
		if talkkit.is_running():
			talkkit.stop()
	if narrator.is_running():
		narrator.stop()


func _update_player_animation(direction: float) -> void:
	# The sprite faces right; flip it when walking left.
	if absf(direction) > 0.05:
		player_sprite.flip_h = direction < 0.0
	var walking := absf(direction) > 0.05 and player.is_on_floor()
	player_sprite.play(&"walk" if walking else &"idle")


func _update_prompts() -> void:
	for index in npcs.size():
		var nearby := player.global_position.distance_to(npcs[index].global_position) <= INTERACT_DISTANCE
		prompts[index].visible = nearby and active_npc < 0


func _on_player_lock(locked: bool, index: int) -> void:
	player_locked = locked
	if locked:
		active_npc = index
	elif active_npc == index:
		active_npc = -1


func _on_face_target(target: Node, index: int) -> void:
	if target == npcs[index]:
		# The forest animals face left; turn them when the player is on their right.
		npc_sprites[index].flip_h = player.global_position.x > npcs[index].global_position.x


## A blocking event pauses the conversation for the game. Here the answer is
## scripted; a real game would show a choice UI, then call resume() or play().
func _on_event_blocked(event_id: StringName, payload: Variant, index: int) -> void:
	print("[TalkKit] blocked on %s · %s" % [event_id, JSON.stringify(payload)])
	status_hint("The forest waits for your answer…")
	await get_tree().create_timer(0.8).timeout
	if talkkits[index].is_blocked():
		talkkits[index].resume()


func _on_event(event_id: StringName, payload: Variant, index: int) -> void:
	completed[index] = true
	print("[TalkKit] %s · %s" % [event_id, JSON.stringify(payload)])


func _on_finished(_conversation_id: StringName, _index: int) -> void:
	if completed.all(func(value: bool) -> bool: return value):
		print("[TalkKit] all three dialogue box checkpoints cleared")


func _on_cancelled(_conversation_id: StringName, index: int) -> void:
	print("[TalkKit] checkpoint %d cancelled; platformer control restored" % (index + 1))


func _build_ground() -> void:
	var platforms := $Platforms
	var index := 0
	var x := -GROUND_TILE_WIDTH
	while x < LEVEL_END + 600.0:
		var tile := Sprite2D.new()
		tile.texture = GROUND_TILES
		tile.region_enabled = true
		tile.region_rect = GROUND_CHUNKS[index % 2]
		tile.flip_h = index % 4 >= 2
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# A hair wider than the step, so no seam shows between chunks.
		tile.scale = Vector2(1.37, 1.35)
		tile.position = Vector2(x, GROUND_TOP - GRASS_TIP_OFFSET + 46.6)
		platforms.add_child(tile)
		tile.reset_physics_interpolation()
		x += GROUND_TILE_WIDTH
		index += 1


func status_hint(message: String) -> void:
	hint.modulate.a = 1.0
	hint.text = message


func _fade_hint() -> void:
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(hint, "modulate:a", 0.0, 1.2)

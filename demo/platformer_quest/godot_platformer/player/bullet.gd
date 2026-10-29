extends RigidBody2D

const Enemy = preload("res://demo/platformer_quest/godot_platformer/enemy/enemy.gd")


@onready var animation_player := $AnimationPlayer as AnimationPlayer


func destroy() -> void:
	animation_player.play(&"destroy")


func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		(body as Enemy).destroy()

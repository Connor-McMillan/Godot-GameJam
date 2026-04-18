extends StaticBody2D

@export var required_item: String = "janitor_key"
@export var opens_with_button: bool = false

var player_near: CharacterBody2D = null
var button_pressed: bool = false

@onready var interaction_zone: Area2D = $InteractionZone
@onready var door_sound: AudioStreamPlayer2D = $DoorSound
@onready var door_message: Label = get_tree().current_scene.get_node("CanvasLayer/DoorMessage")

func _ready():
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _process(_delta):
	if player_near == null:
		return

	if opens_with_button:
		if button_pressed:
			door_message.text = "Door opened"
		else:
			door_message.text = "Push center button"
	else:
		if player_near.has_item(required_item):
			door_message.text = "Press A to unlock " + get_door_name()
		else:
			door_message.text = get_locked_message()

		if Input.is_action_just_pressed("pickup"):
			try_open()

func _on_body_entered(body):
	if body.name == "Player":
		player_near = body

func _on_body_exited(body):
	if body == player_near:
		player_near = null
		door_message.text = ""

func try_open():
	if player_near == null:
		return

	if player_near.has_item(required_item):
		door_message.text = get_unlock_message()
		open_door()

func unlock_from_button():
	if button_pressed:
		return

	button_pressed = true
	open_door()

func open_door():
	if door_sound:
		door_sound.play()

	door_message.text = ""
	hide()
	set_process(false)
	set_physics_process(false)
	interaction_zone.monitoring = false

	var collision = get_node_or_null("CollisionShape2D")
	if collision != null:
		collision.disabled = true

	await door_sound.finished
	queue_free()

func get_locked_message() -> String:
	if required_item == "janitor_key":
		return "Matching slime required"
	elif required_item == "lab_key_card":
		return "Matching slime required"
	elif required_item == "control_code":
		return "Matching slime required"
	else:
		return "Door locked"

func get_unlock_message() -> String:
	if required_item == "janitor_key":
		return "Door unlocked"
	elif required_item == "lab_key_card":
		return "Door unlocked"
	elif required_item == "control_code":
		return "Door unlocked"
	else:
		return "Door unlocked"

func get_door_name() -> String:
	if required_item == "janitor_key":
		return "Orange door"
	elif required_item == "lab_key_card":
		return "Yellow door"
	elif required_item == "control_code":
		return "Purple door"
	else:
		return "door"

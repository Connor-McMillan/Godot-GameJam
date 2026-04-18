extends CharacterBody2D

@export var speed: float = 300.0
@export var normal_zoom: Vector2 = Vector2(2, 2)
@export var fallback_map_zoom: Vector2 = Vector2(1, 1)
@export var max_map_power: float = 100.0
@export var map_drain_rate: float = 12.0

var map_power: float = 100.0
var current_section: Area2D = null
var map_view_active: bool = false
var can_move: bool = true

var nearby_item: Area2D = null
var nearby_battery: Area2D = null

var inventory := {
	"janitor_key": false,
	"lab_key_card": false,
	"control_code": false
}

var exit_countdown_started: bool = false

@onready var detector: Area2D = $Detector
@onready var camera: Camera2D = get_node("../Camera2D")
@onready var takedown_prompt: Label = get_node("../CanvasLayer/TakedownPrompt")
@onready var pickup_prompt: Label = get_node("../CanvasLayer/PickupPrompt")

@onready var lockerroom_key_icon: ColorRect = get_node("../CanvasLayer/InventoryPanel/LockerroomKeyIcon")
@onready var lab_key_card_icon: ColorRect = get_node("../CanvasLayer/InventoryPanel/LabKeyCardIcon")
@onready var control_code_icon: ColorRect = get_node("../CanvasLayer/InventoryPanel/ControlCodeIcon")

@onready var map_tint: ColorRect = get_node("../CanvasLayer/MapTint")
@onready var map_power_bar: ProgressBar = get_node("../CanvasLayer/MapPowerBar")

@onready var world_darkness: CanvasModulate = get_node("../CanvasModulate")
@onready var player_light: PointLight2D = $PointLight2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var takedown_sound: AudioStreamPlayer2D = $TakedownSound
@onready var squish_sound: AudioStreamPlayer2D = $SquishSound
@onready var move_sound: AudioStreamPlayer2D = $MoveSound
@onready var exit_message: Label = get_node("../CanvasLayer/ExitMessage")

func _ready():
	camera.zoom = normal_zoom
	camera.global_position = global_position

	if takedown_prompt:
		takedown_prompt.text = "Press X for takedown"
		takedown_prompt.visible = false

	if pickup_prompt:
		pickup_prompt.visible = false

	if exit_message:
		exit_message.visible = false

	update_inventory_ui()
	map_power = max_map_power

	if map_tint:
		map_tint.visible = false

	if world_darkness:
		world_darkness.visible = true

	if player_light:
		player_light.visible = true

	update_map_power_bar()

	if animated_sprite:
		animated_sprite.play("default")

	detector.area_entered.connect(_on_area_entered)
	detector.area_exited.connect(_on_area_exited)

func _physics_process(delta):
	var takedown_target = get_takedown_target()

	if takedown_prompt:
		takedown_prompt.visible = takedown_target != null

	if takedown_target != null and Input.is_action_just_pressed("takedown"):
		if takedown_target.has_method("apply_takedown"):
			takedown_target.apply_takedown()

		if takedown_sound:
			takedown_sound.play()

	if pickup_prompt:
		if nearby_item:
			pickup_prompt.text = "Press A to pick up"
			pickup_prompt.visible = true
		elif nearby_battery:
			if nearby_battery.is_available:
				pickup_prompt.text = "Press A to recharge Goggles"
				pickup_prompt.visible = true
			else:
				pickup_prompt.visible = false
		else:
			pickup_prompt.visible = false

	if nearby_item and Input.is_action_just_pressed("pickup"):
		pick_up_item(nearby_item)

		if squish_sound:
			squish_sound.play()

	if nearby_battery and Input.is_action_just_pressed("pickup"):
		collect_battery(nearby_battery)

		if squish_sound:
			squish_sound.play()

	if Input.is_action_just_pressed("toggle_map_view"):
		if map_view_active:
			toggle_map_view()
		elif map_power > 0:
			toggle_map_view()
		else:
			print("Map power depleted")

	if map_view_active:
		map_power -= map_drain_rate * delta

		if map_power <= 0:
			map_power = 0
			toggle_map_view()
			print("Map power depleted")

	update_map_power_bar()

	if can_move:
		var direction := Vector2.ZERO
		direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		direction = direction.normalized()

		velocity = direction * speed

		if direction != Vector2.ZERO:
			if move_sound and not move_sound.playing:
				move_sound.pitch_scale = randf_range(0.9, 1.1)
				move_sound.play()
		else:
			if move_sound and move_sound.playing:
				move_sound.stop()

		if animated_sprite:
			if direction == Vector2.ZERO:
				if animated_sprite.animation != "default":
					animated_sprite.play("default")
			else:
				if animated_sprite.animation != "move":
					animated_sprite.play("move")

				if direction.x < 0:
					animated_sprite.flip_h = true
				elif direction.x > 0:
					animated_sprite.flip_h = false
	else:
		velocity = Vector2.ZERO

		if move_sound and move_sound.playing:
			move_sound.stop()

		if animated_sprite and animated_sprite.animation != "default":
			animated_sprite.play("default")

	move_and_slide()

	if not map_view_active:
		camera.global_position = global_position

func get_takedown_target():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("can_be_takedown_by") and enemy.can_be_takedown_by(self):
			return enemy
	return null

func pick_up_item(item: Area2D):
	if item == null:
		return

	var item_name = item.item_name

	if inventory.has(item_name):
		inventory[item_name] = true
		print("Picked up: ", item_name)

		update_inventory_ui()

		if pickup_prompt:
			pickup_prompt.visible = false

		nearby_item = null
		item.queue_free()

func collect_battery(battery: Area2D):
	if battery == null or not battery.is_available:
		return

	map_power += battery.recharge_amount
	map_power = min(map_power, max_map_power)

	update_map_power_bar()
	print("Battery collected. Map power: ", map_power)

	nearby_battery = null
	battery.collect()

func update_inventory_ui():
	if lockerroom_key_icon:
		lockerroom_key_icon.visible = inventory["janitor_key"]

	if lab_key_card_icon:
		lab_key_card_icon.visible = inventory["lab_key_card"]

	if control_code_icon:
		control_code_icon.visible = inventory["control_code"]

func update_map_power_bar():
	if map_power_bar:
		map_power_bar.max_value = max_map_power
		map_power_bar.value = map_power

func has_item(item_name: String) -> bool:
	return inventory.has(item_name) and inventory[item_name]

func toggle_map_view():
	map_view_active = !map_view_active

	if map_view_active:
		can_move = false
		velocity = Vector2.ZERO

		if current_section:
			camera.global_position = current_section.global_position
			camera.zoom = current_section.map_zoom if "map_zoom" in current_section else fallback_map_zoom
		else:
			camera.global_position = global_position
			camera.zoom = fallback_map_zoom

		if map_tint:
			map_tint.visible = true
		if world_darkness:
			world_darkness.visible = false
		if player_light:
			player_light.visible = false
	else:
		can_move = true
		camera.global_position = global_position
		camera.zoom = normal_zoom

		if map_tint:
			map_tint.visible = false
		if world_darkness:
			world_darkness.visible = true
		if player_light:
			player_light.visible = true

func start_exit_countdown():
	exit_countdown_started = true

	if exit_message:
		exit_message.visible = true
		exit_message.text = "Escape successful!!! You Made It To The Flowers!!!"

	await get_tree().create_timer(20.0).timeout
	get_tree().quit()

func _on_area_entered(area):
	if area.is_in_group("map_sections"):
		current_section = area

	if area.is_in_group("pickup_items"):
		nearby_item = area

	if area.is_in_group("battery_cells"):
		nearby_battery = area

	if area.is_in_group("exit_section") and not exit_countdown_started:
		start_exit_countdown()

func _on_area_exited(area):
	if area == current_section:
		current_section = null
		for overlap in detector.get_overlapping_areas():
			if overlap.is_in_group("map_sections"):
				current_section = overlap
				break

	if area == nearby_item:
		nearby_item = null

	if area == nearby_battery:
		nearby_battery = null

extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	RETURN_TO_PATH,
	INCAPACITATED,
	RECOVERING
}

@export var patrol_speed: float = 180.0
@export var chase_speed: float = 430.0
@export var point_reached_distance: float = 20.0
@export var route_path: NodePath

@export var vision_range: float = 140.0
@export var vision_angle_degrees: float = 70.0
@export var detection_time_required: float = 1.0
@export var detection_recovery_speed: float = 0.9

@export var takedown_range: float = 55.0
@export var incapacitated_time: float = 4.0
@export var recovery_look_time: float = 2.0
@export var recovery_turn_speed: float = 3.0

var patrol_points: Array[Vector2] = []
var current_point_index: int = 1
var moving_forward: bool = true

var current_state: State = State.PATROL
var facing_direction: Vector2 = Vector2.RIGHT

var player_in_range: Node2D = null
var last_known_player_position: Vector2 = Vector2.ZERO
var detection_meter: float = 0.0
var player_was_visible_last_frame: bool = false

var return_target_index: int = 1
var incapacitated_timer: float = 0.0
var recovery_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var vision_visual: Node2D = $VisionVisual
@onready var visual: Node2D = $Visual
@onready var takedown_shadow: Node2D = $TakedownShadow
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var alert_sound: AudioStreamPlayer2D = $AlertSound

func _ready():
	if route_path.is_empty():
		push_warning("Enemy has no route_path assigned.")
		return

	var route = get_node(route_path)
	if route == null:
		push_warning("Enemy route_path is invalid.")
		return

	for child in route.get_children():
		if child is Node2D:
			patrol_points.append(child.global_position)

	if patrol_points.size() < 2:
		push_warning("Enemy needs at least 2 patrol points.")
		return

	global_position = patrol_points[0]
	current_point_index = 1
	return_target_index = current_point_index

	if animated_sprite != null:
		animated_sprite.play("default")

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)

func _physics_process(delta):
	match current_state:
		State.PATROL:
			handle_patrol()
		State.CHASE:
			handle_chase()
		State.RETURN_TO_PATH:
			handle_return_to_path()
		State.INCAPACITATED:
			handle_incapacitated(delta)
		State.RECOVERING:
			handle_recovering(delta)

	update_detection(delta)
	update_animation()
	update_visual_feedback()

func handle_patrol():
	if patrol_points.size() < 2:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	move_to_point(patrol_points[current_point_index], patrol_speed)

	if global_position.distance_to(patrol_points[current_point_index]) <= point_reached_distance:
		if moving_forward:
			current_point_index += 1
			if current_point_index >= patrol_points.size():
				current_point_index = patrol_points.size() - 2
				moving_forward = false
		else:
			current_point_index -= 1
			if current_point_index < 0:
				current_point_index = 1
				moving_forward = true

		velocity = Vector2.ZERO

	if can_currently_see_player():
		last_known_player_position = player_in_range.global_position
		current_state = State.CHASE

func handle_chase():
	if can_currently_see_player():
		last_known_player_position = player_in_range.global_position

	move_to_point(last_known_player_position, chase_speed)

	if not can_currently_see_player() and global_position.distance_to(last_known_player_position) <= point_reached_distance:
		return_target_index = current_point_index
		current_state = State.RETURN_TO_PATH

func handle_return_to_path():
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	move_to_point(patrol_points[return_target_index], patrol_speed)

	if global_position.distance_to(patrol_points[return_target_index]) <= point_reached_distance:
		current_point_index = return_target_index
		current_state = State.PATROL
		velocity = Vector2.ZERO

func move_to_point(target: Vector2, speed_value: float):
	var to_target = target - global_position

	if to_target.length() <= point_reached_distance:
		velocity = Vector2.ZERO
		return

	var move_dir = to_target.normalized()
	velocity = move_dir * speed_value
	facing_direction = move_dir

	move_and_slide()

func handle_incapacitated(delta):
	velocity = Vector2.ZERO
	move_and_slide()

	incapacitated_timer -= delta
	if incapacitated_timer <= 0.0:
		recovery_timer = recovery_look_time
		current_state = State.RECOVERING

func handle_recovering(delta):
	velocity = Vector2.ZERO
	facing_direction = facing_direction.rotated(recovery_turn_speed * delta).normalized()
	move_and_slide()

	recovery_timer -= delta
	if recovery_timer <= 0.0:
		current_state = State.PATROL

func update_animation():
	if animated_sprite == null:
		return

	if current_state == State.INCAPACITATED or current_state == State.RECOVERING:
		if animated_sprite.animation != "knockedout":
			animated_sprite.play("knockedout")
	else:
		if animated_sprite.animation != "default":
			animated_sprite.play("default")

	if facing_direction.x < 0:
		animated_sprite.flip_h = true
	elif facing_direction.x > 0:
		animated_sprite.flip_h = false

func update_detection(delta):
	if current_state == State.INCAPACITATED or current_state == State.RECOVERING:
		detection_meter = 0.0
		player_was_visible_last_frame = false
		return

	var can_see_player_now = can_currently_see_player()

	if can_see_player_now and not player_was_visible_last_frame:
		if alert_sound and not alert_sound.playing:
			alert_sound.play()

	player_was_visible_last_frame = can_see_player_now

	if can_see_player_now:
		detection_meter = min(detection_meter + delta, detection_time_required)

		if detection_meter >= detection_time_required:
			on_player_spotted()
	else:
		detection_meter = max(detection_meter - detection_recovery_speed * delta, 0.0)

func can_currently_see_player() -> bool:
	if player_in_range == null:
		return false

	if current_state == State.INCAPACITATED:
		return false

	var to_player = player_in_range.global_position - global_position
	var distance_to_player = to_player.length()

	if distance_to_player > vision_range:
		return false

	if distance_to_player <= 0.01:
		return true

	var dir_to_player = to_player.normalized()
	var facing_dot = facing_direction.normalized().dot(dir_to_player)

	var half_vision_angle_rad = deg_to_rad(vision_angle_degrees * 0.5)
	var vision_threshold = cos(half_vision_angle_rad)

	if facing_dot < vision_threshold:
		return false

	return has_line_of_sight_to_player()

func has_line_of_sight_to_player() -> bool:
	if player_in_range == null:
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player_in_range.global_position)

	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return true

	return result.collider == player_in_range

func can_be_takedown_by(player: Node2D) -> bool:
	if current_state == State.INCAPACITATED:
		return false

	return global_position.distance_to(player.global_position) <= takedown_range

func apply_takedown():
	current_state = State.INCAPACITATED
	incapacitated_timer = incapacitated_time
	detection_meter = 0.0
	velocity = Vector2.ZERO
	player_in_range = null
	player_was_visible_last_frame = false

	if animated_sprite != null:
		animated_sprite.play("knockedout")

func update_visual_feedback():
	var alert_ratio = detection_meter / detection_time_required
	var disabled = current_state == State.INCAPACITATED or current_state == State.RECOVERING

	match current_state:
		State.PATROL:
			alert_ratio *= 0.6
		State.CHASE:
			alert_ratio = max(alert_ratio, 0.8)
		State.RETURN_TO_PATH:
			alert_ratio = 0.35
		State.INCAPACITATED:
			alert_ratio = 0.0
		State.RECOVERING:
			alert_ratio = 0.25

	vision_visual.set_vision_state(facing_direction, clamp(alert_ratio, 0.0, 1.0), disabled)
	visual.set_disabled(disabled)
	takedown_shadow.set_shadow_state(facing_direction, takedown_range, disabled)

func on_player_spotted():
	print("GAME OVER: Player fully spotted.")
	get_tree().paused = true

func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player_in_range = body

func _on_detection_area_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		player_was_visible_last_frame = false

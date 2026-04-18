extends Area2D

@export var recharge_amount: float = 35.0
@export var respawn_time: float = 8.0

@export var ready_color: Color = Color(0.2, 1.0, 0.2)
@export var empty_color: Color = Color(0.35, 0.45, 0.35)

var is_available: bool = true

@onready var polygon: Polygon2D = $Polygon2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("battery_cells")
	update_visual()

func collect():
	if not is_available:
		return

	is_available = false
	update_visual()

	if collision_shape != null:
		collision_shape.disabled = true

	respawn_battery()

func respawn_battery() -> void:
	await get_tree().create_timer(respawn_time).timeout

	is_available = true

	if collision_shape != null:
		collision_shape.disabled = false

	update_visual()

func update_visual():
	if polygon != null:
		if is_available:
			polygon.color = ready_color
		else:
			polygon.color = empty_color

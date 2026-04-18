extends Area2D

@export var item_name: String = "item"
@export var item_color: Color = Color.WHITE

@onready var polygon: Polygon2D = $Polygon2D

func _ready():
	add_to_group("pickup_items")
	polygon.color = item_color

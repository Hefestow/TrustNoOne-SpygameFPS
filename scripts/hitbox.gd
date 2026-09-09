extends Area3D
class_name Hitbox

@export var damage: float = 20.0
@export var knockback: float = 6.0

func _ready() -> void:
	monitoring = false
	monitorable = true

func set_active(on: bool) -> void:
	monitoring = on
	monitorable = on

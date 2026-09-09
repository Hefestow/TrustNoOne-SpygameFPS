extends Node
class_name HealthComponent

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, from: Node)
signal died

@export var max_health: float = 100.0
@export var invuln_time: float = 0.35

var current: float
var is_dead: bool = false
var _invuln: bool = false

func _ready() -> void:
	current = max_health
	health_changed.emit(current, max_health)

func take_damage(amount: float, from: Node = null) -> void:
	if is_dead or _invuln or amount <= 0.0:
		return
	current = max(current - amount, 0.0)
	health_changed.emit(current, max_health)
	damaged.emit(amount, from)
	if current <= 0.0:
		is_dead = true
		died.emit()
		return
	if invuln_time > 0.0:
		_invuln = true
		get_tree().create_timer(invuln_time).timeout.connect(func():
			_invuln = false
		)

func heal(amount: float) -> void:
	if is_dead:
		return
	current = min(current + amount, max_health)
	health_changed.emit(current, max_health)

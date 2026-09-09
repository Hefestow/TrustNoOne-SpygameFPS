extends Area3D
class_name Bullet

@export var speed: float = 40.0
@export var damage: float = 50.0
@export var lifetime: float = 2.0

var direction: Vector3 = Vector3.FORWARD
var armed: bool = false

func setup(origin: Vector3, dir: Vector3) -> void:
	global_position = origin
	global_basis = Basis.looking_at(dir, Vector3.UP)
	scale = Vector3.ONE
	direction = dir.normalized()
	armed = true

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not armed:
		return
	global_position += direction * speed * delta

func _on_hit(thing: Node) -> void:
	if thing.is_in_group("player"):
		return
	var parent := thing.get_parent()
	if parent and parent.is_in_group("player"):
		return
	if thing.has_method("take_damage"):
		thing.take_damage(damage)
	queue_free()

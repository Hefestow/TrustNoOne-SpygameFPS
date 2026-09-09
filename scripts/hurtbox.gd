extends Area3D
class_name Hurtbox

@export var health_path: NodePath
@export var knockback_force: float = 6.0

@onready var health: HealthComponent = get_node_or_null(health_path)

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	if health == null:
		health = owner.find_child("HealthComponent", true, false)


func _on_area_entered(area: Area3D) -> void:
	var hit := area as Hitbox
	if hit == null:
		return
	if hit.owner == owner:
		return
	if health:
		health.take_damage(hit.damage, hit.owner)
		
func apply_hit(amount: float, knockback: float, from: Node) -> void:
	_apply(amount, knockback, from)

func _apply(amount: float, knockback: float, from: Node) -> void:
	if health:
		health.take_damage(amount, from)
	var body := owner as CharacterBody3D
	if body and from is Node3D:
		var dir: Vector3 = body.global_position - (from as Node3D).global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			body.velocity.x += dir.x * knockback
			body.velocity.z += dir.z * knockback
			body.velocity.y = max(body.velocity.y, knockback * 0.25)

extends Node3D
class_name PipeWeapon

@export var damage: float = 25.0
@export var swing_cooldown: float = 0.2
@export var hit_start: float = 0.08
@export var hit_end: float = 0.22

@onready var hitbox: Area3D = $Hitbox
@onready var anim: AnimationPlayer = $PipeAnimation

var can_attack: bool = true
var swinging: bool = false
var already_hit: Array[Node] = []

func _ready() -> void:
	if hitbox:
		hitbox.monitoring = false
		hitbox.body_entered.connect(_on_hit)
		hitbox.area_entered.connect(_on_hit)
	if anim and not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func attack() -> void:
	if not can_attack or not visible:
		return
	if anim == null or not anim.has_animation("swing"):
		push_warning("Pipe needs an AnimationPlayer with a 'swing' animation")
		return

	can_attack = false
	swinging = true
	already_hit.clear()
	anim.play("swing")

func _process(_delta: float) -> void:
	if not swinging or hitbox == null or anim == null:
		return
	var t := anim.current_animation_position
	hitbox.monitoring = t >= hit_start and t <= hit_end

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name != &"swing":
		return
	swinging = false
	if hitbox:
		hitbox.monitoring = false
	await get_tree().create_timer(swing_cooldown).timeout
	can_attack = true

func _on_hit(thing: Node) -> void:
	if not swinging:
		return
	if thing in already_hit:
		return
	if thing.is_in_group("player"):
		return
	already_hit.append(thing)
	if thing.has_method("take_damage"):
		thing.take_damage(damage)

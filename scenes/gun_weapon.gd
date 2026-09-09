extends Node3D
class_name GunWeapon

@export var bullet_scene: PackedScene
@export var max_ammo: int = 2
@export var ammo: int = 2
@export var fire_cooldown: float = 0.25
@export var kick_angle_deg: float = 8.0
@export var aim_distance: float = 100.0

@onready var muzzle: Marker3D = $Muzzle
@onready var camera: Camera3D = $"../.."
@onready var anim: AnimationPlayer = $GunAnimation

var can_fire: bool = true
var is_reloading: bool = false
var rest_rotation: Vector3
var kick_tween: Tween

func _ready() -> void:
	rest_rotation = rotation_degrees
	ammo = max_ammo
	if anim and not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func attack() -> void:
	if not visible or not can_fire or is_reloading:
		return
	if ammo <= 0:
		reload()
		return
	if bullet_scene == null or muzzle == null or camera == null:
		push_warning("Gun is missing bullet_scene, Muzzle, or Camera")
		return

	ammo -= 1
	can_fire = false

	var origin := muzzle.global_position
	var aim_point := _get_aim_point()
	var forward := (aim_point - origin).normalized()

	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	if bullet.has_method("setup"):
		bullet.setup(origin, forward)

	if kick_tween:
		kick_tween.kill()
	kick_tween = create_tween()
	kick_tween.tween_property(self, "rotation_degrees:x", rest_rotation.x + kick_angle_deg, 0.04)
	kick_tween.tween_property(self, "rotation_degrees:x", rest_rotation.x, 0.12)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

func reload() -> void:
	if not visible or is_reloading:
		return
	if ammo >= max_ammo:
		return
	if anim == null or not anim.has_animation("reload"):
		ammo = max_ammo
		return

	is_reloading = true
	can_fire = false
	anim.play("reload")

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name != &"reload":
		return
	ammo = max_ammo
	is_reloading = false
	can_fire = true

func _get_aim_point() -> Vector3:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * aim_distance)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_tree().get_first_node_in_group("player")]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position
	return to

extends CharacterBody3D
class_name Trooper

enum State { PATROL, IDLE, CHASE, ATTACK }

@export var move_speed: float = 2.4
@export var attack_range: float = 0.8
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.2
@export var patrol_pause: float = 1.5
@export var waypoint_reach: float = 0.6
@export var gravity_enabled: bool = true
@export var facing_offset_deg: float = 90.0
@export var look_blend_time: float = 0.45
@export var look_modifier_path: NodePath
@export var waypoints: Array[Node3D] = []
@export var start_hostile: bool = false
@export var hit_stun: float = 0.28


@onready var hurt_sfx: AudioStreamPlayer3D = $TrooperHurtSFX
@onready var health_label: Label3D = $HealthLabel
@onready var anim: AnimationPlayer = $hostile_trooper/AnimationPlayer2
@onready var talk_area: Area3D = $InteractionArea
@onready var attack_hitbox: Area3D = $AttackHitbox
@onready var look_at_mod: LookAtModifier3D = get_node_or_null(look_modifier_path)

@export var flash_time: float = 0.10
@export var flash_color: Color = Color(1.0, 0.152, 0.1, 0.548)

var _flash_mat: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []

var is_dead: bool = false
var stun_left: float = 0.0
var state: State = State.PATROL
var player: Node3D
var player_head: Node3D
var waypoint_index: int = 0
var can_attack: bool = true
var pause_left: float = 0.0
var already_hit: Array[Node] = []
var want_look: bool = false
var look_tween: Tween
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("troopers")
	_find_player()
	if look_at_mod:
		look_at_mod.active = true
		look_at_mod.influence = 0.0
		if look_at_mod.duration <= 0.0:
			look_at_mod.duration = 0.25
		_set_look_target()
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.body_entered.connect(_on_attack_hit)
	if start_hostile:
		become_hostile()
	else:
		_play("idle_anim")
		
	var health := self.get_node_or_null("HealthComponent")
	if health:
		health.health_changed.connect(_on_trooper_health)
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
		_on_trooper_health(health.current, health.max_health)
		
	_meshes.clear()
	for child in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(child)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = flash_color
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_flash_mat.roughness = 1.0
	

		
func become_hostile() -> void:
	if is_dead:
		return

	if state == State.CHASE or state == State.ATTACK:
		return

	state = State.CHASE

	if talk_area:
		talk_area.set_can_talk(false)

	_play("walk")
	_blend_look(true)
	
	


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	if has_node("Hitbox"):
		$Hitbox.set_active(false)
	if has_node("Hurtbox"):
		$Hurtbox.monitoring = false
		$Hurtbox.monitorable = false
	_play("idle_anim")
	get_tree().call_group("troopers", "become_hostile")
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		_set_look_target()

	if gravity_enabled and not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		
	if stun_left > 0.0:
		stun_left -= delta
		velocity.x = lerp(velocity.x, 0.0, 4.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 4.0 * delta)
		move_and_slide()
		return
		
	match state:
		State.PATROL:
			_patrol(delta)
			_blend_look(false)
		State.IDLE:
			_idle()
			_blend_look(false)
		State.CHASE:
			_chase()
			_blend_look(true)
		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_blend_look(true)

	move_and_slide()
	_face_move_dir()

func _patrol(delta: float) -> void:
	if waypoints.is_empty():
		state = State.IDLE
		_play("idle_anim")
		return

	if pause_left > 0.0:
		pause_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target: Node3D = waypoints[waypoint_index]
	if target == null:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() <= waypoint_reach:
		waypoint_index = (waypoint_index + 1) % waypoints.size()
		pause_left = patrol_pause
		_play("idle_anim")
		return

	var dir := to.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_play("walk")

func _idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play("idle_anim")

func _chase() -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() <= attack_range:
		_start_attack()
		return
	var dir := to.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_play("walk")



func apply_knockback_stun(time: float = -1.0) -> void:
	stun_left = hit_stun if time < 0.0 else time
	if state == State.ATTACK:
		return
	state = State.CHASE
	
	
func _start_attack() -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	if not can_attack:
		return
	state = State.ATTACK
	can_attack = false
	velocity.x = 0.0
	velocity.z = 0.0
	await _face_player_now()
	_play("swing")
	if anim:
		await anim.animation_finished
	if has_node("Hitbox"):
		$Hitbox.set_active(false)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	if state == State.ATTACK:
		state = State.CHASE

func _on_attack_hit(body: Node) -> void:
	if state != State.ATTACK:
		return
	if body in already_hit:
		return
	if not body.is_in_group("player"):
		return
	already_hit.append(body)
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func _play(anim_name: String) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim.current_animation == anim_name and anim.is_playing():
		return
	anim.play(anim_name)

func _face_player_now() -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var target_yaw := atan2(-to.x, -to.z) + deg_to_rad(facing_offset_deg)
	var t := 0.0
	while t < 0.15:
		var delta := get_process_delta_time()
		t += delta
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.25)
		await get_tree().process_frame

func _face_yaw(dir: Vector3) -> void:
	if dir.length() < 0.05:
		return
	var target_yaw := atan2(-dir.x, -dir.z) + deg_to_rad(facing_offset_deg)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.15)
func _face_move_dir() -> void:
	if state == State.ATTACK:
		return
	_face_yaw(Vector3(velocity.x, 0.0, velocity.z))

func _face_player() -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	_face_yaw(to)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	player_head = player.get_node_or_null("Head") if player else null

func _set_look_target() -> void:
	if look_at_mod == null:
		return
	var target := player_head if player_head else player
	if target:
		look_at_mod.target_node = target.get_path()

func _blend_look(on: bool) -> void:
	if look_at_mod == null or on == want_look:
		return
	want_look = on
	if look_tween:
		look_tween.kill()
	look_tween = create_tween()
	look_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	look_tween.tween_property(look_at_mod, "influence", 1.0 if on else 0.0, look_blend_time)

func _on_trooper_health(current: float, max_health: float) -> void:
	if health_label:
		health_label.text = "HP %d / %d" % [int(current), int(max_health)]


func _on_damaged(_amount: float, _from: Node) -> void:
	_hit_flash()
	if hurt_sfx:
		hurt_sfx.play()

func _hit_flash() -> void:
	for mi in _meshes:
		mi.material_overlay = _flash_mat
	await get_tree().create_timer(flash_time).timeout
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = null

extends CharacterBody3D
class_name PlayerController

signal interactable_focused(prompt_text: String)
signal interactable_unfocused
signal footstep_played(noise_level: float)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.5
@export var acceleration: float = 10.0
@export var air_control: float = 0.3
@export var jump_velocity: float = 4.5

@export var mouse_sensitivity: float = 0.15
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@export var interact_range: float = 2.5

@export var footstep_sounds: Array[AudioStream] = []
@export var step_interval_walk: float = 0.5
@export var step_interval_sprint: float = 0.35
@export var step_interval_crouch: float = 0.7
@export var footstep_pitch_variation: float = 0.08

@export var talk_fov: float = 58.0
@export var talk_blend_time: float = 0.55
@export var look_at_face_height_bias: float = 0.0
@export var stop_lerp_speed: float = 8.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var crouch_shape: CollisionShape3D = $CollisionShape3D
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var weapons: WeaponManager = $Head/Camera3D/WeaponHolder
@onready var player_model: MeshInstance3D = $PlayerModel
@onready var grab_animation: AnimationPlayer = $GrabAnimation
@onready var grab_sprite: Sprite2D = $GrabSprite


var default_fov: float = 75.0
var dialogue_locked: bool = false
var conversation_target: Node3D = null
var conversation_tween: Tween

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_crouching: bool = false
var standing_height: float = 2.0
var crouch_height: float = 1.0
var footstep_timer: float = 0.0
var last_footstep_index: int = -1

var current_interactable: Node = null
var area_interactable: Node = null
var last_prompt: String = ""
var is_grabbing: bool = false

func _ready() -> void:
	grab_sprite.visible = false
	default_fov = camera.fov
	player_model.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interact_ray.target_position = Vector3(0, 0, -interact_range)
	interact_ray.collide_with_areas = true
	interact_ray.collide_with_bodies = true
	if crouch_shape.shape is CapsuleShape3D:
		standing_height = crouch_shape.shape.height
	add_to_group("player")
	await get_tree().process_frame
	var chief := get_tree().get_first_node_in_group("chief")
	if chief and chief.has_signal("main_dialogue_finished"):
		chief.main_dialogue_finished.connect(_on_weapons_granted)

func _on_weapons_granted() -> void:
	if weapons:
		weapons.grant_weapons()


func play_grab(item: Node) -> void:
	if is_grabbing:
		return
	is_grabbing = true

	var look_at_node: Node3D = item as Node3D
	start_conversation(look_at_node)

	if grab_sprite:
		grab_sprite.visible = true
	if grab_animation and grab_animation.has_animation("grab"):
		grab_animation.play("grab")
		await grab_animation.animation_finished
	else:
		await get_tree().create_timer(0.35).timeout

	if is_instance_valid(item) and item.has_method("on_grabbed"):
		item.on_grabbed()

	if grab_sprite:
		grab_sprite.visible = false

	is_grabbing = false
	end_conversation()
	
func _unhandled_input(event: InputEvent) -> void:
	if dialogue_locked:
		if is_grabbing:
			return
		if _is_leave_event(event):
			_cancel_conversation()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("attack") or event.is_action_pressed("interact"):
			_try_interact()
			get_viewport().set_input_as_handled()
			return
		return

	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
func _is_leave_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event.is_action_pressed("jump"):
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		return true
	return false

func _cancel_conversation() -> void:
	for npc in get_tree().get_nodes_in_group("talking_npc"):
		if npc.has_method("cancel_conversation"):
			npc.cancel_conversation()
			return
	end_conversation()
	
func _physics_process(delta: float) -> void:
	if dialogue_locked:
		_handle_gravity(delta)
		velocity.x = lerp(velocity.x, 0.0, stop_lerp_speed * delta)
		velocity.z = lerp(velocity.z, 0.0, stop_lerp_speed * delta)
		move_and_slide()
		return

	_handle_gravity(delta)
	_handle_jump()
	_handle_crouch(delta)
	_handle_movement(delta)
	move_and_slide()
	_handle_footsteps(delta)
	_handle_interact_check()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	if crouch_shape.shape is CapsuleShape3D:
		var target_height := crouch_height if is_crouching else standing_height
		crouch_shape.shape.height = lerp(crouch_shape.shape.height, target_height, 10.0 * delta)
		crouch_shape.position.y = crouch_shape.shape.height / 2.0



	
func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	var accel := acceleration if is_on_floor() else acceleration * air_control
	if direction:
		velocity.x = lerp(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, accel * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, accel * delta)
		velocity.z = lerp(velocity.z, 0.0, accel * delta)

func _handle_footsteps(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and horizontal_speed > 0.5
	if not moving:
		footstep_timer = 0.0
		return
	var interval := step_interval_walk
	var volume_db := -6.0
	var noise_level := 0.5
	if is_crouching:
		interval = step_interval_crouch
		volume_db = -20.0
		noise_level = 0.15
	elif Input.is_action_pressed("sprint"):
		interval = step_interval_sprint
		volume_db = 0.0
		noise_level = 1.0
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		_play_footstep(volume_db, noise_level)
		footstep_timer = interval

func _play_footstep(volume_db: float, noise_level: float) -> void:
	if footstep_sounds.is_empty():
		return
	var index := randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1:
		while index == last_footstep_index:
			index = randi() % footstep_sounds.size()
	last_footstep_index = index
	footstep_player.stream = footstep_sounds[index]
	footstep_player.pitch_scale = 1.0 + randf_range(-footstep_pitch_variation, footstep_pitch_variation)
	footstep_player.volume_db = volume_db
	footstep_player.play()
	footstep_played.emit(noise_level)

func set_current_interactable(interactable: Node) -> void:
	area_interactable = interactable
	_refresh_interactable()

func _handle_interact_check() -> void:
	_refresh_interactable()

func _refresh_interactable() -> void:
	var next: Node = area_interactable
	if next == null:
		next = _get_ray_interactable()

	if next != current_interactable:
		if current_interactable and current_interactable.has_method("on_unfocus"):
			if current_interactable != area_interactable:
				current_interactable.on_unfocus(self)
		current_interactable = next
		if current_interactable and current_interactable.has_method("on_focus"):
			current_interactable.on_focus(self)

	_update_prompt()

func _get_ray_interactable() -> Node:
	if not interact_ray.is_colliding():
		return null
	var collider := interact_ray.get_collider()
	if collider and collider.has_method("interact"):
		return collider
	return null

func _update_prompt() -> void:
	var prompt := ""
	if current_interactable and current_interactable.has_method("get_prompt"):
		prompt = current_interactable.get_prompt()
	if prompt == last_prompt:
		return
	last_prompt = prompt
	if prompt == "":
		interactable_unfocused.emit()
	else:
		interactable_focused.emit(prompt)

func _try_interact() -> void:
	if current_interactable and current_interactable.has_method("interact"):
		current_interactable.interact(self)
		_update_prompt()
		return
	for npc in get_tree().get_nodes_in_group("talking_npc"):
		if npc.has_method("interact"):
			npc.interact(self)
			_update_prompt()
			return

func start_conversation(face: Node3D) -> void:
	conversation_target = face
	dialogue_locked = true
	_tween_into_conversation()

func end_conversation() -> void:
	conversation_target = null
	dialogue_locked = false
	_tween_out_of_conversation()

func set_dialogue_lock(locked: bool) -> void:
	if locked:
		start_conversation(null)
	else:
		end_conversation()

func _tween_into_conversation() -> void:
	if conversation_tween:
		conversation_tween.kill()
	conversation_tween = create_tween().set_parallel(true)
	conversation_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	conversation_tween.tween_property(camera, "fov", talk_fov, talk_blend_time)
	conversation_tween.tween_method(_blend_look_at_target, 0.0, 1.0, talk_blend_time)

func _tween_out_of_conversation() -> void:
	if conversation_tween:
		conversation_tween.kill()
	conversation_tween = create_tween()
	conversation_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	conversation_tween.tween_property(camera, "fov", default_fov, talk_blend_time)

func _blend_look_at_target(weight: float) -> void:
	if conversation_target == null or not is_instance_valid(conversation_target):
		return

	var face_pos: Vector3 = conversation_target.global_position + Vector3(0.0, look_at_face_height_bias, 0.0)
	var to_face: Vector3 = face_pos - camera.global_position
	if to_face.length() < 0.05:
		return

	var dir := to_face.normalized()
	var target_yaw := atan2(-dir.x, -dir.z)
	var flat := Vector2(dir.x, dir.z).length()
	var target_pitch := atan2(dir.y, flat)
	target_pitch = clamp(target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	head.rotation.x = lerp_angle(head.rotation.x, target_pitch, weight)
	
func player_say(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(text)

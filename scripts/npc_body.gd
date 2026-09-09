extends Node3D
class_name NPCBody

@export var look_only_when_talking: bool = true
@export var max_look_distance: float = 12.0
@export var look_blend_time: float = 0.45

@export var look_modifier_path: NodePath = ^"Armature/Skeleton3D/LookAtModifier3D"
@export var interaction_area_path: NodePath = ^"InteractionArea"
@export var intro_mesh_path: NodePath = ^"Armature/Skeleton3D/Sphere"
@export var play_intro_flash: bool = false
@export var black_material: Material
@export var intro_delay: float = 2.0

@onready var look_at_mod: LookAtModifier3D = get_node_or_null(look_modifier_path)
@onready var talk_npc: Node = get_node_or_null(interaction_area_path)

var player: Node3D
var player_head: Node3D
var want_look: bool = false
var look_tween: Tween

func _ready() -> void:
	if look_at_mod:
		look_at_mod.active = true
		look_at_mod.influence = 0.0
		if look_at_mod.duration <= 0.0:
			look_at_mod.duration = 0.25

	if play_intro_flash:
		_play_intro_flash()

	await get_tree().process_frame
	_find_player()
	_set_look_target()

	if talk_npc == null:
		talk_npc = find_child("InteractionArea", true, false)

func _process(_delta: float) -> void:
	if look_at_mod == null:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		_set_look_target()

	var should_look := false
	if look_only_when_talking:
		if talk_npc:
			should_look = bool(talk_npc.get("is_dialogue_open"))
	elif player:
		should_look = global_position.distance_to(player.global_position) <= max_look_distance

	if should_look != want_look:
		want_look = should_look
		_blend_look(should_look)

func _blend_look(on: bool) -> void:
	if look_at_mod == null:
		return
	if look_tween:
		look_tween.kill()
	look_tween = create_tween()
	look_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	look_tween.tween_property(look_at_mod, "influence", 1.0 if on else 0.0, look_blend_time)

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		player = null
		player_head = null
		return
	player = players[0]
	player_head = player.get_node_or_null("Head")

func _set_look_target() -> void:
	if look_at_mod == null:
		return
	var target := player_head if player_head else player
	if target:
		look_at_mod.target_node = target.get_path()
	else:
		look_at_mod.target_node = NodePath()

func _play_intro_flash() -> void:
	var sphere := get_node_or_null(intro_mesh_path) as MeshInstance3D
	if sphere == null or sphere.mesh == null or black_material == null:
		return
	for i in range(sphere.mesh.get_surface_count()):
		sphere.set_surface_override_material(i, black_material)
	await get_tree().create_timer(intro_delay).timeout
	if not is_instance_valid(sphere):
		return
	for i in range(sphere.mesh.get_surface_count()):
		sphere.set_surface_override_material(i, null)

extends Node3D

@onready var spot_light_3d: SpotLight3D = $SpotLight3D
@onready var omni_light_3d: OmniLight3D = $OmniLight3D
@onready var spotlight_sound: AudioStreamPlayer3D = $SpotLight3D/SpotlightSound
@onready var fluorescent_hum_sfx: AudioStreamPlayer3D = $SpotLight3D/FluorescentHumSFX
@onready var animation_player: AnimationPlayer = $Environment/AnimationPlayer
@onready var door_sfx: AudioStreamPlayer3D = $DoorSFX
@onready var exit_door: Area3D = $"Exit door"
@export var next_level: PackedScene


var _changing_level: bool = false

func _ready() -> void:
	GameState.flags_changed.connect(_sync_door)
	_sync_door()


	spot_light_3d.visible = false
	omni_light_3d.visible = false
	var chief := get_tree().get_first_node_in_group("chief")
	if chief == null:
		chief = find_child("InteractionArea", true, false)
	if chief and chief.has_signal("main_dialogue_finished"):
		chief.main_dialogue_finished.connect(_on_chief_finished_talking)
	else:
		push_warning("World couldn't find Chief to hook door open.")

	await get_tree().create_timer(2.0).timeout

	spot_light_3d.visible = true
	omni_light_3d.visible = true
	spotlight_sound.play()
	fluorescent_hum_sfx.play()
	
func _sync_door() -> void:
	if GameState.door_unlocked:
		animation_player.play("gate_open")
		# disable a blocking StaticBody if you have one
		
func _on_chief_finished_talking() -> void:
	if door_sfx:
		door_sfx.play()
	animation_player.play("slide_door")
	exit_door.monitorable = true
	exit_door.monitoring = true
	

func _on_exit_door_body_entered(body: Node3D) -> void:
	if _changing_level:
		return
	if not body.is_in_group("player"):
		return
	_changing_level = true
	_go_to_level()

func _go_to_level() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_scene"):
		hud.fade_to_scene(next_level)
		return
	if next_level:
		get_tree().change_scene_to_packed(next_level)
	else:
		get_tree().change_scene_to_file("res://scenes/level.tscn")

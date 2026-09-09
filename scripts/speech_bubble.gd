extends Control

@onready var label: Label = $PanelContainer/MarginContainer/Label  # ← adjust path if needed

@export var screen_margin: float = 32.0
@export var soft_clamp_speed: float = 12.0
@export var max_offscreen_time: float = 3.0
@export var fade_duration: float = 0.35

var target_3d: Node3D
var offscreen_timer: float = 0.0
var is_visible_bubble: bool = false
var desired_screen_pos: Vector2 = Vector2.ZERO
var has_initialized_pos: bool = false

func _ready() -> void:
	# Critical: force top-left anchors so position works correctly
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	size = Vector2.ZERO

func show_text(text: String, duration: float = 0.0) -> void:
	label.text = text
	
	# Force the container to recalculate its size
	await get_tree().process_frame
	reset_size()
	
	is_visible_bubble = true
	visible = true
	offscreen_timer = 0.0
	has_initialized_pos = false          # force a snap on the first frame
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		hide_bubble()

func hide_bubble() -> void:
	if not is_visible_bubble:
		return
	is_visible_bubble = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func(): visible = false)

func _process(delta: float) -> void:
	if not is_visible_bubble or target_3d == null or not is_instance_valid(target_3d):
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var world_pos := target_3d.global_position
	var screen_pos := camera.unproject_position(world_pos)
	var behind := camera.is_position_behind(world_pos)

	var viewport_size := get_viewport_rect().size
	var bubble_size := size

	# Ideal position = centered horizontally, a bit above the head
	var ideal := screen_pos - Vector2(bubble_size.x * 0.5, bubble_size.y + 18.0)

	# Soft clamp so it stays on screen
	var min_pos := Vector2(screen_margin, screen_margin)
	var max_pos := viewport_size - bubble_size - Vector2(screen_margin, screen_margin)
	var clamped := ideal.clamp(min_pos, max_pos)

	if not has_initialized_pos:
		# First frame → snap immediately (avoids flying in from corner)
		desired_screen_pos = clamped
		has_initialized_pos = true
	else:
		# Soft follow
		desired_screen_pos = desired_screen_pos.lerp(clamped, 1.0 - exp(-soft_clamp_speed * delta))

	# Use position (not global_position) because we are under a CanvasLayer
	position = desired_screen_pos

	# Off-screen timer
	var significantly_off := behind \
		or ideal.x < -bubble_size.x \
		or ideal.x > viewport_size.x \
		or ideal.y < -bubble_size.y \
		or ideal.y > viewport_size.y

	if significantly_off:
		offscreen_timer += delta
		if offscreen_timer >= max_offscreen_time:
			hide_bubble()
	else:
		offscreen_timer = 0.0

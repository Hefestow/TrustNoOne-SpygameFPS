extends CanvasLayer
class_name HUD

@onready var interact_label: Label = $InteractPrompt
@onready var fade_rect: ColorRect = $FadeRect
@onready var end_message: Label = $EndMessage
@onready var player_bark: Label = $PlayerBark
@onready var health_label: Label = $HealthLabel

@export var bark_chars_per_second: float = 38.0
@export var bark_hold_time: float = 2.4
@export var bark_fade_time: float = 0.25

@onready var hurt_flash: ColorRect = $HurtFlash

@export var hurt_flash_alpha: float = 0.45
@export var hurt_flash_time: float = 0.18

var hurt_tween: Tween
var is_ending: bool = false
var bark_tween: Tween

func _ready() -> void:
	
	interact_label.visible = false
	if fade_rect:
		fade_rect.modulate.a = 0.0
		fade_rect.visible = true
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if end_message:
		end_message.visible = false
	if player_bark:
		player_bark.visible = false
		player_bark.modulate.a = 0.0

	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	
	if player:
		player.interactable_focused.connect(_on_interactable_focused)
		player.interactable_unfocused.connect(_on_interactable_unfocused)
		var health := player.get_node_or_null("HealthComponent")
		if health:
			health.health_changed.connect(_on_player_health)
			_on_player_health(health.current, health.max_health)
	else:
		push_warning("HUD couldn't find a node in the 'player' group.")

	add_to_group("hud")
	if hurt_flash:
		hurt_flash.color = Color(0.7, 0.0, 0.0, 0.0)
		hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	await get_tree().process_frame
	if player:
		# existing interact signals...
		var health := player.get_node_or_null("HealthComponent")
		if health:
			health.health_changed.connect(_on_player_health)
			health.damaged.connect(_on_player_hurt)
			_on_player_health(health.current, health.max_health)
			
func _on_interactable_focused(prompt_text: String) -> void:
	if is_ending:
		return
	interact_label.text = prompt_text
	interact_label.visible = prompt_text != ""

func _on_interactable_unfocused() -> void:
	interact_label.visible = false

func play_exit_sequence(message: String = "The job is done.") -> void:
	if is_ending:
		return
	is_ending = true
	interact_label.visible = false
	if player_bark:
		player_bark.visible = false

	if end_message:
		end_message.text = message
		end_message.visible = false

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	tween.tween_callback(_show_end_message)

func _show_end_message() -> void:
	if end_message:
		end_message.visible = true

func say(text: String) -> void:
	if is_ending or player_bark == null or text.is_empty():
		return

	text = text.replace("\\n", "\n")
	if bark_tween:
		bark_tween.kill()

	player_bark.text = text
	player_bark.visible_characters = 0
	player_bark.visible = true
	player_bark.modulate.a = 1.0

	var duration = text.length() / max(bark_chars_per_second, 1.0)
	bark_tween = create_tween()
	bark_tween.tween_property(player_bark, "visible_characters", text.length(), duration)
	bark_tween.tween_interval(bark_hold_time)
	bark_tween.tween_property(player_bark, "modulate:a", 0.0, bark_fade_time)
	bark_tween.tween_callback(func():
		player_bark.visible = false
		player_bark.visible_characters = -1
	)
func _on_player_health(current: float, max_health: float) -> void:
	if health_label:
		health_label.text = "HP %d / %d" % [int(current), int(max_health)]

func _on_player_hurt(_amount: float, _from: Node) -> void:
	if hurt_flash == null:
		return
	if hurt_tween:
		hurt_tween.kill()
	hurt_flash.color.a = hurt_flash_alpha
	hurt_tween = create_tween()
	hurt_tween.tween_property(hurt_flash, "color:a", 0.0, hurt_flash_time)

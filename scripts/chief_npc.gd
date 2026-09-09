extends Area3D
#class_name NPC

signal main_dialogue_finished

@export var npc_name: String = "Chief"
@export var dialogue_lines: Array[String] = [
	"This is your last job before retirement, so try to keep it clean.",
	"Your target is the CEO of Tech-Tock.\nInfiltrate his HQ, find him and eliminate him.",
	"Here are your tools for the mission:\nA tranq gun, a pipe and a piece of candy.",
	"Actually that candy looks kinda nice, I'm gonna keep that."
]
@export var post_dialogue_line: String = "That'll be all. Godspeed."
@export var beckon_line: String = "Psst... come here a second."
@export var beckon_delay: float = 2.0
@export var beckon_lifetime: float = 4.5
@export var chars_per_second: float = 34.0
@export var comma_pause: float = 0.12
@export var period_pause: float = 0.28
@export var skip_cooldown: float = 0.35
@export var last_line_hold: float = 1.2
@export var fade_duration: float = 0.25
@export var voice_sounds: Array[AudioStream] = []

@onready var voice_player: AudioStreamPlayer3D = $"../ChiefChatter"
@onready var dialogue_box: Control = $"../DialogueBox"

var player_in_range: Node = null
var dialogue_index: int = 0
var has_completed_dialogue: bool = false
var is_typing: bool = false
var is_dialogue_open: bool = false
var can_accept_input: bool = true
var current_full_text: String = ""
var current_kind: String = ""
var visible_chars: int = 0
var type_timer: float = 0.0
var fade_tween: Tween
var pulse_tween: Tween
var hold_tween: Tween
var dialogue_label: Label
var continue_indicator: Label
var name_label: Label

var reopen_cooldown: float = 0.5
var can_reopen: bool = true

func _ready() -> void:
	if dialogue_box:
		dialogue_label = dialogue_box.find_child("DialogueLabel", true, false)
		continue_indicator = dialogue_box.find_child("ContinueIndicator", true, false)
		name_label = dialogue_box.find_child("NameLabel", true, false)
		dialogue_box.visible = false
		dialogue_box.modulate.a = 0.0
		if continue_indicator:
			continue_indicator.visible = false
		if name_label:
			name_label.text = npc_name.to_upper()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	await get_tree().create_timer(beckon_delay).timeout
	_start_line(beckon_line, "beckon")
	get_tree().create_timer(beckon_lifetime).timeout.connect(func():
		if is_dialogue_open and current_kind == "beckon":
			_close_dialogue()
	)

func _process(delta: float) -> void:
	if not is_typing:
		return
	if current_full_text.is_empty():
		_on_typing_finished()
		return

	type_timer -= delta
	if type_timer > 0.0:
		return

	if visible_chars >= current_full_text.length():
		_on_typing_finished()
		return

	var ch := current_full_text[visible_chars]
	visible_chars += 1
	if dialogue_label:
		dialogue_label.visible_characters = visible_chars

	type_timer = 1.0 / max(chars_per_second, 1.0)
	if ch == ",":
		type_timer += comma_pause
	elif ch == "." or ch == "!" or ch == "?":
		type_timer += period_pause

func get_prompt() -> String:
	if is_dialogue_open:
		return ""
	return "Talk [E]" % npc_name

func interact(_by: Node) -> void:
	_handle_interact()

func on_focus(_by: Node) -> void:
	pass

func on_unfocus(_by: Node) -> void:
	# Locked conversations cannot be cancelled by leaving the area
	if current_kind == "main" or current_kind == "post":
		return
	if is_dialogue_open and current_kind == "beckon":
		_close_dialogue()

func _handle_interact() -> void:
	if not can_accept_input:
		return

	if not is_dialogue_open:
		if not can_reopen:
			return
		if has_completed_dialogue:
			_start_line(post_dialogue_line, "post")
		elif not dialogue_lines.is_empty():
			_start_line(dialogue_lines[dialogue_index], "main")
		return

	if is_typing:
		_finish_typing()
		_start_input_cooldown(skip_cooldown)
		return

	if current_kind == "main":
		dialogue_index += 1
		if dialogue_index >= dialogue_lines.size():
			has_completed_dialogue = true
			dialogue_index = 0
			_close_dialogue()
			main_dialogue_finished.emit()
		else:
			_start_line(dialogue_lines[dialogue_index], "main")
		return

	# Post / beckon: close and don't immediately reopen
	_close_dialogue()

func _close_dialogue() -> void:
	is_dialogue_open = false
	is_typing = false
	can_accept_input = true
	current_kind = ""
	remove_from_group("talking_npc")
	_stop_voice()
	_stop_continue_pulse()
	_set_player_locked(false)
	_start_reopen_cooldown()
	if hold_tween:
		hold_tween.kill()

	if dialogue_box:
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.tween_property(dialogue_box, "modulate:a", 0.0, fade_duration)
		fade_tween.tween_callback(func():
			if dialogue_box:
				dialogue_box.visible = false
		)

func _start_reopen_cooldown() -> void:
	can_reopen = false
	get_tree().create_timer(reopen_cooldown).timeout.connect(func():
		can_reopen = true
	)

func _start_line(text: String, kind: String) -> void:
	current_full_text = text.replace("\\n", "\n")
	current_kind = kind
	visible_chars = 0
	type_timer = 0.0
	is_typing = true
	is_dialogue_open = true
	can_accept_input = true
	add_to_group("talking_npc")

	if hold_tween:
		hold_tween.kill()
	_stop_continue_pulse()

	if dialogue_label:
		dialogue_label.text = current_full_text
		dialogue_label.visible_characters = 0

	if dialogue_box:
		dialogue_box.visible = true
		if dialogue_box.modulate.a < 1.0:
			if fade_tween:
				fade_tween.kill()
			fade_tween = create_tween()
			fade_tween.tween_property(dialogue_box, "modulate:a", 1.0, fade_duration)

	if kind == "main" or kind == "post":
		_set_player_locked(true)

	_start_voice_chatter()

func _finish_typing() -> void:
	if not is_typing:
		return
	visible_chars = current_full_text.length()
	if dialogue_label:
		dialogue_label.visible_characters = -1
	_on_typing_finished()

func _on_typing_finished() -> void:
	is_typing = false
	_stop_voice()
	if dialogue_label:
		dialogue_label.visible_characters = -1
	_start_continue_pulse()

	if current_kind == "main" and dialogue_index >= dialogue_lines.size() - 1:
		if hold_tween:
			hold_tween.kill()
		hold_tween = create_tween()
		hold_tween.tween_interval(last_line_hold)
		hold_tween.tween_callback(func():
			if is_dialogue_open and current_kind == "main" and not is_typing:
				has_completed_dialogue = true
				dialogue_index = 0
				_close_dialogue()
				main_dialogue_finished.emit()
		)


func _set_player_locked(locked: bool) -> void:
	var player := player_in_range
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if locked:
		var face := get_node_or_null("../SpeechAnchor")
		if player.has_method("start_conversation"):
			player.start_conversation(face)
	else:
		if player.has_method("end_conversation"):
			player.end_conversation()
			
func cancel_conversation() -> void:
	if not is_dialogue_open:
		return
	if current_kind == "main" and not has_completed_dialogue:
		dialogue_index = 0
	_close_dialogue()
	
func _start_input_cooldown(time: float) -> void:
	can_accept_input = false
	get_tree().create_timer(time).timeout.connect(func():
		can_accept_input = true
	)

func _start_continue_pulse() -> void:
	if continue_indicator == null:
		return
	continue_indicator.visible = true
	continue_indicator.modulate.a = 1.0
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(continue_indicator, "modulate:a", 0.25, 0.4)
	pulse_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.4)

func _stop_continue_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
	if continue_indicator:
		continue_indicator.visible = false
		continue_indicator.modulate.a = 1.0

func _start_voice_chatter() -> void:
	if voice_player == null:
		return
	_play_random_voice()
	if not voice_player.finished.is_connected(_on_voice_finished):
		voice_player.finished.connect(_on_voice_finished)

func _play_random_voice() -> void:
	if voice_player == null:
		return
	if not voice_sounds.is_empty():
		voice_player.stream = voice_sounds[randi() % voice_sounds.size()]
	if voice_player.stream == null:
		return
	voice_player.play()

func _on_voice_finished() -> void:
	if is_typing:
		_play_random_voice()

func _stop_voice() -> void:
	if voice_player and voice_player.playing:
		voice_player.stop()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		if body.has_method("set_current_interactable"):
			body.set_current_interactable(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = null
		if body.has_method("set_current_interactable"):
			body.set_current_interactable(null)
		on_unfocus(body)

extends Area3D
class_name GrabItem

@export var item_name: String = "Item"
@export var prompt_text: String = "Pick up"
@export var consume_on_grab: bool = true
@export var inspect_line: String = "Hmm, guess it's not a scratch and sniff."

var grabbed: bool = false
@export var gives_pass: bool = false

func get_prompt() -> String:
	if grabbed:
		return ""
	return "%s [E]" % prompt_text

func interact(by: Node) -> void:
	if grabbed:
		return
	if by.has_method("play_grab"):
		by.play_grab(self)

func on_focus(_by: Node) -> void:
	pass

func on_unfocus(_by: Node) -> void:
	pass


func on_grabbed() -> void:
	if grabbed:
		return
	grabbed = true

	if gives_pass:
		GameState.give_pass()

	_say(inspect_line)

	if not consume_on_grab:
		return

	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.disabled = true
	hide()

	# Only free the small wrapper this Area lives under (Mesh + Area),
	# never the level / World.
	var wrapper := get_parent()
	if wrapper and wrapper != get_tree().current_scene:
		wrapper.hide()
		wrapper.call_deferred("queue_free")
	else:
		call_deferred("queue_free")
			
func _say(text: String) -> void:
	if text.is_empty():
		push_warning("GrabItem inspect_line is empty")
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(text)
	else:
		push_warning("No HUD in group 'hud' — bark won't show")

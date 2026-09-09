extends Area3D
class_name GrabItem

@export var item_name: String = "Item"
@export var prompt_text: String = "Pick up"
@export var consume_on_grab: bool = true
@export var inspect_line: String = "Hmm, guess it's not a scratch and sniff."

var grabbed: bool = false

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
	#grabbed = true
	_say(inspect_line)
	if consume_on_grab:
		hide()
		var col := get_node_or_null("CollisionShape3D")
		if col:
			col.disabled = true
		queue_free()

func _say(text: String) -> void:
	if text.is_empty():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("say"):
		hud.say(text)

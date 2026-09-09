extends Area3D
class_name Interactable
 
## Attach this script (or extend it) on any physics body — StaticBody3D,
## RigidBody3D, Area3D, CharacterBody3D — that should respond to the
## player's interact raycast. Override the functions below per-object.
 
@export var interact_prompt: String = "Interact"
 
## Called once when the player presses the interact key while looking at this object.
func interact(by: Node) -> void:
	pass
 
## Called every frame the player's crosshair enters this object (use for UI prompts, highlight outlines, etc).
func on_focus(by: Node) -> void:
	pass
 
## Called when the player's crosshair leaves this object.
func on_unfocus(by: Node) -> void:
	pass
 
## Handy for wiring up an interact-prompt label in your HUD.
func get_prompt() -> String:
	return interact_prompt

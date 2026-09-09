extends Node3D
class_name WeaponManager

enum Weapon { NONE, PIPE, GUN }

@export var start_unlocked: bool = true

@onready var pipe: Node3D = $Pipe
@onready var gun: Node3D = $Gun

var unlocked: bool = false
var current: Weapon = Weapon.NONE

func _ready() -> void:
	_hide_all()
	if start_unlocked:
		grant_weapons()

func _unhandled_input(event: InputEvent) -> void:
	if _player_is_busy():
		return
	if not unlocked:
		return

	if event.is_action_pressed("weapon_pipe"):
		equip(Weapon.PIPE)
	elif event.is_action_pressed("weapon_gun"):
		equip(Weapon.GUN)
	elif event.is_action_pressed("attack"):
		_attack()
	if event.is_action_pressed("reload"):
		if current == Weapon.GUN and gun and gun.has_method("reload"):
			gun.reload()
			
func grant_weapons() -> void:
	unlocked = true
	equip(Weapon.PIPE)

func equip(weapon: Weapon) -> void:
	if not unlocked:
		return
	current = weapon
	if pipe:
		pipe.visible = weapon == Weapon.PIPE
	if gun:
		gun.visible = weapon == Weapon.GUN

func _attack() -> void:
	if _player_is_busy():
		return
	match current:
		Weapon.PIPE:
			if pipe and pipe.has_method("attack"):
				pipe.attack()
		Weapon.GUN:
			if gun and gun.has_method("attack"):
				gun.attack()

func _player_is_busy() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return bool(player.get("dialogue_locked")) or bool(player.get("is_grabbing"))
	
func _player_is_talking() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and bool(player.get("dialogue_locked"))

func _hide_all() -> void:
	if pipe:
		pipe.visible = false
	if gun:
		gun.visible = false

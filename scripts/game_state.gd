extends Node

signal flags_changed

var has_pass: bool = false
var door_unlocked: bool = false

func give_pass() -> void:
	if has_pass:
		return
	has_pass = true
	flags_changed.emit()

func unlock_door() -> void:
	if door_unlocked:
		return
	door_unlocked = true
	flags_changed.emit()

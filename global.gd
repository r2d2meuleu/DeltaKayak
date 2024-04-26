extends Node

var character: Node3D
var camera: Camera3D
var camera_path: Path3D
var icon: TextureRect

func is_demo():
	var is_demo:bool = OS.has_feature("demo")
	if not is_demo:
		if not FileAccess.file_exists("res://not_demo.gd"):
			quit_game()
	return is_demo

func quit_game():
	# See https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	# get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

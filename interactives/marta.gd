extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"say_hi_marta":
			main_scene.say_dialogue("say_hi_marta")

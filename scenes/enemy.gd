extends Boat3D

@export var home_position:Vector3

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var ray_cast_3d: RayCast3D = $RayCast3D

var current_state := STATE.SLEEPING
var attack_state := ATTACK_STATE.START

var on_alert_time := 0.0
var attack_start_time := 0.0
var attack_charge_time := 0.0
var attack_intimidate_time := 0.0

enum STATE {
	SLEEPING,
	ALERT,
	ATTACK,
	SEARCHING_FOOD,
	EATING
}

enum ATTACK_STATE {
	START,
	INTIMIDATE,
	CHARGE
}

func _process(_delta: float) -> void:
	Global.log_text += "\nState: %s" % STATE.find_key(current_state)
	Global.log_text += "\nAttack: %s" % ATTACK_STATE.find_key(attack_state)

func _get_target(delta: float) -> void:
	change_state()
	
	if current_state == STATE.ATTACK:
		change_attack_state()
		target_position = Global.character.global_position
		boat_speed = 0.5
		if attack_state == ATTACK_STATE.START:
			attack_start_time += delta
			boat_speed = 0.8
		if attack_state == ATTACK_STATE.CHARGE:
			attack_charge_time += delta
			boat_speed = 0.4
			if global_position.distance_to(Global.character.global_position) > 4.0:
				waiting = false
			else:
				waiting = true
				get_tree().quit()
		if attack_state == ATTACK_STATE.INTIMIDATE:
			attack_intimidate_time += delta
			boat_speed = 0.1
	if current_state == STATE.ALERT:
		on_alert_time += delta
		boat_speed = 0.4
	if current_state == STATE.SLEEPING:
		nav.target_position = home_position
		target_position = nav.get_next_path_position()
		boat_speed = 0.2
		if global_position.distance_to(home_position) > 2.0:
			waiting = false
		else:
			waiting = true

func change_attack_state():
	match attack_state:
		ATTACK_STATE.START:
			check_attack_start_exit()
		ATTACK_STATE.INTIMIDATE:
			check_attack_intimidate_exit()
		ATTACK_STATE.CHARGE:
			check_attack_charge_exit()

func check_attack_start_exit():
	if attack_start_time > 1.0:
		attack_start_time = 0.0
		if randf() > 0.5:
			attack_state = ATTACK_STATE.CHARGE
		else:
			attack_state = ATTACK_STATE.INTIMIDATE

func check_attack_intimidate_exit():
	if attack_intimidate_time > 4.0:
		attack_intimidate_time = 0.0
		attack_state = ATTACK_STATE.CHARGE

func check_attack_charge_exit():
	if attack_charge_time > 10.0:
		attack_charge_time = 0.0
		attack_state = ATTACK_STATE.INTIMIDATE

func change_state():
	match current_state:
		STATE.SLEEPING:
			check_sleeping_exit()
		STATE.ATTACK:
			check_attack_exit()
		STATE.ALERT:
			check_alert_exit()

func check_sleeping_exit():
	if is_character_visible():
		current_state = STATE.ATTACK
		attack_state = ATTACK_STATE.START
		waiting = false

func check_attack_exit():
	if not is_character_visible():
		current_state = STATE.ALERT
		on_alert_time = 0.0

func check_alert_exit():
	if is_character_visible():
		current_state = STATE.ATTACK
		attack_state = ATTACK_STATE.START
		waiting = false
	elif on_alert_time > 10.0:
		current_state = STATE.SLEEPING
		#waiting = true
		waiting = false

func is_character_visible() -> bool:
	var target := to_local(Global.character.global_position)
	target = target.normalized() * 20
	
	var target_vector := global_position.direction_to(Global.character.global_position) # Direction vector to target
	#var target_vector := to_local(Global.character.global_position).normalized() # Vector to target
	var rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	#print(rotation_vector, target_vector)
	var dot_product := target_vector.dot(rotation_vector)
	#Global.log_text += "\ndot_product: %f" % dot_product
	if dot_product < 0.7: return false
	ray_cast_3d.target_position = target
	ray_cast_3d.force_raycast_update()
	if not ray_cast_3d.is_colliding(): return false
	var collider = ray_cast_3d.get_collider()
	Global.log_text += "\ncollider: %s" % collider.name
	if not collider.name == "character": return false
	return true

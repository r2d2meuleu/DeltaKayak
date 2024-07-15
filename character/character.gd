extends RigidBody3D

@onready var target_box := $CSGBox3D
@onready var pepa: Node3D = %pepa
@onready var camera: Camera3D = %POVCamera3D
@onready var marker_3d: Marker3D = $Marker3D
@onready var grabbing_position: Marker3D = $GrabbingPosition

var soft_camera_rotation: float
var speed := 0.0
var torque := 0.0
var going_backwards := false
var damage := 0.0
var damage_timer := 0.0
var max_damage := 10.0

var kayak_speed := 0.17
var speed_mult := 5.0
var torque_mult := 3.0
var temp_speed := 0.0
var temp_time := 0.0
var strength := 0

var left_sample:float=0.0
var right_sample:float=0.0

var last_rotation := 0.0
var target_direction := 0.0

var current := Vector3.ZERO
var current_direction = Vector3.FORWARD
var current_speed := 0.0

var grabbing_object: RigidBody3D
var grabbing_object_position: Vector3
var grabbing_state = GRABBING.NO
var is_grab_locked:=false

var pid_proportional_par := 180 #40.0 #20.0
var pid_integral_par := 251 #1.0
var pid_derivative_par := 3639 #2000.0 #1000.0

var pid_tunning := 0.0
var control_type := CONTROL_TYPE.CAR

var trail_position := []
var trail_velocity := []
var trail_time := 0.0

@onready var character: Node3D = $character

enum GRABBING {
	WANTS_TO,
	YES,
	NO
}

enum CONTROL_TYPE {
	CAR,
	HAUNTING_GROUND
}

func _ready():
	#position = Vector3(-31.8, 0, -5)
	#position = Vector3(34.7, 0, -5)
	last_rotation = rotation.y
	Global.character = self
	var pepa_anim:AnimationPlayer = pepa.get_node("AnimationPlayer")
	pepa_anim.get_animation("Sitting").loop_mode = Animation.LOOP_LINEAR
	pepa_anim.play("Sitting")
	#print("Transform")
	#print($CSGCylinder3D3.transform)
	#print($CSGCylinder3D3.global_transform)
	#var char_anim:AnimationPlayer = %AnimationPlayer
	#char_anim.get_animation("character_anims/ForwardPaddle").loop_mode = Animation.LOOP_LINEAR
	#char_anim.get_animation("character_anims/Idle").loop_mode = Animation.LOOP_LINEAR
	#char_anim.play("character_anims/ForwardPaddle", -1, 2.0)
	
	var kayak_mat:StandardMaterial3D = $kayak_detailed.get_node("Kayak_001").mesh.surface_get_material(0)
	#kayak_mat.albedo_color = Color(0.81, 0.31, 0.25, 1.0) # Pink
	#kayak_mat.albedo_color = Color(0.50, 0.74, 0.72, 1.0) # Light blue
	#kayak_mat.albedo_color = Color(0.18, 0.41, 0.21, 1.0) # Green
	kayak_mat.albedo_color = Color(1.0, 0.8, 0.0, 1.0) # Yellow
	#kayak_mat.albedo_color = Color(0.9, 0.03, 0.03, 1.0) # Red
	#kayak_mat.albedo_color = Color(0.73, 0.07, 0.07, 1.0) # Dark Red
	kayak_mat.emission_enabled = false
	kayak_mat.emission = kayak_mat.albedo_color * 0.1
	#kayak_mat.emission_intensity = 1.0
	

func _process(delta: float) -> void:
	trail_time += delta
	temp_time -= delta
	temp_time = max(0.0, temp_time)
	# Damage
	damage_timer -= delta
	damage_timer = max(0, damage_timer)
	damage -= delta*0.25
	damage = max(0, damage)
	%DamageLight.light_energy = damage * 0.1
	Global.datamosh_mount = damage / max_damage
	
	if trail_time > 1.0:
		trail_time = 0.0
		trail_position.push_front(Vector3(global_position))
		trail_velocity.push_front(Vector3(linear_velocity))
		if trail_position.size() > 10:
			trail_position.pop_back()
			trail_velocity.pop_back()
	handle_animations()
	hide_head_if_needed()

var _mouse_input:bool
var _mouse_rotation:Vector3
var _rotation_input:float
var _tilt_input:float

func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion \
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * Global.mouse_sensibility
		_tilt_input = -event.relative.y * Global.mouse_sensibility

func _update_camera(delta:float)->void:
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.y += _rotation_input * delta
	
	%POVCameraController.transform.basis = Basis.from_euler(_mouse_rotation)
	%POVCameraController.rotation.z = 0.0
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func hide_pepa()->void:
	pepa.visible = false

func hide_head_if_needed()->void:
	if %POVCamera3D.current:
		$character/Armature/Skeleton3D/capucha.visible = false
		$character/Armature/Skeleton3D/head.visible = false
	else:
		$character/Armature/Skeleton3D/capucha.visible = true
		$character/Armature/Skeleton3D/head.visible = true

func handle_animations()->void:
	return
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_dir == Vector2.ZERO:
		%AnimationTree["parameters/conditions/forward"] = false
		%AnimationTree["parameters/conditions/idle"] = true
	else:
		%AnimationTree["parameters/conditions/forward"] = true
		%AnimationTree["parameters/conditions/idle"] = false
	
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_velocity: float = (forward_direction * linear_velocity.dot(forward_direction)).length()
	
	var anim_speed := remap(forward_velocity, 0, 3, 0.25, 0.7)
	if going_backwards:
		anim_speed *= -1
	#Global.log_text += "\nanim_length: %f" % anim_speed
	%AnimationTree.set("parameters/BlendForward/TimeScale/scale", anim_speed)

func handle_finetunning() -> void:
	var test_angle := angle_difference(deg_to_rad(90), deg_to_rad(0))
	#print(test_angle)
	
	if pid_tunning == 0.0: return
	#var angle_to_target := Vector3.BACK.signed_angle_to(Vector3.RIGHT, Vector3.UP)
	var target_direction := angle_difference(pid_tunning, rotation.y)
	#print(-target_direction)
	get_torque(-target_direction, Vector2.ONE)
	last_rotation = rotation.y
	
func reset_rotation()->void:
	rotation = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func handle_controls(delta:float) -> void:
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	padling_intent = input_dir
	
	left_sample = max(0,-input_dir.x)
	right_sample = max(0, input_dir.x)
	
	if input_dir.y < 0:
		left_sample += -input_dir.y
		right_sample += -input_dir.y
	if input_dir.y > 0:
		left_sample += input_dir.y
		right_sample += input_dir.y
	var total_sample := left_sample + right_sample
	if total_sample > 0:
		left_sample = left_sample / total_sample
		right_sample = right_sample / total_sample
	#Global.log_text += "\ninput_dir.x: %f" % input_dir.x
	#Global.log_text += "\ninput_dir.y: %f" % input_dir.y

var paddle_time:= 0.0
var padling_side:PADDLE_SIDE=PADDLE_SIDE.IDLE
var padling_intent:Vector2
var original_highest_contributor:String = ""
var previous_highest_contributor:String = ""
enum PADDLE_SIDE {
	IDLE,
	LEFT,
	RIGHT
}
const TORQUE_TO = {
	"RIGHT": -1,
	"LEFT": 1
}
var paddle_speed := 2.0
func handle_paddling(delta:float) -> void:
	paddle_time -= delta
	paddle_time = max(0, paddle_time)
	if left_sample == 0 and right_sample == 0:
		padling_side = PADDLE_SIDE.IDLE
		%AnimationTree["parameters/conditions/idle"] = true
		%AnimationTree["parameters/conditions/right"] = false
		%AnimationTree["parameters/conditions/left"] = false
	else:
		if paddle_time == 0:
			if padling_side == PADDLE_SIDE.LEFT or padling_side == PADDLE_SIDE.IDLE:
				padling_side = PADDLE_SIDE.RIGHT
				paddle_time = left_sample*paddle_speed
				%AnimationTree["parameters/conditions/idle"] = false
				%AnimationTree["parameters/conditions/left"] = false
				%AnimationTree["parameters/conditions/right"] = true
				%AnimationTree.set("parameters/BlendRight/TimeScale/scale", paddle_speed)
			else:
				padling_side = PADDLE_SIDE.LEFT
				paddle_time = right_sample*paddle_speed
				%AnimationTree["parameters/conditions/idle"] = false
				%AnimationTree["parameters/conditions/right"] = false
				%AnimationTree["parameters/conditions/left"] = true
				%AnimationTree.set("parameters/BlendLeft/TimeScale/scale", paddle_speed)
		else:
			if original_highest_contributor != previous_highest_contributor:
				paddle_time = 0
				if original_highest_contributor.ends_with("left"):
					padling_side = PADDLE_SIDE.LEFT
				elif original_highest_contributor.ends_with("right"):
					padling_side = PADDLE_SIDE.RIGHT
	previous_highest_contributor = original_highest_contributor
	#Global.log_text += "\npaddle_time: %.2f" % paddle_time
	#Global.log_text += "\n%s" % PADDLE_SIDE.find_key(padling_side)
	#Global.log_text += "\nIntent: %s" % PADDLE_INTENT.find_key(padling_intent)
	if false:
		%AnimationTree["parameters/conditions/idle"] = false
		%AnimationTree["parameters/conditions/left"] = false
		%AnimationTree["parameters/conditions/right"] = false
		match padling_side:
			PADDLE_SIDE.IDLE:
				%AnimationTree["parameters/conditions/idle"] = true
			PADDLE_SIDE.LEFT:
				%AnimationTree["parameters/conditions/left"] = true
				#%AnimationTree.set("parameters/BlendLeft/TimeScale/scale", anim_speed)
			PADDLE_SIDE.RIGHT:
				%AnimationTree["parameters/conditions/right"] = true
	
	var paddle_params := {
		"forward": {
			"torque": 2,
			"speed": 10
		},
		"oposite_side": {
			"torque": 6,
			"speed": 1
		},
		"same_side": {
			"torque": 2,
			"speed": 1
		},
		"forward_oposite_side": {
			"torque": 6,
			"speed": 7
		},
		"forward_same_side": {
			"torque": 2,
			"speed": 7
		}
	}
	var forward_contribution = maxf(0, -padling_intent.y)
	var backward_contribution = maxf(0, padling_intent.y)
	var left_contribution = maxf(0, -padling_intent.x)
	var right_contribution = maxf(0, padling_intent.x)
	
	var contributions := {
		"forward": forward_contribution,
		"backward": backward_contribution,
		"left": left_contribution,
		"right": right_contribution,
		"forward_left": forward_contribution + left_contribution,
		"forward_right": forward_contribution + right_contribution,
		"backward_left": backward_contribution + left_contribution,
		"backward_right": backward_contribution + right_contribution
	}
	var highest_contributor:=""
	var highest_value:=0.0
	for k in contributions:
		# NOTE the value added to "highest_value" adds a "deadzone"
		# Allowing analog sticks to point directly front, back and sides
		if contributions[k] > (highest_value+0.1):
			highest_value = contributions[k]
			highest_contributor = k
	var reverse_speed := 1
	var reverse_torque := 1
	original_highest_contributor = highest_contributor
	# TODO change replace for something faster
	if backward_contribution > 0:
		highest_contributor = highest_contributor.replace("backward", "forward")
		reverse_speed = -1
	if left_contribution > 0:
		if padling_side == PADDLE_SIDE.LEFT:
			highest_contributor = highest_contributor.replace("left", "same_side")
			reverse_torque = -1
		else:
			highest_contributor = highest_contributor.replace("left", "oposite_side")
	if right_contribution > 0:
		if padling_side == PADDLE_SIDE.RIGHT:
			highest_contributor = highest_contributor.replace("right", "same_side")
		else:
			highest_contributor = highest_contributor.replace("right", "oposite_side")
			reverse_torque = -1
	if highest_contributor == "forward":
		if padling_side == PADDLE_SIDE.LEFT:
			reverse_torque = -1
	speed = 0
	torque = 0
	if highest_contributor!="":
		speed = -paddle_params[highest_contributor]["speed"] * reverse_speed
		torque = paddle_params[highest_contributor]["torque"] * reverse_torque
	
	if original_highest_contributor == "forward":
		speed *= forward_contribution
		torque *= forward_contribution
	elif original_highest_contributor == "backward":
		speed *= backward_contribution
		torque *= backward_contribution
	elif original_highest_contributor == "left":
		speed *= left_contribution
		torque *= left_contribution
	elif original_highest_contributor == "right":
		speed *= right_contribution
		torque *= right_contribution
	elif ["forward_oposite_side", "forward_same_side"].has(highest_contributor):
		speed *= abs(padling_intent.y)
		torque *= abs(padling_intent.x)
	
	Global.log_text += "\nhighest_contributor: %s" % highest_contributor
	#Global.log_text += "\ntotal: %f" % padling_intent.length()
	#Global.log_text += "\nspeed: %f" % speed
	#Global.log_text += "\ntorque: %f" % torque
	
	speed *= speed_mult
	torque *= torque_mult
	if grabbing_state == GRABBING.YES:
		torque *= 10
	going_backwards = false
	handle_grabbing()

func handle_rotation() -> void:
	marker_3d.position = position
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var movement_direction:Vector2 = input_dir * 2.0
	
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	var ration:float = 0.99-(0.1)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	
	var local_target_position :Vector2
	if control_type == CONTROL_TYPE.HAUNTING_GROUND:
		local_target_position = movement_direction.rotated(-soft_camera_rotation) * 100.0
	elif control_type == CONTROL_TYPE.CAR:
		local_target_position = movement_direction.rotated(-rotation.y) * 100.0
	
	target_box.global_position = global_position + Vector3(local_target_position.x, 0.0, local_target_position.y)
	var target_position_with_rotation := local_target_position.rotated(rotation.y)
	var global_target_rotation := -Vector2.UP.angle_to(target_position_with_rotation)
	target_direction = global_target_rotation
	going_backwards = false
	if PI - abs(target_direction) < 1.0:
		going_backwards = true
		#Global.log_text += "\nBackwards"
	
	if going_backwards:
		if target_direction > 0:
			target_direction = target_direction-PI
		else:
			target_direction = target_direction+PI
		target_direction *=  -1
	#Global.log_text += "\ntarget_direction: %f" % target_direction
	#Global.log_text += "\nrotation.y: %f" % (rotation.y)
	if temp_time == 0:
		temp_speed = 0.0
	#speed = -max(0, -target_position_with_rotation.y) * delta * (kayak_speed + temp_speed + (strength * 5))
	speed = -abs(target_position_with_rotation.y) * (kayak_speed + temp_speed + (strength * 5))
	get_torque(target_direction, input_dir)
	last_rotation = rotation.y
	handle_grabbing()

func get_torque(error:float, input_dir:Vector2) -> void:
	#Global.log_text += "\nspeed: %f" % speed
	#Global.log_text += "\nerror: %f" % error
	#Global.log_text += "\nproportional: %f" % get_proportional(error)
	#Global.log_text += "\nintegral: %f" % get_integral(error)
	#Global.log_text += "\nderivative: %f" % get_derivative(error)
	torque = 0.0
	if input_dir.length() > 0:
		torque += get_proportional(error) #* delta
		torque += get_integral(error) #* delta
		torque += get_derivative(error) #* delta
	if grabbing_state == GRABBING.YES:
		torque *= 5
	#Global.log_text += "\ntorque: %f" % torque

# PID control
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_proportional_par

func get_integral(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	var integral = angular_velocity.y * pid_integral_par
	return -integral

func get_derivative(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
	return derivative * pid_derivative_par
#

func handle_grabbing():
	if is_grab_locked: return
	if Input.is_action_just_pressed("grab") and grabbing_state == GRABBING.NO:
		match grabbing_state:
			GRABBING.NO:
				#grabbing_state = GRABBING.WANTS_TO
				$RayCast3D.force_raycast_update()
				if $RayCast3D.is_colliding():
					grabbing_state = GRABBING.YES
					%GrabRay.visible = true
					%GrabRay.scale.z = $RayCast3D.get_collision_point().distance_to(%GrabRay.global_position)
					var body = $RayCast3D.get_collider()
					Global.grab_joint.global_position = $GrabbingPosition.global_position
					Global.grab_joint.set_node_a(get_path())
					Global.grab_joint.set_node_b(body.get_path())

	elif Input.is_action_just_pressed("grab") and grabbing_state == GRABBING.YES:
		release_grab()

func release_grab()->void:
	%GrabRay.visible = false
	grabbing_state = GRABBING.NO
	Global.grab_joint.set_node_a(NodePath(""))
	Global.grab_joint.set_node_b(NodePath(""))
	set_collision_mask_value(3, true)

func lock_grab(value:=true):
	is_grab_locked = value

func _physics_process(delta: float):
	if false:
		if pid_tunning == 0.0:
			handle_rotation()
		else:
			handle_finetunning()
	else:
		handle_controls(delta)
		handle_paddling(delta)
	#apply_torque(Vector3(0, torque, 0) * remap(linear_velocity.length(), 0, 3, 0.1, 1) * delta)
	apply_torque(Vector3(0, torque, 0) * delta)
	if not going_backwards:
		go_forward(speed * delta)
	else:
		go_backward(speed * delta)
	get_current()
	# Current
	#current *= 0.999
	current = current_direction * current_speed * delta
	#Global.log_text += "\ncurrent.x: %f" % current.x
	#Global.log_text += "\ncurrent.y: %f" % current.y
	#Global.log_text += "\ncurrent.z: %f" % current.z
	_update_camera(delta)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.BACK).normalized()
	#Global.log_text += "\nChar forward_component: %.2f" % (direction*_speed).length()
	apply_central_force(direction * _speed)

func go_backward(_speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces_old(state:PhysicsDirectBodyState3D):
	#if true:#paddle_status !=0 and holding:
		#state.linear_velocity *= 0.999
		#state.angular_velocity *= 0.999
	#else:
		#state.linear_velocity *= 0.999
		#state.angular_velocity *= 0.99
	#Global.log_text += "\nvelocity.x: %f" % state.linear_velocity.x
	#Global.log_text += "\nvelocity.z: %f" % state.linear_velocity.z
	# TODO make it smooth intead of step
	if state.linear_velocity.length() > 1.0:
		var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
		var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
		var side_component: Vector3 = state.linear_velocity - forward_component
		var side_drag := 0.99
		state.linear_velocity = (side_component * side_drag) + forward_component + current
	else:
		state.linear_velocity += current

# TODO duplicated in boat_class.gd
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	handle_contacts(state)
	state.angular_velocity *= 0.999
	#if grabbing_state == GRABBING.YES:
	#	state.linear_velocity *= 0.99
	
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	#var backward_direction := (transform.basis * Vector3.BACK).normalized()
	#prints(forward_direction, backward_direction)
	# Gets only the energy going forward and backwards
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	#var backward_component: Vector3 = backward_direction * state.linear_velocity.dot(backward_direction)
	#prints(forward_component, backward_component)
	# Gets only the energy not going forward
	var side_component: Vector3 = state.linear_velocity - forward_component
	# Transfers the energy not going forward to going forward
	var transferred_energy: Vector3 = forward_direction * side_component.length()
	var side_drag := 0.99 # TODO depends on velocity
	var calculated_velocity := Vector3.ZERO
	calculated_velocity += side_component * side_drag
	calculated_velocity += forward_component
	calculated_velocity += transferred_energy * (1.0 - side_drag)
	calculated_velocity += current
	state.linear_velocity = calculated_velocity

func handle_contacts(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		var collision_impulse:float = state.get_contact_impulse(0).length()
		if collision_impulse > 0.5:
			#prints("collision", collision_impulse)
			%CollisionAudio.global_position = state.get_contact_collider_position(0)
			%CollisionAudio.volume_db = collision_impulse * 50
			%CollisionAudio.play(0.03)
		var body = state.get_contact_collider_object(0)
		if body.has_meta("grabbable"):
			if grabbing_state == GRABBING.WANTS_TO:
				grabbing_object = body
				grabbing_position.global_position = body.global_position
				grabbing_object_position = body.to_local(state.get_contact_collider_position(0))
				grabbing_state = GRABBING.YES
				#$GrabJoint3D.set_node_b(body.get_path())
				var vector_to_body = to_local(body.global_position)
				body.global_position = to_global(vector_to_body*1.2)
				#set_collision_mask_value(3, false)
				#body.set_collision_mask_value(1, false)
				print("GRAB")
			if grabbing_state == GRABBING.YES and grabbing_object == body:
				grabbing_position.global_position = body.global_position

func get_current() -> void:
	# TODO
	return
	current_direction = Vector3.FORWARD
	current_speed = 0.2
	var world_definition = Global.main_scene.dk_world.world_definition
	var min_dist = null
	var min_rotation: Vector3
	var min_scale: Vector3
	for s in world_definition:
		for c in world_definition[s].current:
			var dist := position.distance_squared_to(array_to_vector3(c.position))
			if min_dist == null:
				min_dist = dist
				min_rotation = array_to_vector3(c.rotation)
				min_scale = array_to_vector3(c.scale)
			if dist < min_dist:
				min_dist = dist
				min_rotation = array_to_vector3(c.rotation)
				min_scale = array_to_vector3(c.scale)
	current_direction = Vector3.FORWARD.rotated(Vector3.UP, min_rotation.y)
	current_speed = min_scale.length() * 10
	if min_dist > 10:
		current_speed = 0.0

func array_to_vector3(array: Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])

func array_to_quaternion(array: Array) -> Quaternion:
	return Quaternion(array[0], array[1], array[2], array[3])

func _on_interaction_area_area_entered(area: Area3D) -> void:
	if area.has_meta("oil_spill"):
		temp_speed = 10.0
		temp_time = 3.0
	elif area.has_meta("strength"):
		area.free()
		strength += 1

func set_damage():
	if damage_timer > 0: return
	damage += 1.0
	damage_timer = 1.0
	#var tween := create_tween()
	#tween.tween_callback(Global.main_scene.set_datamosh.bind(true))
	#tween.tween_property(%DamageIndicator, "scale", Vector3.ZERO, 0.1)
	#tween.tween_property(%DamageIndicator, "scale", Vector3.ONE, 0.1)
	#tween.tween_property(%DamageIndicator, "scale", Vector3.ZERO, 0.1)
	#tween.tween_callback(Global.main_scene.set_datamosh.bind(false))
	if damage > max_damage:
		get_tree().quit()

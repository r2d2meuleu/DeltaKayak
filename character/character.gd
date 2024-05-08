extends RigidBody3D

@onready var target_box = $CSGBox3D
@onready var pepa: Node3D = $pepa

var soft_camera_rotation: float
#var target_position: Vector3 = Vector3.ZERO
var speed := 0.0
var torque := 0.0

var last_rotation := 0.0
#var derivative := 0.0
var target_direction := 0.0

#TODO kayak points backwards

func _ready():
	#position = Vector3(-31.8, 0, -5)
	#position = Vector3(34.7, 0, -5)
	last_rotation = rotation.y
	Global.character = self
	pepa.get_node("AnimationPlayer").play("Sitting")

func _process(delta: float) -> void:
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var movement_direction:Vector2 = input_dir * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	var ration:float = 0.99-(0.1*delta)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	
	var local_target_position := movement_direction.rotated(-soft_camera_rotation) * 100.0
	target_box.global_position = position + Vector3(local_target_position.x, 0.0, local_target_position.y)
	
	# TODO rotation target should exists
	# even if the speed is 0.0
	# TODO the kayak points backwards
	var target_position_with_rotation := local_target_position.rotated(rotation.y)
	#if input_dir.length() > 0:
	var global_target_rotation := -Vector2.UP.angle_to(target_position_with_rotation)
	#var global_target_rotation := -Vector2.UP.angle_to(local_target_position)
	#print(target_position_with_rotation.x)
	#Global.log_text += "\ntarget_position_with_rotation.x: %f" % (target_position_with_rotation.x)
	#if target_position_with_rotation.x < 0:
	#	global_target_rotation *= -1
	target_direction = global_target_rotation
	
	Global.log_text += "\ntarget_direction: %f" % target_direction
	Global.log_text += "\nrotation.y: %f" % (rotation.y)
	
	speed = -max(0, -target_position_with_rotation.y) * delta * 50.0
	#var error := target_direction - rotation.y
	var error := target_direction
	Global.log_text += "\nerror: %f" % error
	Global.log_text += "\nproportional: %f" % get_proportional(error)
	Global.log_text += "\nintegral: %f" % get_integral(error)
	Global.log_text += "\nderivative: %f" % get_derivative(error)
	torque = 0.0
	if input_dir.length() > 0:
		torque += get_proportional(error) * delta
		torque += get_integral(error) * delta
		torque += get_derivative(error) * delta
	Global.log_text += "\ntorque: %f" % torque
	#print(torque)
	#torque = 0
	#speed = 0
	last_rotation = rotation.y

# PID control
func get_proportional(error) -> float:
	# Minimiza error
	# Suma
	var proportional = error
	proportional *= 10.0
	return proportional

func get_integral(_error) -> float:
	# Perturvaciones externas (viento). Cámara?
	# Compensa
	var integral = angular_velocity.y
	return integral

func get_derivative(error) -> float:
	# Velocidad del cambio de error
	# Resta
	# derivative += error
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		print(last_rotation)
		print(rotation.y)
		prints("LOOP", derivative)
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
		prints("NEW", derivative)
	
	return derivative*1000.0
#

func _physics_process(_delta: float):
	apply_torque(Vector3(0, torque, 0))
	#prints(speed, torque)
	go_forward(speed)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.BACK).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces(state):
	if true:#paddle_status !=0 and holding:
		state.linear_velocity *= 0.99
		state.angular_velocity *= 0.999
	else:
		state.linear_velocity *= 0.999
		state.angular_velocity *= 0.99
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	if forward_component.length() > 0:
		forward_component *= state.linear_velocity.length() / forward_component.length()
	state.linear_velocity = forward_component

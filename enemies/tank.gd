extends AttackingComponent

var SPEED = 140
var LOOK_PLAYER = false
var DAMAGE = 1

func _ready():
	POWER = 5
	HEALTH = 1

	$tank/AnimationPlayer.play("TankIdle")

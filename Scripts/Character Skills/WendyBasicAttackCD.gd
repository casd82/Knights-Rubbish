extends KinematicBody2D

const SPEED_X = 600
const SPEED_Y = 400
const GRAVITY = 600

const SLIDE_RATIO = 0.2

const ROTATION_SPEED = 2 * PI

const SCALE_INIT = 0.2
const SCALE_FINAL = 1.0
const SCALE_DURATION = 1.0

const DAMAGE_MIN = 45
const DAMAGE_MAX = 60

const STUN_DURATION = 1.0

const SLOW_MULTIPLIER = 0.7
const SLOW_DURATION = 1.5

const KNOCK_BACK_VEL_X = 450
const KNOCK_BACK_VEL_Y = 50
const KNOCK_BACK_FADE_RATE = 900

const LIFE_TIME = 4.3

enum { STUN, SLOW, KNOCK_BACK }

var textures = [
	preload("res://Graphics/Characters/Wendy Vista/Stun CD.png"),
	preload("res://Graphics/Characters/Wendy Vista/Slow CD.png"),
	preload("res://Graphics/Characters/Wendy Vista/Knockback CD.png")
]

const explosion_colors = [
	Color(1.0, 1.0, 0.0),
	Color(0.0, 195.0 / 255.0, 1.0),
	Color(208.0 / 255.0, 188.0 / 255.0, 152.0 / 255.0)
]

var type

var timestamp = 0.0

var side
var attack_modifier
var knock_back_modifier
var size

var hit = false

var rng = preload("res://Scripts/Utils/RandomNumberGenerator.gd")

onready var movement_pattern = preload("res://Scripts/Movements/StraightLineMovement.gd").new(side * SPEED_X, 0)
onready var gravity_movement = preload("res://Scripts/Movements/GravityMovement.gd").new(self, GRAVITY)
onready var scale_tween = $ScaleTween
onready var sprite = $Sprite

func initialize(side, attack_modifier, knock_back_modifier, size):
	self.side = side
	self.attack_modifier = attack_modifier
	self.knock_back_modifier = knock_back_modifier
	self.size = size

func _ready():
	scale = scale * SCALE_INIT * size

	gravity_movement.dy = -SPEED_Y

	type = rng.randi_range(0, textures.size())
	sprite.texture = textures[type]
	$Particles2D.modulate = explosion_colors[type]

	scale_tween.interpolate_method(self, "scale_tween_step", SCALE_INIT, SCALE_FINAL, SCALE_DURATION, Tween.TRANS_LINEAR, Tween.EASE_IN)
	scale_tween.start()

func scale_tween_step(progress):
	scale = Vector2(1, 1) * progress * size

func _process(delta):
	gravity_movement.move(delta)
	var collision = move_and_collide(movement_pattern.movement(delta))

	# Destroy when touches a platform.
	if !hit && (gravity_movement.is_landed || collision != null):
		gravity_movement.dy = 0
		gravity_movement.gravity = 0
		movement_pattern.dx *= SLIDE_RATIO

		explode()

	sprite.rotation += delta * ROTATION_SPEED * side

	timestamp += delta
	if timestamp >= LIFE_TIME:
	 	queue_free()

func on_enemy_hit(area):
	if !hit && area.is_in_group("enemy"):
		var enemy = area.get_node("../..")

		match type:
			STUN:
				enemy.stunned(STUN_DURATION)
			SLOW:
				enemy.slowed(SLOW_MULTIPLIER, SLOW_DURATION)
			KNOCK_BACK:
				enemy.knocked_back(side * KNOCK_BACK_VEL_X * knock_back_modifier, -KNOCK_BACK_VEL_Y * knock_back_modifier, KNOCK_BACK_FADE_RATE * knock_back_modifier)

		enemy.damaged(int(rng.randi_range(DAMAGE_MIN, DAMAGE_MAX) * attack_modifier))
		
		explode()

func explode():
	hit = true
	$AnimationPlayer.play("Explode")
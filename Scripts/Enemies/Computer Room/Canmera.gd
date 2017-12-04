extends Node2D

# Canmera AI
# 1. Aim to a random angle.
# 2. Countdown.
# 3. Shoot Canmera missle.
# 4. Repeat 1.
# ===
# When hurt or stunned, go to 1.

enum { NONE, AIM, COUNTDOWN, SHOOT }

const MAX_HEALTH = 250

const ACTIVATE_RANGE = 3000

# Rotation.
const ROTATE_SPEED_MIN = 30
const ROTATE_SPEED_MAX = 50
const AIM_ANGLE_MAX = 20.0
const AIM_ANGLE_MIN = -20.0

# Animation.
const DIE_ANIMATION_DURATION = 0.5
const COUNTDOWN_ANIMATION_DURATION = 3.0
const SHOOT_DURATION = 0.5

var status_timer = null
var curr_target_angle = null
var curr_speed = null

onready var body_node = get_node("Animation/Stand Remote Transform/Body")

# Missle.
var missle = preload("res://Scenes/Enemies/Computer Room/Canmera Missle.tscn")
onready var missle_spawn_pos = body_node.get_node("Missle Shoot Pos")
onready var spawn_node = get_node("..")

onready var ec = preload("res://Scripts/Enemies/Common/EnemyCommon.gd").new(self)

func activate():
	set_process(true)
	ec.change_status(AIM)
	get_node("Animation/Damage Area").add_to_group("enemy_collider")

func _process(delta):
	if ec.not_hurt_dying_stunned():
		if ec.status == AIM:
			aim_and_rotate(delta)
		elif ec.status == COUNTDOWN:
			start_countdown()
		elif ec.status == SHOOT:
			shoot_missle()

func change_status(to_status):
	ec.change_status(to_status)

func aim_and_rotate(delta):
	ec.play_animation("Still")
	if curr_target_angle == null:
		# New aim.
		curr_target_angle = deg2rad(ec.rng.randf_range(AIM_ANGLE_MIN, AIM_ANGLE_MAX))
		var dir = curr_target_angle - body_node.get_rot()
		curr_speed = dir * deg2rad(ec.rng.randf_range(ROTATE_SPEED_MIN, ROTATE_SPEED_MAX))
	
	if aim_ended():
		curr_target_angle = null
		curr_speed = null
		ec.change_status(COUNTDOWN)
	else:
		body_node.rotate(curr_speed * delta)

func aim_ended():
	var dir = sign(curr_speed)
	return dir == 1 && body_node.get_rot() >= curr_target_angle || dir == -1 && body_node.get_rot() <= curr_target_angle

func start_countdown():
	ec.play_animation("Count Down")
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(COUNTDOWN_ANIMATION_DURATION, self, "change_status", SHOOT)

func shoot_missle():
	ec.change_status(NONE)
	spawn_missle()
	status_timer = ec.cd_timer.new(SHOOT_DURATION, self, "change_status", AIM)

func spawn_missle():
	var rotate_radian = body_node.get_rot()
	var dx = -cos(rotate_radian)
	var dy = sin(rotate_radian)

	var new_missle = missle.instance()
	new_missle.set_global_pos(missle_spawn_pos.get_global_pos())
	new_missle.initialize(dx, dy)
	spawn_node.add_child(new_missle)

func damaged(val):
	ec.change_status(AIM)
	ec.damaged(val)

func resume_from_damaged():
	ec.resume_from_damaged()

func stunned(duration):
	ec.change_status(AIM)
	ec.stunned(duration)

func resume_from_stunned():
	ec.resume_from_stunned()

func damaged_over_time(time_per_tick, total_ticks, damage_per_tick):
	ec.damaged_over_time(time_per_tick, total_ticks, damage_per_tick)

func healed(val):
	ec.healed(val)

func healed_over_time(time_per_tick, total_ticks, heal_per_tick):
	ec.healed_over_time(time_per_tick, total_ticks, heal_per_tick)

func die():
	ec.die()
	status_timer = ec.cd_timer.new(DIE_ANIMATION_DURATION, self, "queue_free")
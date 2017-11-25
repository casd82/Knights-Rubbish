extends Node2D

# Harddies AI:
# 1. Flies through the sky for a certain duration.
# 2. Turn to the side which the nearest character is facing.
# 3. Toss two rings to -150px and +150px or the farthest character.
# 4. Turn to stone and falls on the ground. Gain tons of HP.
# 5. Knocks back and damage characters on the way of falling.
# 6. Become impassible when landed on ground.
# ===
# Don't play hurt animation when tossing ring or stoned.
# Can't be stunned when FALLING, LANDED. Otherwise, go to FLY after stunned.

enum { NONE, FLY, TOSS_ANIM, TOSS, FALLING, LANDED }

const MAX_HEALTH = 200
const STONED_MAX_HEALTH = 800

const ACTIVATE_RANGE = 2000

# Attack.
const RING_SPAWN_OFFSET = 150
const DAMAGE = 50
const KNOCK_BACK_VEL_X = 1000
const KNOCK_BACK_FADE_RATE = 1500
const KNOCK_BACK_VEL_Y= 0

# Movement.
const SPEED_X = 200
const GRAVITY = 600
const RANDOM_MOVEMENT_MIN_STEPS = 3
const RANDOM_MOVEMENT_MAX_STEPS = 6
const RANDOM_MOVEMENT_MIN_TIME_PER_STEP = 0.5
const RANDOM_MOVEMENT_MAX_TIME_PER_STEP = 2

# Animation.
const DIE_ANIMATION_DURATION = 0.8
const STONED_DIE_ANIMATION_DURATION = 0.5
const TOSS_ANIM_DURATION = 2.0
const STONED_ANIM_DURATION = 1.0

const PLATFORM_COLLISION_LAYER = 2

var attack_target = null
var status_timer = null
var curr_rand_movement = null
var facing = -1

# Ring spawning.
var ring = preload("res://Scenes/Enemies/Computer Room/Harddies Ring.tscn")
onready var ring_spawn_pos = get_node("Animation/Ring Spawn Pos")
onready var spawn_node = get_node("..")

onready var impassible_platform = get_node("Platform")

onready var ec = preload("res://Scripts/Enemies/Common/EnemyCommon.gd").new(self)
onready var movement_type = ec.straight_line_movement.new(facing * SPEED_X, 0)
onready var gravity_movement = ec.gravity_movement.new(self, GRAVITY)

func activate():
	set_process(true)
	ec.change_status(FLY)
	get_node("Animation/Damage Area").add_to_group("enemy_collider")

func _process(delta):
	if ec.not_hurt_dying_stunned():
		if ec.status == FLY:
			apply_random_movement(delta)
		elif ec.status == TOSS_ANIM:
			play_toss_animation()
		elif ec.status == TOSS:
			toss_ring()
		elif ec.status == FALLING:
			fall_and_detect_landing(delta)
		elif ec.status == LANDED:
			landed()

func change_status(to_status):
	ec.change_status(to_status)

func apply_random_movement(delta):
	ec.play_animation("Fly")
	if curr_rand_movement == null:
		# New random movement.
		curr_rand_movement = ec.random_movement.new(SPEED_X, 0, true, RANDOM_MOVEMENT_MIN_STEPS, RANDOM_MOVEMENT_MAX_STEPS, RANDOM_MOVEMENT_MIN_TIME_PER_STEP, RANDOM_MOVEMENT_MAX_TIME_PER_STEP)

	if !curr_rand_movement.movement_ended():
		# Existing random movement.
		var final_pos = curr_rand_movement.movement(get_global_pos(), delta)
		move_to(final_pos)
	else:
		# Random movement ended.
		detect_and_face_the_farthest_target()
		curr_rand_movement = null
		ec.change_status(TOSS_ANIM)

func detect_and_face_the_farthest_target():
	attack_target = ec.target_detect.get_farthest(self, ec.char_average_pos.characters)
	facing = -1 if attack_target.get_global_pos().x < get_global_pos().x else 1
	ec.turn_sprites_x(facing)

func play_toss_animation():
	ec.play_animation("Toss Ring")
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(TOSS_ANIM_DURATION, self, "change_status", TOSS)

func toss_ring():
	ec.change_status(NONE)
	spawn_two_rings()
	status_timer = ec.cd_timer.new(STONED_ANIM_DURATION, self, "change_status", FALLING)

func spawn_two_rings():
	var start_pos = get_global_pos()
	var end_pos = attack_target.get_global_pos()

	var left_ring = ring.instance()
	left_ring.set_global_pos(ring_spawn_pos.get_global_pos())
	left_ring.initialize(start_pos, Vector2(end_pos.x - RING_SPAWN_OFFSET, end_pos.y))

	var right_ring = ring.instance()
	right_ring.set_global_pos(ring_spawn_pos.get_global_pos())
	right_ring.initialize(start_pos, Vector2(end_pos.x + RING_SPAWN_OFFSET, end_pos.y))

	spawn_node.add_child(left_ring)
	spawn_node.add_child(right_ring)

func fall_and_detect_landing(delta):
	ec.play_animation("Stiff")

	if ec.health_system.full_health != STONED_MAX_HEALTH:
		ec.change_and_refill_full_health(STONED_MAX_HEALTH)

	var movement_of_gravity = gravity_movement.movement(get_global_pos(), delta)
	move_to(movement_of_gravity)

	if gravity_movement.is_landed():
		change_status(LANDED)

func on_attack_hit(area):
	if ec.status == FALLING && area.is_in_group("player_collider"):
		var character = area.get_node("..")
		character.damaged(DAMAGE)
		
		var dir = -1 if character.get_global_pos().x < get_global_pos().x else 1
		character.knocked_back(dir * KNOCK_BACK_VEL_X, KNOCK_BACK_VEL_Y, KNOCK_BACK_FADE_RATE)

func landed():
	ec.play_animation("Stiff")
	impassible_platform.set_layer_mask(PLATFORM_COLLISION_LAYER)

func damaged(val):
	var play_anim = ec.animator.get_current_animation() != "Toss Ring" && ec.status != FALLING && ec.status != LANDED
	ec.damaged(val, play_anim)

func resume_from_damaged():
	ec.resume_from_damaged()

func damaged_over_time(time_per_tick, total_ticks, damage_per_tick):
	ec.damaged_over_time(time_per_tick, total_ticks, damage_per_tick)

func healed(val):
	ec.healed(val)

func healed_over_time(time_per_tick, total_ticks, heal_per_tick):
	ec.healed_over_time(time_per_tick, total_ticks, heal_per_tick)

func stunned(duration):
	if ec.status == FALLING || ec.status == LANDED:
		ec.display_immune_text()
	else:
		ec.change_status(FLY)
		ec.stunned(duration)

func resume_from_stunned():
	ec.resume_from_stunned()

func die():
	get_node("Animation/Damage Area").remove_from_group("enemy_collider")
	
	var animation_key
	var animation_duration

	if ec.status == FALLING || ec.status == LANDED:
		animation_key = "Stiff Die"
		animation_duration = STONED_DIE_ANIMATION_DURATION
	else:
		animation_key = "Die"
		animation_duration = DIE_ANIMATION_DURATION

	change_status(NONE)
	ec.play_animation_and_diable_others(animation_key)
	status_timer = ec.cd_timer.new(animation_duration, self, "queue_free")
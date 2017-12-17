extends KinematicBody2D

# Eelo Puncher AI:
# 1. Roam randomly.
# 2. If a character is in range, dash and punch!!
# 3. Run away from the player.
# 4. If health < x%, move to healing fountain to heal until health > y%.
# 5. Go to 1.
# ===
# Don't play hurt animation while punching.
# When stunned, go to 1.

enum { NONE, ROAM, DASH, PUNCH, INIT_FLEE, FLEE, SEEK_HEAL, HEALING }

export(NodePath) var fountain_path

const MAX_HEALTH = 150

const ACTIVATE_RANGE = 1000

# Attack.
const ATTACK_RANGE_X = 125
const ATTACK_RANGE_Y = 200
const DAMAGE = 30
const KNOCK_BACK_VEL_X = 600
const KNOCK_BACK_VEL_Y = 0
const KNOCK_BACK_FADE_RATE = 1000

# Movement.
const SPEED_X = 300
const GRAVITY = 600
const DASH_RANGE = 700
const DASH_SPEED = 600
const FLEE_SPEED = 450
const FLEE_MIN_DURATION = 0.6
const FLEE_MAX_DURATION = 1.2
const RANDOM_MOVEMENT_STEPS = 5
const RANDOM_MOVEMENT_MIN_TIME_PER_STEP = 1.0
const RANDOM_MOVEMENT_MAX_TIME_PER_STEP = 2.0

const SEEK_HEAL_PERCENTAGE = 0.4
const HEAL_TO_PERCENTAGE = 0.8
const HEAL_RANGE = 175

# Animation.
const DIE_ANIMATION_DURATION = 0.5
const PUNCH_ANIMATION_DURATION = 2.4

var status_timer = null
var curr_rand_movement = null
var attack_target = null

onready var ec = preload("res://Scripts/Enemies/Common/EnemyCommon.gd").new(self)
onready var gravity_movement = ec.gravity_movement.new(self, GRAVITY)
onready var horizontal_movement = ec.straight_line_movement.new(0, 0)

onready var heal_pos = get_node(fountain_path)

func activate():
	set_process(true)
	ec.change_status(ROAM)
	get_node("Animation/Damage Area").add_to_group("enemy_collider")

func _process(delta):
	if ec.not_hurt_dying_stunned():
		if ec.status == ROAM:
			roam_randomly(delta)
		elif ec.status == DASH:
			dash_to_target(delta)
		elif ec.status == PUNCH:
			punch()
		elif ec.status == INIT_FLEE:
			init_flee()
		elif ec.status == FLEE:
			flee(delta)
		elif ec.status == SEEK_HEAL:
			seek_heal(delta)
		elif ec.status == HEALING:
			check_health()

	apply_gravity(delta)

func change_status(to_status):
	ec.change_status(to_status)

func apply_gravity(delta):
	move_to(gravity_movement.movement(get_global_pos(), delta))

func roam_randomly(delta):
	ec.play_animation("Walk")
	if curr_rand_movement == null:
		curr_rand_movement = ec.random_movement.new(SPEED_X, 0, true, RANDOM_MOVEMENT_STEPS, RANDOM_MOVEMENT_STEPS, RANDOM_MOVEMENT_MIN_TIME_PER_STEP, RANDOM_MOVEMENT_MAX_TIME_PER_STEP)

	if curr_rand_movement.movement_ended():
		curr_rand_movement = null
	else:
		move_to(curr_rand_movement.movement(get_global_pos(), delta))

	# Check if a character is in dash range.
	for character in ec.char_average_pos.characters:
		if abs(character.get_global_pos().x - get_global_pos().x) <= DASH_RANGE:
			attack_target = character
			ec.change_status(DASH)
			curr_rand_movement = null
			return

func dash_to_target(delta):
	ec.play_animation("Walk")
	
	var dir = sign(attack_target.get_global_pos().x - get_global_pos().x)
	horizontal_movement.dx = dir * DASH_SPEED
	move_to(horizontal_movement.movement(get_global_pos(), delta))

	# Check if in attack range.
	if abs(attack_target.get_global_pos().x - get_global_pos().x) <= ATTACK_RANGE_X && abs(attack_target.get_global_pos().y - get_global_pos().y) <= ATTACK_RANGE_Y:
		ec.change_status(PUNCH)

func punch():
	ec.play_animation("Punch")
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(PUNCH_ANIMATION_DURATION, self, "change_status", INIT_FLEE)

func on_left_attack_hit(area):
	if area.is_in_group("player_collider"):
		apply_attack(area.get_node(".."), -1)

func on_right_attack_hit(area):
	if area.is_in_group("player_collider"):
		apply_attack(area.get_node(".."), 1)

func apply_attack(character, dir):
	character.damaged(DAMAGE)
	character.knocked_back(dir * KNOCK_BACK_VEL_X, KNOCK_BACK_VEL_Y, KNOCK_BACK_FADE_RATE)

func init_flee():
	ec.change_status(FLEE)

	var to_status = ROAM if get_health_percentage() > SEEK_HEAL_PERCENTAGE else SEEK_HEAL
	status_timer = ec.cd_timer.new(ec.rng.randf_range(FLEE_MIN_DURATION, FLEE_MAX_DURATION), self, "change_status", to_status)

func flee(delta):
	ec.play_animation("Walk")

	var dir = sign(get_global_pos().x - attack_target.get_global_pos().x)
	horizontal_movement.dx = dir * FLEE_SPEED
	move_to(horizontal_movement.movement(get_global_pos(), delta))

func get_health_percentage():
	return float(ec.health_system.health) / float(MAX_HEALTH)

func seek_heal(delta):
	ec.play_animation("Walk")

	var dir = sign(heal_pos.get_global_pos().x - get_global_pos().x)
	horizontal_movement.dx = dir * FLEE_SPEED
	move_to(horizontal_movement.movement(get_global_pos(), delta))

	if abs(get_global_pos().x - heal_pos.get_global_pos().x) <= HEAL_RANGE:
		ec.change_status(HEALING)

func check_health():
	ec.play_animation("Healing")
	
	if get_health_percentage() >= HEAL_TO_PERCENTAGE:
		ec.change_status(ROAM)

func damaged(val):
	ec.damaged(val, ec.animator.get_current_animation() != "Punch")
	
func resume_from_damaged():
	ec.resume_from_damaged()

func stunned(duration):
	ec.change_status(ROAM)
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
extends Node2D

# Amazlet AI:
# 1. Show face. Speaks "I may be paranoid, but not an android."
# 2. 50% go to 3, 50% go to 5.
# 3. Spawns 1-4 Paranoid Android mob depending on its current HP.
# 4. Repeat 1.
# 5. Throws 2-5 HTC phone frizbee depending on its current HP.
# 6. Repeat 1.
# ===
# Only play hurt animation if it is in 1.
# Cannot be stunned.

enum { NONE, FACE, ANDROID_ANIM, SPAWN_ANDROID, FRIZBEE_ANIM, SPAWN_FRIZBEE, THROW_FRIZBEE, RESUME_FACE }

const MAX_HEALTH = 1000
const ACTIVATE_RANGE = 1000

# Attack.
const TOUCH_DAMAGE = 50
const KNOCK_BACK_VEL_X = 1000
const KNOCK_BACK_VEL_Y = 1000
const KNOCK_BACK_FADE_RATE = 1000
const ANDROID_MIN_SPAWN_COUNT = 1
const ANDROID_MAX_SPAWN_COUNT = 4
const FRIZBEE_MIN_SPAWN_COUNT = 2
const FRIZBEE_MAX_SPAWN_COUNT = 5

# Animation.
const FACE_ANIM_MAX_DURATION = 8
const FACE_ANIM_MIN_DURATION = 4
const ANDROID_ANIM_DURATION = 3.5
const ANDROID_SPAWNING_DURATION = 0.5
const FRIZBEE_ANIM_DURATION = 1.0
const FRIZBEE_SPAWNING_DURATION = 4.5
const FRIZBEE_THROWING_DURATION = 0.25
const RESUME_FACE_ANIM_DURATION = 0.5

var face_anim_timestamp = null
var face_anim_duration = null
var status_timer = null

var android_spawn_count
var frizbees = []

var paranoid_android = preload("res://Scenes/Enemies/Computer Room/Paranoid Android.tscn")
var frizbee = preload("res://Scenes/Enemies/Computer Room/Amazlet Frizbee.tscn")

onready var spawn_node = get_node("..")
onready var android_spawn_pos = get_node("Android Spawn Pos")
onready var frizbee_spawn_pos = get_node("Frizbee Spawn Pos")

onready var ec = preload("res://Scripts/Enemies/Common/EnemyCommon.gd").new(self)

func activate():
	set_process(true)

	ec.change_status(FACE)

	get_node("Animation/Damage Area").add_to_group("enemy_collider")

func _process(delta):
	if ec.not_hurt_dying_stunned():
		if ec.status == FACE:
			show_face_and_play_voice()
		elif ec.status == ANDROID_ANIM:
			play_android_anim()
		elif ec.status == SPAWN_ANDROID:
			spawn_android()
		elif ec.status == FRIZBEE_ANIM:
			play_frizbee_anim()
		elif ec.status == SPAWN_FRIZBEE:
			spawn_frizbee()
		elif ec.status == THROW_FRIZBEE:
			throw_frizbee()
		elif ec.status == RESUME_FACE:
			resume_face()

func change_status(to_status):
	ec.change_status(to_status)

func show_face_and_play_voice():
	ec.play_animation("Face")

	if face_anim_timestamp == null:
		# TODO: Play "I may be paranoid..."
		face_anim_timestamp = OS.get_unix_time()
		face_anim_duration = ec.rng.randi_range(FACE_ANIM_MIN_DURATION, FACE_ANIM_MAX_DURATION + 1)
	elif OS.get_unix_time() - face_anim_timestamp >= face_anim_duration:
		# Goto either android or frizbee animation.
		if ec.rng.randsign() == 1:
			ec.change_status(ANDROID_ANIM)
		else:
			ec.change_status(FRIZBEE_ANIM)
		
		# Reset timestamp.
		face_anim_timestamp = null
		face_anim_duration = null

func play_android_anim():
	ec.play_animation("Spawn Android")
	ec.change_status(NONE)
	android_spawn_count = spawn_num_according_to_health(ANDROID_MIN_SPAWN_COUNT, ANDROID_MAX_SPAWN_COUNT)
	status_timer = ec.cd_timer.new(ANDROID_ANIM_DURATION, self, "change_status", SPAWN_ANDROID)

func spawn_android():
	# Spawn android.
	var new_android = paranoid_android.instance()
	spawn_node.add_child(new_android)
	new_android.set_global_pos(android_spawn_pos.get_global_pos())

	# Keep on spawning or go back to face.
	ec.change_status(NONE)
	android_spawn_count -= 1
	var to_status = RESUME_FACE if android_spawn_count == 0 else SPAWN_ANDROID
	status_timer = ec.cd_timer.new(ANDROID_SPAWNING_DURATION, self, "change_status", to_status)

func play_frizbee_anim():
	ec.play_animation("Throw Frizbee")
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(FRIZBEE_ANIM_DURATION, self, "change_status", SPAWN_FRIZBEE)

func spawn_frizbee():
	var count = spawn_num_according_to_health(FRIZBEE_MIN_SPAWN_COUNT, FRIZBEE_MAX_SPAWN_COUNT)
	for i in range(count):
		var new_frizbee = frizbee.instance()
		spawn_node.add_child(new_frizbee)
		new_frizbee.set_global_pos(frizbee_spawn_pos.get_global_pos())
		frizbees.push_back(new_frizbee)

	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(FRIZBEE_SPAWNING_DURATION, self, "change_status", THROW_FRIZBEE)

func throw_frizbee():
	frizbees.back().start_travel()
	frizbees.pop_back()

	var to_status = RESUME_FACE if frizbees.size() == 0 else THROW_FRIZBEE
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(FRIZBEE_THROWING_DURATION, self, "change_status", to_status)

func resume_face():
	ec.play_animation("Face Coming Back")
	ec.change_status(NONE)
	status_timer = ec.cd_timer.new(RESUME_FACE_ANIM_DURATION, self, "change_status", FACE)

func spawn_num_according_to_health(min_count, max_count):
	return int(lerp(float(min_count), float(max_count), 1.0 - (float(ec.health_system.health) / float(MAX_HEALTH))))

func touch_attack_hit(area):
	if area.is_in_group("player_collider"):
		var character = area.get_node("..")
		var knock_back_dir = -1 if character.get_global_pos().x < get_global_pos().x else 1
		character.knocked_back(knock_back_dir * KNOCK_BACK_VEL_X, KNOCK_BACK_VEL_Y, KNOCK_BACK_FADE_RATE)
		character.damaged(TOUCH_DAMAGE)

func damaged(val):
	# Only play hurt animation in FACE.
	ec.damaged(val, ec.status == FACE)

func resume_from_damaged():
	ec.resume_from_damaged()

func damaged_over_time(time_per_tick, total_ticks, damage_per_tick):
	ec.damaged_over_time(time_per_tick, total_ticks, damage_per_tick)

func die():
	ec.die()

	# Disable touch damage.
	get_node("Animation/Attack Area").queue_free()

	# Remove the frizbees (if any).
	for f in frizbees:
		f.queue_free()

func stunned(duration):
	ec.display_immune_text()

func healed(val):
	ec.healed(val)

func healed_over_time(time_per_tick, total_ticks, heal_per_tick):
	ec.healed_over_time(time_per_tick, total_ticks, heal_per_tick)
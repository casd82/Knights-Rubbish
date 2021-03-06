var physics_body
var gravity
var bounciness

var velocity
var bounced = false

func _init(physics_body, velocity, gravity, bounciness):
    self.physics_body = physics_body
    self.velocity = velocity
    self.gravity = gravity
    self.bounciness = bounciness

func move(delta):
    var collision = physics_body.move_and_collide(velocity * delta)

    if collision != null:
        velocity = velocity.bounce(collision.normal) * bounciness
        bounced = true
    else:
        velocity.y += gravity * delta
        bounced = false
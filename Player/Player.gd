extends CharacterBody3D

# input
@export var mouse_sensitivity = 0.001

# camera
@onready var zoom = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@export var LOWEST_ANGLE = deg_to_rad(-89)
@export var HIGHEST_ANGLE = deg_to_rad(89)


class Controls:
    static func is_jump_pressed() -> bool:
        return Input.is_action_pressed("jump")

    static func is_sprint_pressed() -> bool:
        return Input.is_action_pressed("sprint")

    static func get_movement_input() -> Vector2:
        return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    
    static func get_intended_velocity(player) -> Vector3:
        var input_vector = get_movement_input().normalized()
        return player.transform.basis * Vector3(input_vector.x, 0, input_vector.y)



class State:
    var player
    var next_state : State
    
    
    func init(newPlayer) -> void:
        player = newPlayer
        next_state = null
    
    func update() -> State:
        if next_state != null:
            self.exit()
            next_state.init(player)
            next_state.enter()
            return next_state
        return self
    
    func next(new_state : State) -> void:
        next_state = new_state
    
    # override
    func name() -> String:
        return "State"
    
    # override
    func enter() -> void:
        pass
    
    # override
    func exit() -> void:
        pass
    
    # override
    func physics_process(delta) -> void:
        pass
    
    # override
    func input(event) -> void:
        pass



class IdleState extends State:
    func name() -> String: return "Idle"
    # Duration (seconds) to de-accelerate to a stop
    @export var DEACCELERATION_SECONDS = 0.10

    func deaccelerate(delta):
        player.velocity.x = lerp(player.velocity.x, 0.0, delta / DEACCELERATION_SECONDS)
        player.velocity.z = lerp(player.velocity.z, 0.0, delta / DEACCELERATION_SECONDS)

    func physics_process(delta):
        if not player.is_on_floor():
            next_state = FallState.new()

        var intended_velocity = Controls.get_intended_velocity(player)
        if intended_velocity != Vector3.ZERO:
            next_state = WalkState.new()

        if Controls.is_jump_pressed():
            next_state = JumpState.new()

        deaccelerate(delta)



class WalkState extends State:
    func name() -> String: return "Walk"
    # Duration (seconds) to reach max acceleration
    @export var WALK_ACCELERATION_SECONDS = 0.3
    # Maximum velocity (meters per second) the player walks -- note: probably not meters per second,, too slow...
    @export var WALK_SPEED = 9

    func accelerate(intended_velocity, delta):
        player.velocity.x = lerp(player.velocity.x, intended_velocity.x, delta / WALK_ACCELERATION_SECONDS)
        player.velocity.z = lerp(player.velocity.z, intended_velocity.z, delta / WALK_ACCELERATION_SECONDS)

    func physics_process(delta):
        if not player.is_on_floor():
            next_state = FallState.new()

        var intended_velocity = Controls.get_intended_velocity(player) * WALK_SPEED

        if intended_velocity == Vector3.ZERO:
            next_state = IdleState.new()

        if Controls.is_sprint_pressed():
            next_state = SprintState.new()

        if Controls.is_jump_pressed():
            next_state = JumpState.new()

        accelerate(intended_velocity, delta)

        super(delta)



# TODO: stamina
class SprintState extends State:
    func name() -> String: return "Sprint"
    # Duration (seconds) to reach max acceleration
    @export var SPRINT_ACCELERATION_SECONDS = 0.4
    # Maximum velocity (meters per second) the player sprints
    @export var SPRINT_SPEED = 13
    
    # Amount of total stamina
    @export var MAX_STAMINA = 100.0
    # Rate of stamina drain per second
    @export var STAMINA_DRAIN_RATE = 10.0
    # Duration (seconds) before stamina begins recovery
    @export var STAMINA_RECOVERY_DURATION = 10.0
    # Rate of stamina recharge per second
    @export var STAMINA_RECHARGE_RATE = 5.0

    func accelerate(intended_velocity, delta):
        player.velocity.x = lerp(player.velocity.x, intended_velocity.x, delta / SPRINT_ACCELERATION_SECONDS)
        player.velocity.z = lerp(player.velocity.z, intended_velocity.z, delta / SPRINT_ACCELERATION_SECONDS)

    func physics_process(delta):
        if not player.is_on_floor():
            next_state = FallState.new()
        
        var intended_velocity = Controls.get_intended_velocity(player) * SPRINT_SPEED
        
        if intended_velocity == Vector3.ZERO:
            next_state = IdleState.new()
        
        # TODO: toggle?
        if not Controls.is_sprint_pressed():
            next_state = WalkState.new()
        
        if Controls.is_jump_pressed():
            next_state = JumpState.new()
        
        accelerate(intended_velocity, delta)
        
        super(delta)



class JumpState extends State:
    func name() -> String: return "Jump"
    # Duration (seconds) to reach jump apex (highest point)
    @export var JUMP_RISE_DURATION = 0.55
    # Gravity (meters per seconds)
    @export var GRAVITY = 9.8
    
    func enter():
        player.velocity.y = GRAVITY * JUMP_RISE_DURATION
        
    func physics_process(delta):
        player.velocity.y -= GRAVITY * delta
        if player.velocity.y < 0:
            next_state = FallState.new()



class FallState extends State:
    func name() -> String: return "Fall"
    # gravity
    @export var GRAVITY = 9.8
    # TODO: use this?
    @export var AIR_ACCELERATION = 2.0
    
    # Keep track of y velocity of previous frame (m/s)
    var last_velocity = 0.0
    
    # Keep track of maximum change in y velocity (m/s)
    var max_delta_v = 0.0
    
    func physics_process(delta):
        var current_delta_v = abs(player.velocity.y - last_velocity)
        if (current_delta_v > max_delta_v):
            max_delta_v = current_delta_v
        
        if player.is_on_floor():
            next_state = LandState.new()
            next_state.calculate_severity(max_delta_v)
            
        player.velocity.y -= GRAVITY * delta



class LandState extends IdleState:
    func name() -> String: return "Land"    
    # Duration (seconds) to recover from a landing
    @export var MAX_LANDING_RECOVERY_DURATION = 0.30
    
    var recovery_duration = 0.0
    
    func calculate_severity(deltaV):
#        print(deltaV)
        #TODO: fall damage
        #TODO: shudder effect
        pass
        
    
    func physics_process(delta):
        super.deaccelerate(delta)
        recovery_duration -= delta
        if (recovery_duration < 0):
            next_state = WalkState.new()



############# BEGIN THE MACHINE ###############
var current_state = State.new()
func _init():
    current_state.init(self)
    current_state.next(WalkState.new())


func _physics_process(delta) -> void:
    current_state = current_state.update()
    current_state.physics_process(delta)
#    print(current_state.name())
#    print(velocity)
    move_and_slide()
    
    
    if Input.is_action_pressed("zoom_out"):
        print('test')
        zoom.spring_length = clamp(lerp(zoom.spring_length, zoom.spring_length+1, delta), 0.0, 10.0)
    elif Input.is_action_pressed("zoom_in"):
        zoom.spring_length = clamp(lerp(zoom.spring_length, zoom.spring_length-1, delta), 0.0, 10.0)


func _unhandled_input(event) -> void:
    current_state.input(event)
    
    # camera
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        if event is InputEventMouseMotion:
            # rotate camera
            self.rotate_y(-event.relative.x * mouse_sensitivity)
            camera.rotation.x = clamp(camera.rotation.x - event.relative.y * mouse_sensitivity, LOWEST_ANGLE, HIGHEST_ANGLE)
            

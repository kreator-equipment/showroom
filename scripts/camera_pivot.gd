extends Node3D

@export var target_node: Node3D
@export var rotate_speed: float = 0.004

# Step adjustments for the spring arm length
@export var zoom_step: float = 2.0
@export var zoom_lerp_speed: float = 10.0

@export var min_zoom: float = 1.0
@export var max_zoom: float = 15.0

@export var min_pitch_degrees: float = -45.0
@export var max_pitch_degrees: float = 45.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var is_rotating: bool = false
var current_pitch: float = 0.0
var target_zoom: float = 8.0

func _ready() -> void:
	if target_node:
		global_position = target_node.global_position
	
	current_pitch = rotation.x
	
	# START ZOOMED OUT: Force initial trackers directly to the maximum zoom boundary
	target_zoom = max_zoom
	if spring_arm:
		spring_arm.spring_length = max_zoom
		
	# Initialize our target zoom to the initial spring length set in the editor
	if spring_arm:
		target_zoom = spring_arm.spring_length

func _process(delta: float) -> void:
	if spring_arm:
		# Linearly interpolate the spring length property safely
		spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, zoom_lerp_speed * delta)

func _input(event: InputEvent) -> void:
	# Mouse Drag Trigger
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_rotating = event.pressed
		
		# Precision Mouse Wheel Catching
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom = clamp(target_zoom - zoom_step, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom = clamp(target_zoom + zoom_step, min_zoom, max_zoom)

	# Mouse Orbit Execution
	if event is InputEventMouseMotion and is_rotating:
		handle_orbit(event.relative.x, event.relative.y)

	# Mobile / Tablet Touch Input
	if event is InputEventScreenDrag:
		handle_orbit(event.relative.x * 1.5, event.relative.y * 1.5)

func handle_orbit(delta_x: float, delta_y: float) -> void:
	# Horizontal Rotation (Yaw)
	rotate_y(-delta_x * rotate_speed)
	
	# Vertical Rotation (Pitch)
	var pitch_change = -delta_y * rotate_speed
	var target_pitch = current_pitch + pitch_change
	
	var min_p_rad = deg_to_rad(min_pitch_degrees)
	var max_p_rad = deg_to_rad(max_pitch_degrees)
	
	if target_pitch >= min_p_rad and target_pitch <= max_p_rad:
		current_pitch = target_pitch
		rotate_object_local(Vector3.RIGHT, pitch_change)
	else:
		var clamped_pitch = clamp(target_pitch, min_p_rad, max_p_rad)
		var correction = clamped_pitch - current_pitch
		current_pitch = clamped_pitch
		rotate_object_local(Vector3.RIGHT, correction)

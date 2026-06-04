extends Node3D

@export var target_node: Node3D
@export var rotate_speed: float = 0.004
@export var mobile_rotate_speed: float = 0.0015 # Throttled for hyper-sensitive touch displays

# Step adjustments for the spring arm length
@export var zoom_step: float = 2.0
@export var zoom_lerp_speed: float = 10.0

@export var min_zoom: float = 1.5
@export var max_zoom: float = 55.0

@export var min_pitch_degrees: float = -75.0
@export var max_pitch_degrees: float = 15.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var is_rotating: bool = false
var current_pitch: float = 0.0
var target_zoom: float = 8.0

# Multi-touch memory buffers for mobile gesture calculation
var touch_events: Dictionary = {}
var initial_pinch_distance: float = 0.0
var initial_pinch_zoom: float = 0.0

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
	# ----------------------------------------------------
	# MOUSE CONTEXTS (DESKTOP INTERACTION)
	# ----------------------------------------------------
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
		handle_orbit(event.relative.x, event.relative.y, rotate_speed)

# ----------------------------------------------------
	# SCREEN TOUCH/DRAG CONTEXTS (MOBILE / WEB INPUT)
	# ----------------------------------------------------
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_events[event.index] = event
		else:
			touch_events.erase(event.index)
			if touch_events.size() < 2:
				initial_pinch_distance = 0.0

		# If exactly two fingers touch down, anchor the starting distance
		if touch_events.size() == 2:
			var points = touch_events.values()
			initial_pinch_distance = points[0].position.distance_to(points[1].position)
			initial_pinch_zoom = target_zoom

	if event is InputEventScreenDrag:
		touch_events[event.index] = event # Log live changing finger tracks
		
		# CASE 1: Pinch-to-Zoom (Exactly 2 fingers interacting)
		if touch_events.size() == 2:
			var points = touch_events.values()
			var current_pinch_distance = points[0].position.distance_to(points[1].position)
			
			if initial_pinch_distance > 0.0:
				# Deduce the relative finger movement ratio
				var pinch_factor = current_pinch_distance / initial_pinch_distance
				
				if pinch_factor > 0.0:
					# --- ZOOM SPEED BOOST ---
					# By raising the pinch_factor to a power (e.g., 1.5 or 1.8), 
					# small pinches create much faster, snappier structural magnification adjustments.
					var snappy_factor = pow(pinch_factor, 1.6)
					
					var calculated_zoom = initial_pinch_zoom / snappy_factor
					target_zoom = clamp(calculated_zoom, min_zoom, max_zoom)
			return # Hard short-circuit. Stop rotation processing instantly.

		# CASE 2: Single Finger Orbit (Swipe to Rotate)
		# Only allow rotation if we are absolutely certain a second finger isn't nearby
		if touch_events.size() == 1:
			# Safety check: if an index higher than 0 is moving, it's a residual pinch release frame.
			# Ignoring event.index > 0 kills the "end-of-pinch spin" bug completely.
			if event.index == 0:
				handle_orbit(event.relative.x, event.relative.y, mobile_rotate_speed)

func handle_orbit(delta_x: float, delta_y: float, speed_coeff: float) -> void:
	# Horizontal Rotation (Yaw)
	rotate_y(-delta_x * speed_coeff)
	
	# Vertical Rotation (Pitch)
	var pitch_change = -delta_y * speed_coeff
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

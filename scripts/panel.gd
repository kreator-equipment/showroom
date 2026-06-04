extends Panel

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var rotate_label: Label = $VBoxContainer/RotateLabel
@onready var zoom_label: Label = $VBoxContainer/ZoomLabel

# Starting design defaults
@export var base_font_size: int = 16 
@export var min_font_size: int = 10

func _ready() -> void:
	# 1. Enforce wrapping via code so the boundaries are respected
	rotate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zoom_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# 2. Assign contextual B2B action items
	if DisplayServer.is_touchscreen_available():
		rotate_label.text = "Swipe to Rotate View"
		zoom_label.text = "Pinch to Zoom In/Out"
	else:
		rotate_label.text = "Left Click + Drag to Rotate"
		zoom_label.text = "Scroll Wheel to Zoom"
	
	# 3. Wait for layout processing pass to lock coordinate boundaries
	await get_tree().process_frame
	
	# 4. Safely downscale text to fit container
	fit_label_to_panel(rotate_label)
	fit_label_to_panel(zoom_label)

func fit_label_to_panel(label: Label) -> void:
	# Calculate total safe area width within your panel padding bounds
	var safe_margin: float = vbox.position.x * 2.0 if vbox.position.x > 0 else 20.0
	var max_allowed_width: float = size.x - safe_margin
	
	var current_size: int = base_font_size
	label.add_theme_font_size_override("font_size", current_size)
	
	# Safe font reference retrieval to avoid theme property evaluation errors
	var target_font: Font = label.get_theme_font("font", "Label")
	if not target_font:
		return # Safety fallback if font generation isn't loaded yet
		
	# Loop and reduce point size if string width spills past the panel margins
	while target_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size).x > max_allowed_width:
		current_size -= 1
		label.add_theme_font_size_override("font_size", current_size)
		
		# Prevent infinite loop or microscopic font artifacts
		if current_size <= min_font_size:
			break

extends Node3D

# Drag and drop your final heavy machinery .tscn scenes here via the inspector
@export var model_catalog: Array[PackedScene] = []

@onready var left_button: Button = $UI/LeftButton
@onready var right_button: Button = $UI/RightButton
@onready var share_button: Button = $UI/ShareButton
@onready var name_label: Label = $UI/NameLabel
@onready var toast_label: Label = $UI/ToastLabel

var current_model_instance: Node3D = null
var current_index: int = 0

const DOMAIN: String = "https://kreator-equipment.github.io/showroom"

func _ready() -> void:
	print("--- PRODUCTION CATALOG MANAGER INITIALIZING ---")
	
	# 1. Verify UI Hookups
	if left_button and right_button and share_button:
		print("[SUCCESS] UI Navigation Buttons successfully cached.")
		left_button.pressed.connect(_on_left_button_pressed)
		right_button.pressed.connect(_on_right_button_pressed)
		share_button.pressed.connect(_on_share_button_pressed)
	else:
		push_error("[CRITICAL] Catalog Manager could not locate LeftButton or RightButton nodes!")
		
	if name_label:
		print("[SUCCESS] NameLabel UI node successfully cached.")
		name_label.text = "" # Clear placeholder text on boot
	else:
		push_error("[CRITICAL] Catalog Manager could not locate NameLabel node under $UI/NameLabel!")
	
	# Hide toast label by default on boot
	if toast_label:
		toast_label.visible = false
		print("[SUCCESS] ToastLabel UI node cached and hidden by default.")
	else:
		push_error("[CRITICAL] Catalog Manager could not locate ToastLabel node under $UI/ToastLabel!")
	
	# 2. Check Catalog Size
	print("[INFO] Model catalog array contains ", model_catalog.size(), " production assets.")
	
	# 3. Parse Web URL Deep-Link Query Parameters if running in browser
	_parse_url_query_parameters()
	
	# 4. Handle Initial Bootstrap Load
	if model_catalog.size() > 0:
		print("[INITIALIZING] Spawning starting catalog index: ", current_index)
		load_model(current_index)
	else:
		push_warning("[WARNING] No production machinery scenes found in the inspector catalog array.")

## Interrogates the browser context to find deep-link matching patterns like ?m=1
func _parse_url_query_parameters() -> void:
	if OS.has_feature("web"):
		print("[WEB CONTEXT RECOGNIZED] Attempting to read window URI strings...")
		if JavaScriptBridge:
			var search_string: String = JavaScriptBridge.eval("window.location.search;")
			print("Found raw query string payload: ", search_string)
			
			if not search_string.is_empty():
				var queries = {}
				var pairs = search_string.trim_prefix("?").split("&")
				
				for pair in pairs:
					var parts = pair.split("=")
					if parts.size() == 2:
						queries[parts[0]] = parts[1]
				
				if queries.has("m"):
					var query_value: String = queries["m"]
					if query_value.is_valid_int():
						var requested_index = query_value.to_int()
						print("Found matching deep-link request for model index: ", requested_index)
						
						if requested_index >= 0 and requested_index < model_catalog.size():
							current_index = requested_index
							print("[SUCCESS] Target deep-link index validated. Overriding default bootstrap array pointer.")
						else:
							push_warning("Requested deep-link index " + str(requested_index) + " exceeds catalog array scope. Falling back to index 0.")
					else:
						push_error("Found query 'm' but value '" + query_value + "' is not a valid numerical string.")
		else:
			push_warning("[SYSTEM ERROR] JavaScriptBridge architecture unavailable in this runtime target context.")
	else:
		print("[DESKTOP ENVIRONMENT] Skipping web browser URI parameter parsing pipeline.")

func load_model(index: int) -> void:
	print("\n--- MODEL LOADING PIPELINE START ---")
	print("[TARGET] Attempting to load index slot: ", index)
	
	if index < 0 or index >= model_catalog.size():
		push_error("[ERROR] Aborted model load: Requested index " + str(index) + " is out of bounds.")
		return
		
	if current_model_instance and is_instance_valid(current_model_instance):
		print("[CLEANUP] Queueing active asset '", current_model_instance.name, "' for memory destruction.")
		current_model_instance.queue_free()
	
	var target_scene: PackedScene = model_catalog[index]
	print("[IO] Instantiating packed scene layout: ", target_scene.resource_path)
	
	var new_instance = target_scene.instantiate() as Node3D
	if not new_instance:
		push_error("[CRITICAL] Failed to instantiate scene asset as Node3D! Check node composition structure.")
		return
		
	add_child(new_instance)
	new_instance.global_position = Vector3.ZERO
	current_model_instance = new_instance
	
	# 5. Populate and Format the NameLabel UI Element
	if name_label:
		# Strip out engine instancing suffixes like @ or numbers, replace underscores with spaces
		var raw_name: String = current_model_instance.name
		var clean_name: String = raw_name.split("@")[0].split("外部")[0].replacen("_", " ")
		
		name_label.text = clean_name
		print("[UI UPDATE] NameLabel updated to read: '", clean_name, "'")
	
	print("[SUCCESS] Spawning complete! Active catalog asset name: '", current_model_instance.name, "' centered at: ", new_instance.global_position)
	print("--- MODEL LOADING PIPELINE END ---\n")

func _on_left_button_pressed() -> void:
	print("[INPUT] Left navigation trigger activated.")
	if model_catalog.size() <= 1:
		print("[BYPASS] Catalog has 1 or fewer items. Navigation cycle skipped.")
		return
	
	current_index -= 1
	if current_index < 0:
		current_index = model_catalog.size() - 1
		print("[WRAP] Index hit left boundary. Wrapping backward to final index: ", current_index)
		
	load_model(current_index)

func _on_right_button_pressed() -> void:
	print("[INPUT] Right navigation trigger activated.")
	if model_catalog.size() <= 1:
		print("[BYPASS] Catalog has 1 or fewer items. Navigation cycle skipped.")
		return
	
	current_index += 1
	if current_index >= model_catalog.size():
		current_index = 0
		print("[WRAP] Index hit right boundary. Wrapping forward to initial index: 0")
		
	load_model(current_index)
	
func _on_share_button_pressed() -> void:
	print("[INPUT] Share button trigger activated.")
	var full_share_url: String = DOMAIN + "?m=" + str(current_index)
	
	if OS.has_feature("web"):
		if JavaScriptBridge:
			var js_clipboard_command = "navigator.clipboard.writeText('" + full_share_url + "');"
			JavaScriptBridge.eval(js_clipboard_command)
			print("[CLIPBOARD: WEB] Evaluated navigator.clipboard successfully for: ", full_share_url)
		else:
			push_error("[CLIPBOARD ERROR] JavaScriptBridge architecture unavailable.")
	else:
		DisplayServer.clipboard_set(full_share_url)
		print("[CLIPBOARD: DESKTOP] Set native OS clipboard to: ", full_share_url)

	# --- UPGRADED TOAST LABEL HANDLING LAYER ---
	if toast_label:
		# 1. Update text to show exactly what was sent to the clipboard system context
		toast_label.text = "Link Copied: " + full_share_url
		
		# 2. Force the visibility to be active
		toast_label.visible = true
		
		# 3. Non-blocking async sleep. Delays script runtime for 1.5 seconds without lagging the 3D viewport.
		await get_tree().create_timer(1.5).timeout
		
		# 4. Hide the panel cleanly once the client has read the confirmation message
		toast_label.visible = false

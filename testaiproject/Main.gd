extends Node2D

var player_speed = 300
var bullet_scene = preload("res://Bullet.tscn")
var enemy_scene = preload("res://Enemy.tscn")
var resource_node_scene = preload("res://ResourceNode.tscn")
var tower_scene = preload("res://Tower.tscn")
var coin_sound = preload("res://Sounds/coin.wav")
const Tower = preload("res://Tower.gd")

# Grid system variables
var grid_size = 40  # Size of each grid cell
var grid_lines: Array[Line2D] = []  # Store grid lines
var grid_visible = false
var preview_tower: ColorRect  # Preview tower placement
var selected_tower_type: int = -1  # -1 = none, 0 = gun, 1 = laser
var grid_container: Node2D  # Container for grid lines
var base_grid_line_width = 1.0  # Base width of grid lines

# World size variables
var world_size = Vector2(20000, 20000)  # Large playing field
var world_center = world_size / 2  # Center of the world

# Tilemap variables
var tile_size = 64  # Size of each tile in pixels
var chunk_size = 16  # Number of tiles per chunk (16x16 tiles)
var loaded_chunks = {}  # Dictionary to store loaded chunks
var chunk_container: Node2D  # Container for all chunks
var tilemap_texture: Texture2D  # The spritesheet texture
var tiles_per_row = 8  # Number of tiles per row in spritesheet (550/64 ≈ 8)
var total_tiles = 64  # Total number of tiles in spritesheet

# Camera variables
var camera: Camera2D
var camera_smoothing = 0.1  # Camera smoothing factor
var camera_zoom = Vector2.ONE  # Current camera zoom level
var min_zoom = Vector2(0.5, 0.5)  # Minimum zoom level
var max_zoom = Vector2(2.0, 2.0)  # Maximum zoom level
var zoom_speed = 0.1  # How fast to zoom in/out

# Tower placement variables
var tower_cost = 10
var tower_placement_cooldown = 0.5  # Seconds between tower placements
var last_tower_placement = 0.0

# UI variables
var kills = 0
var ui_label: Label
var game_timer_label: Label
var hud_container: CanvasLayer  # New container for HUD elements

# Spawn variables
var spawn_timer = 0.0
var spawn_interval = 5.0  # Initial spawn interval (5 seconds)
var min_spawn_interval = 0.1  # Minimum spawn interval (2 enemies per second)
var spawn_interval_decrease_rate = 2  # How much to decrease interval per minute
var game_time = 0.0  # Total time elapsed
var max_game_time = 300.0 # Time until maximum spawn rate

# Spawn progression variables
var current_spawn_interval: float
var spawn_progress_label: Label

# Resource variables
var resources = 100  # Start with 10 resources
var resource_spawn_timer = 0.0
var resource_spawn_interval = 10.0  # Spawn resource node every 10 seconds
var max_resource_nodes = 5  # Maximum number of resource nodes at once

# Floating text variables
var floating_text_scene = preload("res://FloatingText.tscn")

# Player variables
var player_dead = false
var player_explosion_time = 0.0
var player_explosion_duration = 0.3
var player_destroyed = false  # Track if player node is destroyed
var min_spawn_distance = 200

# Audio player for coin sound
var coin_audio_player: AudioStreamPlayer

# Build menu variables
var build_menu_visible = false
var build_menu_container: Panel
var build_menu_label: Label
var build_menu_cooldown = 0.3  # Cooldown in seconds
var last_build_menu_toggle = 0.0

# Game over screen variables
var game_over_container: Panel
var game_over_label: Label
var game_over_options_label: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize game objects
	$Player.position = world_center  # Start player in center of world
	
	# Load tilemap texture
	tilemap_texture = load("res://TileSheet/medievalRTS_spritesheet.png")
	
	# Create chunk container
	chunk_container = Node2D.new()
	add_child(chunk_container)
	
	# Setup audio player for coin sound
	coin_audio_player = AudioStreamPlayer.new()
	coin_audio_player.stream = coin_sound
	add_child(coin_audio_player)
	
	# Setup camera
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.zoom = camera_zoom  # Set initial zoom
	$Player.add_child(camera)
	
	# Initialize grid system
	grid_container = Node2D.new()
	add_child(grid_container)
	create_grid()
	
	# Create preview tower
	preview_tower = ColorRect.new()
	preview_tower.size = Vector2(grid_size, grid_size)
	preview_tower.modulate = Color(1, 1, 1, 0.3)  # Semi-transparent white
	preview_tower.visible = false
	add_child(preview_tower)
	
	# Create HUD container (this will stay fixed on screen)
	hud_container = CanvasLayer.new()
	add_child(hud_container)
	
	# Create UI label for kills and resources
	ui_label = Label.new()
	ui_label.position = Vector2(20, 20)
	ui_label.add_theme_font_size_override("font_size", 24)
	hud_container.add_child(ui_label)
	
	# Create game timer label
	game_timer_label = Label.new()
	game_timer_label.position = Vector2(20, 80)
	game_timer_label.add_theme_font_size_override("font_size", 20)
	hud_container.add_child(game_timer_label)
	
	# Create spawn progress label
	spawn_progress_label = Label.new()
	spawn_progress_label.position = Vector2(20, 60)
	spawn_progress_label.add_theme_font_size_override("font_size", 16)
	add_child(spawn_progress_label)
	
	# Create game over screen
	create_game_over_screen()
	
	# Initialize spawn interval
	current_spawn_interval = spawn_interval
	
	update_ui()
	
	# Connect the player's body_entered signal
	$Player.body_entered.connect(_on_player_body_entered)
	
	# Create build menu container
	build_menu_container = Panel.new()
	build_menu_container.visible = false
	build_menu_container.add_theme_stylebox_override("panel", create_menu_stylebox())
	hud_container.add_child(build_menu_container)
	
	# Create build menu label
	build_menu_label = Label.new()
	build_menu_label.add_theme_font_size_override("font_size", 20)
	build_menu_label.text = "Build Menu:\n1. Gun Tower (10 gold)\n2. Laser Tower (15 gold)"
	build_menu_container.add_child(build_menu_label)
	
	# Center the label in the panel
	build_menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_menu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	print("Game initialized")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_dead:
		# Update game time
		game_time += delta
		
		# Update spawn interval based on time
		update_spawn_interval()
		
		# Update visible chunks based on camera position
		update_visible_chunks()
		
		grid_container.visible = build_menu_visible
		
		# Handle build menu with cooldown
		if Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_B):  # B key
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_build_menu_toggle >= build_menu_cooldown:
				toggle_build_menu()
				last_build_menu_toggle = current_time
		
		# Handle tower selection when menu is open
		if build_menu_visible:
			if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_1):  # 1 key
				selected_tower_type = Tower.TowerType.GUN
				#toggle_build_menu()
			elif Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_2):  # 2 key
				selected_tower_type = Tower.TowerType.LASER
				#toggle_build_menu()
		
		# Update preview tower position
		update_preview_tower()
		
		# Handle tower placement with left click
		if selected_tower_type != -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			print("PLACING TOWER")
			var mouse_pos = get_global_mouse_position()
			var grid_pos = get_grid_position(mouse_pos)
			place_tower_at_position(selected_tower_type, grid_pos)
			selected_tower_type = -1
			preview_tower.visible = false
		
		# Handle canceling tower placement with right click
		if selected_tower_type != -1 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			selected_tower_type = -1
			preview_tower.visible = false
		
		# Update build menu position to stay at bottom of screen
		if build_menu_container:
			var viewport_size = get_viewport().get_visible_rect().size
			build_menu_container.size = Vector2(300, 100)  # Fixed size for the menu
			build_menu_container.position = Vector2(
				(viewport_size.x - build_menu_container.size.x) / 2,  # Center horizontally
				viewport_size.y - build_menu_container.size.y - 20  # 20 pixels from bottom
			)
			build_menu_label.size = build_menu_container.size  # Make label fill the panel
		
		# Handle enemy spawning
		spawn_timer += delta
		if spawn_timer >= current_spawn_interval:
			spawn_timer = 0
			spawn_enemy()
		
		# Handle resource node spawning
		resource_spawn_timer += delta
		if resource_spawn_timer >= resource_spawn_interval:
			resource_spawn_timer = 0
			spawn_resource_node()
	
	if not player_dead:
		# Player movement
		var input_dir = Vector2.ZERO
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			input_dir.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			input_dir.y += 1
		
		if input_dir != Vector2.ZERO:
			input_dir = input_dir.normalized()
			if is_instance_valid($Player):
				# Calculate new position
				var new_position = $Player.position + input_dir * player_speed * delta
				
				# Clamp position to world bounds
				var margin = 20  # Small margin from world edges
				new_position.x = clamp(new_position.x, margin, world_size.x - margin)
				new_position.y = clamp(new_position.y, margin, world_size.y - margin)
				
				$Player.position = new_position
	
	if not player_dead:
		# Check for enemies touching player
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and is_instance_valid($Player):
				var distance = $Player.position.distance_to(enemy.position)
				if distance < 30:  # If they're close enough to be touching
					print("Player touching enemy! Distance: ", distance)
					_on_player_body_entered(enemy)
	elif not player_destroyed:
		# Handle player explosion effect
		player_explosion_time += delta
		var progress = player_explosion_time / player_explosion_duration
		print("Player explosion progress: ", progress)
		
		# Scale up and fade out
		if is_instance_valid($Player):  # Check if player still exists
			$Player.scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
			$Player.modulate.a = 1.0 - progress  # Fade out
		
		if player_explosion_time >= player_explosion_duration:
			print("Player destroyed")
			if is_instance_valid($Player):
				$Player.queue_free()
			player_destroyed = true
			show_game_over_screen()
	else:
		# Handle game over screen input
		if Input.is_action_just_pressed("ui_accept"):  # Enter key
			restart_game()
		elif Input.is_action_just_pressed("ui_cancel"):  # Escape key
			get_tree().quit()

func get_valid_spawn_position() -> Vector2:
	var position = Vector2.ZERO
	var margin = 100  # Distance from world edges
	
	# Randomly choose which side to spawn from (0: top, 1: right, 2: bottom, 3: left)
	var side = randi() % 4
	
	match side:
		0:  # Top
			position = Vector2(
				randf_range(margin, world_size.x - margin),
				margin
			)
		1:  # Right
			position = Vector2(
				world_size.x - margin,
				randf_range(margin, world_size.y - margin)
			)
		2:  # Bottom
			position = Vector2(
				randf_range(margin, world_size.x - margin),
				world_size.y - margin
			)
		3:  # Left
			position = Vector2(
				margin,
				randf_range(margin, world_size.y - margin)
			)
	
	return position

func get_valid_resource_position() -> Vector2:
	var max_attempts = 10
	var position = Vector2.ZERO
	var margin = 100  # Distance from world edges
	
	for i in range(max_attempts):
		# Generate random position within world bounds (with margin)
		position = Vector2(
			randf_range(margin, world_size.x - margin),
			randf_range(margin, world_size.y - margin)
		)
		
		# Check distance from player
		var valid_position = true
		if is_instance_valid($Player):
			if position.distance_to($Player.position) < min_spawn_distance:
				valid_position = false
		
		# Check distance from other resource nodes
		for node in get_tree().get_nodes_in_group("resource_nodes"):
			if is_instance_valid(node):
				if position.distance_to(node.position) < min_spawn_distance:
					valid_position = false
		
		if valid_position:
			return position
	
	# If no valid position found, try a random position in the world
	return Vector2(
		randf_range(margin, world_size.x - margin),
		randf_range(margin, world_size.y - margin)
	)

func spawn_enemy():
	var new_enemy = enemy_scene.instantiate()
	add_child(new_enemy)
	new_enemy.position = get_valid_spawn_position()
	new_enemy.add_to_group("enemies")
	
	# Create floating text at player position
	var floating_text = floating_text_scene.instantiate()
	add_child(floating_text)
	floating_text.position = $Player.position + Vector2(0, -30)
	floating_text.set_text("! enemy spawned")
	floating_text.modulate = Color(1, 0, 0)

func spawn_resource_node():
	# Count current resource nodes
	var current_nodes = get_tree().get_nodes_in_group("resource_nodes").size()
	
	if current_nodes < max_resource_nodes:
		var new_node = resource_node_scene.instantiate()
		add_child(new_node)
		new_node.position = get_valid_resource_position()
		new_node.add_to_group("resource_nodes")

func add_resources(type: String, amount: int):
	resources += amount
	update_ui()
	
	# Play coin sound
	coin_audio_player.play()
	
	# Create floating text at player position
	if is_instance_valid($Player):
		var floating_text = floating_text_scene.instantiate()
		add_child(floating_text)
		floating_text.position = $Player.position + Vector2(0, -30)
		floating_text.set_text("+" + str(amount) + " " + type)
		floating_text.modulate = Color(1, 0.84, 0)  # Gold color

func _on_player_body_entered(body):
	print("Player hit by: ", body.name)
	if body.is_in_group("enemies"):
		print("Player hit by enemy!")
		player_dead = true
		player_explosion_time = 0.0

func enemy_killed() -> void:
	kills += 1
	update_ui()

func update_ui() -> void:
	if ui_label:
		ui_label.text = "Kills: " + str(kills) + "\nResources: " + str(resources)
	
	if game_timer_label:
		var minutes = int(game_time / 60)
		var seconds = int(game_time) % 60
		var spawns_per_second = 1.0 / current_spawn_interval
		game_timer_label.text = "Time: %02d:%02d\nSpawn Rate: %.1f/sec" % [minutes, seconds, spawns_per_second]

func update_spawn_interval():
	# Calculate progress (0 to 1)
	var progress = min(game_time / max_game_time, 1.0)
	
	# Calculate new spawn interval
	# Start at spawn_interval and decrease to min_spawn_interval over time
	current_spawn_interval = spawn_interval - (spawn_interval - min_spawn_interval) * progress
	
	# Update UI with time and spawn rate
	update_ui()

func toggle_build_menu():
	build_menu_visible = !build_menu_visible
	build_menu_container.visible = build_menu_visible
	
	# Reset tower selection when closing menu
	if !build_menu_visible:
		selected_tower_type = -1
		preview_tower.visible = false

func place_tower_at_position(tower_type: int, position: Vector2) -> void:
	var cost = 10 if tower_type == Tower.TowerType.GUN else 15
	
	if resources >= cost:
		# Check if position is already occupied
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower.position.distance_to(position) < grid_size:
				# Show floating text for occupied position
				var floating_text = floating_text_scene.instantiate()
				add_child(floating_text)
				floating_text.position = position + Vector2(0, -30)
				floating_text.set_text("Position occupied!")
				floating_text.modulate = Color(1, 0, 0)
				return
		
		# Create new tower
		var new_tower = tower_scene.instantiate()
		new_tower.mainRef = self
		new_tower.tower_type = tower_type
		add_child(new_tower)
		new_tower.add_to_group("towers")
		new_tower.position = position
		
		# Deduct resources
		resources -= cost
		update_ui()
		
		# Show floating text for tower placement
		var floating_text = floating_text_scene.instantiate()
		add_child(floating_text)
		floating_text.position = position + Vector2(0, -30)
		floating_text.set_text("-" + str(cost) + " gold")
		floating_text.modulate = Color(1, 0, 0)
	else:
		# Show floating text for insufficient resources
		var floating_text = floating_text_scene.instantiate()
		add_child(floating_text)
		floating_text.position = position + Vector2(0, -30)
		floating_text.set_text("Need " + str(cost) + " gold!")
		floating_text.modulate = Color(1, 0, 0)

func create_menu_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)  # Dark background with high opacity
	style.border_color = Color(0.8, 0.8, 0.8, 0.9)  # Light border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func create_grid() -> void:
	# Clear existing grid lines
	for line in grid_lines:
		line.queue_free()
	grid_lines.clear()
	
	# Calculate number of lines needed
	var num_horizontal = int(world_size.y / grid_size) + 1
	var num_vertical = int(world_size.x / grid_size) + 1
	
	# Create horizontal lines
	for i in range(num_horizontal):
		var line = Line2D.new()
		line.width = base_grid_line_width
		line.default_color = Color(1, 1, 1, 0.2)  # Semi-transparent white
		line.add_point(Vector2(0, i * grid_size))
		line.add_point(Vector2(world_size.x, i * grid_size))
		grid_container.add_child(line)
		grid_lines.append(line)
	
	# Create vertical lines
	for i in range(num_vertical):
		var line = Line2D.new()
		line.width = base_grid_line_width
		line.default_color = Color(1, 1, 1, 0.2)  # Semi-transparent white
		line.add_point(Vector2(i * grid_size, 0))
		line.add_point(Vector2(i * grid_size, world_size.y))
		grid_container.add_child(line)
		grid_lines.append(line)
	
	# Initial grid appearance update
	update_grid_appearance()

func get_grid_position(world_pos: Vector2) -> Vector2:
	var max_grid = Vector2(world_size.x / grid_size -1, world_size.y / grid_size -1)
	var grid_x = max(0, min(max_grid.x, floor(world_pos.x / grid_size))) * grid_size + (grid_size /2)
	var grid_y = max(0, min(max_grid.y, floor(world_pos.y / grid_size))) * grid_size + (grid_size /2)
	return Vector2(grid_x, grid_y)

func update_preview_tower() -> void:
	if selected_tower_type != -1:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = get_grid_position(mouse_pos)
		preview_tower.position = grid_pos - (preview_tower.size / 2)
		preview_tower.visible = true
		
		# Update color based on tower type
		if selected_tower_type == Tower.TowerType.GUN:
			preview_tower.color = Color(0.5, 0, 0, 0.3)  # Semi-transparent red
		else:
			preview_tower.color = Color(1, 1, 0, 0.3)  # Semi-transparent yellow
	else:
		preview_tower.visible = false

func create_game_over_screen() -> void:
	# Create container panel
	game_over_container = Panel.new()
	game_over_container.visible = false
	game_over_container.add_theme_stylebox_override("panel", create_game_over_stylebox())
	hud_container.add_child(game_over_container)
	
	# Create game over label
	game_over_label = Label.new()
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_color_override("font_color", Color(0.8, 0, 0))  # Dark red
	game_over_container.add_child(game_over_label)
	
	# Create options label
	game_over_options_label = Label.new()
	game_over_options_label.add_theme_font_size_override("font_size", 24)
	game_over_options_label.text = "Enter - Try Again\nEsc - Quit Game"
	game_over_options_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_options_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_container.add_child(game_over_options_label)

func create_game_over_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark background with high opacity
	style.border_color = Color(0.8, 0, 0, 0.9)  # Red border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	return style

func show_game_over_screen() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	game_over_container.size = Vector2(400, 300)  # Fixed size for the game over screen
	game_over_container.position = Vector2(
		(viewport_size.x - game_over_container.size.x) / 2,  # Center horizontally
		(viewport_size.y - game_over_container.size.y) / 2   # Center vertically
	)
	
	# Position the labels
	game_over_label.size = Vector2(game_over_container.size.x, 100)
	game_over_label.position = Vector2(0, 50)
	
	game_over_options_label.size = Vector2(game_over_container.size.x, 100)
	game_over_options_label.position = Vector2(0, 150)
	
	game_over_container.visible = true

func restart_game() -> void:
	# Clear all chunks
	for chunk in loaded_chunks.values():
		chunk.queue_free()
	loaded_chunks.clear()
	
	# Reset game state
	player_dead = false
	player_destroyed = false
	player_explosion_time = 0.0
	game_time = 0.0
	kills = 0
	resources = 100
	spawn_timer = 0.0
	resource_spawn_timer = 0.0
	current_spawn_interval = spawn_interval
	camera_zoom = Vector2.ONE  # Reset zoom level
	
	# Hide game over screen
	game_over_container.visible = false
	
	# Clear all enemies and towers
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.queue_free()
	for resource_node in get_tree().get_nodes_in_group("resource_nodes"):
		resource_node.queue_free()
	
	# Create new player
	var new_player = Area2D.new()
	new_player.name = "Player"
	add_child(new_player)
	
	# Add player components
	var player_rect = ColorRect.new()
	player_rect.offset_left = -20.0
	player_rect.offset_top = -20.0
	player_rect.offset_right = 20.0
	player_rect.offset_bottom = 20.0
	player_rect.color = Color(0, 1, 0, 1)
	new_player.add_child(player_rect)
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision_shape.shape = shape
	new_player.add_child(collision_shape)
	
	# Set player position and add camera
	new_player.position = world_center
	if is_instance_valid(camera):
		camera.reparent(new_player)
		camera.zoom = camera_zoom  # Restore zoom level
	else:
		print("Camera instance is invalid. Creating a new camera.")
		camera = Camera2D.new()
		camera.zoom = camera_zoom  # Set zoom level for new camera
		new_player.add_child(camera)
	
	# Connect player signals
	new_player.body_entered.connect(_on_player_body_entered)
	
	# Update UI
	update_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom in
			camera_zoom = camera_zoom * (1.0 - zoom_speed)
			camera_zoom = camera_zoom.clamp(min_zoom, max_zoom)
			camera.zoom = camera_zoom
			update_grid_appearance()  # Update grid when zooming
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom out
			camera_zoom = camera_zoom * (1.0 + zoom_speed)
			camera_zoom = camera_zoom.clamp(min_zoom, max_zoom)
			camera.zoom = camera_zoom
			update_grid_appearance()  # Update grid when zooming

func update_grid_appearance() -> void:
	# Calculate line width based on zoom level
	var zoom_factor = 1.0 / camera_zoom.x  # Use x component since we maintain uniform zoom
	var line_width = base_grid_line_width * zoom_factor
	
	# Calculate opacity based on zoom level
	var opacity = 0.2  # Base opacity
	if zoom_factor < 0.5:  # When zoomed out far
		opacity = 0.1
	elif zoom_factor > 1.5:  # When zoomed in close
		opacity = 0.3
	
	# Update all grid lines
	for line in grid_lines:
		line.width = line_width
		line.default_color.a = opacity

func update_visible_chunks() -> void:
	if not is_instance_valid($Player):
		return
		
	var player_pos = $Player.position
	var chunk_x = floor(player_pos.x / (chunk_size * tile_size))
	var chunk_y = floor(player_pos.y / (chunk_size * tile_size))
	
	# Calculate visible chunk range based on camera zoom
	var visible_range = ceil(2.0 / camera_zoom.x)  # Adjust range based on zoom level
	
	# Unload chunks that are too far away
	var chunks_to_remove = []
	for chunk_key in loaded_chunks:
		var chunk_pos = chunk_key.split(",")
		var cx = int(chunk_pos[0])
		var cy = int(chunk_pos[1])
		
		if abs(cx - chunk_x) > visible_range or abs(cy - chunk_y) > visible_range:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		loaded_chunks[chunk_key].queue_free()
		loaded_chunks.erase(chunk_key)
	
	# Load new chunks in visible range
	for x in range(chunk_x - visible_range, chunk_x + visible_range + 1):
		for y in range(chunk_y - visible_range, chunk_y + visible_range + 1):
			var chunk_key = str(x) + "," + str(y)
			if not loaded_chunks.has(chunk_key):
				create_chunk(x, y)

func create_chunk(chunk_x: int, chunk_y: int) -> void:
	var chunk = Node2D.new()
	chunk_container.add_child(chunk)
	
	# Calculate chunk position
	var chunk_pos = Vector2(
		chunk_x * chunk_size * tile_size,
		chunk_y * chunk_size * tile_size
	)
	chunk.position = chunk_pos
	
	# Create tiles for this chunk
	for x in range(chunk_size):
		for y in range(chunk_size):
			# Calculate world position for this tile
			var tile_pos = Vector2(x * tile_size, y * tile_size)
			
			# Generate a deterministic tile index based on position
			var tile_index = get_tile_index(chunk_x * chunk_size + x, chunk_y * chunk_size + y)
			
			# Create sprite for this tile
			var sprite = Sprite2D.new()
			sprite.texture = tilemap_texture
			sprite.region_enabled = true
			sprite.region_rect = get_tile_region(tile_index)
			sprite.position = tile_pos
			chunk.add_child(sprite)
	
	# Store chunk reference
	loaded_chunks[str(chunk_x) + "," + str(chunk_y)] = chunk

func get_tile_index(x: int, y: int) -> int:
	# Use a simple hash function to generate deterministic tile indices
	var hash = (x * 73856093) ^ (y * 19349663)
	return abs(hash) % total_tiles

func get_tile_region(tile_index: int) -> Rect2:
	var row = tile_index / tiles_per_row
	var col = tile_index % tiles_per_row
	
	# Calculate region in the spritesheet
	var region = Rect2(
		col * tile_size,
		row * tile_size,
		tile_size,
		tile_size
	)
	
	return region

extends Node2D

var player_speed = 300
var bullet_scene = preload("res://Bullet.tscn")
var enemy_scene = preload("res://Enemy.tscn")
var resource_node_scene = preload("res://ResourceNode.tscn")
var tower_scene = preload("res://Tower.tscn")

# World size variables
var world_size = Vector2(2000, 2000)  # Large playing field
var world_center = Vector2(1000, 1000)  # Center of the world

# Camera variables
var camera: Camera2D
var camera_smoothing = 0.1  # Camera smoothing factor

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
var min_spawn_interval = 0.5  # Minimum spawn interval (2 enemies per second)
var spawn_interval_decrease_rate = 0.5  # How much to decrease interval per minute
var game_time = 0.0  # Total time elapsed
var max_game_time = 600.0  # 10 minutes in seconds

# Spawn progression variables
var current_spawn_interval: float
var spawn_progress_label: Label

# Resource variables
var resources = 10  # Start with 10 resources
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize game objects
	$Player.position = world_center  # Start player in center of world
	
	# Setup camera
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	$Player.add_child(camera)
	
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
	
	# Initialize spawn interval
	current_spawn_interval = spawn_interval
	
	update_ui()
	
	# Connect the player's body_entered signal
	$Player.body_entered.connect(_on_player_body_entered)
	
	print("Game initialized")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_dead:
		# Update game time
		game_time += delta
		
		# Update spawn interval based on time
		update_spawn_interval()
		
		# Handle tower placement
		if Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_B):  # B key or space
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_tower_placement >= tower_placement_cooldown:
				place_tower()
				last_tower_placement = current_time

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

func place_tower() -> void:
	if resources >= tower_cost and is_instance_valid($Player):
		# Create new tower
		var new_tower = tower_scene.instantiate()
		add_child(new_tower)
		new_tower.position = $Player.position
		
		# Deduct resources
		resources -= tower_cost
		update_ui()
		
		# Show floating text for tower placement
		var floating_text = floating_text_scene.instantiate()
		add_child(floating_text)
		floating_text.position = $Player.position + Vector2(0, -30)
		floating_text.set_text("-" + str(tower_cost) + " gold")
		floating_text.modulate = Color(1, 0, 0)
	else:
		# Show floating text for insufficient resources
		var floating_text = floating_text_scene.instantiate()
		add_child(floating_text)
		floating_text.position = $Player.position + Vector2(0, -30)
		floating_text.set_text("Need " + str(tower_cost) + " gold!")
		floating_text.modulate = Color(1, 0, 0)

func update_spawn_interval():
	# Calculate progress (0 to 1)
	var progress = min(game_time / max_game_time, 1.0)
	
	# Calculate new spawn interval
	# Start at spawn_interval and decrease to min_spawn_interval over time
	current_spawn_interval = spawn_interval - (spawn_interval - min_spawn_interval) * progress
	
	# Update UI with time and spawn rate
	update_ui()

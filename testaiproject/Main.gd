extends Node2D

var player_speed = 300
var enemy_speed = 150
var tower_range = 200
var bullet_speed = 400
var bullet_scene = preload("res://Bullet.tscn")

# Turret cooldown variables
var last_shot_time = 0.0
var shot_cooldown = 0.5  # Time between shots in seconds

# Enemy variables
var enemy_exploding = false
var enemy_explosion_time = 0.0
var enemy_explosion_duration = 0.3  # Duration of explosion effect in seconds
var enemy_destroyed = false  # New variable to track if enemy is destroyed

# Player variables
var player_dead = false
var player_explosion_time = 0.0
var player_explosion_duration = 0.3
var player_destroyed = false  # Track if player node is destroyed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize game objects
	$Player.position = Vector2(100, 100)
	$Tower.position = Vector2(400, 300)
	$Enemy.position = Vector2(700, 500)
	
	# Print collision setup information
	print("Player setup:")
	print("- Is Area2D: ", $Player is Area2D)
	print("- Monitoring: ", $Player.monitoring)
	print("- Monitorable: ", $Player.monitorable)
	print("- Collision Layer: ", $Player.collision_layer)
	print("- Collision Mask: ", $Player.collision_mask)
	
	print("\nEnemy setup:")
	print("- Is Area2D: ", $Enemy is Area2D)
	print("- Monitoring: ", $Enemy.monitoring)
	print("- Monitorable: ", $Enemy.monitorable)
	print("- Collision Layer: ", $Enemy.collision_layer)
	print("- Collision Mask: ", $Enemy.collision_mask)
	
	# Connect the player's body_entered signal
	if $Player is Area2D:
		$Player.body_entered.connect(_on_player_body_entered)
		print("\nConnected player body_entered signal")
	else:
		print("\nERROR: Player is not an Area2D!")
	
	print("Game initialized")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
				$Player.position += input_dir * player_speed * delta
			
		# Check if player and enemy are touching
		if is_instance_valid($Player) and is_instance_valid($Enemy):
			var distance = $Player.position.distance_to($Enemy.position)
			if distance < 30:  # If they're close enough to be touching
				print("Objects are touching! Distance: ", distance)
				# Try to trigger collision manually
				_on_player_body_entered($Enemy)
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
	
	# Enemy movement and explosion effect
	if not enemy_exploding and is_instance_valid($Enemy):
		# Normal enemy movement
		if is_instance_valid($Player):
			var direction = ($Player.position - $Enemy.position).normalized()
			$Enemy.position += direction * enemy_speed * delta
	elif not enemy_destroyed:
		# Handle explosion effect
		enemy_explosion_time += delta
		var progress = enemy_explosion_time / enemy_explosion_duration
		print("Explosion progress: ", progress)
		
		# Scale up and fade out
		if is_instance_valid($Enemy):
			$Enemy.scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
			$Enemy.modulate.a = 1.0 - progress  # Fade out
		
		if enemy_explosion_time >= enemy_explosion_duration:
			print("Enemy destroyed after explosion")
			if is_instance_valid($Enemy):
				$Enemy.queue_free()
			enemy_destroyed = true
	
	# Tower shooting with cooldown
	if is_instance_valid($Enemy) and is_instance_valid($Tower):
		var distance_to_enemy = $Tower.position.distance_to($Enemy.position)
		var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
		
		if distance_to_enemy < tower_range and (current_time - last_shot_time) >= shot_cooldown:
			shoot_at_enemy()
			last_shot_time = current_time

func shoot_at_enemy():
	if not is_instance_valid($Enemy) or not is_instance_valid($Player) or not is_instance_valid($Tower):
		return
		
	var bullet = bullet_scene.instantiate()
	add_child(bullet)
	bullet.position = $Tower.position
	
	# Calculate enemy's current velocity
	var enemy_velocity = ($Player.position - $Enemy.position).normalized() * enemy_speed
	
	# Calculate time to reach enemy (approximate)
	var distance_to_enemy = $Tower.position.distance_to($Enemy.position)
	var time_to_reach = distance_to_enemy / bullet_speed
	
	# Predict enemy's future position
	var predicted_position = $Enemy.position + enemy_velocity * time_to_reach
	
	# Calculate direction to predicted position
	var direction = (predicted_position - $Tower.position).normalized()
	bullet.velocity = direction * bullet_speed

func _on_player_body_entered(body):
	print("Player hit by: ", body.name)
	if body.name == "Enemy":
		print("Player hit by enemy!")
		player_dead = true
		player_explosion_time = 0.0

func _on_enemy_body_entered(body):
	print("Enemy hit by: ", body.name)
	if body is Area2D:  # Check if it's a bullet
		print("Hit by bullet!")
		start_explosion()
		body.queue_free()  # Remove the bullet

func start_explosion():
	print("Starting explosion effect on enemy")
	enemy_exploding = true
	enemy_explosion_time = 0.0

extends Area2D

var speed = 250
var collision_radius = 15
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3
var explosion_scene = preload("res://ExplosionEffect.tscn")
var sound_explode = preload("res://Sounds/explosion2.wav")
var audio_player_explode: AudioStreamPlayer

var health = 10
var max_health = 10  # Added max health for health bar calculation

# Health bar variables
var health_bar_width = 40
var health_bar_height = 4
var health_bar: Node2D
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

# Movement behavior variables
var current_direction = Vector2.ZERO
var wander_angle = 0.0
var wander_radius = 50.0
var wander_distance = 100.0
var wander_jitter = 10.0
var separation_radius = 40.0
var separation_weight = 1.5
var last_direction_change = 0.0
var direction_change_interval = 0.5  # Change direction every 0.5 seconds

# Attack variables
var attack_damage = 10
var attack_cooldown = 1.0  # Seconds between attacks
var last_attack_time = 0.0
var current_target = null

func _ready():	
	body_entered.connect(_on_body_entered)
	# Initialize random wander angle
	wander_angle = randf() * TAU  # Random angle between 0 and 2π
	
	# Replace ColorRect with Sprite2D
	var sprite = Sprite2D.new()
	sprite.texture = load("res://Sprites/Spider.png")
	sprite.z_index = 1
	add_child(sprite)
	
	# Setup audio player for gunshot sound
	audio_player_explode = AudioStreamPlayer.new()
	audio_player_explode.stream = sound_explode
	add_child(audio_player_explode)
	
	# Create health bar container
	health_bar = Node2D.new()
	health_bar.position = Vector2(-health_bar_width/2, 25)  # Position below enemy
	add_child(health_bar)
	
	# Create background bar
	health_bar_bg = ColorRect.new()
	health_bar_bg.size = Vector2(health_bar_width, health_bar_height)
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray with slight transparency
	health_bar.add_child(health_bar_bg)
	
	# Create fill bar
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(health_bar_width, health_bar_height)
	health_bar_fill.color = Color(0, 1, 0, 0.8)  # Green with slight transparency
	health_bar.add_child(health_bar_fill)
	
	# Initially hide health bar since enemy is at full health
	health_bar.visible = false

func _process(delta):
	if not exploding:
		# Find closest target (player or tower)
		find_closest_target()

		if current_target and is_instance_valid(current_target):
			# Calculate base direction to target
			var to_target = (current_target.position - position).normalized()
			
			# Add separation from other enemies
			var separation = calculate_separation()
			
			# Add wandering behavior
			var wander = calculate_wander(delta)
			
			# Combine behaviors
			current_direction = (to_target + separation * separation_weight + wander).normalized()
			
			# Add some randomness to direction changes
			last_direction_change += delta
			if last_direction_change >= direction_change_interval:
				last_direction_change = 0
				# Add small random deviation
				current_direction = current_direction.rotated(randf_range(-0.2, 0.2))
			
			# Move with the calculated direction
			position += current_direction * speed * delta
			
			# Check if we're close enough to attack
			var distance = position.distance_to(current_target.position)
			if distance < 50:
				look_at(current_target.global_position)
				
			if distance < 30:  # Attack range
				attack_target()
	else:
		# Handle explosion effect
		explosion_time += delta
		var progress = explosion_time / explosion_duration
		
		# Scale up and fade out
		scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
		modulate.a = 1.0 - progress  # Fade out
		
		if explosion_time >= explosion_duration:
			print("Enemy destroyed after explosion")
			# Notify Main scene about the kill
			var main = get_node("/root/Main")
			if main:
				main.enemy_killed()
			queue_free()
	
func find_closest_target():
	var closest_distance = INF
	current_target = null
	
	# Check player
	var player = get_node_or_null("/root/Main/Player")
	if player and not player.is_queued_for_deletion():
		var distance = position.distance_to(player.position)
		if distance < closest_distance:
			closest_distance = distance
			current_target = player
	
	# Check towers
	var towers = get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():			
			var distance = position.distance_to(tower.position)
			if distance < closest_distance:
				closest_distance = distance
				current_target = tower

func attack_target():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cooldown:
		last_attack_time = current_time
		
		if current_target.is_in_group("towers"):
			current_target.take_damage(attack_damage, self)  # Pass self as attacker
		elif current_target.name == "Player":
			# Player hit logic is handled in Main.gd
			pass
	
func calculate_separation() -> Vector2:
	var separation_force = Vector2.ZERO
	var neighbors = 0
	
	# Check all enemies in the scene
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance < separation_radius:
				var away = (position - enemy.position).normalized()
				separation_force += away * (1.0 - distance / separation_radius)
				neighbors += 1
	
	if neighbors > 0:
		separation_force /= neighbors
	
	return separation_force

func calculate_wander(delta: float) -> Vector2:
	# Update wander angle with some randomness
	wander_angle += randf_range(-wander_jitter, wander_jitter) * delta
	
	# Calculate circle position in front of the enemy
	var circle_center = current_direction * wander_distance
	var displacement = Vector2(cos(wander_angle), sin(wander_angle)) * wander_radius
	
	return (circle_center + displacement).normalized()

func _on_body_entered(body):
	print("Enemy _on_body_entered called with: ", body.name)  # Debug print
	if body is Area2D and not exploding:  # Check if it's a bullet
		print("Enemy hit by bullet!")
		check_health()
		body.queue_free()  # Remove the bulle
		

func take_damage(damage):
	health -= damage
	# Show health bar when taking damage
	health_bar.visible = true
	update_health_bar()
	check_health()

func update_health_bar():
	var health_percent = float(health) / max_health
	health_bar_fill.size.x = health_bar_width * health_percent
	
	# Update color based on health percentage
	if health_percent > 0.6:
		health_bar_fill.color = Color(0, 1, 0, 0.8)  # Green
	elif health_percent > 0.3:
		health_bar_fill.color = Color(1, 1, 0, 0.8)  # Yellow
	else:
		health_bar_fill.color = Color(1, 0, 0, 0.8)  # Red

func check_health():
	if health <= 0:
		start_explosion()

func start_explosion():
	print("Enemy start_explosion called")  # Debug print
	exploding = true
	explosion_time = 0.0
	
	# Create the explosion effect
	var explosion = explosion_scene.instantiate()
	get_parent().add_child(explosion)
	explosion.position = position
	
	audio_player_explode.play()
	

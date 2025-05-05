extends Area2D

var speed = 150
var collision_radius = 15
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3

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

func _ready():
	body_entered.connect(_on_body_entered)
	# Initialize random wander angle
	wander_angle = randf() * TAU  # Random angle between 0 and 2π
	print("Enemy ready with collision shape")

func _process(delta):
	if not exploding:
		# Get reference to player
		var player = get_node_or_null("/root/Main/Player")
		if player and not player.is_queued_for_deletion():
			# Calculate base direction to player
			var to_player = (player.position - position).normalized()
			
			# Add separation from other enemies
			var separation = calculate_separation()
			
			# Add wandering behavior
			var wander = calculate_wander(delta)
			
			# Combine behaviors
			current_direction = (to_player + separation * separation_weight + wander).normalized()
			
			# Add some randomness to direction changes
			last_direction_change += delta
			if last_direction_change >= direction_change_interval:
				last_direction_change = 0
				# Add small random deviation
				current_direction = current_direction.rotated(randf_range(-0.2, 0.2))
			
			# Move with the calculated direction
			position += current_direction * speed * delta
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
		start_explosion()
		body.queue_free()  # Remove the bullet

func start_explosion():
	print("Enemy start_explosion called")  # Debug print
	exploding = true
	explosion_time = 0.0 

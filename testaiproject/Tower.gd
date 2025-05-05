extends Node2D

var bullet_scene = preload("res://Bullet.tscn")
var bullet_speed = 300
var tower_range = 300
var last_shot_time = 0.0
var shot_cooldown = 2.5  # Time between shots in seconds
var gunshot_sound = preload("res://Sounds/gunshot.mp3")

# Tower health variables
var health = 100
var max_health = 100
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3

# Health bar variables
var health_bar_width = 50
var health_bar_height = 4
var health_bar: Node2D
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

# Audio player for gunshot sound
var gunshot_audio_player: AudioStreamPlayer

func _ready():
	# Create health bar container
	health_bar = Node2D.new()
	health_bar.position = Vector2(-health_bar_width/2, 35)  # Center below tower
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
	
	# Update initial health bar
	update_health_bar()
	
	# Setup audio player for gunshot sound
	gunshot_audio_player = AudioStreamPlayer.new()
	gunshot_audio_player.stream = gunshot_sound
	add_child(gunshot_audio_player)

func _process(delta):
	if exploding:
		# Handle explosion effect
		explosion_time += delta
		var progress = explosion_time / explosion_duration
		
		# Scale up and fade out
		scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
		modulate.a = 1.0 - progress  # Fade out
		
		if explosion_time >= explosion_duration:
			print("Tower destroyed")
			queue_free()
		return
	
	# Tower shooting with cooldown
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	if (current_time - last_shot_time) >= shot_cooldown:
		# Find closest enemy in range
		var closest_enemy = null
		var closest_distance = tower_range
		
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				var distance = position.distance_to(enemy.position)
				if distance < closest_distance:
					closest_enemy = enemy
					closest_distance = distance
		
		if closest_enemy:
			shoot_at_enemy(closest_enemy)
			last_shot_time = current_time

func take_damage(amount: int, attacker = null):
	if exploding:
		return
		
	health -= amount
	print("Tower took damage: ", amount, " Health remaining: ", health)
	
	update_health_bar()
	
	# Flash white when taking damage
	modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	
	if health <= 0:
		start_explosion()
		# If there was an attacker, destroy it
		if attacker and is_instance_valid(attacker):
			attacker.start_explosion()

func start_explosion():
	print("Tower starting explosion")
	exploding = true
	explosion_time = 0.0

func shoot_at_enemy(target_enemy):
	if not is_instance_valid(target_enemy):
		return
		
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.position = position
	
	# Calculate direction to enemy
	var direction = (target_enemy.position - position).normalized()
	bullet.velocity = direction * bullet_speed 
	
	gunshot_audio_player.play()
	
# not used yet, I need to get the target_velocity first and to learn how Vector2 works in this aspect
func get_predicted_position(target_pos: Vector2, target_velocity: Vector2, bullet_speed: float) -> Vector2:
	var to_target = target_pos - position
	var a = target_velocity.length_squared() - bullet_speed * bullet_speed
	var b = 2 * to_target.dot(target_velocity)
	var c = to_target.length_squared()

	if abs(a) < 0.001:
		# Bullet speed ≈ target speed: fallback to naive aim
		return target_pos

	var discriminant = b * b - 4 * a * c
	if discriminant < 0:
		# No valid solution, aim directly at target
		return target_pos

	var t1 = (-b - sqrt(discriminant)) / (2 * a)
	var t2 = (-b + sqrt(discriminant)) / (2 * a)
	var t = min(t1, t2)
	
	if t < 0:
		t = max(t1, t2)
	if t < 0:
		# Both times negative, target is moving away too fast
		return target_pos

	return target_pos + target_velocity * t

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

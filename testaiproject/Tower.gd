extends Node2D

var bullet_scene = preload("res://Bullet.tscn")
var bullet_speed = 300
var tower_range = 300
var last_shot_time = 0.0
var shot_cooldown = 2.5  # Time between shots in seconds

# Tower health variables
var health = 100
var max_health = 100
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3

# Health bar variables
var health_bar: ProgressBar
var health_bar_width = 50
var health_bar_height = 5
var health_bar_offset = Vector2(0, 35)  # Position below the tower

func _ready():
	# Create visual representation
	var tower = ColorRect.new()
	tower.size = Vector2(50, 50)  # 50x50 pixel square
	tower.color = Color(0, 0, 1, 1)  # Blue color
	tower.position = Vector2(-25, -25)  # Center the square
	add_child(tower)
	
	# Create health bar
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(health_bar_width, health_bar_height)
	health_bar.position = Vector2(-health_bar_width/2, 0) + health_bar_offset
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	
	# Style the health bar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)  # Dark background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.5)  # Gray border
	health_bar.add_theme_stylebox_override("background", style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0, 1, 0)  # Green fill
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	add_child(health_bar)
	
	# Add to towers group for easy access
	add_to_group("towers")

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
	
	# Update health bar
	health_bar.value = health
	
	# Update health bar color based on health percentage
	var health_percent = float(health) / max_health
	var fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if health_percent > 0.6:
			fill_style.bg_color = Color(0, 1, 0)  # Green
		elif health_percent > 0.3:
			fill_style.bg_color = Color(1, 1, 0)  # Yellow
		else:
			fill_style.bg_color = Color(1, 0, 0)  # Red
	
	# Update tower color based on health percentage
	var tower = get_node_or_null("ColorRect")
	if tower:
		tower.color = Color(0, 0, 1, health_percent)  # Fade blue based on health
	
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

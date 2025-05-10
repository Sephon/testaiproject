extends Node2D

var mainRef

# Tower type enum
enum TowerType { GUN, LASER }

# Base tower variables
var tower_type: TowerType
var bullet_scene = preload("res://Bullet.tscn")
var bullet_speed = 0
var tower_range = 0
var last_shot_time = 0.0
var shot_cooldown = 0
var damage = 0
var gunshot_sound = preload("res://Sounds/gunshot.mp3")
var laser_sound = preload("res://Sounds/laser_shot.mp3")
var texture_path := "res://Sprites/Turret.png"
var sprite: Sprite2D

# Upgrade variables
var upgrade_cost = 10
var upgrade_multiplier = 1.1  # How much stats increase when upgraded
var tower_level = 1

var turret_turn_speed = 3.0  # Radians per second (adjust as needed)
var aim_threshold = 2 #degrees in which to fire
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

# Node references
var control: Control
var popup_menu: PopupMenu
var popup_world_position: Vector2
var fire_audio_player: AudioStreamPlayer

# Laser beam variables
var laser_beam: Line2D
var laser_width = 4.0
var laser_color = Color(1, 0.2, 0.2, 0.8)  # Red with slight transparency
var laser_fade_time = 0.1  # How long the laser beam stays visible
var current_laser_fade = 0.0

# Upgrade border variables
var upgrade_borders: Array[ColorRect] = []
var max_border_layers = 5  # Maximum number of border layers
var border_colors: Array[Color] = []  # Store colors for each layer

# Hover effect variables
var is_hovered = false
var hover_brightness = 2.0 # How much to brighten when hovered
var normal_brightness = 1.0

func _init(type: TowerType = TowerType.GUN):
	tower_type = type
	match tower_type:
		TowerType.GUN:
			bullet_speed = 300
			tower_range = 300
			shot_cooldown = 2.0
			damage = 5
		TowerType.LASER:
			bullet_speed = 0  # Lasers don't use bullet speed
			tower_range = 150
			shot_cooldown = 4.0
			damage = 20

func _ready():
	var texture = load(texture_path)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true  # viktigt för rotation runt mitten
	add_child(sprite)

	# Create upgrade borders first (so they're at the bottom)
	for i in range(max_border_layers):
		var border = ColorRect.new()
		border.visible = false
		border.z_index = -1  # Ensure borders are below everything
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Make borders ignore mouse input
		
		# Calculate and store the color for this layer
		var color = Color(1, 0.84, 0)  # Start with bright gold
		var darken_factor = i * 0.15  # Each layer gets 15% darker
		color.r = max(0.4, color.r - darken_factor)  # Keep some red
		color.g = max(0.3, color.g - darken_factor)  # Keep some green
		color.b = max(0.0, color.b - darken_factor)  # No blue in gold
		color.a = 0.8 - (i * 0.1)  # Each layer gets more transparent
		border.color = color
		border_colors.append(color)
		
		add_child(border)
		upgrade_borders.append(border)
	
	# Get node references
	control = $Control
	control.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure control captures mouse events
	
	# Create laser beam for laser tower
	if tower_type == TowerType.LASER:
		laser_beam = Line2D.new()
		laser_beam.width = laser_width
		laser_beam.default_color = laser_color
		laser_beam.visible = false
		add_child(laser_beam)
	
	# Create popup menu
	popup_menu = PopupMenu.new()
	update_popup_menu()
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	get_tree().root.add_child(popup_menu)
	
	# Connect input events
	control.gui_input.connect(_on_control_gui_input)
	control.mouse_entered.connect(_on_mouse_entered)
	control.mouse_exited.connect(_on_mouse_exited)
	
	# Create health bar container
	health_bar = Node2D.new()
	health_bar.position = Vector2(-health_bar_width/2, 35)
	add_child(health_bar)
	
	# Create background bar
	health_bar_bg = ColorRect.new()
	health_bar_bg.size = Vector2(health_bar_width, health_bar_height)
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar.add_child(health_bar_bg)
	
	# Create fill bar
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(health_bar_width, health_bar_height)
	health_bar_fill.color = Color(0, 1, 0, 0.8)
	health_bar.add_child(health_bar_fill)
	
	update_health_bar()
	
	# Setup audio player for gunshot sound
	fire_audio_player = AudioStreamPlayer.new()
	if tower_type == TowerType.LASER: 
		fire_audio_player.stream = laser_sound
	else:
		fire_audio_player.stream = gunshot_sound
		
	add_child(fire_audio_player)
	
func update_popup_menu():
	popup_menu.clear()
	var tower_name = "Gun Tower" if tower_type == TowerType.GUN else "Laser Tower"
	popup_menu.add_item("%s (level: %d)" % [tower_name, tower_level])
	popup_menu.set_item_disabled(0, true)
	popup_menu.add_item(str("Upgrade Tower (", tower_level * upgrade_cost, " coins)"))
	
	if mainRef.resources < (tower_level * upgrade_cost):
		popup_menu.set_item_disabled(1, true)

func _process(delta):
	# Keep health bar upright and in position
	health_bar.global_position = global_position + Vector2(-25, -30)  # Adjust Y offset as needed
	health_bar.rotation = -rotation
	
	if exploding:
		# Handle explosion effect
		explosion_time += delta
		var progress = explosion_time / explosion_duration
		
		# Scale up and fade out
		scale = Vector2.ONE * (1.0 + progress * 0.5)
		modulate.a = 1.0 - progress
		
		if explosion_time >= explosion_duration:
			print("Tower destroyed")
			queue_free()
		return
	
	# Update laser beam if it's visible
	if tower_type == TowerType.LASER and laser_beam.visible:
		current_laser_fade += delta
		if current_laser_fade >= laser_fade_time:
			laser_beam.visible = false
		else:
			# Fade out the laser
			var alpha = 1.0 - (current_laser_fade / laser_fade_time)
			laser_beam.default_color.a = alpha * 0.8  # Keep slight transparency
	
	# Tower shooting with cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	
	var closest = get_closest_enemy(tower_range +100 )
	if closest:
		var target_dir = (closest.global_position - global_position).normalized()
		var target_angle = target_dir.angle()
		var current_angle = global_rotation
		#var current_angle = rotation
		rotation = lerp_angle(current_angle, target_angle, turret_turn_speed * delta)
		#look_at(closest.global_position)	
	
	if (current_time - last_shot_time) >= shot_cooldown:		
		var closest_enemy = get_closest_enemy(tower_range)
		
		if closest_enemy and is_aimed_at_target(closest_enemy.position):
			shoot_at_enemy(closest_enemy)
			last_shot_time = current_time
	
	# If popup is visible, update its position based on camera movement
	if popup_menu.visible:
		var screen_pos = get_viewport().get_canvas_transform() * popup_world_position
		popup_menu.position = screen_pos
		
		var viewport_rect = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var popup_rect = Rect2(popup_menu.position, popup_menu.size)
		
		if not viewport_rect.intersects(popup_rect):
			popup_menu.hide()

func angular_distance(a, b):
	# Shortest distance between two angles, considering wrap-around
	return wrapf(b - a + PI, -PI, PI)

func is_aimed_at_target(target_position: Vector2) -> bool:
	var target_dir = (target_position - global_position).normalized()
	var target_angle = target_dir.angle() - PI / 2
	var angle_diff = abs(angular_distance(rotation, target_angle))
	print("angle diff: ", angle_diff)
	return angle_diff < aim_threshold
	
func get_closest_enemy(range):
	# Find closest enemy in range
	var closest_enemy = null
	var closest_distance = range

	for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				var distance = position.distance_to(enemy.position)
				if distance < closest_distance:
					closest_enemy = enemy
					closest_distance = distance					
	return closest_enemy

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
		
	fire_audio_player.play()
	if tower_type == TowerType.GUN:
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.position = position
		bullet.damage = damage
		
		# Get enemy's current velocity
		var target_velocity = target_enemy.current_direction * target_enemy.speed
		
		# Calculate predicted position
		var predicted_pos = get_predicted_position(target_enemy.position, target_velocity, bullet_speed)
		
		# Calculate direction to predicted position
		var direction = (predicted_pos - position).normalized()
		bullet.velocity = direction * bullet_speed
		
	else:  # Laser Tower
		# Create laser beam effect
		laser_beam.clear_points()
		# Convert world positions to laser_beam's local space
		var start_pos = laser_beam.to_local(global_position)
		var end_pos = laser_beam.to_local(target_enemy.global_position)
		laser_beam.add_point(Vector2.ZERO)  # Start at tower center
		#laser_beam.add_point(target_enemy.position - position)  # End at enemy
		laser_beam.add_point(end_pos)  # End at enemy
		
		
		# Reset laser beam properties
		laser_beam.default_color = laser_color
		laser_beam.visible = true
		current_laser_fade = 0.0
		
		# Apply damage to enemy
		target_enemy.take_damage(damage)
		
		# Add a small flash effect at the impact point
		var flash = ColorRect.new()
		flash.size = Vector2(10, 10)
		flash.color = Color(1, 1, 1, 0.8)  # White flash
		flash.position = target_enemy.position - position - Vector2(5, 5)  # Center the flash
		add_child(flash)
		
		# Animate the flash
		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.1)
		tween.tween_callback(flash.queue_free)

# Calculate where to aim based on target's movement
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

func _on_control_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Store the world position where popup was opened
			popup_world_position = get_global_mouse_position()
			# Set initial screen position
			update_popup_menu()
			popup_menu.position = event.global_position
			popup_menu.popup()

func _on_popup_menu_id_pressed(id: int):
	if id == 1:  # Upgrade Tower option
		upgrade_tower()

func update_upgrade_borders():
	# Hide all borders first
	for border in upgrade_borders:
		border.visible = false
	
	# Show borders based on tower level
	for i in range(min(tower_level, max_border_layers)):
		var border = upgrade_borders[i]
		var size = 20 + (i * 2)  # Base size + 2 pixels per level
		border.size = Vector2(size * 2, size * 2)  # Double for width and height
		border.position = Vector2(-size, -size)  # Center the border
		border.visible = true
		border.color = border_colors[i]  # Use the stored color for this layer

func upgrade_tower():
	tower_level += 1
	bullet_speed *= upgrade_multiplier
	tower_range *= upgrade_multiplier
	shot_cooldown /= upgrade_multiplier
	
	# Update the upgrade borders
	update_upgrade_borders()
	
	print("Tower upgraded! New stats:")
	print("Bullet Speed: ", bullet_speed)
	print("Tower Range: ", tower_range)
	print("Shot Cooldown: ", shot_cooldown)

func _on_mouse_entered():
	is_hovered = true
	modulate = Color(hover_brightness, hover_brightness, hover_brightness)

func _on_mouse_exited():
	is_hovered = false
	modulate = Color(normal_brightness, normal_brightness, normal_brightness)

extends Node2D

var bullet_scene = preload("res://Bullet.tscn")
var bullet_speed = 400
var tower_range = 200
var last_shot_time = 0.0
var shot_cooldown = 0.5  # Time between shots in seconds

func _ready():
	# Create visual representation
	var tower = ColorRect.new()
	tower.size = Vector2(50, 50)  # 50x50 pixel square
	tower.color = Color(0, 0, 1, 1)  # Blue color
	tower.position = Vector2(-25, -25)  # Center the square
	add_child(tower)

func _process(delta):
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

func shoot_at_enemy(target_enemy):
	if not is_instance_valid(target_enemy):
		return
		
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.position = position
	
	# Calculate direction to enemy
	var direction = (target_enemy.position - position).normalized()
	bullet.velocity = direction * bullet_speed 

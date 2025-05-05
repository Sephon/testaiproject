extends Area2D

var velocity = Vector2.ZERO
var collision_radius = 4  # Radius for collision detection

func _ready():
	# Create a small white circle for the bullet
	var circle = ColorRect.new()
	circle.size = Vector2(8, 8)  # 8x8 pixel square
	circle.color = Color.WHITE
	circle.position = Vector2(-4, -4)  # Center the square
	add_child(circle)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = collision_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set up collision properties
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)
	
	print("Bullet ready with collision shape")

func _process(delta):
	position += velocity * delta
	
	# Check for collision with enemy using distance
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and not enemy.is_queued_for_deletion():
			var distance = position.distance_to(enemy.position)
			if distance < collision_radius + 15:  # 15 is approximate enemy radius
				print("Bullet hit enemy! Distance: ", distance)
				enemy.start_explosion()  # Call the enemy's explosion function
				queue_free()  # Remove the bullet
				return
	
	# Remove bullet if it goes off screen
	var screen_rect = get_viewport().get_visible_rect()
	if not screen_rect.has_point(position):
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		print("Bullet hit enemy through signal!")
		body.start_explosion()
		queue_free() 

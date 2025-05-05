extends Area2D

var resource_type = "gold"  # Could be different types of resources
var collection_radius = 50  # How close player needs to be
var collection_rate = 1  # Resources per collection
var collection_cooldown = 2.0  # Seconds between collections
var last_collection_time = 0.0

# Resource exhaustion variables
var max_collections = 0  # Will be set randomly in _ready
var current_collections = 0
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3

func _ready():
	# Set random number of collections before exhaustion (1-10)
	max_collections = randi() % 10 + 1
	print("Resource node will exhaust after ", max_collections, " collections")
	
	# Create visual representation
	var circle = ColorRect.new()
	circle.size = Vector2(20, 20)  # 20x20 pixel square
	circle.color = Color.YELLOW  # Gold color
	circle.position = Vector2(-10, -10)  # Center the square
	add_child(circle)
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = collection_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set up collision properties
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)
	
	print("Resource node ready")

func _process(delta):
	if not exploding:
		# Get reference to player
		var player = get_node_or_null("/root/Main/Player")
		if player and not player.is_queued_for_deletion():
			var distance = position.distance_to(player.position)
			if distance < collection_radius:
				var current_time = Time.get_ticks_msec() / 1000.0
				if current_time - last_collection_time >= collection_cooldown:
					collect_resource()
					last_collection_time = current_time
	else:
		# Handle explosion effect
		explosion_time += delta
		var progress = explosion_time / explosion_duration
		
		# Scale up and fade out
		scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
		modulate.a = 1.0 - progress  # Fade out
		
		if explosion_time >= explosion_duration:
			print("Resource node exhausted and destroyed")
			queue_free()

func collect_resource():
	# Get the main scene to handle resource collection
	var main = get_node("/root/Main")
	if main:
		main.add_resources(resource_type, collection_rate)
		print("Collected ", collection_rate, " ", resource_type)
		
		current_collections += 1
		print("Collections remaining: ", max_collections - current_collections)
		
		if current_collections >= max_collections:
			start_explosion()

func start_explosion():
	print("Resource node exhausted, starting explosion")
	exploding = true
	explosion_time = 0.0

func _on_body_entered(body):
	if body.name == "Player":
		print("Player entered resource node area") 

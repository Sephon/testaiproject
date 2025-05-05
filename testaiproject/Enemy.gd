extends Area2D

var speed = 150
var collision_radius = 15
var exploding = false
var explosion_time = 0.0
var explosion_duration = 0.3

func _ready():
	body_entered.connect(_on_body_entered)
	
	print("Enemy ready with collision shape")

func _process(delta):
	if not exploding:
		# Get reference to player
		var player = get_node_or_null("/root/Main/Player")
		if player and not player.is_queued_for_deletion():
			# Calculate direction to player
			var direction = (player.position - position).normalized()
			# Move towards player
			position += direction * speed * delta
	else:
		# Handle explosion effect
		explosion_time += delta
		var progress = explosion_time / explosion_duration
		
		# Scale up and fade out
		scale = Vector2.ONE * (1.0 + progress * 0.5)  # Scale up to 1.5x
		modulate.a = 1.0 - progress  # Fade out
		
		if explosion_time >= explosion_duration:
			print("Enemy destroyed after explosion")
			queue_free()

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

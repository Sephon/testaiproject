extends Node2D

var duration = 0.5  # Total duration of the explosion
var elapsed_time = 0.0
var particles = []  # Array to store explosion particles
var num_particles = 12  # Number of particles in the explosion
var base_speed = 300  # Base speed of particles
var size_variation = 0.5  # How much the particle sizes can vary

class Particle:
	var rect: ColorRect
	var velocity: Vector2
	var rotation_speed: float
	var scale_speed: float
	var color: Color
	
	func _init(pos: Vector2, vel: Vector2, size: float, col: Color):
		rect = ColorRect.new()
		rect.size = Vector2(size, size)
		rect.position = pos
		rect.color = col
		velocity = vel
		rotation_speed = randf_range(-10, 10)  # Random rotation speed
		scale_speed = randf_range(0.5, 1.5)    # Random scale speed
		color = col

func _ready():
	# Create particles
	for i in range(num_particles):
		var angle = (2 * PI * i) / num_particles  # Evenly distribute particles
		var speed = base_speed * randf_range(0.8, 1.2)  # Add some randomness to speed
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		
		# Random size between 4 and 12
		var size = randf_range(4, 12)
		
		# Create a particle with random color variation
		var base_color = Color(1, 0.5, 0)  # Orange base color
		var color_variation = randf_range(-0.2, 0.2)
		var particle_color = Color(
			base_color.r + color_variation,
			base_color.g + color_variation,
			base_color.b + color_variation,
			1.0
		)
		
		var particle = Particle.new(Vector2.ZERO, velocity, size, particle_color)
		particles.append(particle)
		add_child(particle.rect)

func _process(delta):
	elapsed_time += delta
	var progress = elapsed_time / duration
	
	# Update each particle
	for particle in particles:
		# Move particle
		particle.rect.position += particle.velocity * delta
		
		# Rotate particle
		particle.rect.rotation_degrees += particle.rotation_speed
		
		# Scale particle (grow then shrink)
		var scale_factor = 1.0
		if progress < 0.5:
			scale_factor = 1.0 + progress * 2 * particle.scale_speed
		else:
			scale_factor = 2.0 * particle.scale_speed - (progress - 0.5) * 2 * particle.scale_speed
		particle.rect.scale = Vector2.ONE * scale_factor
		
		# Fade out
		particle.rect.modulate.a = 1.0 - progress
	
	# Remove the explosion when it's done
	if elapsed_time >= duration:
		queue_free() 

extends Node2D

var duration = 1.0  # How long the text stays visible
var fade_start = 0.75  # Start fading at 75% of duration
var float_distance = 1  # How fast text floats upwards
var start_position: Vector2
var label: Label  # Store the label reference as a class variable

func _ready():
	# Create the label
	label = Label.new()
	label.name = "Label"  # Give it a name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # Gold color
	label.position = Vector2(-50, -10)  # Center the text
	label.custom_minimum_size = Vector2(100, 20)  # Give it some space
	add_child(label)
	
	print("Label created and added to scene")  # Debug print
	
	# Store starting position
	start_position = position
	
	# Make sure we have the timer
	if not has_node("AnimationTimer"):
		print("ERROR: AnimationTimer not found!")
		var timer = Timer.new()
		timer.name = "AnimationTimer"
		add_child(timer)
		print("Created new AnimationTimer")
	
	# Configure the animation timer
	var timer = $AnimationTimer
	timer.wait_time = duration
	timer.one_shot = true
	timer.autostart = false  # Don't start automatically
	print("Timer configured - wait_time: ", timer.wait_time, ", one_shot: ", timer.one_shot)
	
	# Start the timer
	timer.start()
	print("Animation timer started for ", duration, " seconds")

func _process(delta):	
	var timer = $AnimationTimer
	if timer.time_left > 0:
		var progress = 1.0 - (timer.time_left / duration)
		
		# Move upward
		position = position + Vector2(0, -float_distance * progress)
		
		# Fade out
		if progress > fade_start:
			var fade_progress = (progress - fade_start) / (1.0 - fade_start)
			modulate.a = 1.0 - fade_progress
	else:
		queue_free()

func set_text(text: String):
	if label and is_instance_valid(label):
		label.text = text
		print("Text set to: ", text)  # Debug print 

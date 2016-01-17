extends Spatial

var time = 0.0;

func _ready():
	set_process(true);

func _process(delta):
	time += delta;
	
	if time>0.2 && get_node("Particles").is_emitting():
		get_node("Particles").set_emitting(false);
	
	if time>4.0:
		queue_free();
		set_process(false);
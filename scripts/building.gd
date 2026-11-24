extends Node2D

var team:int=0
var max_health:int=300
var health:int=300
var health_bar:Polygon2D

func _ready()->void:
	health_bar=Polygon2D.new()
	health_bar.position=Vector2(0,-36)
	add_child(health_bar)
	update_health_bar()

func update_health_bar()->void:
	if not is_instance_valid(health_bar): return
	var ratio=float(health)/float(max_health)
	health_bar.polygon=PackedVector2Array([Vector2(-18,-2),Vector2(-18+36*ratio,-2),Vector2(-18+36*ratio,2),Vector2(-18,2)])
	health_bar.color=Color(0.2,0.9,0.25) if ratio>0.5 else Color(1,0.65,0.1) if ratio>0.25 else Color(0.95,0.2,0.15)

func take_damage(amount:int)->void:
	health=max(0,health-amount)
	update_health_bar()
	if health<=0: queue_free()

extends Node2D

var team:int=0
var max_health:int=300
var health:int=300
var building_type:String=""
var attack_range:float=230.0
var attack_damage:int=20
var attack_timer:float=0.0
var attack_cooldown:float=1.5
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

func _process(delta:float)->void:
	if building_type!="Guard Tower" or team!=0: return
	attack_timer=max(0.0,attack_timer-delta)
	if attack_timer>0.0: return
	var parent=get_parent()
	if not parent.has_method("enemy_count"): return
	var target:Node2D=null
	var nearest=attack_range
	for u in parent.units:
		if is_instance_valid(u) and u.team==1 and u.health>0:
			var d=position.distance_to(u.position)
			if d<nearest:
				nearest=d
				target=u
	if target!=null:
		target.take_damage(attack_damage)
		attack_timer=attack_cooldown

func take_damage(amount:int)->void:
	health=max(0,health-amount)
	update_health_bar()
	if health<=0: queue_free()

extends Node2D

var team:int=0
var selected:bool=false
var destination:=Vector2.ZERO
var moving:=false
var speed:=120.0
var max_health:=100
var health:=100
var attack_damage:=15
var attack_range:=42.0\nvar detection_range:=220.0
var attack_cooldown:=1.0
var attack_timer:=0.0
var target:Node2D=null
var body:Polygon2D
var ring:Line2D
var health_bar:Polygon2D

func _ready() -> void:
	destination=position
	body=Polygon2D.new()
	body.polygon=PackedVector2Array([Vector2(0,-14),Vector2(9,-4),Vector2(7,8),Vector2(0,13),Vector2(-7,8),Vector2(-9,-4)])
	body.color=team_color()
	body.name="Body"
	add_child(body)
	ring=Line2D.new()
	ring.name="Ring"
	ring.points=PackedVector2Array([Vector2(-15,0),Vector2(0,-8),Vector2(15,0),Vector2(0,8),Vector2(-15,0)])
	ring.width=2.0
	ring.default_color=Color(1,0.9,0.3)
	add_child(ring)
	ring.visible=false
	health_bar=Polygon2D.new()
	health_bar.position=Vector2(0,-22)
	add_child(health_bar)
	update_health_bar()

func team_color()->Color:
	return Color(0.25,0.48,0.85) if team==0 else Color(0.8,0.25,0.22)

func set_team(t:int)->void:
	team=t
	if is_instance_valid(body): body.color=team_color()

func set_selected(v:bool)->void:
	selected=v
	if is_instance_valid(ring): ring.visible=v

func move_to(p:Vector2)->void:
	target=null
	destination=p
	moving=true

func attack_target(enemy:Node2D)->void:
	if enemy==null or not is_instance_valid(enemy): return
	target=enemy
	moving=false

func acquire_player_target()->void:\n\tvar parent=get_parent()\n\tif not parent.has_method("enemy_count"): return\n\tvar closest:Node2D=null\n\tvar nearest=detection_range\n\tfor candidate in parent.units:\n\t\tif is_instance_valid(candidate) and candidate.team==0 and candidate.health>0:\n\t\t\tvar distance=position.distance_to(candidate.position)\n\t\t\tif distance<nearest:\n\t\t\t\tnearest=distance\n\t\t\t\tclosest=candidate\n\tif closest!=null: attack_target(closest)\n\nfunc take_damage(amount:int)->void:
	health=max(0,health-amount)
	update_health_bar()
	if health<=0:
		queue_free()

func update_health_bar()->void:
	if not is_instance_valid(health_bar): return
	var ratio=float(health)/float(max_health)
	health_bar.polygon=PackedVector2Array([Vector2(-12,-2),Vector2(-12+24*ratio,-2),Vector2(-12+24*ratio,2),Vector2(-12,2)])
	health_bar.color=Color(0.2,0.9,0.25) if ratio>0.5 else Color(1,0.65,0.1) if ratio>0.25 else Color(0.95,0.2,0.15)

func _process(delta:float)->void:
	attack_timer=max(0.0,attack_timer-delta)
	if target!=null:
		if not is_instance_valid(target) or target.health<=0:
			target=null
		else:
			var d=target.position-position
			if d.length()>attack_range:
				position+=d.normalized()*min(speed*delta,d.length()-attack_range+2.0)
			elif attack_timer<=0.0:
				target.take_damage(attack_damage)
				attack_timer=attack_cooldown
				if target!=null and is_instance_valid(target) and target.health>0:
					target.attack_target(self)
	if moving and target==null:
		var d=destination-position
		if d.length()<3.0:
			position=destination
			moving=false
		else:
			position+=d.normalized()*min(speed*delta,d.length())

extends Node2D

var team:int=0
var selected:bool=false
var destination:=Vector2.ZERO
var moving:=false
var speed:=120.0
var max_health:=100
var health:=100
var attack_damage:=15
var attack_range:=42.0
var detection_range:=220.0
var attack_cooldown:=1.0
var attack_timer:=0.0
var acquire_timer:=0.0
var harvest_target_node:Node2D=null
var harvest_timer:=0.0
var carried_amount:=0
var carried_type:String=""
var cargo_capacity:=100
var storage_target:Node2D=null
var resume_harvest_node:Node2D=null
var build_target_site:Node2D=null
var target:Node2D=null
var body:Polygon2D
var ring:Line2D
var health_bar:Polygon2D

func _ready()->void:
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
	harvest_target_node=null
	storage_target=null
	build_target_site=null
	carried_amount=0
	carried_type=""
	destination=p
	moving=true

func harvest_target(node:Node2D)->void:
	if node==null or not is_instance_valid(node) or team!=0:return
	target=null
	storage_target=null
	harvest_target_node=node
	if carried_amount>=cargo_capacity:
		return_to_storage()
	else:
		moving=true
		destination=node.position

func return_to_storage()->void:
	var parent=get_parent()
	if parent==null:return
	storage_target=parent.get_nearest_storage(position)
	harvest_target_node=null
	moving=storage_target!=null
	if storage_target!=null:destination=storage_target.position

func build_target(site:Node2D)->void:
	if team!=0 or site==null or not is_instance_valid(site) or site.is_complete:return
	target=null
	harvest_target_node=null
	storage_target=null
	build_target_site=site
	moving=true
	destination=site.position

func attack_target(enemy:Node2D)->void:
	harvest_target_node=null
	storage_target=null
	if enemy==null or not is_instance_valid(enemy):return
	target=enemy
	moving=false

func acquire_player_target()->void:
	var parent=get_parent()
	if not parent.has_method("enemy_count"):return
	var closest:Node2D=null
	var nearest=detection_range
	for candidate in parent.units:
		if is_instance_valid(candidate) and candidate.team==0 and candidate.health>0:
			var distance=position.distance_to(candidate.position)
			if distance<nearest:
				nearest=distance
				closest=candidate
	if closest!=null:attack_target(closest)

func take_damage(amount:int)->void:
	health=max(0,health-amount)
	update_health_bar()
	if health<=0:queue_free()

func update_health_bar()->void:
	if not is_instance_valid(health_bar):return
	var ratio=float(health)/float(max_health)
	health_bar.polygon=PackedVector2Array([Vector2(-12,-2),Vector2(-12+24*ratio,-2),Vector2(-12+24*ratio,2),Vector2(-12,2)])
	health_bar.color=Color(0.2,0.9,0.25) if ratio>0.5 else Color(1,0.65,0.1) if ratio>0.25 else Color(0.95,0.2,0.15)

func _process(delta:float)->void:
	if storage_target!=null:
		if not is_instance_valid(storage_target) or storage_target.health<=0:
			storage_target=null
			moving=false
		elif position.distance_to(storage_target.position)<=38.0:
			moving=false
			var parent=get_parent()
			if parent!=null and carried_amount>0:
				var delivered:int=parent.deliver_resource(carried_type,carried_amount)
				carried_amount-=delivered
				if carried_amount<=0:
					carried_type=""
					storage_target=null
					if is_instance_valid(harvest_target_node):
						harvest_target(harvest_target_node)
				else:
						moving=false
			else:
				moving=true
				destination=storage_target.position
		else:
			moving=true
			destination=storage_target.position
	if harvest_target_node!=null:
		if not is_instance_valid(harvest_target_node) or harvest_target_node.amount<=0:
			harvest_target_node=null
			if carried_amount>0:
				return_to_storage()
			else:
				moving=false
		else:
			var hd:Vector2=harvest_target_node.position-position
			if hd.length()>30.0:
				moving=true
				destination=harvest_target_node.position
			else:
				moving=false
				harvest_timer+=delta
				if carried_amount>=cargo_capacity:
					return_to_storage()
				elif harvest_timer>=1.5:
					harvest_timer=0.0
					var gathered:int=harvest_target_node.harvest(min(10,cargo_capacity-carried_amount))
					carried_amount+=gathered
					carried_type=harvest_target_node.resource_type
					if carried_amount>=cargo_capacity or harvest_target_node.amount<=0:
						return_to_storage()
	if build_target_site!=null:
		if not is_instance_valid(build_target_site) or build_target_site.is_complete:
			build_target_site=null
			moving=false
		elif position.distance_to(build_target_site.position)<=42.0:
			moving=false
			build_target_site.add_build_work(delta*12.0)
		else:
			moving=true
			destination=build_target_site.position
	attack_timer=max(0.0,attack_timer-delta)
	acquire_timer-=delta
	if team==1 and target==null and acquire_timer<=0.0:
		acquire_timer=1.5
		acquire_player_target()
	if target!=null:
		if not is_instance_valid(target) or target.health<=0:
			target=null
		else:
			var d:Vector2=target.position-position
			if d.length()>attack_range:
				var step:Vector2=d.normalized()*min(speed*delta,d.length()-attack_range+2.0)
				var parent=get_parent()
				var candidate=position+step
				if not parent.has_method("is_unit_position_blocked") or not parent.is_unit_position_blocked(candidate,self,target):
					position=candidate
				else:
					var slide_x=position+Vector2(step.x,0)
					var slide_y=position+Vector2(0,step.y)
					if not parent.is_unit_position_blocked(slide_x,self,target):position=slide_x
					elif not parent.is_unit_position_blocked(slide_y,self,target):position=slide_y
			elif attack_timer<=0.0:
				target.take_damage(attack_damage)
				attack_timer=attack_cooldown
				if is_instance_valid(target) and target.health>0 and target.has_method("attack_target") and target.team!=team:
					target.attack_target(self)
	if moving and target==null:
		var d2:Vector2=destination-position
		if d2.length()<3.0 and harvest_target_node==null and storage_target==null and build_target_site==null:
			position=destination
			moving=false
		else:
			var step2:Vector2=d2.normalized()*min(speed*delta,d2.length())
			var candidate2=position+step2
			var parent2=get_parent()
			if not parent2.has_method("is_unit_position_blocked") or not parent2.is_unit_position_blocked(candidate2,self):
				position=candidate2
			else:
				var slide_x2=position+Vector2(step2.x,0)
				var slide_y2=position+Vector2(0,step2.y)
				if not parent2.is_unit_position_blocked(slide_x2,self):position=slide_x2
				elif not parent2.is_unit_position_blocked(slide_y2,self):position=slide_y2

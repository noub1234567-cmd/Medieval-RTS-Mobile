extends Node2D

var team:int=0
var selected:bool=false
var destination:=Vector2.ZERO
var moving:=false
var speed:=120.0
var body:Polygon2D
var ring:Line2D

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

func team_color()->Color:
	return Color(0.25,0.48,0.85) if team==0 else Color(0.8,0.25,0.22)

func set_team(t:int)->void:
	team=t
	if is_instance_valid(body):
		body.color=team_color()

func set_selected(v:bool)->void:
	selected=v
	if is_instance_valid(ring):
		ring.visible=v

func move_to(p:Vector2)->void:
	destination=p
	moving=true

func _process(delta:float)->void:
	if moving:
		var d:=destination-position
		if d.length()<3.0:
			position=destination
			moving=false
		else:
			position+=d.normalized()*min(speed*delta,d.length())

extends Node2D

var team=0
var selected=false
var destination:Vector2
var moving=false
var speed=120.0

func _ready():
	destination=position
	var body=Polygon2D.new()
	body.polygon=PackedVector2Array([Vector2(0,-14),Vector2(9,-4),Vector2(7,8),Vector2(0,13),Vector2(-7,8),Vector2(-9,-4)])
	body.color=Color(0.25,0.48,0.85)
	body.name="Body"
	add_child(body)
	var ring=Line2D.new()
	ring.name="Ring"
	ring.points=PackedVector2Array([Vector2(-15,0),Vector2(0,-8),Vector2(15,0),Vector2(0,8),Vector2(-15,0)])
	ring.width=2
	ring.default_color=Color(1,0.9,0.3)
	add_child(ring)
	ring.visible=false

func set_team(t):
	team=t
	if has_node("Body"): $Body.color=Color(0.25,0.48,0.85) if team==0 else Color(0.8,0.25,0.22)

func set_selected(v):
	selected=v
	if has_node("Ring"): $Ring.visible=v

func move_to(p):
	destination=p
	moving=true

func _process(delta):
	if moving:
		var d=destination-position
		if d.length()<3:
			position=destination
			moving=false
		else:
			position+=d.normalized()*min(speed*delta,d.length())

extends Node2D

const GRID = Vector2i(40, 40)
const TILE_W = 64.0
const TILE_H = 32.0
const UnitScene = preload("res://scenes/unit.tscn")

var units: Array[Node2D] = []
var selected: Array[Node2D] = []
var drag_start := Vector2.ZERO
var dragging := false
var camera_offset := Vector2.ZERO
var zoom_level := 1.0

@onready var overlay = $SelectionOverlay

func _ready():
	for y in range(GRID.y):
		for x in range(GRID.x):
			var tile = Polygon2D.new()
			tile.polygon = PackedVector2Array([Vector2(0,-TILE_H/2),Vector2(TILE_W/2,0),Vector2(0,TILE_H/2),Vector2(-TILE_W/2,0)])
			tile.position = grid_to_screen(Vector2i(x,y))
			tile.color = tile_color(x,y)
			tile.z_index = -10
			add_child(tile)
			var outline = Line2D.new()
			outline.points = PackedVector2Array([Vector2(0,-TILE_H/2),Vector2(TILE_W/2,0),Vector2(0,TILE_H/2),Vector2(-TILE_W/2,0),Vector2(0,-TILE_H/2)])
			outline.width = 1
			outline.default_color = Color(0.15,0.2,0.13,0.2)
			tile.add_child(outline)
	for i in range(8):
		var u = UnitScene.instantiate()
		add_child(u)
		u.position = grid_to_screen(Vector2i(12+i%4, 12+i/4))
		units.append(u)
		u.set_team(0)
	for i in range(4):
		var e = UnitScene.instantiate()
		add_child(e)
		e.position = grid_to_screen(Vector2i(25+i%2, 25+i/2))
		e.set_team(1)
		units.append(e)
	update_view()

func tile_color(x:int,y:int)->Color:
	var v = ((x*17+y*31)%11)/100.0
	return Color(0.23+v,0.42+v,0.22+v*0.5)

func grid_to_screen(cell:Vector2i)->Vector2:
	return Vector2((cell.x-cell.y)*TILE_W/2,(cell.x+cell.y)*TILE_H/2)

func screen_to_world(p:Vector2)->Vector2:
	return (p-camera_offset)/zoom_level

func world_to_grid(p:Vector2)->Vector2i:
	var x = p/TILE_W
	var y = p/TILE_H
	return Vector2i(round(x+y),round(y-x))

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			drag_start = screen_to_world(event.position)
			dragging = true
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if dragging:
				finish_selection(screen_to_world(event.position))
				dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				move_selected(screen_to_world(event.position))
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_level = min(zoom_level*1.1,2.0)
				update_view()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_level = max(zoom_level/1.1,0.5)
				update_view()
		elif event is InputEventMouseMotion and dragging:
			overlay.set_rect(Rect2(drag_start,screen_to_world(event.position)-drag_start))
		elif event is InputEventScreenTouch:
			if event.pressed:
				drag_start=screen_to_world(event.position)
				dragging=true
			else:
				if dragging: finish_selection(screen_to_world(event.position))
				dragging=false
		elif event is InputEventScreenDrag and dragging:
			overlay.set_rect(Rect2(drag_start,screen_to_world(event.position)-drag_start))

func finish_selection(end_pos:Vector2):
	var box = Rect2(drag_start,end_pos-drag_start).abs()
	if box.size.length()<12:
		var nearest=null
		var distance=36.0
		for u in units:
			if u.team==0:
				var d=u.position.distance_to(end_pos)
				if d<distance: distance=d;nearest=u
			clear_selection()
			if nearest: add_selection(nearest)
	else:
		clear_selection()
		for u in units:
			if u.team==0 and box.has_point(u.position): add_selection(u)
	overlay.clear_rect()
	update_view()

func clear_selection():
	for u in selected: u.set_selected(false)
	selected.clear()

func add_selection(u):
	if not selected.has(u):
		selected.append(u)
		u.set_selected(true)

func move_selected(target:Vector2):
	for i in range(selected.size()):
		selected[i].move_to(target+Vector2((i%3)*18,(i/3)*18))

func update_view():
	position=camera_offset
	scale=Vector2(zoom_level,zoom_level)

func _process(delta):
	var motion=Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): motion.x+=1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): motion.x-=1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): motion.y+=1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): motion.y-=1
	camera_offset+=motion*500*delta
	update_view()

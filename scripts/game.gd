extends Node2D

const GRID := Vector2i(40, 40)
const TILE_W := 64.0
const TILE_H := 32.0
const UnitScene := preload("res://scenes/unit.tscn")
const OverlayScene := preload("res://scenes/selection_overlay.tscn")

var units: Array[Node2D] = []
var selected: Array[Node2D] = []
var drag_start := Vector2.ZERO
var dragging := false
var camera_offset := Vector2(0, -640)
var zoom_level := 1.0
var drag_current := Vector2.ZERO
var touch_pending := false

var hud: CanvasLayer
var status_label: Label
var help_label: Label
var resources := {"wood": 300, "food": 250, "gold": 200}
var buildings: Array[Node2D] = []
var placing_building := false
var pending_building := ""
var population := 8
var population_cap := 8
var income_timer := 0.0
var building_cost := {"Farm": {"wood": 80, "gold": 30}, "House": {"wood": 100, "gold": 50}, "Barracks": {"wood": 150, "gold": 80}}

func _ready() -> void:
	var overlay := OverlayScene.instantiate()
	overlay.name = "SelectionOverlay"
	add_child(overlay)
	for y in range(GRID.y):
		for x in range(GRID.x):
			var tile := Polygon2D.new()
			tile.polygon = PackedVector2Array([Vector2(0,-TILE_H/2),Vector2(TILE_W/2,0),Vector2(0,TILE_H/2),Vector2(-TILE_W/2,0)])
			tile.position = grid_to_screen(Vector2i(x,y))
			tile.color = tile_color(x,y)
			tile.z_index = -10
			add_child(tile)
			var outline := Line2D.new()
			outline.points = PackedVector2Array([Vector2(0,-TILE_H/2),Vector2(TILE_W/2,0),Vector2(0,TILE_H/2),Vector2(-TILE_W/2,0),Vector2(0,-TILE_H/2)])
			outline.width = 1.0
			outline.default_color = Color(0.12,0.18,0.1,0.24)
			tile.add_child(outline)
	add_map_details()
	for i in range(8):
		var u: Node2D = UnitScene.instantiate()
		add_child(u)
		u.set_team(0)
		u.position = grid_to_screen(Vector2i(12+i%4, 12+i/4))
		units.append(u)
	for i in range(4):
		var e: Node2D = UnitScene.instantiate()
		add_child(e)
		e.set_team(1)
		e.position = grid_to_screen(Vector2i(25+i%2, 25+i/2))
		units.append(e)
	create_hud()
	update_view()
	update_status()

func add_map_details() -> void:
	# Small decorative woodland patches, avoiding the starting armies.
	for p in [Vector2i(6,7),Vector2i(7,7),Vector2i(6,8),Vector2i(33,10),Vector2i(34,10),Vector2i(33,11),Vector2i(8,30),Vector2i(9,30),Vector2i(8,31)]:
		var tree := Polygon2D.new()
		tree.polygon = PackedVector2Array([Vector2(0,-22),Vector2(12,-6),Vector2(8,7),Vector2(0,12),Vector2(-8,7),Vector2(-12,-6)])
		tree.position = grid_to_screen(p)+Vector2(0,-10)
		tree.color = Color(0.12,0.32,0.16)
		tree.z_index = 1
		add_child(tree)

func tile_color(x:int,y:int) -> Color:
	var v := float((x*17+y*31)%11)/100.0
	if (x+y)%9==0:
		return Color(0.28+v,0.39+v,0.2+v*0.5)
	return Color(0.23+v,0.42+v,0.22+v*0.5)

func grid_to_screen(cell:Vector2i) -> Vector2:
	return Vector2((cell.x-cell.y)*TILE_W/2,(cell.x+cell.y)*TILE_H/2)

func screen_to_world(p:Vector2) -> Vector2:
	return (p-camera_offset)/zoom_level

func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start=screen_to_world(event.position)
				drag_current=drag_start
				dragging=true
			elif dragging:
				finish_selection(screen_to_world(event.position))
				dragging=false
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			if placing_building: place_building(screen_to_world(event.position))
			else: move_selected(screen_to_world(event.position))
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP:
			zoom_level=min(zoom_level*1.1,2.0)
			update_view()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level=max(zoom_level/1.1,0.45)
			update_view()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		placing_building=false
		help_label.text="Placement cancelled"
	elif event is InputEventMouseMotion and dragging:
		drag_current=screen_to_world(event.position)
		overlay_update()
	elif event is InputEventScreenTouch:
		if event.pressed:
			drag_start=screen_to_world(event.position)
			drag_current=drag_start
			dragging=true
		elif dragging:
			finish_selection(screen_to_world(event.position))
			dragging=false
	elif event is InputEventScreenDrag and dragging:
		drag_current=screen_to_world(event.position)
		overlay_update()

func overlay_update() -> void:
	var overlay:Node = get_node("SelectionOverlay")
	overlay.set_rect(Rect2(drag_start,drag_current-drag_start).abs())

func finish_selection(end_pos:Vector2) -> void:
	if placing_building:
		place_building(end_pos)
		get_node("SelectionOverlay").clear_rect()
		return
	var box := Rect2(drag_start,end_pos-drag_start).abs()
	if box.size.length()<14.0:
		var nearest:Node2D=null
		var distance:=44.0
		for u in units:
			if u.team==0:
				var d:=u.position.distance_to(end_pos)
				if d<distance:
					distance=d
					nearest=u
		clear_selection()
		if nearest!=null:
			add_selection(nearest)
	else:
		clear_selection()
		for u in units:
			if u.team==0 and box.has_point(u.position):
				add_selection(u)
	get_node("SelectionOverlay").clear_rect()
	update_status()

func clear_selection() -> void:
	for u in selected:
		u.set_selected(false)
	selected.clear()

func add_selection(u:Node2D) -> void:
	if not selected.has(u):
		selected.append(u)
		u.set_selected(true)

func move_selected(target:Vector2) -> void:
	if selected.is_empty():
		return
	for i in range(selected.size()):
		var offset:=Vector2((i%3)*20-20,(i/3)*18)
		selected[i].move_to(target+offset)

func update_view() -> void:
	position=camera_offset
	scale=Vector2(zoom_level,zoom_level)

func create_hud() -> void:
	hud=CanvasLayer.new()
	add_child(hud)
	var panel:=PanelContainer.new()
	panel.position=Vector2(12,12)
	panel.add_theme_stylebox_override("panel",make_panel_style())
	hud.add_child(panel)
	var v:=VBoxContainer.new()
	panel.add_child(v)
	var title:=Label.new()
	title.text="MEDIEVAL RTS  •  DEMO"
	title.add_theme_font_size_override("font_size",20)
	v.add_child(title)
	status_label=Label.new()
	v.add_child(status_label)
	var buttons:=HBoxContainer.new()
	v.add_child(buttons)
	var recruit:=Button.new()
	recruit.text="Recruit soldier"
	recruit.pressed.connect(recruit_soldier)
	buttons.add_child(recruit)
	for building_name in ["Farm", "House", "Barracks"]:
		var b:=Button.new()
		b.text=building_name
		b.pressed.connect(func(): begin_placement(building_name))
		buttons.add_child(b)
	help_label=Label.new()
	help_label.text="Select: tap / drag     Move: right-click\nCamera: WASD / arrows     Zoom: wheel"
	help_label.add_theme_font_size_override("font_size",14)
	v.add_child(help_label)

func make_panel_style() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(0.07,0.09,0.07,0.88)
	s.border_color=Color(0.55,0.48,0.3,0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=8
	s.content_margin_bottom=8
	return s

func recruit_soldier() -> void:
	var has_barracks:=false
	for b in buildings:
		if b.name=="Barracks": has_barracks=true
	if not has_barracks:
		help_label.text="Build a Barracks first"
		return
	if population>=population_cap:
		help_label.text="Population limit reached"
		return
	if resources.food<50 or resources.gold<25:
		help_label.text="Recruitment costs 50 food and 25 gold"
		return
	resources.food-=50
	resources.gold-=25
	population+=1
	var soldier:Node2D=UnitScene.instantiate()
	add_child(soldier)
	soldier.set_team(0)
	var barracks:Node2D=buildings.filter(func(b): return b.name=="Barracks")[0]
	soldier.position=barracks.position+Vector2(30,20)
	units.append(soldier)
	update_status()
	help_label.text="Soldier recruited!"

func enemy_count() -> int:
	var count:=0
	for u in units:
		if u.team==1: count+=1
	return count

func begin_placement(building_name:String) -> void:
	placing_building=true
	pending_building=building_name
	help_label.text="Tap map to place %s (Esc cancels)" % building_name

func place_building(pos:Vector2) -> void:
	if not placing_building: return
	var cost:Dictionary=building_cost[pending_building]
	for key in cost:
		if resources[key]<cost[key]:
			help_label.text="Not enough %s" % key
			placing_building=false
			return
	for key in cost: resources[key]-=cost[key]
	var structure:=Node2D.new()
	structure.name=pending_building
	structure.position=pos
	var shape:=Polygon2D.new()
	shape.polygon=PackedVector2Array([Vector2(0,-26),Vector2(24,-10),Vector2(24,12),Vector2(0,28),Vector2(-24,12),Vector2(-24,-10)])
	shape.color={"Farm":Color(0.65,0.55,0.25),"House":Color(0.65,0.3,0.22),"Barracks":Color(0.3,0.32,0.4)}[pending_building]
	structure.add_child(shape)
	var label:=Label.new()
	label.text=pending_building
	label.position=Vector2(-32,-42)
	label.scale=Vector2(0.8,0.8)
	structure.add_child(label)
	add_child(structure)
	buildings.append(structure)
	if pending_building=="House": population_cap+=5
	placing_building=false
	help_label.text="Right-click moves units. Choose building then tap map."
	update_status()

func update_status() -> void:
	if status_label:
		status_label.text="Wood: %d  Food: %d  Gold: %d\nPopulation: %d/%d  Selected: %d  Enemies: %d\nBuildings: %d" % [resources.wood,resources.food,resources.gold,population,population_cap,selected.size(),enemy_count(),buildings.size()]

func _process(delta:float) -> void:
	income_timer+=delta
	if income_timer>=5.0:
		income_timer=0.0
		for b in buildings:
			if b.name=="Farm": resources.food+=10
			elif b.name=="House": resources.gold+=3
		update_status()
	var motion:=Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): motion.x+=1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): motion.x-=1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): motion.y+=1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): motion.y-=1
	if motion!=Vector2.ZERO:
		camera_offset+=motion.normalized()*520.0*delta
		update_view()

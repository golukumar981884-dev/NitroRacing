extends Node3D

const MOVE_SPEED := 4.2
const ATTACK_RANGE := 2.25
var player_team: Array[Node3D] = []
var enemy: Node3D
var active_index := 0
var player_hp := 100.0
var enemy_hp := 100.0
var attack_cooldown := 0.0
var enemy_cooldown := 0.0
var move_dir := 0.0
var ui: CanvasLayer
var hp_player: ProgressBar
var hp_enemy: ProgressBar
var status: Label
var touch_move_left := false
var touch_move_right := false

func _ready() -> void:
	_build_arena()
	player_team.append(_fighter("STRIKER", Color(0.08,0.48,0.95), Vector3(-2.0,0,0)))
	player_team.append(_fighter("PHANTOM", Color(0.78,0.16,0.32), Vector3(-3.0,0,0)))
	player_team[1].visible = false
	enemy = _fighter("RIVAL", Color(0.95,0.55,0.08), Vector3(2.0,0,0))
	enemy.rotation.y = PI
	_make_camera()
	_make_ui()

func _build_arena() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035,0.055,0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48,0.55,0.72)
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	_box("Arena Floor", Vector3(0,-0.25,0), Vector3(14,0.5,10), Color(0.09,0.12,0.17))
	_box("Ring", Vector3(0,0.02,0), Vector3(10.5,0.08,7.2), Color(0.16,0.22,0.3))
	for x in [-5.3,5.3]:
		_box("Neon rail", Vector3(x,0.25,0), Vector3(0.12,0.5,7.4), Color(0.05,0.65,0.95))
	for z in [-3.7,3.7]:
		_box("Neon rail", Vector3(0,0.25,z), Vector3(10.7,0.5,0.12), Color(0.05,0.65,0.95))
	for i in range(8):
		var pillar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.32
		mesh.height = 4.0
		pillar.mesh = mesh
		pillar.position = Vector3(-6.3 + float(i%4)*4.2,1.8,-4.8 if i<4 else 4.8)
		pillar.material_override = _mat(Color(0.11,0.16,0.24),0.35,0.4)
		add_child(pillar)

func _fighter(label: String, color: Color, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.name = label
	add_child(root)
	var suit := _mat(color,0.28,0.45)
	var dark := _mat(Color(0.045,0.055,0.075),0.25,0.5)
	var skin := _mat(Color(0.72,0.48,0.34),0.35,0.35)
	_part(root,"Torso",Vector3(0,1.35,0),Vector3(0.72,0.9,0.42),suit)
	_part(root,"Chest armor",Vector3(0,1.52,-0.225),Vector3(0.48,0.38,0.06),_mat(color.lightened(0.25),0.2,0.35))
	_part(root,"Head",Vector3(0,2.05,0),Vector3(0.42,0.48,0.4),skin,true)
	_part(root,"Hair",Vector3(0,2.28,0.02),Vector3(0.44,0.16,0.42),dark)
	for side in [-1.0,1.0]:
		_part(root,"Shoulder",Vector3(side*0.48,1.62,0),Vector3(0.34,0.32,0.38),suit,true)
		_part(root,"Arm",Vector3(side*0.55,1.18,-0.02),Vector3(0.23,0.65,0.25),skin,true)
		_part(root,"Glove",Vector3(side*0.57,0.82,-0.08),Vector3(0.28,0.24,0.28),dark,true)
		_part(root,"Leg",Vector3(side*0.2,0.48,0),Vector3(0.29,0.72,0.34),dark)
		_part(root,"Boot",Vector3(side*0.2,0.12,-0.1),Vector3(0.34,0.2,0.55),suit)
	return root

func _part(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material, sphere := false) -> void:
	var m := MeshInstance3D.new()
	if sphere:
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		m.mesh = sm
	else:
		m.mesh = BoxMesh.new()
	m.name = label
	m.position = pos
	m.scale = size if sphere else Vector3.ONE
	if not sphere:
		(m.mesh as BoxMesh).size = size
	m.material_override = material
	parent.add_child(m)

func _box(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.name = label
	m.material_override = _mat(color,0.5,0.25)
	add_child(m)

func _mat(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func _make_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0,5.4,10.8)
	camera.look_at(Vector3(0,1.1,0),Vector3.UP)
	camera.fov = 48
	add_child(camera)
	camera.current = true

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var top := Panel.new()
	top.position = Vector2(30,22)
	top.size = Vector2(1220,92)
	top.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.04,0.08,0.88)))
	ui.add_child(top)
	hp_player = _bar(Vector2(55,42),Color(0.05,0.65,1.0),100)
	hp_enemy = _bar(Vector2(860,42),Color(1.0,0.28,0.12),100)
	var title := Label.new()
	title.text = "TAG ARENA  /  ROUND 01"
	title.position = Vector2(510,48)
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color(0.85,0.95,1))
	ui.add_child(title)
	status = Label.new()
	status.position = Vector2(515,112)
	status.add_theme_font_size_override("font_size",18)
	status.text = "FIGHT!"
	ui.add_child(status)
	_button("◀",Vector2(42,570),Callable(self,"_hold_left"),Callable(self,"_release_move"))
	_button("▶",Vector2(142,570),Callable(self,"_hold_right"),Callable(self,"_release_move"))
	_button("TAG",Vector2(1040,565),Callable(self,"_tag"),Callable())
	_button("PUNCH",Vector2(890,565),Callable(self,"_punch"),Callable())
	_button("KICK",Vector2(1160,565),Callable(self,"_kick"),Callable())

func _panel_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.border_width_bottom = 2
	s.border_color = Color(0.05,0.55,0.9)
	return s

func _bar(pos: Vector2, color: Color, value: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(330,26)
	b.max_value = 100
	b.value = value
	b.show_percentage = false
	b.add_theme_stylebox_override("background",_panel_style(Color(0.12,0.14,0.19)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 8
	fill.corner_radius_bottom_left = 8
	b.add_theme_stylebox_override("fill",fill)
	ui.add_child(b)
	return b

func _button(text_value: String, pos: Vector2, down: Callable, up: Callable) -> void:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = Vector2(88,78)
	b.add_theme_font_size_override("font_size",20)
	b.add_theme_stylebox_override("normal",_panel_style(Color(0.035,0.09,0.16,0.92)))
	b.add_theme_stylebox_override("pressed",_panel_style(Color(0.02,0.42,0.72,0.98)))
	b.button_down.connect(down)
	if up.is_valid():
		b.button_up.connect(up)
	ui.add_child(b)

func _hold_left() -> void: touch_move_left = true
func _hold_right() -> void: touch_move_right = true
func _release_move() -> void:
	touch_move_left = false
	touch_move_right = false

func _tag() -> void:
	active_index = 1-active_index
	for i in range(player_team.size()):
		player_team[i].visible = i == active_index
	player_team[active_index].position = Vector3(-2.0,0,0)
	player_team[1-active_index].position = Vector3(-3.2,0,-0.4)
	status.text = player_team[active_index].name + " TAG IN!"

func _punch() -> void: _hit(8.0,"PUNCH")
func _kick() -> void: _hit(13.0,"KICK")

func _hit(damage: float, move_name: String) -> void:
	if attack_cooldown > 0: return
	attack_cooldown = 0.48
	if player_team[active_index].global_position.distance_to(enemy.global_position) <= ATTACK_RANGE:
		enemy_hp = maxf(0,enemy_hp-damage)
		enemy.position.x = minf(4.2,enemy.position.x+0.28)
		status.text = move_name + "  HIT!"
	else:
		status.text = move_name + "  MISS"
	hp_enemy.value = enemy_hp
	if enemy_hp <= 0: status.text = "YOU WIN!  TAP TO KEEP FIGHTING"

func _process(delta: float) -> void:
	attack_cooldown = maxf(0,attack_cooldown-delta)
	enemy_cooldown = maxf(0,enemy_cooldown-delta)
	var p := player_team[active_index]
	var direction := Input.get_axis("ui_left","ui_right")
	if touch_move_left: direction = -1
	if touch_move_right: direction = 1
	p.position.x = clampf(p.position.x+direction*MOVE_SPEED*delta,-4.3,1.0)
	p.rotation.y = lerp_angle(p.rotation.y,0.0,delta*8.0)
	enemy.rotation.y = lerp_angle(enemy.rotation.y,PI,delta*8.0)
	if enemy_hp > 0 and player_hp > 0:
		var gap := p.position.x-enemy.position.x
		if absf(gap)>1.35:
			enemy.position.x += signf(gap)*1.6*delta
		elif enemy_cooldown <= 0:
			enemy_cooldown = 1.2
			player_hp = maxf(0,player_hp-5)
			hp_player.value = player_hp
			status.text = "RIVAL STRIKE!"
	if player_hp <= 0: status.text = "K.O.  RIVAL WINS"

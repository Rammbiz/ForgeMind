class_name HeroShowcaseStage
extends SubViewportContainer
## The live 3D hero of the Showcase (starters: HeroModels; others have no model yet and never get
## a stage): the rigged hero idling on the ivory dais (HubShowcase.ivory_dais) in its own world
## with a transparent background, so the painted backdrop shows around it. Daylight studio: warm
## key, a rim tinted by the hero's gem, no shadow maps (gl_compatibility). `interactive` = the
## «3D» view: a horizontal drag turns the hero (with a little inertia); otherwise a slow sway.
## Rendering stops while hidden (UPDATE_WHEN_VISIBLE).
##   var st := HeroShowcaseStage.make("bolt", "R")
##   st.interactive = true

var hero_id := "bolt"
var gem := "R"
var interactive := false
## Subject region (w, h) in world units the camera keeps in frame.
var region := Vector2(2.2, 2.4)
var _look := Vector3(0, 0.95, 0)
## Where the hero stands across the stage (0..1): the art view keeps it right of the info
## column with a lens shift (Camera3D.h_offset), the 3D view centres it.
## Art view: the model's widest point stays right of this screen fraction (the info column).
var left_clear := 0.0
const DAIS_W := 1.2
## Art view: px kept free between the info column and the hero's (or the dais') widest point.
const CLEAR_PX := 24.0
var _model_w := 0.0
var _model_px := 0.0
var focus_x := 0.5:
	set(v):
		focus_x = v
		_frame()
var _vp: SubViewport
var _cam: Camera3D
var _turn: Node3D
var _model: Node3D
var _t := 0.0
var _yaw := 0.35
var _vel := 0.0
var _drag := false


static func make(p_id: String, p_gem: String) -> HeroShowcaseStage:
	var s := HeroShowcaseStage.new()
	s.hero_id = p_id
	s.gem = HeroesText.gem_letter(p_gem)
	return s


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)


func _ready() -> void:
	var root := Node3D.new()
	_vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.92, 0.88)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -30, 0)
	key.light_color = Color(1.0, 0.97, 0.92)
	key.light_energy = 0.9
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	var gc: Color = UITokens.gem(gem)["rim"]
	rim.light_color = Color(1, 0.9, 0.75).lerp(gc, 0.5)
	rim.light_energy = 0.65
	rim.light_specular = 0.0
	root.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	root.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 1.15, 5.2), Vector3(0, 0.95, 0))
	# The dais at 0.8 of the hub size, so the hero (not the plinth) owns the art column and the
	# head lands near the upper third (Genshin framing).
	var dais := HubShowcase.ivory_dais(DAIS_W, gc.lerp(Color(1, 1, 1), 0.2))
	var dais_depth := 0.45
	if not dais.is_empty():
		root.add_child(dais["node"])
		dais_depth = float(dais.get("depth", 0.45))
	_turn = Node3D.new()
	root.add_child(_turn)
	if HeroArt.has_live3d(hero_id):
		_model = HeroModels.hero(hero_id)
		_model.scale = Vector3.ONE * 1.12
		_turn.add_child(_model)
		# Frame this hero (a slim fox and a wide golem need different cameras): the model's box
		# plus the dais (about 1.6 wide, 0.45 deep below the feet).
		var box := WeaponModels._visual_aabb(_model, _model.transform)
		if box.size != Vector3.ZERO:
			var top := box.end.y + 0.12
			var bottom := -dais_depth - 0.06
			_model_w = maxf(box.size.x, box.size.z)
			# Projected width at the idle yaw (~0.35 rad): what the info column actually meets.
			_model_px = box.size.x * cos(0.35) + box.size.z * sin(0.35)
			region = Vector2(maxf(_model_w, DAIS_W + 0.2) + 0.25, top - bottom)
			_look = Vector3(0, (top + bottom) * 0.5, 0)
	_cam.look_at_from_position(Vector3(0, _look.y + 0.2, 5.2), _look)
	resized.connect(_frame)
	_frame()


func _frame() -> void:
	if size.y < 4.0 or _cam == null:
		return
	var d := _cam.position.distance_to(_look)
	var aspect := size.x / size.y
	var right := maxf(0.15, 1.0 - focus_x)
	var v_need := 2.0 * atan(region.y * 0.5 / d)
	# The visible width holds most of the subject's right half between the focus and the edge
	# (with the focus off-centre the dais may run off the right edge of the screen a little).
	var vis_w_need := region.x / (2.0 * right) * (1.0 if focus_x <= 0.5 else 0.74)
	if left_clear > 0.0 and focus_x > left_clear + 0.05:
		# The widest point (the model's arms or the dais rim) starts CLEAR_PX right of the info
		# column: focus - half / vis_w >= left_clear + margin.
		var half := maxf(_model_px * 0.42, DAIS_W * 0.5)
		var room := focus_x - left_clear - CLEAR_PX / maxf(1.0, size.x)
		if room > 0.02:
			vis_w_need = maxf(vis_w_need, half / room)
	var v_from_h := 2.0 * atan(vis_w_need * 0.5 / d / aspect)
	_cam.fov = clampf(rad_to_deg(maxf(v_need, v_from_h)), 14.0, 70.0)
	var vis_h := 2.0 * d * tan(deg_to_rad(_cam.fov) * 0.5)
	var vis_w := vis_h * aspect
	_cam.h_offset = (0.5 - focus_x) * vis_w
	# A wide hero framed by width leaves spare height: stand it lower (on the skill band's
	# horizon) instead of floating in the middle of the art column.
	_cam.v_offset = maxf(0.0, (vis_h - region.y) * 0.4) if focus_x > 0.5 else 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if interactive:
		if not _drag:
			_yaw += _vel * delta
			_vel = move_toward(_vel, 0.0, delta * 2.4)
	else:
		var target := 0.35 + (0.0 if UITokens.reduce_motion() else sin(fmod(_t, 100.0 * PI) * 0.4) * 0.35)
		_yaw = lerpf(_yaw, target, minf(1.0, delta * 2.0))
	if _turn:
		_turn.rotation.y = _yaw
	if _model:
		HeroModels.animate_hero(_model, _t, false, 0.0)


func _gui_input(e: InputEvent) -> void:
	if not interactive:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		var dx: float = (e as InputEventMouseMotion).relative.x
		_yaw += dx * 0.012
		_vel = clampf(dx * 0.6, -6.0, 6.0)
		accept_event()


## Stops / resumes rendering (a sheet covers the stage).
func set_paused(paused: bool) -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if paused else SubViewport.UPDATE_WHEN_VISIBLE

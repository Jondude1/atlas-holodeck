class_name TvPanel
extends Node3D
## R7-1 TV wall panel with Jellyfin browser + Theora/Vorbis (.ogv) playback.
## Matches WallPanel's framed-display language and dark-titanium hardware family:
## one merged dark-titanium slab + thin cyan emissive edge line + 16:9 screen quad
## driven by a single SubViewport. Lives on a wall (default FRONT wall, behind spawn),
## grabs with one hand to slide along the wall (snaps on release), and stretches
## with two hands to resize while strictly preserving 16:9 (width 0.8–2.6 m).

signal changed(panel: TvPanel)
signal state_changed(new_state: int)

enum State { BROWSE, PREPARING, PLAYING, ERROR }

const STORE_PATH := "user://tv_layout.json"
const CACHE_DIR := "user://tv_cache"
const DEFAULT_BRIDGE_URL := "http://192.168.4.51:8791"

const ASPECT := 16.0 / 9.0
const MIN_WIDTH := 0.8
const MAX_WIDTH := 2.6
const DEFAULT_WIDTH := 1.80
const VP_SIZE := Vector2i(960, 540)
const POLL_INTERVAL := 0.8

const WALLS := {
	"left": {"pos": -3.94, "yaw": 90.0, "umin": -4.5, "umax": 2.5},
	"right": {"pos": 3.94, "yaw": -90.0, "umin": -4.5, "umax": 2.5},
	"front": {"pos": 2.94, "yaw": 180.0, "umin": -3.5, "umax": 3.5},
}

var wall := "front"
var size := Vector2(DEFAULT_WIDTH, DEFAULT_WIDTH / ASPECT)
var center_local := Vector3.ZERO
var grab_radius := 1.15

var state: int = State.BROWSE
var bridge_url := ""

var _u := 0.0
var _v := 1.62
var _built := false
var _hands: Array[Node3D] = []
var _grab_off := Vector2.ZERO
var _resize_d0 := 0.5
var _resize_w0 := DEFAULT_WIDTH

# 3D nodes (3 draw calls total when visible: Frame, Accent, Display; Rim hidden at rest)
var _frame: MeshInstance3D
var _accent: MeshInstance3D
var _display: MeshInstance3D
var _rim: MeshInstance3D
var _frame_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D
var _display_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D

# SubViewport + UI nodes
var _vp: SubViewport
var _chrome: _TvChrome
var _browser_layer: Control
var _lib_list: VBoxContainer
var _items_scroll: ScrollContainer
var _items_grid: GridContainer
var _header_meta: Label
var _status_banner: Label
var _retry_btn: Button
var _prep_overlay: PanelContainer
var _prep_title: Label
var _prep_status: Label
var _prep_bar: ProgressBar
var _play_layer: Control
var _video_player: VideoStreamPlayer
var _play_bar: PanelContainer
var _play_title_lbl: Label

# Data + network state
var _libraries: Array = []
var _items_by_lib: Dictionary = {}
var _active_lib_id := ""
var _selected_item_id := ""
var _active_item: Dictionary = {}
var _poster_cache: Dictionary = {}         # item_id -> Texture2D
var _poster_rects: Dictionary = {}         # item_id -> TextureRect
var _poster_queue: Array[String] = []
var _poster_busy := false
var _placeholder_tex: ImageTexture
var _injected_data := false

var _http_libs: HTTPRequest
var _http_items: HTTPRequest
var _http_poster: HTTPRequest
var _http_play: HTTPRequest
var _http_poll: HTTPRequest
var _http_dl: HTTPRequest
var _poll_timer: Timer

# Viewport refresh discipline (0 2D draw calls at rest when not playing)
const POKE_SECONDS := 1.2
var _poke_t := 0.0
var _needs_once := true
var _controls_hide_t := 0.0


## Subtle Stark technical chrome behind the media browser (zero 3D draw cost).
class _TvChrome extends Control:
	var wave_phase := 0.4

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		# Faint technical micro-grid
		var grid_col := Color(0.24, 0.76, 0.88, 0.045)
		var step := 36.0
		var gx := 14.0 + step
		while gx < w - 14.0:
			draw_line(Vector2(gx, 14.0), Vector2(gx, h - 14.0), grid_col, 1.0)
			gx += step
		var gy := 14.0 + step
		while gy < h - 14.0:
			draw_line(Vector2(14.0, gy), Vector2(w - 14.0, gy), grid_col, 1.0)
			gy += step
		# Thin teal inner frame + corner L-brackets (wall_panel.gd sibling language)
		var border_col := Color(0.35, 0.86, 0.96, 0.32)
		draw_rect(Rect2(10.0, 10.0, w - 20.0, h - 20.0), border_col, false, 1.5)
		var brk := Color(0.58, 0.96, 1.0, 0.85)
		var bl := 18.0
		var bw := 2.5
		draw_line(Vector2(10.0, 10.0), Vector2(10.0 + bl, 10.0), brk, bw)
		draw_line(Vector2(10.0, 10.0), Vector2(10.0, 10.0 + bl), brk, bw)
		draw_line(Vector2(w - 10.0, 10.0), Vector2(w - 10.0 - bl, 10.0), brk, bw)
		draw_line(Vector2(w - 10.0, 10.0), Vector2(w - 10.0, 10.0 + bl), brk, bw)
		draw_line(Vector2(10.0, h - 10.0), Vector2(10.0 + bl, h - 10.0), brk, bw)
		draw_line(Vector2(10.0, h - 10.0), Vector2(10.0, h - 10.0 - bl), brk, bw)
		draw_line(Vector2(w - 10.0, h - 10.0), Vector2(w - 10.0 - bl, h - 10.0), brk, bw)
		draw_line(Vector2(w - 10.0, h - 10.0), Vector2(w - 10.0, h - 10.0 - bl), brk, bw)
		# Header divider + sidebar divider
		var div_col := Color(0.32, 0.84, 0.96, 0.22)
		draw_line(Vector2(22.0, 68.0), Vector2(w - 22.0, 68.0), div_col, 1.0)
		draw_line(Vector2(214.0, 78.0), Vector2(214.0, h - 48.0), div_col, 1.0)
		# Subtle concentric Stark ring badge in the top-right corner
		var cen := Vector2(w - 42.0, 40.0)
		draw_arc(cen, 16.0, 0.0, TAU, 32, Color(0.30, 0.80, 0.94, 0.30), 1.4, true)
		draw_arc(cen, 10.5, 0.0, TAU, 24, Color(0.45, 0.92, 1.0, 0.45), 1.2, true)
		draw_arc(cen, 16.0, deg_to_rad(-60.0), deg_to_rad(170.0), 24, Color(0.62, 0.96, 1.0, 0.85), 2.2, true)
		draw_circle(cen, 2.2, Color(0.75, 0.98, 1.0, 0.85))
		# Subtle oscilloscope waveform strip tucked cleanly inside the left sidebar footer
		var wx0 := 26.0
		var wx1 := 198.0
		var wy := h - 82.0
		draw_line(Vector2(wx0, wy), Vector2(wx1, wy), Color(0.26, 0.76, 0.90, 0.16), 1.0)
		var pts1 := PackedVector2Array()
		var pts2 := PackedVector2Array()
		var xx := wx0
		while xx <= wx1:
			var u := (xx - wx0) / maxf(wx1 - wx0, 1.0)
			var env := sin(u * PI)
			var y1 := wy + (sin(xx * 0.09 + wave_phase) * 0.55 + sin(xx * 0.21 + wave_phase * 1.7) * 0.30) * 14.0 * (0.25 + 0.75 * env)
			var y2 := wy + (cos(xx * 0.06 - wave_phase * 1.1) * 0.65) * 9.0 * (0.25 + 0.75 * env)
			pts1.append(Vector2(xx, y1))
			pts2.append(Vector2(xx, y2))
			xx += 4.0
		if pts2.size() >= 2:
			draw_polyline(pts2, Color(0.24, 0.78, 0.92, 0.28), 1.3, true)
		if pts1.size() >= 2:
			draw_polyline(pts1, Color(0.48, 0.95, 1.0, 0.72), 1.8, true)


static func resolve_bridge_url() -> String:
	var env_url := OS.get_environment("HOLODECK_BRIDGE").strip_edges()
	if env_url != "":
		return env_url.trim_suffix("/")
	return DEFAULT_BRIDGE_URL


func build(bridge_url_override := "") -> void:
	if _built:
		return
	bridge_url = bridge_url_override.trim_suffix("/") if bridge_url_override != "" else resolve_bridge_url()
	add_to_group("grabbable")
	add_to_group("tv_panel")

	_frame_mat = StandardMaterial3D.new()
	_frame_mat.vertex_color_use_as_albedo = true
	_frame_mat.vertex_color_is_srgb = true
	_frame_mat.albedo_texture = Fx.brushed_texture()
	_frame_mat.normal_enabled = true
	_frame_mat.normal_texture = Fx.brushed_normal()
	_frame_mat.normal_scale = 0.55
	_frame_mat.metallic = 0.78
	_frame_mat.roughness = 0.36

	_accent_mat = Fx.emissive(Tokens.HOLO_LINE, 0.72)

	_display_mat = StandardMaterial3D.new()
	_display_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_display_mat.albedo_color = Color.WHITE

	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rim_mat.albedo_color = Color(Tokens.HOLO_LINE, 0.0)

	_frame = MeshInstance3D.new()
	_frame.name = "Frame"
	_frame.material_override = _frame_mat
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_frame)

	_accent = MeshInstance3D.new()
	_accent.name = "EdgeAccent"
	_accent.material_override = _accent_mat
	_accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_accent)

	_rim = MeshInstance3D.new()
	_rim.name = "Rim"
	_rim.material_override = _rim_mat
	_rim.position = Vector3(0, 0, -0.004)
	_rim.visible = false
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)

	_display = MeshInstance3D.new()
	_display.name = "Display"
	_display.material_override = _display_mat
	_display.position = Vector3(0, 0, 0.022)
	_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_display)

	_placeholder_tex = _make_placeholder_tex()
	_build_viewport()
	_build_http()

	# Restore persisted spot/width if present
	var saved := _load_store()
	if not saved.is_empty():
		var sw := str(saved.get("wall", wall))
		if WALLS.has(sw):
			wall = sw
		_u = float(saved.get("u", _u))
		_v = float(saved.get("v", _v))
		var width_saved := clampf(float(saved.get("width", DEFAULT_WIDTH)), MIN_WIDTH, MAX_WIDTH)
		size = Vector2(width_saved, width_saved / ASPECT)
	else:
		size = Vector2(DEFAULT_WIDTH, DEFAULT_WIDTH / ASPECT)

	_rebuild_geometry()
	_place()
	_built = true
	_set_state(State.BROWSE)
	request_redraw()
	set_process(true)


## Build the machined dark-titanium TV chassis (1 draw call) + thin cyan bevel accent (1 draw call).
func _rebuild_geometry() -> void:
	var w := size.x
	var h := size.y
	grab_radius = maxf(w * 0.58, 0.75)

	var mb := MeshBuilder.new()
	var body := Tokens.TITANIUM_BODY
	var dark := Tokens.TITANIUM_DARK
	var edge := Tokens.TITANIUM_DARK.lerp(Tokens.TITANIUM, 0.28)
	var recess := Color(0.008, 0.012, 0.018)
	var bw := 0.032             # outer titanium frame rail width
	var chin := 0.044           # slightly deeper machined lower chin rail
	var depth := 0.038

	# Wall-mount spine behind the chassis so it reads anchored to the concrete wall
	mb.add_box(Vector3(0, 0, -0.018), Vector3(w * 0.68, h * 0.56, 0.020), dark)
	# Recessed near-black rear enclosure plate
	mb.add_box(Vector3(0, -0.006, 0.0), Vector3(w + bw * 1.5, h + bw + chin * 0.5, 0.024), recess)
	# Four outer machined dark-titanium bezel rails (stepped profile)
	mb.add_box(Vector3(0, h * 0.5 + bw * 0.5, 0.012), Vector3(w + bw * 2.0, bw, depth), body)
	mb.add_box(Vector3(0, -h * 0.5 - chin * 0.5, 0.012), Vector3(w + bw * 2.0, chin, depth), body)
	mb.add_box(Vector3(-w * 0.5 - bw * 0.5, -(chin - bw) * 0.5, 0.012), Vector3(bw, h + (chin - bw), depth), body)
	mb.add_box(Vector3(w * 0.5 + bw * 0.5, -(chin - bw) * 0.5, 0.012), Vector3(bw, h + (chin - bw), depth), body)
	# Inner chamfer lip catching subtle specular around the screen glass
	var lip := 0.009
	mb.add_box(Vector3(0, h * 0.5 + lip * 0.5, 0.024), Vector3(w + lip * 2.0, lip, 0.012), edge)
	mb.add_box(Vector3(0, -h * 0.5 - lip * 0.5, 0.024), Vector3(w + lip * 2.0, lip, 0.012), edge)
	mb.add_box(Vector3(-w * 0.5 - lip * 0.5, 0, 0.024), Vector3(lip, h, 0.012), edge)
	mb.add_box(Vector3(w * 0.5 + lip * 0.5, 0, 0.024), Vector3(lip, h, 0.012), edge)
	# Subtle machined corner cleats
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var cy := (h * 0.5 + bw * 0.55) if sy > 0.0 else (-h * 0.5 - chin * 0.55)
			mb.add_box(Vector3(sx * (w * 0.5 + bw * 0.55), cy, 0.018), Vector3(0.038, 0.038, 0.032), edge)
	_frame.mesh = mb.build()

	# Thin cyan emissive edge line recessed along top + bottom chassis perimeter
	var eb := MeshBuilder.new()
	var line_t := 0.0045
	var col := Color(1.0, 1.0, 1.0)
	eb.add_box(Vector3(0, h * 0.5 + bw + line_t * 0.5, 0.026), Vector3(w + bw * 1.9, line_t, 0.005), col)
	eb.add_box(Vector3(0, -h * 0.5 - chin - line_t * 0.5, 0.026), Vector3(w + bw * 1.9, line_t, 0.005), col)
	# Short vertical corner ticks on left/right edges
	for sx in [-1.0, 1.0]:
		eb.add_box(Vector3(sx * (w * 0.5 + bw + line_t * 0.5), 0.0, 0.026), Vector3(line_t, h * 0.36, 0.005), col)
	_accent.mesh = eb.build()

	var dq := QuadMesh.new()
	dq.size = size
	_display.mesh = dq

	var rq := QuadMesh.new()
	rq.size = size + Vector2(0.15, 0.15)
	_rim.mesh = rq


func _build_viewport() -> void:
	_vp = SubViewport.new()
	_vp.name = "SubViewport"
	_vp.size = VP_SIZE
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(root)

	# ---------------- Layer A: Browser UI ----------------
	_browser_layer = Control.new()
	_browser_layer.name = "BrowserLayer"
	_browser_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_browser_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.006, 0.018, 0.028, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_browser_layer.add_child(bg)

	_chrome = _TvChrome.new()
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_browser_layer.add_child(_chrome)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 24)
	main_margin.add_theme_constant_override("margin_top", 18)
	main_margin.add_theme_constant_override("margin_right", 24)
	main_margin.add_theme_constant_override("margin_bottom", 18)
	_browser_layer.add_child(main_margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	main_margin.add_child(outer)

	# Header bar
	var hdr := HBoxContainer.new()
	hdr.custom_minimum_size = Vector2(0, 44)
	hdr.add_theme_constant_override("separation", 14)
	outer.add_child(hdr)

	var title := _mk_label("HOLODECK MEDIA  //  JELLYFIN", 26, Tokens.HOLO_CORE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_header_meta = _mk_label("CONNECTING…", 18, Tokens.HOLO_LINE, false)
	hdr.add_child(_header_meta)

	var sync_btn := _mk_button("SYNC", Vector2(76, 34), 17)
	sync_btn.pressed.connect(func() -> void: fetch_libraries())
	hdr.add_child(sync_btn)

	# Leave breathing room for the top-right Stark ring badge
	var badge_pad := Control.new()
	badge_pad.custom_minimum_size = Vector2(40, 0)
	hdr.add_child(badge_pad)

	# Body row: Left libraries rail + Right poster grid
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(184, 0)
	sidebar.add_theme_constant_override("separation", 8)
	body.add_child(sidebar)

	var lib_hdr := _mk_label("LIBRARIES", 15, Color(0.45, 0.86, 0.96, 0.72), true)
	sidebar.add_child(lib_hdr)

	_lib_list = VBoxContainer.new()
	_lib_list.add_theme_constant_override("separation", 6)
	_lib_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_lib_list)

	# Pointer scroll buttons for the poster grid (VR laser cannot drag-scroll)
	var scroll_row := HBoxContainer.new()
	scroll_row.add_theme_constant_override("separation", 8)
	sidebar.add_child(scroll_row)
	for dir in [-1, 1]:
		var sbtn := _mk_button("▲ UP" if dir < 0 else "▼ DOWN", Vector2(84, 32), 15)
		sbtn.pressed.connect(func() -> void: _scroll_items(dir))
		scroll_row.add_child(sbtn)

	# Spacer so left sidebar buttons stay clear of the waveform deco strip
	var wave_spacer := Control.new()
	wave_spacer.custom_minimum_size = Vector2(0, 44)
	sidebar.add_child(wave_spacer)

	# Right: Poster grid inside ScrollContainer
	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(_items_scroll)

	_items_grid = GridContainer.new()
	_items_grid.columns = 4
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_grid.add_theme_constant_override("h_separation", 12)
	_items_grid.add_theme_constant_override("v_separation", 12)
	_items_scroll.add_child(_items_grid)

	# Bottom status / error line
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, 28)
	footer.add_theme_constant_override("separation", 12)
	outer.add_child(footer)

	_status_banner = _mk_label("READY · SELECT A TITLE TO STREAM", 16, Color(0.55, 0.88, 0.96, 0.84), false)
	_status_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_banner.clip_text = true
	footer.add_child(_status_banner)

	_retry_btn = _mk_button("RETRY", Vector2(78, 28), 15)
	_retry_btn.visible = false
	_retry_btn.pressed.connect(func() -> void: fetch_libraries())
	footer.add_child(_retry_btn)

	# Preparing overlay card (centered over browser during transcode/download)
	_prep_overlay = PanelContainer.new()
	_prep_overlay.name = "PreparingOverlay"
	_prep_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_prep_overlay.custom_minimum_size = Vector2(540, 220)
	_prep_overlay.position = Vector2((VP_SIZE.x - 540) * 0.5, (VP_SIZE.y - 220) * 0.5)
	var psb := _flat(Color(0.008, 0.026, 0.044, 0.96), Tokens.HOLO_LINE, 2)
	psb.set_content_margin_all(24)
	_prep_overlay.add_theme_stylebox_override("panel", psb)
	_prep_overlay.visible = false
	_browser_layer.add_child(_prep_overlay)

	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 14)
	_prep_overlay.add_child(pbox)

	_prep_title = _mk_label("PREPARING TITLE", 26, Tokens.HOLO_CORE, true)
	_prep_title.clip_text = true
	pbox.add_child(_prep_title)

	_prep_status = _mk_label("Preparing… 0%", 20, Tokens.HOLO_LINE, false)
	pbox.add_child(_prep_status)

	_prep_bar = ProgressBar.new()
	_prep_bar.min_value = 0.0
	_prep_bar.max_value = 100.0
	_prep_bar.value = 0.0
	_prep_bar.show_percentage = false
	_prep_bar.custom_minimum_size = Vector2(0, 18)
	_prep_bar.add_theme_stylebox_override("background", _flat(Color(0.015, 0.045, 0.075, 1.0), Color(0.28, 0.72, 0.88, 0.5), 1))
	_prep_bar.add_theme_stylebox_override("fill", _flat(Tokens.HOLO_LINE, Tokens.HOLO_CORE, 1))
	pbox.add_child(_prep_bar)

	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_END
	pbox.add_child(prow)
	var cancel_btn := _mk_button("BACK / CANCEL", Vector2(160, 38), 18)
	cancel_btn.pressed.connect(func() -> void: stop_playback())
	prow.add_child(cancel_btn)

	# ---------------- Layer B: Video Playback ----------------
	_play_layer = Control.new()
	_play_layer.name = "PlaybackLayer"
	_play_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_layer.visible = false
	root.add_child(_play_layer)

	var pbg := ColorRect.new()
	pbg.color = Color.BLACK
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_layer.add_child(pbg)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoPlayer"
	_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.finished.connect(_on_video_finished)
	_play_layer.add_child(_video_player)

	# Invisible full-screen click catcher to reveal STOP/BACK controls on tap
	var tap_catch := Button.new()
	tap_catch.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap_catch.flat = true
	tap_catch.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap_catch.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap_catch.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap_catch.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tap_catch.pressed.connect(func() -> void:
		set_controls_visible(not _play_bar.visible))
	_play_layer.add_child(tap_catch)

	# Floating minimal STOP/BACK overlay — hidden during playback ("controls vanish")
	_play_bar = PanelContainer.new()
	_play_bar.name = "PlayControls"
	_play_bar.position = Vector2(20, 18)
	_play_bar.custom_minimum_size = Vector2(VP_SIZE.x - 40, 52)
	var bar_sb := _flat(Color(0.006, 0.018, 0.028, 0.84), Tokens.HOLO_LINE, 1)
	bar_sb.set_content_margin_all(8)
	_play_bar.add_theme_stylebox_override("panel", bar_sb)
	_play_bar.visible = false
	_play_layer.add_child(_play_bar)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 14)
	_play_bar.add_child(bar_row)

	var back_btn := _mk_button("◂ STOP / BACK", Vector2(150, 34), 18)
	back_btn.pressed.connect(func() -> void: stop_playback())
	bar_row.add_child(back_btn)

	_play_title_lbl = _mk_label("", 20, Tokens.HOLO_CORE, true)
	_play_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_title_lbl.clip_text = true
	bar_row.add_child(_play_title_lbl)

	_display_mat.albedo_texture = _vp.get_texture()


func _build_http() -> void:
	_http_libs = HTTPRequest.new()
	_http_libs.timeout = 8.0
	_http_libs.request_completed.connect(_on_libs_completed)
	add_child(_http_libs)

	_http_items = HTTPRequest.new()
	_http_items.timeout = 10.0
	_http_items.request_completed.connect(_on_items_completed)
	add_child(_http_items)

	_http_poster = HTTPRequest.new()
	_http_poster.timeout = 10.0
	_http_poster.request_completed.connect(_on_poster_completed)
	add_child(_http_poster)

	_http_play = HTTPRequest.new()
	_http_play.timeout = 15.0
	_http_play.request_completed.connect(_on_play_completed)
	add_child(_http_play)

	_http_poll = HTTPRequest.new()
	_http_poll.timeout = 10.0
	_http_poll.request_completed.connect(_on_poll_completed)
	add_child(_http_poll)

	_http_dl = HTTPRequest.new()
	_http_dl.timeout = 120.0
	_http_dl.request_completed.connect(_on_download_completed)
	add_child(_http_dl)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = true
	_poll_timer.timeout.connect(_poll_play_status)
	add_child(_poll_timer)


func _flat(fill: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(6)
	return sb


func _mk_label(txt: String, px: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", load(Tokens.FONT_BOLD if bold else Tokens.FONT_REGULAR))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


func _mk_button(txt: String, min_size: Vector2, px: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	b.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
	b.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
	b.add_theme_stylebox_override("normal", _flat(Color(0.012, 0.036, 0.056, 0.9), Color(0.32, 0.80, 0.94, 0.42), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.04, 0.14, 0.22, 0.95), Tokens.HOLO_LINE, 2))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.08, 0.24, 0.36, 0.98), Tokens.HOLO_CORE, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _make_placeholder_tex() -> ImageTexture:
	var w := 120
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(0.010, 0.028, 0.044, 1.0)
	var line := Color(0.24, 0.72, 0.86, 0.35)
	var core := Color(0.45, 0.90, 1.0, 0.65)
	img.fill(bg)
	for x in range(8, w - 8):
		img.set_pixel(x, 8, line)
		img.set_pixel(x, h - 9, line)
	for y in range(8, h - 8):
		img.set_pixel(8, y, line)
		img.set_pixel(w - 9, y, line)
	# Concentric holo emblem in the center of missing-poster cards
	var cx := w * 0.5
	var cy := h * 0.5
	for y in range(28, h - 28):
		for x in range(16, w - 16):
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			if absf(d - 24.0) < 1.1:
				img.set_pixel(x, y, core)
			elif absf(d - 14.0) < 0.9:
				img.set_pixel(x, y, line)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- visibility & state

func toggle_tv() -> bool:
	set_tv_visible(not visible)
	return visible


func set_tv_visible(v: bool) -> void:
	visible = v
	if not visible:
		if state == State.PLAYING and _video_player:
			_video_player.paused = true
		if _vp:
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		if state == State.PLAYING and _video_player:
			_video_player.paused = false
		request_redraw()
		fetch_libraries_if_idle()


func state_name() -> String:
	match state:
		State.BROWSE: return "BROWSE"
		State.PREPARING: return "PREPARING"
		State.PLAYING: return "PLAYING"
		State.ERROR: return "ERROR"
	return "UNKNOWN"


func _set_state(new_state: int) -> void:
	state = new_state
	if not _built:
		return
	var playing := state == State.PLAYING
	_browser_layer.visible = not playing
	_prep_overlay.visible = state == State.PREPARING
	_play_layer.visible = playing
	_retry_btn.visible = state == State.ERROR
	if playing:
		_play_bar.visible = false
		_controls_hide_t = 0.0
	request_redraw()
	state_changed.emit(state)


func set_controls_visible(v: bool) -> void:
	if _play_bar:
		_play_bar.visible = v
		_controls_hide_t = 3.2 if v else 0.0
		request_redraw()


func poke(seconds := POKE_SECONDS) -> void:
	_poke_t = maxf(_poke_t, seconds)
	_needs_once = true


func request_redraw() -> void:
	_needs_once = true
	if _chrome:
		_chrome.queue_redraw()
	if _vp and visible and state != State.PLAYING:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ---------------------------------------------------------------- bridge API & browser flow

func set_bridge_url(url: String) -> void:
	bridge_url = url.strip_edges().trim_suffix("/")


func fetch_libraries_if_idle() -> void:
	if not _built or _injected_data or not _libraries.is_empty():
		return
	fetch_libraries()


func fetch_libraries() -> void:
	if not _built:
		return
	_injected_data = false
	_header_meta.text = "SYNCING…"
	_status_banner.text = "CONTACTING BRIDGE · %s" % bridge_url
	_retry_btn.visible = false
	request_redraw()
	_http_libs.cancel_request()
	var err := _http_libs.request(bridge_url + "/jf/libraries")
	if err != OK:
		set_error("Bridge request failed (code %d) — %s" % [err, bridge_url])


func _on_libs_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		set_error("Bridge unreachable (%s) — check jellyfin_bridge.py" % bridge_url)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var libs: Array = []
	if parsed is Dictionary:
		var raw: Variant = (parsed as Dictionary).get("libraries", [])
		if raw is Array:
			libs = raw
	elif parsed is Array:
		libs = parsed
	if libs.is_empty():
		set_error("Jellyfin returned no libraries")
		return
	_populate_libraries(libs, true)


## Inject library list directly (for offline unit tests or pre-seeded data).
func inject_libraries(libs: Array) -> void:
	_injected_data = true
	_populate_libraries(libs, false)


## Inject items for a given library id (for offline unit tests or captures).
func inject_items(lib_id: String, items: Array) -> void:
	_injected_data = true
	_items_by_lib[lib_id] = items.duplicate(true)
	if _active_lib_id == "" or _active_lib_id == lib_id:
		_active_lib_id = lib_id
		_rebuild_library_buttons()
		_rebuild_items_grid(items)
		if state == State.ERROR:
			_set_state(State.BROWSE)


func _populate_libraries(libs: Array, auto_fetch_items: bool) -> void:
	_libraries = libs.duplicate(true)
	if _active_lib_id == "" and not _libraries.is_empty():
		var first_d: Dictionary = _libraries[0] if _libraries[0] is Dictionary else {}
		_active_lib_id = str(first_d.get("id", ""))
	_rebuild_library_buttons()
	if state == State.ERROR:
		_set_state(State.BROWSE)
	_header_meta.text = "JELLYFIN · %d LIBRARIES" % _libraries.size()
	_status_banner.text = "SELECT A LIBRARY OR TITLE"
	request_redraw()
	if auto_fetch_items and _active_lib_id != "":
		select_library(_active_lib_id)


func _rebuild_library_buttons() -> void:
	if _lib_list == null:
		return
	for c in _lib_list.get_children():
		c.queue_free()
		_lib_list.remove_child(c)
	for entry in _libraries:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var lid := str(d.get("id", ""))
		var nm := str(d.get("name", "Library")).to_upper()
		var active := lid == _active_lib_id
		var btn := _mk_button(("▸ " if active else "  ") + nm, Vector2(0, 42), 18)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if active:
			btn.add_theme_stylebox_override("normal", _flat(Color(0.035, 0.14, 0.22, 0.96), Tokens.HOLO_CORE, 2))
			btn.add_theme_color_override("font_color", Tokens.HOLO_CORE)
		btn.pressed.connect(func() -> void: select_library(lid))
		_lib_list.add_child(btn)


func select_library(lib_id: String) -> void:
	_active_lib_id = lib_id
	_rebuild_library_buttons()
	if _items_by_lib.has(lib_id):
		var cached_items: Array = _items_by_lib[lib_id]
		_rebuild_items_grid(cached_items)
		return
	if _injected_data:
		_rebuild_items_grid([])
		return
	_header_meta.text = "LOADING…"
	_status_banner.text = "FETCHING ITEMS…"
	request_redraw()
	_http_items.cancel_request()
	var err := _http_items.request("%s/jf/items?parent=%s" % [bridge_url, lib_id.uri_encode()])
	if err != OK:
		set_error("Failed to request items (code %d)" % err)


func _on_items_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		set_error("Could not load library items (HTTP %d)" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var items: Array = []
	if parsed is Dictionary:
		var raw: Variant = (parsed as Dictionary).get("items", [])
		if raw is Array:
			items = raw
	elif parsed is Array:
		items = parsed
	_items_by_lib[_active_lib_id] = items
	if state == State.ERROR:
		_set_state(State.BROWSE)
	_rebuild_items_grid(items)


func _rebuild_items_grid(items: Array) -> void:
	if _items_grid == null:
		return
	for c in _items_grid.get_children():
		c.queue_free()
		_items_grid.remove_child(c)
	_poster_rects.clear()
	_poster_queue.clear()
	_items_scroll.scroll_vertical = 0

	var lib_label := "LIBRARY"
	for l in _libraries:
		if l is Dictionary and str((l as Dictionary).get("id", "")) == _active_lib_id:
			lib_label = str((l as Dictionary).get("name", "LIBRARY")).to_upper()
			break
	_header_meta.text = "%s · %d TITLES" % [lib_label, items.size()]

	if items.is_empty():
		var empty_lbl := _mk_label("NO MEDIA ITEMS FOUND IN THIS LIBRARY", 20, Color(0.50, 0.80, 0.90, 0.72), false)
		_items_grid.add_child(empty_lbl)
		request_redraw()
		return

	for i in items.size():
		if not (items[i] is Dictionary):
			continue
		var item: Dictionary = items[i]
		if _selected_item_id == "" and i == 0:
			_selected_item_id = str(item.get("id", ""))
		_items_grid.add_child(_build_item_card(item))
		var iid := str(item.get("id", ""))
		if bool(item.get("has_poster", false)) and iid != "" and not _poster_cache.has(iid) and not _injected_data:
			_poster_queue.append(iid)

	_status_banner.text = "TAP A TITLE TO PLAY  ·  GRAB TO MOVE  ·  TWO HANDS TO RESIZE"
	request_redraw()
	_pump_posters()


func _build_item_card(item: Dictionary) -> Control:
	var iid := str(item.get("id", ""))
	var title_txt := str(item.get("name", "Untitled"))
	var yr_val: Variant = item.get("year", null)
	var yr_str := "" if yr_val == null else str(yr_val)
	var rt_s := int(item.get("runtime", 0))
	var rt_str := _fmt_runtime(rt_s)
	var sub_parts: Array[String] = []
	if yr_str != "" and yr_str != "0":
		sub_parts.append(yr_str)
	if rt_str != "":
		sub_parts.append(rt_str)
	var sub_txt := " · ".join(sub_parts) if not sub_parts.is_empty() else "MEDIA"

	var selected := iid == _selected_item_id
	var card := PanelContainer.new()
	card.name = "ItemCard_" + iid
	card.custom_minimum_size = Vector2(160, 212)
	var border_col := Tokens.HOLO_CORE if selected else Color(0.32, 0.80, 0.94, 0.36)
	var fill_col := Color(0.018, 0.056, 0.088, 0.96) if selected else Color(0.011, 0.032, 0.050, 0.92)
	var sb := _flat(fill_col, border_col, 2 if selected else 1)
	sb.set_content_margin_all(7)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var poster := TextureRect.new()
	poster.custom_minimum_size = Vector2(144, 146)
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _poster_cache.has(iid):
		poster.texture = _poster_cache[iid]
	elif item.has("poster_texture") and item["poster_texture"] is Texture2D:
		poster.texture = item["poster_texture"]
	else:
		poster.texture = _placeholder_tex
	vbox.add_child(poster)
	if iid != "":
		_poster_rects[iid] = poster

	var t_lbl := _mk_label(title_txt, 15, Tokens.HOLO_CORE if selected else Color(0.78, 0.95, 1.0, 0.95), true)
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(t_lbl)

	var s_lbl := _mk_label(sub_txt, 13, Color(0.48, 0.84, 0.94, 0.82), false)
	s_lbl.clip_text = true
	s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(s_lbl)

	# Full-card invisible button for clean pointer click + hover highlight
	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", _flat(Color(0.18, 0.62, 0.82, 0.14), Tokens.HOLO_CORE, 2))
	hit.add_theme_stylebox_override("pressed", _flat(Color(0.32, 0.82, 0.96, 0.24), Tokens.HOLO_CORE, 2))
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hit.pressed.connect(func() -> void: request_play(item))
	card.add_child(hit)
	return card


static func _fmt_runtime(seconds: int) -> String:
	if seconds <= 0:
		return ""
	var mins := int(round(float(seconds) / 60.0))
	if mins < 60:
		return "%dm" % maxi(mins, 1)
	return "%dh %02dm" % [mins / 60, mins % 60]


func _scroll_items(dir: int) -> void:
	if _items_scroll:
		_items_scroll.scroll_vertical = maxi(0, _items_scroll.scroll_vertical + dir * 224)
		poke()


func _pump_posters() -> void:
	if _poster_busy or _poster_queue.is_empty() or _injected_data:
		return
	var next_id: String = _poster_queue.pop_front()
	if _poster_cache.has(next_id):
		_pump_posters()
		return
	_poster_busy = true
	_http_poster.set_meta("item_id", next_id)
	var err := _http_poster.request("%s/jf/poster/%s" % [bridge_url, next_id.uri_encode()])
	if err != OK:
		_poster_busy = false
		_pump_posters()


func _on_poster_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var item_id := str(_http_poster.get_meta("item_id", ""))
	_poster_busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300 and not body.is_empty():
		var tex := _decode_image_bytes(body, headers)
		if tex != null:
			_poster_cache[item_id] = tex
			if _poster_rects.has(item_id):
				var tr: Variant = _poster_rects[item_id]
				if tr != null and is_instance_valid(tr):
					(tr as TextureRect).texture = tex
					request_redraw()
	_pump_posters()


static func _decode_image_bytes(body: PackedByteArray, headers: PackedStringArray) -> ImageTexture:
	var ctype := ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			ctype = h.to_lower()
			break
	var img := Image.new()
	var err := ERR_INVALID_DATA
	if ctype.contains("png") or (body.size() >= 4 and body[0] == 0x89 and body[1] == 0x50):
		err = img.load_png_from_buffer(body)
	elif ctype.contains("webp") or (body.size() >= 12 and body[0] == 0x52 and body[8] == 0x57):
		err = img.load_webp_from_buffer(body)
	else:
		err = img.load_jpg_from_buffer(body)
		if err != OK:
			err = img.load_png_from_buffer(body)
		if err != OK:
			err = img.load_webp_from_buffer(body)
	if err != OK or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- playback pipeline

func request_play(item: Dictionary) -> void:
	var iid := str(item.get("id", ""))
	if iid == "":
		return
	_selected_item_id = iid
	_active_item = item.duplicate(true)
	var title_txt := str(item.get("name", "Media"))
	set_preparing_progress(0.0, title_txt)

	# If already cached locally in user://tv_cache/, play right away
	var local_path := "%s/%s.ogv" % [CACHE_DIR, iid]
	if FileAccess.file_exists(local_path):
		var f := FileAccess.open(local_path, FileAccess.READ)
		if f and f.get_length() > 4096:
			f.close()
			play_local_file(local_path, title_txt)
			return
		if f:
			f.close()

	if _injected_data:
		# Offline unit-test mode stays in PREPARING so tests can verify state transitions.
		return

	_poll_timer.stop()
	_http_play.cancel_request()
	var err := _http_play.request("%s/jf/play/%s" % [bridge_url, iid.uri_encode()], PackedStringArray(), HTTPClient.METHOD_POST, "")
	if err != OK:
		set_error("Could not start transcode (code %d)" % err)


func set_preparing_progress(progress: float, title_txt := "") -> void:
	var p := clampf(progress, 0.0, 1.0)
	if title_txt != "" and _prep_title:
		_prep_title.text = title_txt.to_upper()
	if _prep_status:
		_prep_status.text = "Preparing… %d%%" % int(round(p * 100.0))
	if _prep_bar:
		_prep_bar.value = p * 100.0
	if state != State.PREPARING:
		_set_state(State.PREPARING)
	else:
		request_redraw()


func _on_play_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state != State.PREPARING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		set_error("Bridge rejected playback request (HTTP %d)" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		set_error("Invalid bridge response for play")
		return
	_handle_play_status(parsed as Dictionary)


func _poll_play_status() -> void:
	if state != State.PREPARING:
		return
	var iid := str(_active_item.get("id", ""))
	if iid == "":
		return
	_http_poll.cancel_request()
	var err := _http_poll.request("%s/jf/play_status/%s" % [bridge_url, iid.uri_encode()])
	if err != OK:
		set_error("Status poll failed (code %d)" % err)


func _on_poll_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state != State.PREPARING:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		set_error("Lost contact with bridge while preparing (HTTP %d)" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		set_error("Invalid play_status response")
		return
	_handle_play_status(parsed as Dictionary)


func _handle_play_status(d: Dictionary) -> void:
	var st := str(d.get("state", "none"))
	var prog := clampf(float(d.get("progress", 0.0)), 0.0, 1.0)
	if st == "ready":
		_prep_status.text = "Downloading… 100%"
		_prep_bar.value = 100.0
		request_redraw()
		_start_download(str(_active_item.get("id", "")))
	elif st == "working":
		set_preparing_progress(prog)
		_poll_timer.start()
	elif st == "error":
		var msg := str(d.get("error", "Transcode error"))
		set_error("Playback failed: %s" % msg)
	else:
		set_error("Transcode job not found on bridge")


func _start_download(item_id: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var local_path := "%s/%s.ogv" % [CACHE_DIR, item_id]
	_http_dl.cancel_request()
	_http_dl.download_file = local_path
	_http_dl.set_meta("local_path", local_path)
	var err := _http_dl.request("%s/jf/file/%s" % [bridge_url, item_id.uri_encode()])
	if err != OK:
		set_error("Download failed to start (code %d)" % err)


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.PREPARING:
		return
	var local_path := str(_http_dl.get_meta("local_path", ""))
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or local_path == "":
		set_error("Could not download transcoded clip (HTTP %d)" % code)
		return
	var title_txt := str(_active_item.get("name", "Media"))
	if not play_local_file(local_path, title_txt):
		set_error("Downloaded clip could not be played as Theora/Vorbis")


## Play a local .ogv file directly on the TV's VideoStreamPlayer.
func play_local_file(path: String, title_txt := "") -> bool:
	if not _built or _video_player == null:
		return false
	if not FileAccess.file_exists(path):
		set_error("Video file not found: %s" % path.get_file())
		return false
	var stream := VideoStreamTheora.new()
	stream.file = path
	_video_player.stop()
	_video_player.stream = stream
	_video_player.paused = false
	_video_player.play()
	if _play_title_lbl:
		_play_title_lbl.text = (title_txt if title_txt != "" else path.get_file()).to_upper()
	_set_state(State.PLAYING)
	if _vp and visible:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return true


func stop_playback() -> void:
	_poll_timer.stop()
	_http_play.cancel_request()
	_http_poll.cancel_request()
	_http_dl.cancel_request()
	if _video_player:
		_video_player.stop()
		_video_player.stream = null
	_set_state(State.BROWSE)
	if _vp and visible:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_video_finished() -> void:
	if state == State.PLAYING:
		stop_playback()


func set_error(msg: String) -> void:
	_poll_timer.stop()
	if _status_banner:
		_status_banner.text = "ERROR · " + msg
	if _header_meta:
		_header_meta.text = "OFFLINE"
	_set_state(State.ERROR)


func is_playing() -> bool:
	return state == State.PLAYING and _video_player != null and _video_player.is_playing()


func playback_position() -> float:
	return _video_player.stream_position if _video_player else 0.0


func video_player() -> VideoStreamPlayer:
	return _video_player


func library_count() -> int:
	return _libraries.size()


func item_count() -> int:
	if not _items_by_lib.has(_active_lib_id):
		return 0
	var arr: Array = _items_by_lib[_active_lib_id]
	return arr.size()


# ---------------------------------------------------------------- placement & resize

func set_spot(wall_in: String, u: float, v: float) -> void:
	if WALLS.has(wall_in):
		wall = wall_in
	_u = u
	_v = v
	_place()


func set_width(w: float) -> void:
	var clamped_w := clampf(w, MIN_WIDTH, MAX_WIDTH)
	size = Vector2(clamped_w, clamped_w / ASPECT)
	if _built:
		_rebuild_geometry()
		_place()


func panel_size() -> Vector2:
	return size


func spot() -> Dictionary:
	return {"wall": wall, "u": _u, "v": _v, "width": size.x}


func _place() -> void:
	var w: Dictionary = WALLS[wall]
	var clamped := _clamped(_u, _v)
	_u = clamped.x
	_v = clamped.y
	if wall == "front":
		position = Vector3(_u, _v, float(w["pos"]))
	else:
		position = Vector3(float(w["pos"]), _v, _u)
	rotation_degrees = Vector3(0.0, float(w["yaw"]), 0.0)


func _clamped(u: float, v: float) -> Vector2:
	var w: Dictionary = WALLS[wall]
	var hw := size.x * 0.5 + 0.08
	var hh := size.y * 0.5 + 0.08
	return Vector2(
		clampf(u, float(w["umin"]) + hw, float(w["umax"]) - hw),
		clampf(v, 0.45 + hh, 3.10 - hh))


func _save_store() -> void:
	var out := {"version": 1, "wall": wall, "u": _u, "v": _v, "width": size.x}
	var f := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()


func _load_store() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != 1:
		return {}
	return d


# ---------------------------------------------------------------- pointer ray contract

## World ray -> Vector3(pixel_x, pixel_y, distance), or null if missed / hidden.
func pick(origin: Vector3, dir: Vector3) -> Variant:
	if not visible or not _built or _display == null:
		return null
	var inv := _display.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-5:
		return null
	var t := -o.z / d.z
	if t < 0.0:
		return null
	var p := o + d * t
	if absf(p.x) > size.x * 0.5 or absf(p.y) > size.y * 0.5:
		return null
	var uv := Vector2(p.x / size.x + 0.5, 0.5 - p.y / size.y)
	return Vector3(uv.x * VP_SIZE.x, uv.y * VP_SIZE.y, t * dir.length())


func push(ev: InputEvent) -> void:
	if not visible or _vp == null:
		return
	poke()
	_vp.push_input(ev)


# ---------------------------------------------------------------- hand grab / 2-hand resize contract

func can_grab(hand: Node3D) -> bool:
	if not visible or not _built:
		return false
	if hand in _hands or _hands.size() >= 2:
		return false
	var loc := to_local(hand.global_position)
	return absf(loc.x) <= size.x * 0.5 + 0.30 and absf(loc.y) <= size.y * 0.5 + 0.30 and absf(loc.z) <= 0.55


func is_held() -> bool:
	return not _hands.is_empty()


func begin_grab(hand: Node3D) -> void:
	if hand in _hands or _hands.size() >= 2:
		return
	_hands.append(hand)
	_recapture()
	set_all_hot(true)
	if hand.has_method("buzz"):
		hand.buzz(0.03, 0.5)


func end_grab(hand: Node3D) -> void:
	if not (hand in _hands):
		return
	_hands.erase(hand)
	if hand.has_method("buzz"):
		hand.buzz(0.02, 0.3)
	if _hands.size() == 1:
		_recapture()
	elif _hands.is_empty():
		set_all_hot(false)
		_u = snappedf(_u, 0.05)
		_v = snappedf(_v, 0.05)
		_place()
		_save_store()
		changed.emit(self)


func _recapture() -> void:
	if _hands.size() == 1:
		_grab_off = _hand_wall_coords(_hands[0]) - Vector2(_u, _v)
	elif _hands.size() == 2:
		_resize_d0 = maxf(_hands[0].global_position.distance_to(_hands[1].global_position), 0.05)
		_resize_w0 = size.x
		_grab_off = _mid_wall_coords() - Vector2(_u, _v)


func set_all_hot(v: bool) -> void:
	if _rim:
		_rim.visible = v
	if _rim_mat:
		_rim_mat.albedo_color = Color(Tokens.HOLO_LINE, 0.28 if v else 0.0)


func _hand_wall_coords(hand: Node3D) -> Vector2:
	var p := hand.global_position
	if wall == "front":
		return Vector2(p.x, p.y)
	return Vector2(p.z, p.y)


func _mid_wall_coords() -> Vector2:
	return (_hand_wall_coords(_hands[0]) + _hand_wall_coords(_hands[1])) * 0.5


func step(dt: float) -> void:
	if _hands.size() == 1:
		var target := _clamped(_hand_wall_coords(_hands[0]).x - _grab_off.x, _hand_wall_coords(_hands[0]).y - _grab_off.y)
		var alpha := clampf(dt * 14.0, 0.0, 1.0)
		_u = lerpf(_u, target.x, alpha)
		_v = lerpf(_v, target.y, alpha)
		_place()
	elif _hands.size() == 2:
		var d := maxf(_hands[0].global_position.distance_to(_hands[1].global_position), 0.05)
		var new_w := clampf(_resize_w0 * d / _resize_d0, MIN_WIDTH, MAX_WIDTH)
		if absf(new_w - size.x) > 0.002:
			size = Vector2(new_w, new_w / ASPECT)
			_rebuild_geometry()
		var mid := _mid_wall_coords() - _grab_off
		var target := _clamped(mid.x, mid.y)
		var alpha := clampf(dt * 14.0, 0.0, 1.0)
		_u = lerpf(_u, target.x, alpha)
		_v = lerpf(_v, target.y, alpha)
		_place()


func _process(delta: float) -> void:
	if not _built:
		return
	if not _hands.is_empty():
		step(delta)
	if not visible:
		if _vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if state == State.PLAYING:
		if _vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _play_bar and _play_bar.visible and _controls_hide_t > 0.0:
			_controls_hide_t -= delta
			if _controls_hide_t <= 0.0:
				_play_bar.visible = false
	else:
		if _poke_t > 0.0:
			_poke_t -= delta
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			if _poke_t <= 0.0:
				_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif _needs_once:
			_needs_once = false
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			if _vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
				_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

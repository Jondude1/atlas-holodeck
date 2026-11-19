class_name Tokens
## Show-accuracy design tokens (SPEC §2.6). Single source of truth: nothing else in the
## project carries a colour literal. Alpha variants go through a().

const ROOM_BG := Color("#04070C")        # room/background near-black blue
const HOLO_DEEP := Color("#0B3556")      # panel fills, translucent volume base
const HOLO_PRIMARY := Color("#2F7FC4")   # bodies, grid majors
const HOLO_LINE := Color("#7FD4FF")      # edge line-work, ring strokes, text accents
const HOLO_CORE := Color("#EAF7FF")      # white-hot cores, active highlights
const GRID_MINOR := Color("#1D5F8A")     # minor grid lines (use at GRID_MINOR_ALPHA)
const TABLE_SURFACE := Color("#06283F")  # table plane base (display inset)
const TITANIUM := Color("#3B4046")       # table body: machined dark titanium (one step up from #33373D, first-contact tune)
const TITANIUM_DARK := Color("#1A1D21")  # under-slab apron / bezel screen housing

const GRID_MINOR_ALPHA := 0.35
const PANEL_ALPHA := 0.5           # holo_deep panel fill, range 0.35-0.55
const VOLUME_ALPHA := 0.28         # hologram volume fill, range 0.18-0.35

# Ring geometry token
const RING_MINOR_TICKS := 60       # every 6 degrees
const RING_MAJOR_TICKS := 12       # every 30 degrees, ~2x length
const RING_INNER := [0.82, 0.64]   # inner ring radii (fraction of the outer ring)

# Table grid token (scene units = metres): 6 in minor, 1 ft major
const GRID_MINOR_STEP := 0.1524
const GRID_MAJOR_STEP := 0.3048

const FONT_REGULAR := "res://fonts/Rajdhani-Medium.ttf"
const FONT_BOLD := "res://fonts/Rajdhani-SemiBold.ttf"

static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)

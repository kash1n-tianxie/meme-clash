extends RefCounted
## Summer cut-paper fight identity. HD type and focus shapes frame the pixel world.
const CREAM := Color("FFF8E8")
const SEA := Color("58D8E8")
const AQUA := Color("1BAFCA")
const NAVY := Color("173B55")
const SUN := Color("FFD75C")
const CORAL := Color("FF8A75")
const MUTED := Color("426177")
const HOVER_SECONDS := 0.15
const CONFIRM_SECONDS := 0.24
const PAGE_SECONDS := 0.32
const MENU_BPM := 160.0
const TEXT_SIZE := 20
const SMALL_TEXT_SIZE := 16
const TITLE_SIZE := 54
const LAYER_BACKDROP := -3
const LAYER_SCENERY := -2
const LAYER_PERFORMERS := -1
const LAYER_INTERFACE := 0
const LAYER_TRANSITION := 10

## The world uses an integer pixel grid; these remain high-resolution interface values.
const LOGICAL_UI_SIZE := Vector2i(1280, 720)
const PIXEL_WORLD_SIZE := Vector2i(320, 180)
const PIXEL_DISPLAY_SCALE := 4
const MENU_DANCE_BEATS := 2.0

## Component hierarchy: only the chosen menu expands its paper background.
const PRINT_EDGE_WIDTH := 2.0
const MENU_STEP := Vector2(-13, 75)
const KEYCAP_HEIGHT := 29.0

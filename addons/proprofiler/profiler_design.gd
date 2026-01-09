###############################################################
# addons/proprofiler/profiler_design.gd
# Global design system: colors, sizes, fonts, spacing
# Used by all profiler tabs and UI components
###############################################################


# ──────────────────── PALETTE ────────────────────
# Apple-inspired minimal color system

# Backgrounds
const COLOR_BG_PRIMARY: Color = Color(0.12, 0.12, 0.14, 1.0)
const COLOR_BG_SECONDARY: Color = Color(0.08, 0.08, 0.10, 1.0)
const COLOR_BG_TERTIARY: Color = Color(0.15, 0.15, 0.17, 1.0)

# Text
const COLOR_TEXT: Color = Color(0.90, 0.90, 0.90, 1.0)
const COLOR_TEXT_DIM: Color = Color(0.55, 0.55, 0.60, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.40, 0.40, 0.45, 1.0)

# Status colors
const COLOR_GOOD: Color = Color(0.30, 0.85, 0.50, 1.0)     # Green - good performance
const COLOR_WARN: Color = Color(0.95, 0.75, 0.20, 1.0)     # Yellow - warning
const COLOR_BAD: Color = Color(0.95, 0.30, 0.30, 1.0)      # Red - critical
const COLOR_NEUTRAL: Color = Color(0.50, 0.70, 0.95, 1.0)  # Blue - neutral

# Accents
const COLOR_SELECT: Color = Color(0.40, 0.70, 1.00, 0.9)   # Selection highlight
const COLOR_GRID: Color = Color(0.15, 0.15, 0.18, 1.0)     # Grid lines
const COLOR_DIVIDER: Color = Color(0.20, 0.20, 0.22, 1.0)  # Separators

# File type colors (for charts & trees)
const COLOR_TYPE_IMAGE: Color = Color(1.0, 0.50, 0.25, 1.0)   # Orange - images
const COLOR_TYPE_AUDIO: Color = Color(0.80, 0.30, 0.80, 1.0)  # Magenta - audio
const COLOR_TYPE_VIDEO: Color = Color(0.95, 0.20, 0.60, 1.0)  # Pink/Red - video
const COLOR_TYPE_CODE: Color = Color(0.40, 0.80, 1.0, 1.0)    # Cyan - code
const COLOR_TYPE_SCENE: Color = Color(0.50, 1.0, 0.50, 1.0)   # Green - scenes
const COLOR_TYPE_DATA: Color = Color(1.0, 0.80, 0.40, 1.0)    # Gold - JSON/data
const COLOR_TYPE_SHADER: Color = Color(1.0, 0.40, 0.80, 1.0)  # Pink - shaders
const COLOR_TYPE_FONT: Color = Color(0.70, 0.85, 1.0, 1.0)    # Light blue - fonts
const COLOR_TYPE_OTHER: Color = Color(0.60, 0.60, 0.65, 1.0)  # Gray - other

# Performance targets
const COLOR_TARGET_60FPS: Color = Color(0.30, 0.85, 0.50, 0.3)
const COLOR_TARGET_30FPS: Color = Color(0.95, 0.75, 0.20, 0.3)


# ──────────────────── TYPOGRAPHY ────────────────────

const FONT_SIZE_TITLE: int = 26
const FONT_SIZE_HEADING: int = 24
const FONT_SIZE_BODY: int = 22
const FONT_SIZE_SMALL: int = 18
const FONT_SIZE_TINY: int = 16


# ──────────────────── SPACING & SIZING ────────────────────

# Margins & padding
const MARGIN_LARGE: int = 20
const MARGIN_STANDARD: int = 18
const MARGIN_SMALL: int = 16
const MARGIN_TINY: int = 14

# Component heights
const HEIGHT_STAT_ROW: int = 48
const HEIGHT_BUTTON: int = 32
const HEIGHT_INPUT: int = 28
const HEIGHT_TREE_ROW: int = 24

# Component widths
const WIDTH_STAT_ITEM: int = 70
const WIDTH_BUTTON_ICON: int = 32

# Graph/Chart sizing
const GRAPH_PADDING: int = 60
const CHART_BAR_HEIGHT: int = 24
const CHART_GAP: int = 8


# ──────────────────── CPU PROFILER SPECIFIC ────────────────────

const PROFILER_MAX_HISTORY: int = 1800  # 30 seconds @ 60fps
const PROFILER_FRAME_WIDTH: float = 3.0
const PROFILER_TARGET_60FPS: float = 16.67
const PROFILER_TARGET_30FPS: float = 33.33


# ──────────────────── HELPER FUNCTIONS ────────────────────

## Get color for file type
static func get_type_color(file_extension: String) -> Color:
    match file_extension.to_lower():
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp":
            return COLOR_TYPE_IMAGE
        "mp4", "avi", "mov", "mkv", "flv", "webm", "ogv":
            return COLOR_TYPE_VIDEO
        "ogg", "mp3", "wav", "aiff", "flac":
            return COLOR_TYPE_AUDIO
        "gd", "py", "cs", "cpp", "h", "ts", "js", "rs":
            return COLOR_TYPE_CODE
        "tscn", "tres":
            return COLOR_TYPE_SCENE
        "json", "yaml", "toml", "cfg", "ini", "txt":
            return COLOR_TYPE_DATA
        "gdshader", "glsl", "shader":
            return COLOR_TYPE_SHADER
        "ttf", "otf", "woff", "woff2":
            return COLOR_TYPE_FONT
        _:
            return COLOR_TYPE_OTHER


## Get category for file extension
static func get_file_category(file_extension: String) -> String:
    match file_extension.to_lower():
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp":
            return "Images"
        "mp4", "avi", "mov", "mkv", "flv", "webm", "ogv":
            return "Videos"
        "ogg", "mp3", "wav", "aiff", "flac":
            return "Audio"
        "gd", "py", "cs", "cpp", "h", "ts", "js", "rs":
            return "Code"
        "tscn", "tres":
            return "Scenes"
        "json", "yaml", "toml", "cfg", "ini", "txt":
            return "Data"
        "gdshader", "glsl", "shader":
            return "Shaders"
        "ttf", "otf", "woff", "woff2":
            return "Fonts"
        _:
            return "Other"


## Format bytes to human-readable string
static func format_bytes(bytes: int) -> String:
    if bytes < 1024:
        return "%d B" % bytes
    elif bytes < 1024 * 1024:
        return "%.1f KB" % (bytes / 1024.0)
    elif bytes < 1024 * 1024 * 1024:
        return "%.1f MB" % (bytes / (1024.0 * 1024.0))
    else:
        return "%.1f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))


## Format percentage with 1 decimal
static func format_percent(percent: float) -> String:
    return "%.1f%%" % percent

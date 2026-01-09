###############################################################
# addons/proprofiler/cpu_profiler/core/profiler_constants.gd
# Backward compatibility wrapper for ProfilerDesign
###############################################################

class_name ProfilerConstants

# Re-export design constants for backward compatibility
const Design = preload("res://addons/proprofiler/profiler_design.gd")

# Configuration
const MAX_HISTORY: int = Design.PROFILER_MAX_HISTORY
const FRAME_WIDTH: float = Design.PROFILER_FRAME_WIDTH
const TARGET_60FPS: float = Design.PROFILER_TARGET_60FPS
const TARGET_30FPS: float = Design.PROFILER_TARGET_30FPS
const GRAPH_PADDING: int = Design.GRAPH_PADDING

# Colors
const COLOR_BG: Color = Design.COLOR_BG_PRIMARY
const COLOR_GRAPH_BG: Color = Design.COLOR_BG_SECONDARY
const COLOR_TEXT: Color = Design.COLOR_TEXT
const COLOR_TEXT_DIM: Color = Design.COLOR_TEXT_DIM
const COLOR_GOOD: Color = Design.COLOR_GOOD
const COLOR_WARN: Color = Design.COLOR_WARN
const COLOR_BAD: Color = Design.COLOR_BAD
const COLOR_SELECT: Color = Design.COLOR_SELECT
const COLOR_GRID: Color = Design.COLOR_GRID
const COLOR_TARGET_60: Color = Design.COLOR_TARGET_60FPS
const COLOR_TARGET_30: Color = Design.COLOR_TARGET_30FPS

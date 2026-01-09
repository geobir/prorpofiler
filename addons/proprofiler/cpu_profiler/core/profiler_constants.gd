###############################################################
# addons/proprofiler/cpu_profiler/core/profiler_constants.gd
# Backward compatibility wrapper for ProfilerDesign
###############################################################

# Re-export Profilerdesign constants for backward compatibility
const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")

# Configuration
const MAX_HISTORY: int = ProfilerDesign.PROFILER_MAX_HISTORY
const FRAME_WIDTH: float = ProfilerDesign.PROFILER_FRAME_WIDTH
const TARGET_60FPS: float = ProfilerDesign.PROFILER_TARGET_60FPS
const TARGET_30FPS: float = ProfilerDesign.PROFILER_TARGET_30FPS
const GRAPH_PADDING: int = ProfilerDesign.GRAPH_PADDING

# Colors
const COLOR_BG: Color = ProfilerDesign.COLOR_BG_PRIMARY
const COLOR_GRAPH_BG: Color = ProfilerDesign.COLOR_BG_SECONDARY
const COLOR_TEXT: Color = ProfilerDesign.COLOR_TEXT
const COLOR_TEXT_DIM: Color = ProfilerDesign.COLOR_TEXT_DIM
const COLOR_GOOD: Color = ProfilerDesign.COLOR_GOOD
const COLOR_WARN: Color = ProfilerDesign.COLOR_WARN
const COLOR_BAD: Color = ProfilerDesign.COLOR_BAD
const COLOR_SELECT: Color = ProfilerDesign.COLOR_SELECT
const COLOR_GRID: Color = ProfilerDesign.COLOR_GRID
const COLOR_TARGET_60: Color = ProfilerDesign.COLOR_TARGET_60FPS
const COLOR_TARGET_30: Color = ProfilerDesign.COLOR_TARGET_30FPS

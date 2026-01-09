###############################################################
# addons/proprofiler/cpu_profiler/ui/profiler_graph.gd
# Graph visualization and frame selection
###############################################################

extends Control

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")
const CPUProfiler = preload("res://addons/proprofiler/cpu_profiler/core/cpu_profiler.gd")

var profiler: CPUProfiler
var on_frame_selected: Callable


func _ready() -> void:
    gui_input.connect(_on_graph_input)


## Draw graph with frame bars and grid
func draw_graph(frame_times: Array) -> void:
    var count = frame_times.size()
    var height = size.y
    var width = size.x
    
    # Expand graph width to fit all frames
    if count > 0:
        var required_width = ProfilerConstants.GRAPH_PADDING * 2 + count * ProfilerConstants.FRAME_WIDTH
        if required_width > width:
            custom_minimum_size.x = required_width

    # Background
    draw_rect(Rect2(0, 0, width, height), ProfilerConstants.COLOR_GRAPH_BG)

    # Grid
    var max_time = _get_max_time(frame_times) if count > 0 else ProfilerConstants.TARGET_30FPS
    var grid_step = 5.0
    var draw_height = height - ProfilerConstants.GRAPH_PADDING * 2

    for grid_ms in range(0, int(max_time) + 1, int(grid_step)):
        var y = height - ProfilerConstants.GRAPH_PADDING - (grid_ms / max_time) * draw_height
        draw_line(Vector2(0, y), Vector2(width, y), ProfilerConstants.COLOR_GRID)

    if count == 0:
        return

    # Frame bars
    for i in range(count):
        var visual_x = ProfilerConstants.GRAPH_PADDING + i * ProfilerConstants.FRAME_WIDTH

        var time_ms = frame_times[i]
        var bar_height = (time_ms / max_time) * draw_height
        var y = height - ProfilerConstants.GRAPH_PADDING - bar_height

        var color = _get_time_color(time_ms)
        if i == profiler.selected_frame_index:
            color = ProfilerConstants.COLOR_SELECT

        var rect = Rect2(visual_x, y, ProfilerConstants.FRAME_WIDTH - 1, bar_height)
        draw_rect(rect, color)
    
    # Draw vertical selection line
    if profiler.selected_frame_index >= 0 and profiler.selected_frame_index < count:
        var sel_x = ProfilerConstants.GRAPH_PADDING + profiler.selected_frame_index * ProfilerConstants.FRAME_WIDTH + ProfilerConstants.FRAME_WIDTH / 2
        draw_line(Vector2(sel_x, 0), Vector2(sel_x, height), Color.WHITE.lerp(ProfilerConstants.COLOR_GRAPH_BG, 0.3))


## Handle graph clicks
func _on_graph_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var frame_count = profiler.get_frame_count()
        if frame_count == 0:
            return

        var clicked_x = event.position.x - ProfilerConstants.GRAPH_PADDING
        if clicked_x < 0:
            return

        var clicked_frame = int(clicked_x / ProfilerConstants.FRAME_WIDTH) % profiler.get_max_history()
        if clicked_frame >= frame_count:
            return

        on_frame_selected.call(clicked_frame)


## Get max time from frame times
func _get_max_time(frame_times: Array) -> float:
    var max_time: float = ProfilerConstants.TARGET_30FPS
    for t in frame_times:
        if t > max_time:
            max_time = t
    return maxf(max_time * 1.1, ProfilerConstants.TARGET_30FPS)


## Get color based on frame time
func _get_time_color(time_ms: float) -> Color:
    if time_ms <= ProfilerConstants.TARGET_60FPS:
        return ProfilerConstants.COLOR_GOOD
    elif time_ms <= ProfilerConstants.TARGET_30FPS:
        return ProfilerConstants.COLOR_WARN
    return ProfilerConstants.COLOR_BAD

###############################################################
# addons/proprofiler/cpu_profiler/ui/profiler_stats.gd
# Real-time stats display: FPS, frame time, memory
###############################################################

extends HBoxContainer

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")

var lbl_fps: Label
var lbl_average_fps: Label
var lbl_frame_time: Label
var lbl_peak_frame: Label
var lbl_memory: Label


func _ready() -> void:
    add_theme_constant_override("separation", 24)
    custom_minimum_size = Vector2(0, 48)

    lbl_fps = _create_stat_item("FPS", "0", ProfilerConstants.COLOR_TEXT)
    lbl_average_fps = _create_stat_item("AVG", "0", ProfilerConstants.COLOR_TEXT_DIM)
    lbl_frame_time = _create_stat_item("FRAME", "0.00 ms", ProfilerConstants.COLOR_GOOD)
    lbl_peak_frame = _create_stat_item("PEAK", "0.00 ms", ProfilerConstants.COLOR_BAD)
    lbl_memory = _create_stat_item("MEM", "0 MB", Color(0.5, 0.8, 1.0))


## Update all stats
func update_stats(current_fps: int, avg_fps: int, frame_time: float, peak_time: float, mem: int) -> void:
    lbl_fps.text = "%d" % current_fps
    lbl_fps.add_theme_color_override("font_color", _get_fps_color(current_fps))

    lbl_average_fps.text = "%d" % avg_fps
    lbl_frame_time.text = "%.2f ms" % frame_time
    lbl_frame_time.add_theme_color_override("font_color", _get_time_color(frame_time))

    lbl_peak_frame.text = "%.2f ms" % peak_time
    lbl_memory.text = "%d MB" % mem


## Create a stat item (label pair)
func _create_stat_item(title: String, value: String, color: Color) -> Label:
    var vbox = VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(70, 0)

    var lbl_title = Label.new()
    lbl_title.text = title
    lbl_title.add_theme_font_size_override("font_size", 16)
    lbl_title.add_theme_color_override("font_color", ProfilerConstants.COLOR_TEXT_DIM)
    lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lbl_title)

    var lbl_value = Label.new()
    lbl_value.text = value
    lbl_value.add_theme_font_size_override("font_size", 18)
    lbl_value.add_theme_color_override("font_color", color)
    lbl_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(lbl_value)

    add_child(vbox)
    return lbl_value


## Get FPS color
func _get_fps_color(fps: int) -> Color:
    if fps >= 55:
        return ProfilerConstants.COLOR_GOOD
    elif fps >= 30:
        return ProfilerConstants.COLOR_WARN
    return ProfilerConstants.COLOR_BAD


## Get time color
func _get_time_color(time_ms: float) -> Color:
    if time_ms <= ProfilerConstants.TARGET_60FPS:
        return ProfilerConstants.COLOR_GOOD
    elif time_ms <= ProfilerConstants.TARGET_30FPS:
        return ProfilerConstants.COLOR_WARN
    return ProfilerConstants.COLOR_BAD

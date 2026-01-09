###############################################################
# addons/proprofiler/cpu_profiler/ui/profiler_breakdown.gd
# Frame breakdown tree display with timing details
###############################################################

extends Tree

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")
const ProfilerFrameData = preload("res://addons/proprofiler/cpu_profiler/core/profiler_data.gd")
const CPUProfiler = preload("res://addons/proprofiler/cpu_profiler/core/cpu_profiler.gd")

var profiler: CPUProfiler


func _ready() -> void:
    hide_root = true
    columns = 3
    set_column_title(0, "Process")
    set_column_title(1, "Time")
    set_column_title(2, "Info")
    set_column_expand(0, true)
    set_column_expand(1, false)
    set_column_expand(2, false)
    set_column_custom_minimum_width(0, 200)
    set_column_custom_minimum_width(1, 80)
    set_column_custom_minimum_width(2, 100)


## Update tree with frame data
func update_breakdown(frame_data: ProfilerFrameData, selected_idx: int) -> void:
    clear()

    if not frame_data:
        return

    var root = create_item()

    # Summary header
    var summary = create_item(root)
    var title = "📊 Frame #%d" % selected_idx if selected_idx >= 0 else "📊 Current Frame"
    summary.set_text(0, title)
    summary.set_text(1, "%.2f ms" % frame_data.frame_time_ms)
    # summary.set_text(2, "%.2f ms" % frame_data.frame_time_ms)
    summary.set_custom_color(0, ProfilerConstants.COLOR_TEXT)
    summary.set_custom_color(1, _get_time_color(frame_data.frame_time_ms))

    # Process categories
    for proc in frame_data.processes:
        var proc_item = create_item(root)
        var proc_time = proc.get("time", 0.0) if proc is Dictionary else 0.0
        var proc_name = proc.get("name", "Unknown") if proc is Dictionary else ""
        var proc_details = proc.get("details", "") if proc is Dictionary else ""

        proc_item.set_text(0, proc_name)
        proc_item.set_text(1, "%.2f ms" % proc_time if proc_time > 0.01 else "-")
        proc_item.set_text(2, proc_details)
        proc_item.set_custom_color(0, ProfilerConstants.COLOR_TEXT)
        proc_item.set_custom_color(1, _get_time_color(proc_time) if proc_time > 0.01 else ProfilerConstants.COLOR_TEXT_DIM)
        proc_item.set_custom_color(2, ProfilerConstants.COLOR_TEXT_DIM)
        proc_item.collapsed = false

        # Children
        var children = proc.get("children", []) if proc is Dictionary else []
        for child in children:
            var child_item = create_item(proc_item)
            var child_time = child.get("time", 0.0) if child is Dictionary else 0.0
            var child_name = child.get("name", "Unknown") if child is Dictionary else ""
            var child_details = child.get("details", "") if child is Dictionary else ""

            child_item.set_text(0, "  └ " + child_name)
            child_item.set_text(1, "%.2f ms" % child_time if child_time > 0.01 else "-")
            child_item.set_text(2, child_details)
            child_item.set_custom_color(0, ProfilerConstants.COLOR_TEXT_DIM)
            child_item.set_custom_color(1, _get_time_color(child_time) if child_time > 0.01 else ProfilerConstants.COLOR_TEXT_DIM)
            child_item.set_custom_color(2, ProfilerConstants.COLOR_TEXT_DIM)
            child_item.collapsed = false
            
            # Sub-children for even more detail
            var sub_children = child.get("children", []) if child is Dictionary else []
            for sub_child in sub_children:
                var sub_item = create_item(child_item)
                var sub_time = sub_child.get("time", 0.0) if sub_child is Dictionary else 0.0
                var sub_name = sub_child.get("name", "Unknown") if sub_child is Dictionary else ""
                var sub_details = sub_child.get("details", "") if sub_child is Dictionary else ""
                
                sub_item.set_text(0, "    └ " + sub_name)
                sub_item.set_text(1, "%.3f ms" % sub_time if sub_time > 0.001 else "-")
                sub_item.set_text(2, sub_details)
                sub_item.set_custom_color(0, ProfilerConstants.COLOR_TEXT_DIM)
                sub_item.set_custom_color(1, _get_time_color(sub_time) if sub_time > 0.001 else ProfilerConstants.COLOR_TEXT_DIM)
                sub_item.set_custom_color(2, ProfilerConstants.COLOR_TEXT_DIM)


## Get time color
func _get_time_color(time_ms: float) -> Color:
    if time_ms <= ProfilerConstants.TARGET_60FPS:
        return ProfilerConstants.COLOR_GOOD
    elif time_ms <= ProfilerConstants.TARGET_30FPS:
        return ProfilerConstants.COLOR_WARN
    return ProfilerConstants.COLOR_BAD

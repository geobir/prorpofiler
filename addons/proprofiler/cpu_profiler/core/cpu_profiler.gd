###############################################################
# addons/proprofiler/cpu_profiler/core/cpu_profiler.gd
# Main profiler: collects and manages frame data
###############################################################

extends RefCounted

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")
const ProfilerFrameData = preload("res://addons/proprofiler/cpu_profiler/core/profiler_data.gd")
const ProfilerCollector = preload("res://addons/proprofiler/cpu_profiler/core/profiler_collector.gd")

var collector = ProfilerCollector.new()

var frame_history: Array = []
var current_frame_index: int = 0
var frame_count: int = 0
var start_time: float = 0.0

var peak_frame_time: float = 0.0
var average_frame_time: float = 0.0

var is_paused: bool = false
var paused_frame_index: int = -1
var selected_frame_index: int = -1

var is_active: bool = false  # Only collect data when game is running


func _init() -> void:
    start_time = Time.get_ticks_msec() / 1000.0


## Sample current frame
func sample_frame(delta: float) -> void:
    if not is_active or is_paused:
        return

    var frame_time_ms: float = delta * 1000.0
    var current_fps: int = ceili(1.0 / delta) if delta > 0.0 else 0
    var mem_mb: int = ceili(float(OS.get_static_memory_usage()) / (1024.0 * 1024.0))
    var timestamp: float = (Time.get_ticks_msec() / 1000.0) - start_time

    var fd = ProfilerFrameData.new(frame_time_ms, current_fps, mem_mb, timestamp)
    collector.collect_process_data(fd, delta)

    frame_history.append(fd)

    if frame_time_ms > peak_frame_time:
        peak_frame_time = frame_time_ms

    frame_count += 1
    _update_average()


## Get current FPS
func get_current_fps() -> int:
    if frame_count == 0:
        return 0
    return frame_history[frame_history.size() - 1].fps


## Get average FPS
func get_average_fps() -> int:
    var sum: int = 0
    var count: int = frame_history.size()
    for i in range(count):
        sum += frame_history[i].fps
    return ceili(float(sum) / float(count)) if count > 0 else 0


## Get current memory
func get_current_memory() -> int:
    if frame_count == 0:
        return 0
    return frame_history[frame_history.size() - 1].memory_mb


## Get frame times for graphing
func get_frame_times() -> Array:
    var times: Array = []
    for frame_data in frame_history:
        times.append(frame_data.frame_time_ms)
    return times


## Toggle pause state
func toggle_pause() -> void:
    is_paused = !is_paused
    if is_paused:
        paused_frame_index = frame_history.size() - 1


## Start/stop data collection
func set_active(active: bool) -> void:
    is_active = active
    if active:
        is_paused = false
    print("[CPUProfiler] Data collection ", "ACTIVE" if active else "INACTIVE")


## Get paused frame data
func get_paused_frame() -> ProfilerFrameData:
    if selected_frame_index >= 0 and selected_frame_index < frame_history.size():
        return frame_history[selected_frame_index]
    if paused_frame_index >= 0 and paused_frame_index < frame_history.size():
        return frame_history[paused_frame_index]
    if frame_history.size() > 0:
        return frame_history[frame_history.size() - 1]
    return frame_history[0] if frame_history.size() > 0 else null


## Get frame at index
func get_frame_at(idx: int) -> ProfilerFrameData:
    if idx >= 0 and idx < frame_history.size():
        return frame_history[idx]
    return null


## Select frame for inspection
func select_frame(idx: int) -> void:
    selected_frame_index = clampi(idx, 0, frame_history.size() - 1)


## Get frame count
func get_frame_count() -> int:
    return frame_history.size()


## Get max history
func get_max_history() -> int:
    return frame_history.size()


## Get current frame index
func get_current_frame_index() -> int:
    return frame_history.size() - 1


## Reset all data
func reset() -> void:
    start_time = Time.get_ticks_msec() / 1000.0
    frame_history.clear()
    frame_count = 0
    peak_frame_time = 0.0
    average_frame_time = 0.0
    is_paused = false


## Update average frame time
func _update_average() -> void:
    var sum: float = 0.0
    var count: int = frame_history.size()
    for i in range(count):
        sum += frame_history[i].frame_time_ms
    average_frame_time = sum / float(count) if count > 0 else 0.0

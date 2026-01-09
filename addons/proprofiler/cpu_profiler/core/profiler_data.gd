###############################################################
# addons/proprofiler/cpu_profiler/core/profiler_data.gd
# Data structures: FrameData and ProcessData classes
###############################################################

extends RefCounted


## Process data container for breakdown tree
class ProfilerProcessData:
    var name: String
    var time_ms: float = 0.0
    var details: String = ""
    var children: Array[ProfilerProcessData] = []

    func _init(p_name: String, p_time: float = 0.0, p_details: String = "") -> void:
        name = p_name
        time_ms = p_time
        details = p_details


## Main frame data container
var frame_time_ms: float = 0.0
var fps: int = 0
var memory_mb: int = 0
var timestamp: float = 0.0
var processes: Array = []  # Array of process data dictionaries


func _init(p_time_ms: float = 0.0, p_fps: int = 0, p_mem_mb: int = 0, p_timestamp: float = 0.0) -> void:
    frame_time_ms = p_time_ms
    fps = p_fps
    memory_mb = p_mem_mb
    timestamp = p_timestamp
    processes = []

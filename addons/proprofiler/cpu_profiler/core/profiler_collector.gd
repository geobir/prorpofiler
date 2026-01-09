###############################################################
# addons/proprofiler/cpu_profiler/core/profiler_collector.gd
# Collects performance metrics from Godot monitors
###############################################################

extends RefCounted

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")
const ProfilerFrameData = preload("res://addons/proprofiler/cpu_profiler/core/profiler_data.gd")

## Collect detailed process/function timing data - GAME ONLY
func collect_process_data(fd: ProfilerFrameData, delta: float) -> void:
    # Get ONLY game-relevant performance data
    var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
    var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

    # Object counts for context
    var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

    # Only show GAME processes - Scripts and Physics
    var processes = [
        {
            "name": "📝 Game Scripts",
            "time": process_time,
            "calls": int(node_count),
            "details": "%d active nodes" % int(node_count),
            "children": []
        },
        {
            "name": "⚙️ Physics Simulation",
            "time": physics_time,
            "calls": 1,
            "details": "Physics bodies & collisions",
            "children": []
        },
    ]
    fd.processes = processes
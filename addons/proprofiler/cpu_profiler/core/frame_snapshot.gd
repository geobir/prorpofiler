###############################################################
# addons/proprofiler/cpu_profiler/core/frame_snapshot.gd
# Key funcs/classes: • FrameSnapshot – serialize ProfilerFrameData to JSON
# Critical consts    • none
###############################################################

extends RefCounted


static func _process_process_entry(proc) -> Dictionary:
    # proc may be a Dictionary or an object with properties
    var d := {}
    if typeof(proc) == TYPE_DICTIONARY:
        for k in proc.keys():
            d[k] = proc[k]
    else:
        # safe property copy
        if proc is Object:
            for p in ["name", "time_ms", "calls", "details", "children"]:
                if proc.has_method("get") or proc.has_property(p):
                    d[p] = proc.get(p) if proc.has_method("get") else proc.get(p)
    # children recursion
    if d.has("children") and typeof(d.children) == TYPE_ARRAY:
        var kids := []
        for c in d.children:
            kids.append(_process_process_entry(c))
        d.children = kids
    return d


static func frame_to_dict(frame) -> Dictionary:
    # frame: ProfilerFrameData-like object
    var out := {}
    if frame == null:
        return {"error": "no_frame"}
    
    # common fields (safe getters)
    for key in ["frame_time_ms", "fps", "memory_mb", "timestamp"]:
        if typeof(frame) == TYPE_DICTIONARY:
            if frame.has(key):
                out[key] = frame[key]
        elif frame is Object:
            out[key] = frame.get(key) if frame.has_property(key) else null
    
    # processes / breakdown
    out["processes"] = []
    var procs = null
    if typeof(frame) == TYPE_DICTIONARY:
        if frame.has("processes"):
            procs = frame["processes"]
    elif frame is Object and frame.has_property("processes"):
        procs = frame.processes
    
    if procs:
        for p in procs:
            out["processes"].append(_process_process_entry(p))
    
    return out


static func snapshot_to_json(snapshot: Dictionary, pretty: bool = true) -> String:
    # JSON.print may not be available on all Godot versions; use stringify for compatibility
    return JSON.stringify(snapshot)


static func copy_frame_to_clipboard(frame) -> bool:
    var dict = frame_to_dict(frame)
    var json_str = snapshot_to_json(dict, true)
    if json_str == "":
        return false
    DisplayServer.clipboard_set(json_str)
    return true


static func save_frame_to_file(frame, path: String = "") -> String:
    var dict = frame_to_dict(frame)
    if path == "":
        var ts = str(Time.get_unix_time_from_system())
        path = "user://profiler_snapshot_%s.json" % ts
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to open snapshot file: %s" % path)
        return ""
    
    file.store_string(snapshot_to_json(dict, true))
    return path

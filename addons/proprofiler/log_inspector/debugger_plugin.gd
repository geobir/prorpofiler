@tool
extends EditorDebuggerPlugin

signal log_received(entry: Dictionary)

# Custom channel for our RuntimeLogger
const MESSAGE_CHANNEL = "gd_profiler:log"

func _has_capture(prefix: String) -> bool:
    # Capture our custom channel, plus standard errors, outputs, and the new 4.5 backtrace channel
    return prefix == "gd_profiler" or prefix == "error" or prefix == "output" or prefix == "error:with_backtrace"

func _setup_session(session_id: int) -> void:
    # Diagnostic to confirm session start
    print("[GDProfiler] Debug Session Started: ", session_id)

func _capture(message: String, data: Array, session_id: int) -> bool:
    # 1. Custom Channel (Rich Data from our RuntimeLogger)
    if message == MESSAGE_CHANNEL:
        if data.size() > 0:
            var raw = data[0]
            if raw is Dictionary:
                _process_rich_log(raw)
        return true
        
    # 2. Standard Output (print statements)
    if message == "output":
         _process_output(data)
         return false # Let it pass through to standard output

    # 3. Standard Godot Errors (Standard & Backtrace versions)
    if message == "error":
        _process_standard_error(data)
        return false # Let it pass through
        
    if message == "error:with_backtrace":
        _process_error_with_backtrace(data)
        return false

    return false

func _process_output(data: Array) -> void:
    var msg_str = ""
    for part in data:
        msg_str += str(part)
        
    # Check if it's a GDScript static warning sent over output
    if "GDScript::" in msg_str or "UNUSED_" in msg_str or "<GDScript Error>" in msg_str:
        var entry = _parse_gdscript_warning(msg_str)
        log_received.emit(entry)
        return

    var entry = {
        "time": Time.get_time_string_from_system(),
        "type": "INFO",
        "message": msg_str.strip_edges().split("\n")[0],
        "details": "Output:\n" + msg_str,
        "is_warning": false
    }
    log_received.emit(entry)

func _parse_gdscript_warning(message: String) -> Dictionary:
    var entry = {
        "time": Time.get_time_string_from_system(),
        "type": "WARNING",
        "message": message.strip_edges().split("\n")[0],
        "details": message,
        "is_warning": true
    }
    
    var re_code = RegEx.new()
    re_code.compile("<GDScript Error>(\\w+)")
    var m_code = re_code.search(message)
    if m_code:
        var code = m_code.get_string(1)
        entry.message = "[" + code + "] " + entry.message
        
    var re_loc = RegEx.new()
    re_loc.compile("<GDScript Source>([^:]+):(\\d+)")
    var m_loc = re_loc.search(message)
    if m_loc:
        var file = m_loc.get_string(1)
        var line = m_loc.get_string(2)
        entry.details += "\n\nLocation: " + file + ":" + line
        
    return entry

func _process_standard_error(data: Array) -> void:
    # Expected Legacy/Standard Data Format:
    # [hr, min, sec, msec, func, file, line, err_msg, err_descr, is_warning, callstack_size, ...stack...]
    
    if data.size() < 10:
        _process_fallback_error(data)
        return

    var timestamp = "%02d:%02d:%02d" % [data[0], data[1], data[2]]
    var func_name = str(data[4])
    var file = str(data[5])
    var line = str(data[6])
    var err_msg = str(data[7])
    var descr = str(data[8])
    var is_warning = bool(data[9])
    
    var type_str = "WARNING" if is_warning else "ERROR"
    var message = descr if descr else err_msg
    
    var details = "Type: " + type_str + "\n"
    details += "Message: " + message + "\n"
    details += "Location: " + func_name + " (" + file + ":" + line + ")\n"
    details += "Raw Error: " + err_msg + "\n"
    
    # Parse C++ Callstack if present
    var stack_size = int(data[10])
    var idx = 11
    if stack_size > 0:
        details += "\n--- Call Stack ---\n"
        for i in range(stack_size):
            if idx + 2 < data.size():
                var s_file = str(data[idx])
                var s_func = str(data[idx+1])
                var s_line = str(data[idx+2])
                details += "  [%d] %s (%s:%s)\n" % [i, s_func, s_file, s_line]
                idx += 3

    var entry = {
        "time": timestamp,
        "type": type_str,
        "message": message,
        "details": details,
        "is_warning": is_warning
    }
    log_received.emit(entry)

func _process_error_with_backtrace(data: Array) -> void:
    # Enhanced Data Format (Godot 4.5+):
    # Same prefix as standard error, but appended with script backtraces
    
    if data.size() < 10:
        _process_fallback_error(data)
        return

    var timestamp = "%02d:%02d:%02d" % [data[0], data[1], data[2]]
    var func_name = str(data[4])
    var file = str(data[5])
    var line = str(data[6])
    var err_msg = str(data[7])
    var descr = str(data[8])
    var is_warning = bool(data[9])
    
    var type_str = "WARNING" if is_warning else "ERROR"
    var message = descr if descr else err_msg

    var details = "Type: " + type_str + "\n"
    details += "Message: " + message + "\n"
    details += "Location: " + func_name + " (" + file + ":" + line + ")\n"
    
    # Skip C++ stack (idx 10 + size + data)
    var stack_size = int(data[10])
    var idx = 11 + (stack_size * 3)
    
    # Script Backtraces
    if idx < data.size():
        var bt_count = int(data[idx])
        idx += 1
        if bt_count > 0:
            details += "\n--- Script Backtraces ---\n"
            for i in range(bt_count):
                if idx >= data.size(): break
                var lang = str(data[idx])
                idx += 1
                details += "[Language: " + lang + "]\n"
                
                if idx < data.size():
                    var frame_count = int(data[idx])
                    idx += 1
                    for j in range(frame_count):
                        if idx + 2 < data.size():
                            var f_func = str(data[idx])
                            var f_file = str(data[idx+1])
                            var f_line = str(data[idx+2])
                            details += "  [%d] %s (%s:%s)\n" % [j, f_func, f_file, f_line]
                            idx += 3

    var entry = {
        "time": timestamp,
        "type": type_str,
        "message": message,
        "details": details,
        "is_warning": is_warning
    }
    log_received.emit(entry)

func _process_fallback_error(data: Array) -> void:
    # Matches original fallback or unknown format
    var entry = {
        "time": Time.get_time_string_from_system(),
        "type": "ERROR",
        "message": "Unknown Error Format",
        "details": "Raw Data: " + str(data),
        "is_warning": false
    }
    log_received.emit(entry)

func _process_rich_log(data: Dictionary) -> void:
    var entry = {
        "time": data.get("timestamp", Time.get_time_string_from_system()),
        "type": "INFO",
        "message": "",
        "details": "",
        "backtraces": []
    }
    
    if data.get("event_type") == "error":
        entry.type = data.get("error_type", "ERROR")
        var rationale = data.get("rationale", "")
        # code can be int or string
        var code = str(data.get("code", ""))
        
        entry.message = rationale if rationale else ("Error " + code)
        
        entry.details += "Type: " + entry.type + "\n"
        entry.details += "Message: " + entry.message + "\n"
        entry.details += "Location: " + str(data.get("function", "?")) + " (" + str(data.get("file", "?")) + ":" + str(data.get("line", 0)) + ")\n"
        
        var bts = data.get("backtraces", [])
        if bts.size() > 0:
            entry.details += "\n--- Script Backtraces ---\n"
            for bt in bts:
                entry.details += "[Language: " + str(bt.get("language", "Unknown")) + "]\n"
                var frames = bt.get("frames", [])
                var idx = 0
                for f in frames:
                    entry.details += "  [%d] %s (%s:%s)\n" % [idx, str(f.get("function")), str(f.get("file")), str(f.get("line"))]
                    idx += 1
                entry.details += "\n"
                
    elif data.get("event_type") == "message":
        entry.type = "ERROR" if data.get("is_error") else "INFO"
        entry.message = data.get("message", "")
        entry.details = "Message: " + entry.message + "\n"
        
        var bts = data.get("backtraces", [])
        if bts.size() > 0:
            entry.details += "\n--- Caller Context ---\n"
            for bt in bts:
                entry.details += "[Language: " + str(bt.get("language", "Unknown")) + "]\n"
                var frames = bt.get("frames", [])
                var idx = 0
                # Usually frame 0 is the log call itself, frame 1 is the caller
                for f in frames:
                    entry.details += "  [%d] %s (%s:%s)\n" % [idx, str(f.get("function")), str(f.get("file")), str(f.get("line"))]
                    idx += 1
                entry.details += "\n"
        else:
            entry.details += "(No stack trace available)"
        
    log_received.emit(entry)

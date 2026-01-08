@tool
extends Logger

signal log_received(entry: Dictionary)

# This logger intercepts Editor-side errors/warnings (compilation, static checks, plugin errors)
# It mimics the Godot 4.5+ Logger API to capturing structured data.

func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
    
    var type_str = "UNKNOWN"
    var is_warning = false
    
    match error_type:
        0: # ERROR_TYPE_ERROR
            type_str = "ERROR"
        1: # ERROR_TYPE_WARNING
            type_str = "WARNING"
            is_warning = true
        2: # ERROR_TYPE_SCRIPT
            type_str = "SCRIPT"
        3: # ERROR_TYPE_SHADER
            type_str = "SHADER"
            
    var msg = rationale
    if msg.is_empty():
        msg = code 
        if msg.is_empty():
            msg = "Unknown Error"

    var details = "Type: " + type_str + "\n"
    if not code.is_empty():
        details += "Code: " + code + "\n"
    
    details += "Message: " + msg + "\n"
    details += "Location: " + function + "\n"
    details += "File: " + file + ":" + str(line) + "\n"
    
    # Process Script Backtraces (Godot 4.5+)
    if not script_backtraces.is_empty():
        details += "\n--- Script Backtraces ---\n"
        for bt in script_backtraces:
             # Verify it's a ScriptBacktrace object before calling methods
             # (Though in 4.5 it should always be)
            if bt.has_method("get_frame_count"):
                var frames = bt.get_frame_count()
                for i in range(frames):
                    var func_name = bt.get_frame_function(i)
                    var f_path = bt.get_frame_file(i)
                    var f_line = bt.get_frame_line(i)
                    details += "  [%d] %s (%s:%d)\n" % [i, func_name, f_path, f_line]
            else:
                 details += "  (Invalid Backtrace Object)\n"
    
    var entry = {
        "time": Time.get_time_string_from_system(),
        "type": type_str,
        "message": msg,
        "details": details,
        "is_warning": is_warning
    }
    
    log_received.emit(entry)


func _log_message(message: String, error: bool) -> void:
    # This captures standard print() and push_error() string representations.
    # Note: High-level errors (caught by _log_error) might also appear here as strings.
    # We can perform simple deduplication or just log everything.
    
    # Optional: Filter out raw formatted error strings if we trust _log_error
    if message.begins_with("**ERROR**") or message.begins_with("**WARNING**"):
        return

    var entry = {
        "time": Time.get_time_string_from_system(),
        "type": "ERROR" if error else "INFO",
        "message": message.strip_edges().split("\n")[0],
        "details": "Standard Output/Error:\n" + message
    }
    log_received.emit(entry)

# Redundant helper removed as logic is now inline or simplified

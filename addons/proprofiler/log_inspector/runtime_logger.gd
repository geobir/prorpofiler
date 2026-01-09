###############################################################
# res://addons/proprofiler/log_inspector/runtime_logger.gd
# Key funcs: • _enter_tree - registers the custom logger
#            • ProfilerLogger - internal class extending Godot 4.5 Logger
###############################################################

extends Node

const MESSAGE_CHANNEL = "gd_profiler:log"

# Internal class that inherits from Logger
class ProfilerLogger extends Logger:
    func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array):
        if not EngineDebugger.is_active():
            return

        var backtrace_data = []
        for bt in script_backtraces:
            if bt:
                backtrace_data.append(_serialize_backtrace(bt))
        
        var error_type_name = "ERROR"
        match error_type:
            0: error_type_name = "ERROR"
            1: error_type_name = "WARNING"
            2: error_type_name = "SCRIPT"
            3: error_type_name = "SHADER"

        var data = {
            "event_type": "error",
            "timestamp": Time.get_time_string_from_system(),
            "error_type": error_type_name,
            "function": function,
            "file": file,
            "line": line,
            "code": code,
            "rationale": rationale,
            "backtraces": backtrace_data
        }
        EngineDebugger.send_message(MESSAGE_CHANNEL, [data])

    func _log_message(message: String, is_error: bool):
        if not EngineDebugger.is_active():
            return
            
        var backtrace_data = []
        # Attempt to capture backtraces for standard print/messages if available
        if Engine.has_method("capture_script_backtraces"):
            var bts = Engine.capture_script_backtraces()
            for bt in bts:
                if bt:
                    backtrace_data.append(_serialize_backtrace(bt))
            
        var data = {
            "event_type": "message",
            "timestamp": Time.get_time_string_from_system(),
            "message": message,
            "is_error": is_error,
            "backtraces": backtrace_data
        }
        EngineDebugger.send_message(MESSAGE_CHANNEL, [data])

    func _serialize_backtrace(bt) -> Dictionary:
        var frames = []
        var frame_count = bt.get_frame_count()
        for i in range(frame_count):
            frames.append({
                "function": bt.get_frame_function(i),
                "file": bt.get_frame_file(i),
                "line": bt.get_frame_line(i)
            })
        return {
            "language": bt.get_language_name(),
            "frames": frames
        }

var _actual_logger: ProfilerLogger

func _ready():
    _actual_logger = ProfilerLogger.new()
    OS.add_logger(_actual_logger)

func _exit_tree():
    if _actual_logger:
        OS.remove_logger(_actual_logger)

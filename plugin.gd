@tool
extends EditorPlugin

var CPUProfilerUI = preload("res://addons/proprofiler/cpu_profiler/ui/cpu_profiler_ui.gd")
var FileSpaceUI = preload("res://addons/proprofiler/file_space/ui/file_space_ui.gd")
var LogInspectorUI = preload("res://addons/proprofiler/log_inspector/ui/log_inspector_ui.gd")
var LogDebuggerPlugin = preload("res://addons/proprofiler/log_inspector/debugger_plugin.gd")
var EditorLogCapture = preload("res://addons/proprofiler/log_inspector/editor_logger.gd")

var _profiler_dock: Panel
var _log_debugger: EditorDebuggerPlugin
var _editor_logger: Logger
var tab_name: String = "🧠 ProProfiler"


# Helper to create a colored tab with placeholder content
func _make_tab(title_text: String, emoji: String, color: Color, placeholder_text: String) -> Control:
    var v = VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var header = Label.new()
    header.text = emoji + " " + title_text
    # use Godot 4.5+ alignment (0=LEFT, 1=CENTER, 2=RIGHT)
    header.horizontal_alignment = 0
    header.vertical_alignment = 1
    header.custom_minimum_size = Vector2(0, 30)
    header.modulate = color
    v.add_child(header)
    var hr = HSeparator.new()
    v.add_child(hr)
    var placeholder_lbl = Label.new()
    placeholder_lbl.text = placeholder_text
    placeholder_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    placeholder_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(placeholder_lbl)
    return v


func _enter_tree():
    # Create a dock with a TabContainer and multiple sub-tabs for profiling info.
    _profiler_dock = Panel.new()
    _profiler_dock.name = "GDProfilerDock"
    var tabs = TabContainer.new()
    tabs.anchor_left = 0.0
    tabs.anchor_top = 0.0
    tabs.anchor_right = 1.0
    tabs.anchor_bottom = 1.0
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.custom_minimum_size = Vector2(400, 240)

    # Tabs: Logs, Profiler (CPU/GPU), File/Space, RAM, Visual
    var log_inspector_ui = LogInspectorUI.new()
    var cpu_profiler_ui = CPUProfilerUI.new()
    var file_space_ui = FileSpaceUI.new()
    var ram_tab = _make_tab("RAM", "💾", Color(0.6, 0.9, 0.6), "Memory usage and breakdown will appear here.")
    var visual_tab = _make_tab("Visual Profiler", "📊", Color(0.8, 0.5, 0.8), "Visual profiling graphs will appear here.")

    tabs.add_child(log_inspector_ui)
    tabs.add_child(cpu_profiler_ui)
    tabs.add_child(file_space_ui)
    tabs.add_child(ram_tab)
    tabs.add_child(visual_tab)

    # Set titles and icons for each tab
    tabs.set_tab_title(0, "🖨️ Logs")
    tabs.set_tab_title(1, "⚡ CPU Profiler")
    tabs.set_tab_title(2, "💾 Disk Usage")
    tabs.set_tab_title(3, "🧠 RAM")
    tabs.set_tab_title(4, "📊 Visual")

    _profiler_dock.add_child(tabs)

    add_control_to_bottom_panel(_profiler_dock, tab_name)

    # Setup Log Debugger (Game Runtime)
    _log_debugger = LogDebuggerPlugin.new()
    _log_debugger.log_received.connect(log_inspector_ui.add_log)
    add_debugger_plugin(_log_debugger)
    
    # Setup Editor Logger (Editor/tool script errors)
    _editor_logger = EditorLogCapture.new()
    _editor_logger.log_received.connect(log_inspector_ui.add_log)
    OS.add_logger(_editor_logger)
    
    # Add Runtime Logger as Autoload to capture advanced backtraces in game
    add_autoload_singleton("GDProfilerLogger", "res://addons/proprofiler/log_inspector/runtime_logger.gd")

    print_rich("[b]Godot ProProfiler has Loaded![/b]")


func _exit_tree():
    # Clean-up of the plugin goes here.
    if _log_debugger:
        remove_debugger_plugin(_log_debugger)
        _log_debugger = null
        
    if _editor_logger:
        OS.remove_logger(_editor_logger)
        _editor_logger = null

    remove_autoload_singleton("GDProfilerLogger")

    remove_custom_type("GodotProfiler")
    remove_custom_type("MovableProfiler")
    if _profiler_dock:
        remove_control_from_bottom_panel(_profiler_dock)
        _profiler_dock.free()

    print_rich("[b]Godot Profiler was Stopped.[/b]")

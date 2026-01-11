###############################################################
# addons/proprofiler/cpu_profiler/ui/cpu_profiler_ui.gd
# Main UI container: orchestrates all profiler UI components
###############################################################

extends VBoxContainer

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")
const CPUProfiler = preload("res://addons/proprofiler/cpu_profiler/core/cpu_profiler.gd")
const ProfilerStats = preload("res://addons/proprofiler/cpu_profiler/ui/profiler_stats.gd")
const ProfilerControls = preload("res://addons/proprofiler/cpu_profiler/ui/profiler_controls.gd")
const ProfilerGraph = preload("res://addons/proprofiler/cpu_profiler/ui/profiler_graph.gd")
const ProfilerBreakdown = preload("res://addons/proprofiler/cpu_profiler/ui/profiler_breakdown.gd")


var profiler: CPUProfiler
var stats_display: ProfilerStats
var controls: ProfilerControls
var graph_canvas: ProfilerGraph
var breakdown_tree: ProfilerBreakdown
var graph_viewport: Control  # For dynamic resizing
var graph_scroll: ScrollContainer  # For auto-scroll

var update_rate: int = 2
var frame_counter: int = 0
var follow_latest: bool = true  # Auto-scroll to newest data


func _ready() -> void:
    profiler = CPUProfiler.new()

    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 4)

    _build_ui()


## Build entire UI structure
func _build_ui() -> void:
    # Warning Panel (Duplicate of Settings warning for clarity)
    var warning_panel = PanelContainer.new()
    var warning_stylebox = StyleBoxFlat.new()
    warning_stylebox.bg_color = Color(0.6, 0.4, 0.2, 0.3)
    warning_stylebox.set_corner_radius_all(4)
    warning_panel.add_theme_stylebox_override("panel", warning_stylebox)
    add_child(warning_panel)
    
    var warning_vbox = VBoxContainer.new()
    warning_vbox.add_theme_constant_override("separation", 6)
    warning_panel.add_child(warning_vbox)
    
    var warning_title = Label.new()
    warning_title.text = ProProfilerLocalization.localize("cpu.warning.title", "⚠️  CPU Profiler Status")
    warning_title.add_theme_font_size_override("font_size", 16)
    warning_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
    warning_vbox.add_child(warning_title)
    
    var warning_text = Label.new()
    warning_text.text = ProProfilerLocalization.localize("cpu.warning.text", "The CPU Profiler tab is currently not functional due to Godot's addon API limitations. Godot does not expose sufficient per-process performance data to addons for safe profiling. This feature may be available in future Godot versions.")
    warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD
    warning_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    warning_vbox.add_child(warning_text)

    # Stats display
    var stats_panel = PanelContainer.new()
    stats_display = ProfilerStats.new()
    stats_panel.add_child(stats_display)
    add_child(stats_panel)

    # Controls
    controls = ProfilerControls.new()
    _connect_controls()
    add_child(controls)

    # Main content (graph + breakdown)
    var split = HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.split_offset = 280

    # Breakdown tree
    var tree_vbox = VBoxContainer.new()
    tree_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree_vbox.custom_minimum_size = Vector2(450, 0)

    var tree_header = Label.new()
    tree_header.text = ProProfilerLocalization.localize("cpu.tree.header", "  📊 Game Profile (Play to Start)")
    tree_header.add_theme_font_size_override("font_size", 16)
    tree_header.add_theme_color_override("font_color", ProfilerConstants.COLOR_TEXT_DIM)
    tree_header.custom_minimum_size = Vector2(0, 24)
    tree_vbox.add_child(tree_header)

    breakdown_tree = ProfilerBreakdown.new()
    breakdown_tree.profiler = profiler
    breakdown_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    breakdown_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tree_vbox.add_child(breakdown_tree)
    split.add_child(tree_vbox)

    # Graph
    var graph_vbox = VBoxContainer.new()
    graph_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    graph_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var graph_header = HBoxContainer.new()
    graph_header.custom_minimum_size = Vector2(0, 24)
    var graph_title = Label.new()
    graph_title.text = "  📈 Frame Time (ms)"
    graph_title.add_theme_font_size_override("font_size", 16)
    graph_title.add_theme_color_override("font_color", ProfilerConstants.COLOR_TEXT_DIM)
    graph_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    graph_header.add_child(graph_title)
    graph_vbox.add_child(graph_header)

    var graph_scroll = ScrollContainer.new()
    graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

    graph_canvas = ProfilerGraph.new()
    graph_canvas.profiler = profiler
    graph_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    graph_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    graph_canvas.draw.connect(_on_graph_draw)
    graph_canvas.on_frame_selected = Callable(self, "_on_graph_frame_selected")
    graph_scroll.add_child(graph_canvas)

    graph_vbox.add_child(graph_scroll)
    
    # Store references for dynamic updating
    self.graph_scroll = graph_scroll
    split.add_child(graph_vbox)

    add_child(split)


## Connect control signals
func _connect_controls() -> void:
    controls.on_pause_pressed = Callable(self, "_on_pause_pressed")
    controls.on_reset_pressed = Callable(self, "_on_reset_pressed")
    controls.on_peak_pressed = Callable(self, "_on_peak_pressed")
    controls.on_prev_frame = Callable(self, "_on_prev_frame")
    controls.on_next_frame = Callable(self, "_on_next_frame")
    controls.on_frame_changed = Callable(self, "_on_frame_changed")
    controls.on_follow_toggled = Callable(self, "_on_follow_toggled")
    controls.on_copy_frame = Callable(self, "_on_copy_frame")


func _process(delta: float) -> void:
    # CPU Profiler disabled by default (Godot asset blocking prevents full functionality)
    return
    # Original auto-activation code commented out below:
    # var tree = get_tree()
    # var is_game_running = not tree.paused and tree.root.get_child_count() > 1  # More than just editor root
    # 
    # # Activate profiler only when game is running
    # if is_game_running != profiler.is_active:
    #     profiler.set_active(is_game_running)
    # 
    # if not is_game_running:
    #     return
    #
    # profiler.sample_frame(delta)
    # frame_counter += 1
    #
    # if frame_counter >= update_rate:
    #     frame_counter = 0
    #     _update_display()
    #     _expand_graph_if_needed()


## Update all displays
func _update_display() -> void:
    var fps = profiler.get_current_fps()
    var avg = profiler.get_average_fps()
    var frame_time = profiler.average_frame_time
    var peak = profiler.peak_frame_time
    var mem = profiler.get_current_memory()

    stats_display.update_stats(fps, avg, frame_time, peak, mem)

    var count = profiler.get_frame_count()
    controls.set_max_frame(count)

    if not profiler.is_paused or profiler.selected_frame_index < 0:
        graph_canvas.queue_redraw()

    if profiler.is_paused or profiler.selected_frame_index >= 0:
        var frame_data = profiler.get_paused_frame()
        if frame_data != null:
            breakdown_tree.update_breakdown(frame_data, profiler.selected_frame_index)


## No graph expansion or movement - keep completely static
func _expand_graph_if_needed() -> void:
    # Graph stays fixed width, data flows left to right
    # No movement or scrolling
    pass


## Draw graph
func _on_graph_draw() -> void:
    var times = profiler.get_frame_times()
    graph_canvas.draw_graph(times)
    
    # Auto-scroll to latest data if follow is enabled
    if follow_latest and graph_scroll != null and times.size() > 0:
        await get_tree().process_frame
        graph_scroll.scroll_horizontal = int(graph_scroll.get_h_scroll_bar().max_value)


## Handle graph click - select frame
func _on_graph_frame_selected(frame_idx: int) -> void:
    profiler.select_frame(frame_idx)
    controls.spin_frame.value = frame_idx
    controls.set_frame_info("[#%d]" % frame_idx)
    
    if not profiler.is_paused:
        profiler.toggle_pause()
        controls.set_paused(true)
    
    _update_display()


## Pause button pressed
func _on_pause_pressed() -> void:
    profiler.toggle_pause()
    controls.set_paused(profiler.is_paused)
    _update_display()


## Reset button pressed
func _on_reset_pressed() -> void:
    profiler.reset()
    frame_counter = 0
    controls.spin_frame.value = 0
    profiler.selected_frame_index = -1
    _update_display()


## Peak button pressed
func _on_peak_pressed() -> void:
    var times = profiler.get_frame_times()
    var peak_idx = 0
    var peak_time = 0.0

    for i in range(times.size()):
        if times[i] > peak_time:
            peak_time = times[i]
            peak_idx = i

    profiler.select_frame(peak_idx)
    controls.spin_frame.value = peak_idx
    controls.set_frame_info("[#%d] %.2f ms" % [peak_idx, peak_time])

    if not profiler.is_paused:
        profiler.toggle_pause()
        controls.set_paused(true)

    _update_display()


## Previous frame pressed
func _on_prev_frame() -> void:
    if controls.spin_frame.value > 0:
        controls.spin_frame.value -= 1


## Next frame pressed
func _on_next_frame() -> void:
    if controls.spin_frame.value < controls.spin_frame.max_value:
        controls.spin_frame.value += 1


## Frame changed via spinbox or click
func _on_frame_changed(value: float) -> void:
    var idx = int(value)
    profiler.select_frame(idx)
    controls.set_frame_info("[#%d]" % idx)
    _update_display()
    graph_canvas.queue_redraw()  # Force immediate redraw for vertical line


## Toggle follow latest data
func _on_follow_toggled(enabled: bool) -> void:
    follow_latest = enabled


## Copy paused frame to clipboard
func _on_copy_frame() -> void:
    var FrameSnapshot = preload("res://addons/proprofiler/cpu_profiler/core/frame_snapshot.gd")
    var frame = profiler.get_paused_frame()
    if frame == null:
        push_warning("[CPUProfiler] No frame to copy")
        return
    
    var success = FrameSnapshot.copy_frame_to_clipboard(frame)
    if success:
        print("[CPUProfiler] Frame copied to clipboard!")
        # Visual feedback: briefly highlight status
        controls.lbl_pause_status.text = "✓ Copied!"
        await get_tree().create_timer(2.0).timeout
        controls.lbl_pause_status.text = "● Paused" if profiler.is_paused else "● Recording"
    else:
        push_error("[CPUProfiler] Failed to copy frame")


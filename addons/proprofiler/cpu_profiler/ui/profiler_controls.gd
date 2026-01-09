###############################################################
# addons/proprofiler/cpu_profiler/ui/profiler_controls.gd
# Control buttons: pause, reset, peak, frame navigation
###############################################################

extends HBoxContainer

const ProfilerConstants = preload("res://addons/proprofiler/cpu_profiler/core/profiler_constants.gd")

var btn_pause: Button
var spin_frame: SpinBox
var lbl_frame_info: Label
var lbl_pause_status: Label

var on_pause_pressed: Callable
var on_reset_pressed: Callable
var on_peak_pressed: Callable
var on_prev_frame: Callable
var on_next_frame: Callable
var on_frame_changed: Callable
var on_follow_toggled: Callable
var on_copy_frame: Callable


func _ready() -> void:
    add_theme_constant_override("separation", 12)
    custom_minimum_size = Vector2(0, 32)

    # Pause button
    btn_pause = Button.new()
    btn_pause.text = "⏸ Pause"
    btn_pause.custom_minimum_size = Vector2(90, 28)
    btn_pause.pressed.connect(on_pause_pressed)
    add_child(btn_pause)

    # Reset button
    var btn_reset = Button.new()
    btn_reset.text = "↺ Reset"
    btn_reset.custom_minimum_size = Vector2(80, 28)
    btn_reset.pressed.connect(on_reset_pressed)
    add_child(btn_reset)

    # Peak button
    var btn_peak = Button.new()
    btn_peak.text = "📈 Peak"
    btn_peak.custom_minimum_size = Vector2(80, 28)
    btn_peak.pressed.connect(on_peak_pressed)
    add_child(btn_peak)

    # Separator
    add_child(VSeparator.new())

    # Frame spinbox only (removed < > buttons as user has navigation controls)
    var nav_label = Label.new()
    nav_label.text = "Frame:"
    nav_label.add_theme_color_override("font_color", ProfilerConstants.COLOR_TEXT_DIM)
    add_child(nav_label)

    spin_frame = SpinBox.new()
    spin_frame.min_value = 0
    spin_frame.max_value = 0
    spin_frame.custom_minimum_size = Vector2(80, 28)
    spin_frame.value_changed.connect(on_frame_changed)
    add_child(spin_frame)

    # Frame info
    lbl_frame_info = Label.new()
    lbl_frame_info.text = ""
    lbl_frame_info.add_theme_color_override("font_color", ProfilerConstants.COLOR_TEXT_DIM)
    lbl_frame_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(lbl_frame_info)

    # Follow toggle
    var btn_follow = Button.new()
    btn_follow.text = "👁 Follow"
    btn_follow.toggle_mode = true
    btn_follow.button_pressed = true
    btn_follow.custom_minimum_size = Vector2(80, 28)
    btn_follow.pressed.connect(func(): on_follow_toggled.call(btn_follow.button_pressed))
    add_child(btn_follow)

    # Copy frame button
    var btn_copy = Button.new()
    btn_copy.text = "📋 Copy"
    btn_copy.custom_minimum_size = Vector2(80, 28)
    btn_copy.pressed.connect(on_copy_frame)
    add_child(btn_copy)

    # Status
    lbl_pause_status = Label.new()
    lbl_pause_status.text = "● Recording"
    lbl_pause_status.add_theme_color_override("font_color", ProfilerConstants.COLOR_GOOD)
    add_child(lbl_pause_status)


## Update pause button state
func set_paused(paused: bool) -> void:
    if paused:
        btn_pause.text = "▶ Play"
        lbl_pause_status.text = "● Paused"
        lbl_pause_status.add_theme_color_override("font_color", ProfilerConstants.COLOR_WARN)
    else:
        btn_pause.text = "⏸ Pause"
        lbl_pause_status.text = "● Recording"
        lbl_pause_status.add_theme_color_override("font_color", ProfilerConstants.COLOR_GOOD)


## Update frame count
func set_max_frame(count: int) -> void:
    spin_frame.max_value = maxi(0, count - 1)


## Set frame info text
func set_frame_info(text: String) -> void:
    lbl_frame_info.text = text

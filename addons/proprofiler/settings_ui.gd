###############################################################
# addons/proprofiler/settings_ui.gd
# Settings panel with logo, metadata, and links
###############################################################

extends Control

func _ready() -> void:
    custom_minimum_size = Vector2(400, 300)
    
    # Main scroll container
    var scroll = ScrollContainer.new()
    scroll.anchor_left = 0.0
    scroll.anchor_top = 0.0
    scroll.anchor_right = 1.0
    scroll.anchor_bottom = 1.0
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(scroll)
    
    # Content panel
    var content = PanelContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    
    # VBox for content
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    content.add_child(vbox)
    
    # Logo
    var logo_container = CenterContainer.new()
    logo_container.custom_minimum_size = Vector2(0, 100)
    var logo = TextureRect.new()
    logo.texture = load("res://addons/proprofiler/images/proprofiler_logo_64.png")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.custom_minimum_size = Vector2(64, 64)
    logo_container.add_child(logo)
    vbox.add_child(logo_container)
    
    # Title
    var title = Label.new()
    title.text = "ProProfiler"
    title.add_theme_font_size_override("font_size", 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # Version and Author
    var meta_label = Label.new()
    meta_label.text = "v0.5 • by Glorek"
    meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    vbox.add_child(meta_label)
    
    # Separator
    var sep1 = HSeparator.new()
    vbox.add_child(sep1)
    
    # Description
    var desc = Label.new()
    desc.text = "Lightweight Godot addon that centralizes logs, inspects disk usage, and provides simple runtime profiling tools for development."
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
    vbox.add_child(desc)
    
    # Separator
    var sep2 = HSeparator.new()
    vbox.add_child(sep2)
    
    # Features
    var features_title = Label.new()
    features_title.text = "Features"
    features_title.add_theme_font_size_override("font_size", 14)
    vbox.add_child(features_title)
    
    var features = Label.new()
    features.text = "• 🖨️  Centralized Logs — Editor & runtime\n• ⚡ CPU Profiler — Frame analysis\n• 💾 Disk Usage — Asset breakdown\n• 🧩 Modular — Easy to extend"
    features.autowrap_mode = TextServer.AUTOWRAP_WORD
    vbox.add_child(features)
    
    # Separator
    var sep3 = HSeparator.new()
    vbox.add_child(sep3)
    
    # Warning about CPU Profiler
    var warning_panel = PanelContainer.new()
    var warning_stylebox = StyleBoxFlat.new()
    warning_stylebox.bg_color = Color(0.6, 0.4, 0.2, 0.3)
    warning_stylebox.set_corner_radius_all(4)
    warning_panel.add_theme_stylebox_override("panel", warning_stylebox)
    vbox.add_child(warning_panel)
    
    var warning_vbox = VBoxContainer.new()
    warning_vbox.add_theme_constant_override("separation", 6)
    warning_panel.add_child(warning_vbox)
    
    var warning_title = Label.new()
    warning_title.text = "⚠️  CPU Profiler Status"
    warning_title.add_theme_font_size_override("font_size", 12)
    warning_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
    warning_vbox.add_child(warning_title)
    
    var warning_text = Label.new()
    warning_text.text = "The CPU Profiler tab is currently not functional due to Godot's addon API limitations. Godot does not expose sufficient per-process performance data to addons for safe profiling. This feature may be available in future Godot versions."
    warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD
    warning_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    warning_vbox.add_child(warning_text)
    
    # Separator
    var sep4 = HSeparator.new()
    vbox.add_child(sep4)
    
    # Links
    var links_title = Label.new()
    links_title.text = "Links"
    links_title.add_theme_font_size_override("font_size", 14)
    vbox.add_child(links_title)
    
    var links_container = HBoxContainer.new()
    links_container.add_theme_constant_override("separation", 8)
    vbox.add_child(links_container)
    
    # GitHub button
    var github_btn = Button.new()
    github_btn.text = "📖 GitHub"
    github_btn.custom_minimum_size = Vector2(0, 32)
    github_btn.pressed.connect(func(): OS.shell_open("https://github.com/geobir/prorpofiler"))
    links_container.add_child(github_btn)
    
    # Spacer
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)


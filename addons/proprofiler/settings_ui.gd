###############################################################
# addons/proprofiler/settings_ui.gd
# Settings panel with logo, metadata, and links
###############################################################

@tool
extends Control

signal setting_changed(key: String, value: Variant)

var plugin: EditorPlugin
var _config_path = "user://proprofiler_settings.cfg"

func _ready() -> void:
    custom_minimum_size = Vector2(400, 400)
    _build_ui()


func _build_ui() -> void:
    # Clear existing
    for child in get_children():
        child.queue_free()

    # Layout: Split Left (Settings) | Right (Info)
    var main_hbox = HBoxContainer.new()
    main_hbox.anchor_left = 0.0
    main_hbox.anchor_top = 0.0
    main_hbox.anchor_right = 1.0
    main_hbox.anchor_bottom = 1.0
    main_hbox.add_theme_constant_override("separation", 24)
    add_child(main_hbox)

    # --- LEFT SIDE: SETTINGS ---
    var left_panel = ScrollContainer.new()
    left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_hbox.add_child(left_panel)

    var left_vbox = VBoxContainer.new()
    left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_vbox.add_theme_constant_override("separation", 16)
    left_panel.add_child(left_vbox)

    # Language Setting
    var lang_hbox = HBoxContainer.new()
    var lang_label = Label.new()
    lang_label.text = ProProfilerLocalization.localize("settings.language", "Language / Langue:")
    lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lang_hbox.add_child(lang_label)
    
    var lang_opt = OptionButton.new()
    lang_opt.add_item(ProProfilerLocalization.localize("settings.language.default", "Default (Editor)"), 0)
    lang_opt.add_item("English", 1)
    lang_opt.add_item("Français", 2)
    lang_opt.add_item("Español", 3)
    lang_opt.add_item("简体中文", 4)
    lang_opt.add_item("Deutsch", 5)
    lang_opt.add_item("日本語", 6)
    lang_opt.add_item("Português", 7)
    lang_opt.add_item("Русский", 8)
    lang_opt.add_item("한국어", 9)
    lang_opt.add_item("Türkçe", 10)
    lang_opt.add_item("Italiano", 11)
    lang_opt.add_item("Українська", 12)
    
    var current_lang = _get_setting("language", "")
    match current_lang:
        "en": lang_opt.selected = 1
        "fr": lang_opt.selected = 2
        "es": lang_opt.selected = 3
        "zh_CN": lang_opt.selected = 4
        "de": lang_opt.selected = 5
        "ja": lang_opt.selected = 6
        "pt": lang_opt.selected = 7
        "ru": lang_opt.selected = 8
        "ko": lang_opt.selected = 9
        "tr": lang_opt.selected = 10
        "it": lang_opt.selected = 11
        "uk": lang_opt.selected = 12
        _: lang_opt.selected = 0
        
    lang_opt.item_selected.connect(_on_language_selected)
    lang_hbox.add_child(lang_opt)
    left_vbox.add_child(lang_hbox)

    left_vbox.add_child(HSeparator.new())

    # Tab Toggles
    var tabs_title = Label.new()
    tabs_title.text = ProProfilerLocalization.localize("settings.visible_tabs", "Visible Tabs:")
    left_vbox.add_child(tabs_title)

    _add_tab_toggle(left_vbox, "tabs.logs", "show_logs", true)
    _add_tab_toggle(left_vbox, "tabs.cpu", "show_cpu", false)
    _add_tab_toggle(left_vbox, "tabs.disk", "show_disk", true)
    
    left_vbox.add_child(HSeparator.new())
    
    # Other useful settings
    var auto_scrape_chk = CheckBox.new()
    auto_scrape_chk.text = ProProfilerLocalization.localize("settings.auto_scrape", "Auto-scrape logs on startup")
    auto_scrape_chk.button_pressed = _get_setting("auto_scrape", true)
    auto_scrape_chk.toggled.connect(func(v): _set_setting("auto_scrape", v))
    left_vbox.add_child(auto_scrape_chk)

    # --- RIGHT SIDE: INFO ---
    var right_scroll = ScrollContainer.new()
    right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_hbox.add_child(right_scroll)

    var right_vbox = VBoxContainer.new()
    right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_vbox.add_theme_constant_override("separation", 12)
    right_scroll.add_child(right_vbox)

    # Load metadata from plugin.cfg
    var plugin_cfg = ConfigFile.new()
    plugin_cfg.load("res://addons/proprofiler/plugin.cfg")
    var p_name = plugin_cfg.get_value("plugin", "name", "ProProfiler")
    var p_version = plugin_cfg.get_value("plugin", "version", "0.0.0")
    var p_author = plugin_cfg.get_value("plugin", "author", "Glorek")
    var p_desc = plugin_cfg.get_value("plugin", "description", "")

    # Logo
    var logo_container = CenterContainer.new()
    var logo = TextureRect.new()
    logo.texture = load("res://addons/proprofiler/images/proprofiler_logo_64.png")
    logo.custom_minimum_size = Vector2(64, 64)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo_container.add_child(logo)
    right_vbox.add_child(logo_container)

    # Title & Version
    var title = Label.new()
    title.text = p_name
    title.add_theme_font_size_override("font_size", 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    right_vbox.add_child(title)

    var meta = Label.new()
    meta.text = "v%s • by %s" % [p_version, p_author]
    meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    meta.modulate = Color(0.7, 0.7, 0.7)
    right_vbox.add_child(meta)

    right_vbox.add_child(HSeparator.new())

    # Description
    var desc = Label.new()
    desc.text = p_desc if p_desc != "" else ProProfilerLocalization.localize("settings.description", "Lightweight Godot addon...")
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    right_vbox.add_child(desc)

    # Features
    var feat_title = Label.new()
    feat_title.text = ProProfilerLocalization.localize("settings.features.title", "Features")
    feat_title.add_theme_font_size_override("font_size", 14)
    right_vbox.add_child(feat_title)

    var feat_text = Label.new()
    feat_text.text = ProProfilerLocalization.localize("settings.features.text", "• Centralized Logs\n• CPU Profiler\n• Disk Usage")
    feat_text.modulate = Color(0.9, 0.9, 0.9)
    right_vbox.add_child(feat_text)

    right_vbox.add_child(HSeparator.new())

    # Links
    var links_title = Label.new()
    links_title.text = ProProfilerLocalization.localize("settings.resources", "Resources")
    right_vbox.add_child(links_title)

    var links_hb = HBoxContainer.new()
    links_hb.alignment = BoxContainer.ALIGNMENT_CENTER
    right_vbox.add_child(links_hb)

    var github = Button.new()
    github.text = ProProfilerLocalization.localize("settings.github", "GitHub")
    github.pressed.connect(func(): OS.shell_open("https://github.com/geobir/prorpofiler"))
    links_hb.add_child(github)

    var asset_lib = Button.new()
    asset_lib.text = ProProfilerLocalization.localize("settings.asset_lib", "Asset Library")
    asset_lib.pressed.connect(func(): OS.shell_open("https://godotengine.org/asset-library/asset/4656"))
    links_hb.add_child(asset_lib)


func _add_tab_toggle(container: Control, lang_key: String, setting_key: String, default: bool) -> void:
    var chk = CheckBox.new()
    chk.text = ProProfilerLocalization.localize(lang_key, lang_key)
    chk.button_pressed = _get_setting(setting_key, default)
    chk.toggled.connect(func(v): 
        _set_setting(setting_key, v)
        setting_changed.emit(setting_key, v)
    )
    container.add_child(chk)


func _on_language_selected(index: int) -> void:
    var codes = ["", "en", "fr", "es", "zh_CN", "de", "ja", "pt", "ru", "ko", "tr", "it", "uk"]
    var code = codes[index]
    _set_setting("language", code)
    
    if code == "":
        ProProfilerLocalization.load_translations()
    else:
        ProProfilerLocalization.set_forced_locale(code)
    
    _build_ui() # Refresh UI with new language
    setting_changed.emit("language", code)


func _get_setting(key: String, default: Variant) -> Variant:
    var config = ConfigFile.new()
    if config.load(_config_path) == OK:
        return config.get_value("settings", key, default)
    return default


func _set_setting(key: String, value: Variant) -> void:
    var config = ConfigFile.new()
    config.load(_config_path)
    config.set_value("settings", key, value)
    config.save(_config_path)


@tool
extends Control

var _search_bar: LineEdit
var _search_clear_btn: Button
var _scrape_btn: Button
var _err_toggle: CheckBox
var _warn_toggle: CheckBox
var _info_toggle: CheckBox
var _collapse_toggle: CheckBox
var _tree: Tree
var _details_text: RichTextLabel
var _copy_visible_btn: Button
var _copy_details_btn: Button
var _clear_btn: Button
var _auto_scroll_chk: CheckBox
var _realtime_scrape_chk: CheckBox
var _scrape_timer: Timer

# Column configuration: widths driven by code (for manual resizing)
var configs = [
    {"name": "#", "min_w": 60},
    {"name": "x", "min_w": 50},
    {"name": "Time", "min_w": 100}, # Will be translated in _ready
    {"name": "Type", "min_w": 100},
    {"name": "Cat", "min_w": 60},
    {"name": "Message", "min_w": 400}
]
# Column resize state
var _col_widths: PackedInt32Array = PackedInt32Array()
var _resize_drag_col: int = -1
var _resize_drag_start_x: float = 0.0
var _resize_drag_start_w: int = 0
var _resize_hit_px: float = 5.0 # Thickness (px) of the hit area near column separators
var _col_sep_overlay: Control
var _show_separators: bool = true

# Reference to the EditorPlugin to access EditorInterface
var plugin: EditorPlugin

# Data storage
var _logs: Array = []
var _filtered_logs: Array = []
var _collapsed_map: Dictionary = {} # Key: message, Value: {entry, count}
var _waiting_node: TreeItem = null
var _total_count: int = 0

# Scraper Optimization
var _cached_debugger_node: Node = null
var _last_item_counts: Dictionary = {} # Key: Object ID, Value: last count


func _ready() -> void:
    name = "LogInspectorUI"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Translate columns
    configs[2]["name"] = ProProfilerLocalization.localize("logs.col.time", "Time")
    configs[3]["name"] = ProProfilerLocalization.localize("logs.col.type", "Type")
    configs[4]["name"] = ProProfilerLocalization.localize("logs.col.cat", "Cat")
    configs[5]["name"] = ProProfilerLocalization.localize("logs.col.message", "Message")
    
    # Main Vertical Container
    var main_vbox = VBoxContainer.new()
    main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(main_vbox)
    
    # Header (Search Bar on Top of everything)
    var header = VBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(header)
    
    var search_hbox = HBoxContainer.new()
    header.add_child(search_hbox)
    
    _search_bar = LineEdit.new()
    _search_bar.placeholder_text = ProProfilerLocalization.localize("logs.search_placeholder", "Search logs...")
    _search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _search_bar.text_changed.connect(_on_search_text_changed)
    _search_bar.tooltip_text = ProProfilerLocalization.localize("logs.search_tooltip", "Supports Regex patterns (e.g., Error\\s\\d+)")
    search_hbox.add_child(_search_bar)
    
    _search_clear_btn = Button.new()
    _search_clear_btn.text = "×"
    _search_clear_btn.tooltip_text = ProProfilerLocalization.localize("logs.clear_search_tooltip", "Clear search")
    _search_clear_btn.custom_minimum_size = Vector2(32, 0)
    _search_clear_btn.pressed.connect(_on_search_clear_pressed)
    search_hbox.add_child(_search_clear_btn)
    
    # Main Horizontal Split: Left (Data) | Right (Controls)
    var hsplit = HSplitContainer.new()
    hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL # Take remaining vertical space
    main_vbox.add_child(hsplit)
    
    # --- Left Pane (Logs + Details) ---
    var left_split = VSplitContainer.new()
    left_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hsplit.add_child(left_split)
    
    # Log List
    _tree = Tree.new()
    _tree.columns = 6
    _tree.column_titles_visible = true
    _tree.set_column_title(0, "#")
    _tree.set_column_title(1, "x") # Count
    _tree.set_column_title(2, "Time") # Was Cat
    _tree.set_column_title(3, "Type") # Was Time
    _tree.set_column_title(4, "Cat") # Was Type, now Category (moved after Type)
    _tree.set_column_title(5, "Message")

    _col_widths = PackedInt32Array()
    _col_widths.resize(configs.size())
    for i in range(configs.size()):
        _col_widths[i] = int(configs[i].min_w)

    _apply_column_widths()

    # Enable mouse-driven resizing
    _tree.gui_input.connect(_on_tree_gui_input)
    _tree.mouse_filter = Control.MOUSE_FILTER_STOP
    _tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    
    _tree.hide_root = true
    _tree.select_mode = Tree.SELECT_ROW
    _tree.item_selected.connect(_on_item_selected)
    _tree.item_activated.connect(_on_item_activated) # Double-click or Enter
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_split.add_child(_tree)
    
    # Overlay to draw visible column separators on the Tree header
    _col_sep_overlay = ColumnSeparatorOverlay.new()
    _col_sep_overlay.owner_ui = self
    _col_sep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _col_sep_overlay.top_level = false
    _col_sep_overlay.z_index = 1000
    _tree.add_child(_col_sep_overlay)
    _tree.move_child(_col_sep_overlay, _tree.get_child_count() - 1)

    # Ensure overlay keeps correct size and redraws when Tree resizes
    _tree.resized.connect(func():
        _update_col_sep_overlay()
    )

    _update_col_sep_overlay()

    
    # Details - Swtiched to RichTextLabel for formatting
    _details_text = RichTextLabel.new()
    _details_text.bbcode_enabled = true
    _details_text.scroll_active = true
    _details_text.selection_enabled = true
    _details_text.focus_mode = Control.FOCUS_CLICK
    _details_text.meta_clicked.connect(_on_detail_meta_clicked) # Handle category clicks
    _details_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _details_text.custom_minimum_size.y = 150
    left_split.add_child(_details_text)
    
    # --- Right Pane (Sidebar Controls) ---
    var sidebar_panel = PanelContainer.new()
    sidebar_panel.custom_minimum_size.x = 220
    sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hsplit.add_child(sidebar_panel)
    
    var sidebar = VBoxContainer.new()
    sidebar_panel.add_child(sidebar)
    
    # Title
    var lbl = Label.new()
    lbl.text = "FILTERS & TOOLS"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.modulate = Color(0.7, 0.7, 0.7)
    sidebar.add_child(lbl)
    
    _clear_btn = Button.new()
    _clear_btn.text = "Clear All Logs"
    _clear_btn.modulate = Color(1.0, 0.3, 0.3) # Red for Clear
    _clear_btn.pressed.connect(clear_logs)
    sidebar.add_child(_clear_btn)
    
    sidebar.add_child(HSeparator.new())
    
    # Type Toggles
    var filter_label = Label.new()
    filter_label.text = "Filter by Type:"
    filter_label.add_theme_font_size_override("font_size", 18)
    filter_label.add_theme_constant_override("line_spacing", 4)
    # Make it look more like a header
    filter_label.modulate = Color(0.9, 0.9, 0.9)
    sidebar.add_child(filter_label)
    
    _err_toggle = CheckBox.new()
    _err_toggle.text = "Errors"
    _err_toggle.button_pressed = true
    _err_toggle.modulate = Color(1.0, 0.4, 0.4) # Red
    _err_toggle.toggled.connect(func(_v): _apply_filter())
    sidebar.add_child(_err_toggle)
    
    _warn_toggle = CheckBox.new()
    _warn_toggle.text = "Warnings"
    _warn_toggle.button_pressed = true
    _warn_toggle.modulate = Color(1.0, 1.0, 0.4) # Yellow
    _warn_toggle.toggled.connect(func(_v): _apply_filter())
    sidebar.add_child(_warn_toggle)
    
    _info_toggle = CheckBox.new()
    _info_toggle.text = "Info / Scripts"
    _info_toggle.button_pressed = true
    _info_toggle.modulate = Color(0.7, 0.5, 1.0) # Purple/Blue
    _info_toggle.toggled.connect(func(_v): _apply_filter())
    sidebar.add_child(_info_toggle)
    
    sidebar.add_child(HSeparator.new())
    
    # View Options
    var view_label = Label.new()
    view_label.text = "View Options:"
    view_label.add_theme_font_size_override("font_size", 18)
    view_label.modulate = Color(0.9, 0.9, 0.9)
    sidebar.add_child(view_label)
    
    # Collapse Toggle
    _collapse_toggle = CheckBox.new()
    _collapse_toggle.text = "Collapse Duplicates"
    _collapse_toggle.tooltip_text = "Group identical logs together"
    _collapse_toggle.button_pressed = false
    _collapse_toggle.toggled.connect(func(_v): _apply_filter())
    sidebar.add_child(_collapse_toggle)
    
    _auto_scroll_chk = CheckBox.new()
    _auto_scroll_chk.text = "Auto-Scroll"
    _auto_scroll_chk.button_pressed = true
    sidebar.add_child(_auto_scroll_chk)
    
    _realtime_scrape_chk = CheckBox.new()
    _realtime_scrape_chk.text = "Real-time Scrape"
    _realtime_scrape_chk.tooltip_text = "Periodically checks (1s) the Editor Debugger for new errors."
    _realtime_scrape_chk.button_pressed = true 
    _realtime_scrape_chk.toggled.connect(func(active): 
        if active: _scrape_timer.start()
        else: _scrape_timer.stop()
    )
    sidebar.add_child(_realtime_scrape_chk)
    
    sidebar.add_child(HSeparator.new())
    
    # Actions
    var actions_label = Label.new()
    actions_label.text = "Actions:"
    actions_label.add_theme_font_size_override("font_size", 18)
    actions_label.modulate = Color(0.9, 0.9, 0.9)
    sidebar.add_child(actions_label)
    
    # Scrape button removed as requested
    
    sidebar.add_child(HSeparator.new())
    
    # Export / Clipboard Tools
    var export_label = Label.new()
    export_label.text = "Export:"
    export_label.add_theme_font_size_override("font_size", 18)
    export_label.modulate = Color(0.9, 0.9, 0.9)
    sidebar.add_child(export_label)
    
    _copy_visible_btn = Button.new()
    _copy_visible_btn.text = "Copy Filtered List"
    _copy_visible_btn.tooltip_text = "Copy all currently visible logs to clipboard"
    _copy_visible_btn.pressed.connect(_on_copy_visible_pressed)
    sidebar.add_child(_copy_visible_btn)
    
    _copy_details_btn = Button.new()
    _copy_details_btn.text = "Copy Selected Detail"
    _copy_details_btn.pressed.connect(_on_copy_details_pressed)
    sidebar.add_child(_copy_details_btn)

    # Initial Status (Child of hidden root)
    _reset_tree_status()
    
    # Setup Timer
    _scrape_timer = Timer.new()
    _scrape_timer.wait_time = 1.0 # Check every second
    _scrape_timer.one_shot = false
    _scrape_timer.timeout.connect(_on_auto_scrape_timer)
    add_child(_scrape_timer)
    _scrape_timer.start()


func _reset_tree_status() -> void:
    _tree.clear()
    _total_count = 0
    var root = _tree.create_item() # Hidden root
    _waiting_node = _tree.create_item(root) # Visible child
    _waiting_node.set_text(0, "0")
    _waiting_node.set_text(1, "--:--")
    _waiting_node.set_text(2, "STATUS")
    _waiting_node.set_text(3, "Waiting for logs... (Run the game or Scrape)")


func add_log(entry: Dictionary) -> void:
    # Remove waiting node if it exists
    if _waiting_node:
        _waiting_node.free()
        _waiting_node = null

    _total_count += 1
    entry["id"] = _total_count
    
    # Extract category from message (e.g., "[Core]", "[Network]")
    var category = _extract_category(entry.message)
    if category:
        entry["category"] = category
        entry["category_color"] = _category_color(category)
    
    _logs.append(entry)
    _apply_filter_to_entry(entry)


func clear_logs() -> void:
    _logs.clear()
    _filtered_logs.clear()
    _reset_tree_status()
    _details_text.text = ""


func _apply_filter() -> void:
    if not _tree or not _search_bar: return # Not ready yet
    
    # Rebuild tree from _logs
    _tree.clear()
    var root = _tree.create_item() # Hidden root
    _waiting_node = null # Clear status since we are filtering real logs (or list will be empty)

    _filtered_logs.clear()
    _collapsed_map.clear()
    
    # Pre-calculate filter parameters to avoid recompilation in loop
    var raw_filter_txt = _search_bar.text
    var filter_regex: RegEx = null
    var fallback_search_txt = raw_filter_txt.to_lower()
    
    if raw_filter_txt != "":
        # HEURISTIC: Check if user actually intends to use Regex
        # We only use regex if special chars exists: \ ^ $ . | ? * + ( ) { }
        # Note: [ ] and - are NOT included, to allow "Simple [Tag-Search]" to work as literal text.
        var special_chars_reg = RegEx.new()
        special_chars_reg.compile("[\\\\\\^\\$\\.\\|\\?\\*\\+\\(\\)\\{\\}]")
        
        if special_chars_reg.search(raw_filter_txt):
            # Contains advanced regex chars - compile as Regex
            var test_reg = RegEx.new()
            # If it compiles, use it. Auto-prepend (?i) for case insensitivity unless likely unwanted?
            # Let's keep (?i) for consistency.
            if test_reg.compile("(?i)" + raw_filter_txt) == OK:
                filter_regex = test_reg
        
        # If no special chars, OR regex failed to compile, we proceed with filter_regex = null
        # which triggers the Fallback Literal Search in _check_match
            
    var do_collapse = _collapse_toggle.button_pressed if _collapse_toggle else false
    
    for entry in _logs:
        if _check_match(entry, filter_regex, fallback_search_txt):
            if do_collapse:
                # Key based on message and type (ignore time)
                var key = entry.type + "|||" + entry.message + "|||" + entry.get("details", "")
                if _collapsed_map.has(key):
                    var data = _collapsed_map[key]
                    data.count += 1
                    # Update to latest capture
                    data.entry = entry 
                    # Refresh tree item text (count)
                    # Note: We can't easily find the tree item for this key without storing it
                    # But since we rebuild tree every filter, we process distinct keys later? No.
                    # Actually _logs is ordered by time.
                    # If we collapse, we should only show ONE entry per key.
                else:
                    _collapsed_map[key] = {"entry": entry, "count": 1}
            else:
                _add_tree_item(root, entry, 1)
                _filtered_logs.append(entry)

    # If collapsing, now build the tree from the map
    if do_collapse:
        # We want to preserve time order roughly, or sort by count?
        # Preserving original insertion order of the *first* or *last* occurrence is good.
        # But a map is unordered.
        # Let's iterate logs again to respect order, or just use values.
        # To respect order: we can iterate _logs reversely (latest first) or normally.
        # Simple approach: just iterate the map values.
        for val in _collapsed_map.values():
            _add_tree_item(root, val.entry, val.count)
            # Add count for clipboard usage
            var copy_entry = val.entry.duplicate()
            copy_entry["collapse_count"] = val.count
            _filtered_logs.append(copy_entry)


func _apply_filter_to_entry(entry: Dictionary) -> void:
    if not _search_bar or not _tree: return # UI not ready
    
    # If collapsing is ON, we need to rebuild the whole tree unfortunately
    if _collapse_toggle and _collapse_toggle.button_pressed:
        _apply_filter()
        return

    # For single entry add, we do a quick check.
    # We could cache the regex, but for single entry add, performance is less critical than 1000 items loop.
    # Re-use logic:
    var raw_filter_txt = _search_bar.text
    var filter_regex: RegEx = null
    var fallback_search_txt = raw_filter_txt.to_lower()
    
    if raw_filter_txt != "":
        var special_chars_reg = RegEx.new()
        special_chars_reg.compile("[\\\\\\^\\$\\.\\|\\?\\*\\+\\(\\)\\{\\}]")
        
        if special_chars_reg.search(raw_filter_txt):
            var test_reg = RegEx.new()
            if test_reg.compile("(?i)" + raw_filter_txt) == OK:
                filter_regex = test_reg

    if _check_match(entry, filter_regex, fallback_search_txt):
        var root = _tree.get_root()
        if not root:
            root = _tree.create_item()
        
        _add_tree_item(root, entry, 1)
        _filtered_logs.append(entry)
        
        # Auto-scroll logic
        if _auto_scroll_chk and _auto_scroll_chk.button_pressed:
             # Defer scrolling to next frame to ensure item is in tree
            get_tree().create_timer(0.01).timeout.connect(func():
                if is_instance_valid(_tree):
                    var last = root.get_child(root.get_child_count() - 1)
                    if last:
                        _tree.scroll_to_item(last)
            )


# Unified match logic that takes pre-compiled regex (or null) and fallback string
func _check_match(entry: Dictionary, filter_regex: RegEx, fallback_txt_lower: String) -> bool:
    # 1. Toggle Selection
    var type_u = entry.type.to_upper()
    var is_error = "ERROR" in type_u or "SCRIPT_ERROR" in type_u or "SHADER_ERROR" in type_u
    var is_warn = "WARNING" in type_u or entry.get("is_warning", false)
    # If not error or warning, treat as Info/Script
    var is_info = not (is_error or is_warn)
    
    if is_error and _err_toggle and not _err_toggle.button_pressed: return false
    if is_warn and _warn_toggle and not _warn_toggle.button_pressed: return false
    if is_info and _info_toggle and not _info_toggle.button_pressed: return false
    
    # 2. Text Search
    if fallback_txt_lower == "": return true # Empty search matches simple filters
    
    # If we have a valid regex, use it
    if filter_regex:
        # Search against raw message to preserve case info (regex handles case-insensitivity if (?i) used)
        if filter_regex.search(entry.message) or filter_regex.search(entry.details) or filter_regex.search(str(entry.get("id", ""))):
            return true
            
    # Fallback / No-Regex path
    # Even if Regex was valid, if it didn't match... well actually if regex is valid we ONLY trust regex.
    # But if regex is null (invalid pattern), we do fallback
    if filter_regex == null:
        var id_str = str(entry.get("id", ""))
        if fallback_txt_lower in id_str.to_lower(): return true
        
        var msg_lower = entry.message.to_lower()
        var det_lower = entry.details.to_lower()
        return fallback_txt_lower in msg_lower or fallback_txt_lower in det_lower
        
    return false


# DEPRECATED: Old function, keeping mainly if called elsewhere but shouldn't be
func _matches_filter(entry: Dictionary, filter_txt: String) -> bool:
    return _check_match(entry, null, filter_txt) # Treat as plain text fallback


func _add_tree_item(root: TreeItem, entry: Dictionary, count: int) -> void:
    var item = _tree.create_item(root)
    item.set_text(0, str(entry.get("id", 0)))
    
    if count > 1:
        item.set_text(1, str(count))
        item.set_custom_color(1, Color(1, 1, 1)) # White
        item.set_custom_bg_color(1, Color(0.3, 0.3, 1.0, 0.5)) # Blue bg
    else:
        item.set_text(1, "")
    
    # Text mapping (Reordered columns: #, x, Time, Type, Cat, Message)
    item.set_text(2, entry.time)
    item.set_text(3, entry.type)
    
    # Category column (Index 4)
    if entry.has("category"):
        var cat = entry.category
        item.set_text(4, cat)
        item.set_custom_color(4, entry.category_color)
        item.set_tooltip_text(4, "Click to filter by [" + cat + "]")
    else:
        item.set_text(4, "")
    
    # Strip ANSI and BBCode from Tree display for cleanliness
    var clean_msg = _strip_formatting(entry.message).left(120)
    item.set_text(5, clean_msg) 
    
    # Store count in metadata for details view
    var meta = entry.duplicate()
    meta["collapse_count"] = count
    item.set_metadata(0, meta)
    
    # Color coding
    var color = Color(0.9, 0.9, 0.9)
    # Strict Type Checking to avoid false positives (e.g. "INFO" vs "ERROR")
    # "SCRIPT" error type often comes as just "SCRIPT" or "SCRIPT_ERROR"
    var type_u = entry.type.to_upper()
    
    if type_u == "ERROR" or type_u == "SCRIPT_ERROR" or type_u == "SHADER_ERROR":
        color = Color(1, 0.4, 0.4)
    elif type_u == "WARNING" or entry.get("is_warning", false):
        color = Color(1, 1, 0.4)
    elif type_u == "SCRIPT":
        color = Color(0.7, 0.5, 1.0)
    elif type_u == "SHADER":
        color = Color(0.4, 1.0, 1.0)
        
    for i in range(6):
        if i == 1: continue # Skip count column custom color overrides (handled above)
        if i == 4: continue # Skip category column (has its own color)
        item.set_custom_color(i, color)


func _on_item_selected() -> void:
    var item = _tree.get_selected()
    if item:
        var entry = item.get_metadata(0)
        if typeof(entry) == TYPE_DICTIONARY:
            var count = entry.get("collapse_count", 1)
            
            var t = "[b]ID:[/b] " + str(entry.get("id", "??")) + "\n"
            if count > 1:
                t += "[color=#8888ff]|Occurrences: " + str(count) + "[/color]\n"
            
            # Type with color and filter link
            var type_color = _get_type_color(entry.type)
            var type_color_html = type_color.to_html(false)
            t += "[b]Type:[/b] [url=type:" + entry.type + "][color=#" + type_color_html + "][b]" + entry.type + "[/b][/color][/url] (click to filter)\n"
            
            # Category (clickable)
            if entry.has("category"):
                var cat = entry.category
                var cat_color = entry.category_color.to_html(false)
                t += "[b]Category:[/b] [url=cat:" + cat + "][color=#" + cat_color + "][" + cat + "][/color][/url] (click to filter)\n"
            
            t += "[b]Time:[/b] " + entry.time + "\n"
            
            var msg_clean = _ansi_to_bbcode(entry.message)
            t += "[b]Message:[/b] " + msg_clean + "\n"
            t += "[color=#555555]────────────────────────────────────────[/color]\n"
            
            # Details section - make it bold and formatted nicely
            var det_clean = _ansi_to_bbcode(entry.details)
            # Extract file location info and format it
            var formatted_details = _format_details_section(det_clean)
            t += formatted_details
            
            _details_text.text = t
        else:
            _details_text.text = ""


func _on_item_activated() -> void:
    # User double-clicked or pressed Enter on a row
    # If the row has a category, apply filter
    var item = _tree.get_selected()
    if item:
        var entry = item.get_metadata(0)
        if typeof(entry) == TYPE_DICTIONARY and entry.has("category"):
            _apply_category_filter(entry.category)


func _on_detail_meta_clicked(meta: Variant) -> void:
    # Handle clicks on links in the details panel
    var meta_str = str(meta)
    
    if meta_str.begins_with("cat:"):
        # Category filter
        var cat = meta_str.substr(4) # Remove "cat:" prefix
        _apply_category_filter(cat)
    elif meta_str.begins_with("type:"):
        # Type filter
        var type_name = meta_str.substr(5) # Remove "type:" prefix
        _apply_type_filter(type_name)
    elif meta_str.begins_with("file:"):
        # Open file in editor
        var file_data = meta_str.substr(5) # Remove "file:" prefix
        # Format: "path::line"
        var parts = file_data.split("::")
        if parts.size() == 2:
            var file_path = parts[0]
            var line_num = int(parts[1])
            _open_file_in_editor(file_path, line_num)


func _apply_category_filter(category: String) -> void:
    # Set search bar to literal bracketed category
    var pattern = "[" + category + "]"
    _search_bar.text = pattern
    
    # Must manually trigger filter since setting text doesn't emit signal
    _apply_filter()


func _on_search_text_changed(new_text: String) -> void:
    _apply_filter()


func _on_search_clear_pressed() -> void:
    _search_bar.text = ""
    _apply_filter()


func _on_copy_details_pressed() -> void:
    if _details_text.text != "":
        DisplayServer.clipboard_set(_details_text.get_parsed_text()) # Copy raw text, not bbcode
        _show_copy_feedback(_copy_details_btn, "Copy Selected Detail")


func _strip_formatting(text: String) -> String:
    # Strip both ANSI codes and BBCode tags
    var res = text
    
    # Strip ANSI escape sequences: \x1b followed by [ and parameters
    var reg_ansi = RegEx.new()
    reg_ansi.compile("\\x1b\\[[0-9;]*m")
    res = reg_ansi.sub(res, "", true)
    
    # Strip literal ANSI-style codes like [1m, [22m, [0m
    var reg_literal = RegEx.new()
    reg_literal.compile("\\[[0-9;]+m")
    res = reg_literal.sub(res, "", true)
    
    # Strip BBCode tags
    var reg_bbcode = RegEx.new()
    reg_bbcode.compile("\\[/?[a-z]+[^\\]]*\\]")
    res = reg_bbcode.sub(res, "", true)
    
    return res


func _ansi_to_bbcode(text: String) -> String:
    # Convert ANSI codes to BBCode, handling both escape sequences and literal formats
    var res = text
    
    # Handle standard ANSI escape sequences
    var reg_bold = RegEx.new()
    reg_bold.compile("\\x1b\\[1m")
    res = reg_bold.sub(res, "[b]", true)
    
    # Handle literal [1m format (as seen in user's logs)
    res = res.replace("[1m", "[b]")
    
    # Handle all reset codes (0, 22) - replace with close bold
    var reg_reset = RegEx.new()
    reg_reset.compile("\\x1b\\[[0-9;]*m")
    res = reg_reset.sub(res, "[/b]", true)
    
    # Handle literal reset codes
    res = res.replace("[22m", "[/b]")
    res = res.replace("[0m", "[/b]")
    
    # Clean up duplicate or mismatched tags
    # Multiple [/b] in a row become one
    while "[/b][/b]" in res:
        res = res.replace("[/b][/b]", "[/b]")
    
    # Orphaned closing tags at the end (if text started with bold but didn't have explicit open)
    if res.ends_with("[/b]") and not "[b]" in res:
        res = res.trim_suffix("[/b]")
    
    return res


func _extract_category(message: String) -> String:
    # Extract category from message like "[Core] Something happened"
    # Returns "Core" (case preserved as typed)
    var reg = RegEx.new()
    reg.compile("^\\[([^\\]]+)\\]")
    var match = reg.search(message)
    if match:
        return match.get_string(1)
    return ""


func _category_color(category: String) -> Color:
    # Generate a consistent color from category name using hash
    var hash_val = category.to_lower().hash()
    
    # Use hash to generate HSV values
    var hue = float(abs(hash_val) % 360) / 360.0
    var saturation = 0.6 + (float(abs(hash_val >> 8) % 20) / 100.0) # 0.6-0.8
    var value = 0.8 + (float(abs(hash_val >> 16) % 20) / 100.0) # 0.8-1.0
    
    # Convert HSV to RGB
    return Color.from_hsv(hue, saturation, value)


func _on_copy_visible_pressed() -> void:
    var txt = ""
    for entry in _filtered_logs:
        var count = entry.get("collapse_count", 1)
        txt += "[%s] [%s] %s\n" % [entry.time, entry.type, entry.message]
        if count > 1:
            txt += "|Occurrences: %d\n" % count
        if entry.has("details"):
            txt += entry.details + "\n"
        txt += "----------------------------------------\n"
    
    if txt != "":
        DisplayServer.clipboard_set(txt)
        _show_copy_feedback(_copy_visible_btn, "Copy Filtered List")
    else:
        # User might have clicked copy with empty list or no filters
        if _logs.is_empty():
            DisplayServer.clipboard_set("No logs captured.")
        else:
            DisplayServer.clipboard_set("No logs match the current filters.")


func _show_copy_feedback(btn: Button, original_text: String) -> void:
    btn.modulate = Color(0.5, 1.0, 0.5) # Success green
    btn.text = "✓ Copied!"
    get_tree().create_timer(1.2).timeout.connect(func():
        if is_instance_valid(btn):
            btn.modulate = Color(1, 1, 1)
            btn.text = original_text
    )


func _on_scrape_pressed() -> void:
    _perform_scrape()


func _on_auto_scrape_timer() -> void:
    if not is_visible_in_tree(): return # Save CPU if tab is hidden
    
    # Lightweight check before doing full scrape
    if _check_if_debugger_changed():
        _perform_scrape()


func _perform_scrape() -> void:
    # Attempt to find the EditorDebuggerNode and scrape its current list
    var debugger_node = _get_debugger_node()
    if not debugger_node:
        if not _scrape_timer.is_stopped(): return # Be silent in auto-mode
        
        add_log({
            "time": Time.get_time_string_from_system(),
            "type": "WARNING",
            "message": "Scraper failed: Could not find Editor's Debugger node.",
            "details": "The internal path for Godot's debugger tab varies. Automatic capture is preferred."
        })
        return
    
    # Save current known log IDs to avoid duplicates if scraping same content
    # (Actually simpler: Scraper grabs everything visible. We must avoid adding what we already have.)
    # For now, simplistic approach: "Scraped" logs usually lack precise timestamps matching our system.
    # To avoid duplicates, we can check if the LAST log message matches.
    # OR we just scrape and user clears manually.
    # BETTER: Maintain a hash of scraped messages?
    # Simple Deduplication:
    # If the exact same message+details exists in _logs (last 50?), skip.
    
    var found_lists = []
    _find_item_containers(debugger_node, found_lists)
    
    var state = {"count": 0}
    for list in found_lists:
        if list is ItemList:
            for i in range(list.item_count):
                var txt = list.get_item_text(i)
                if "ERROR" in txt.to_upper() or "WARNING" in txt.to_upper():
                    _add_scraped_log_if_new(txt, state)
        elif list is Tree:
            _scrape_tree(list.get_root(), state)

    # Note: Silent success in auto-mode

func _get_debugger_node() -> Node:
    if is_instance_valid(_cached_debugger_node):
        return _cached_debugger_node
        
    var base = get_tree().root.get_child(0) # Likely EditorNode
    _cached_debugger_node = _find_debugger_node(base)
    return _cached_debugger_node


func _check_if_debugger_changed() -> bool:
    var node = _get_debugger_node()
    if not node: return false
    
    var found_lists = []
    _find_item_containers(node, found_lists)
    
    var changed = false
    for list in found_lists:
        var oid = list.get_instance_id()
        var current_count = 0
        
        if list is ItemList:
            current_count = list.item_count
        elif list is Tree:
            # Tree doesn't have a simple item_count property easily accessible without traversal?
            # Start of Tree usually has a root. We can check root child count?
            # get_root() might be null.
            var r = list.get_root()
            if r:
                # Approximate change detection by checking first level children count
                # This isn't perfect but is fast.
                var c = r.get_first_child()
                while c:
                    current_count += 1
                    c = c.get_next()
            
        if _last_item_counts.get(oid, -1) != current_count:
            _last_item_counts[oid] = current_count
            changed = true
            
    return changed


func _add_scraped_log_if_new(raw_text: String, state: Dictionary) -> void:
    # This helper is for ItemList strings. Tree items call add_log directly in _scrape_tree.
    # We should update _scrape_tree to use a dedup check too.
    var entry = _parse_scraped_text(raw_text)
    _dedup_and_add(entry, state)


func _dedup_and_add(entry: Dictionary, state: Dictionary) -> void:
    # Check if this exact message was added recently (in last 20 logs)
    # This helps prevents infinite scrape loops if the list structure doesn't change but we re-read.
    var duplicate_found = false
    var limit = min(_logs.size(), 50)
    for i in range(limit):
        var idx = _logs.size() - 1 - i
        var existing = _logs[idx]
        if existing.message == entry.message and existing.get("details_hash") == entry.details.hash():
            duplicate_found = true
            break
            
    if not duplicate_found:
        entry["details_hash"] = entry.details.hash()
        add_log(entry)
        state.count += 1


func _find_debugger_node(node: Node) -> Node:
    if node.get_class() == "EditorDebuggerNode":
        return node
    for child in node.get_children():
        var res = _find_debugger_node(child)
        if res: return res
    return null


func _find_item_containers(node: Node, results: Array):
    if node is Tree or node is ItemList:
        results.append(node)
    for child in node.get_children():
        _find_item_containers(child, results)


func _scrape_tree(item: TreeItem, state: Dictionary):
    if not item: return
    
    # 1. Harvest all text data from this item (columns and tooltip)
    var item_text = item.get_text(0)
    var full_data = item_text
    
    # Check other columns (up to 4 usually enough) - safely checking column limit
    var tree_ref = item.get_tree()
    var col_count = tree_ref.columns if tree_ref else 1
    
    for c in range(1, min(4, col_count)):
        var c_text = item.get_text(c)
        if c_text != "":
            full_data += " | " + c_text
            
    # Check tooltips
    var tip = item.get_tooltip_text(0)
    if tip != "":
        full_data += "\nTooltip: " + tip
        
    var is_error = "ERROR" in full_data.to_upper()
    var is_warning = "WARNING" in full_data.to_upper()
    
    # If it's a relevant node
    if is_error or is_warning:
        # 2. Check for child nodes (Stack Trace often lives here as children)
        var child = item.get_first_child()
        if child:
            full_data += "\n--- Sub-Items ---"
            var depth_limit = 0
            while child and depth_limit < 50: # Safety break
                var child_txt = child.get_text(0)
                # Try to get more info from columns - safely
                var extra = ""
                for c in range(1, min(3, col_count)):
                    var t = child.get_text(c)
                    if t != "": extra += " :: " + t
                
                full_data += "\n" + child_txt + extra
                child = child.get_next()
                depth_limit += 1
        
        # 3. Add to log
        var log_entry = _parse_scraped_text(full_data)
        if "ERROR" in log_entry.type: # Ensure we don't misclassify generic headers
            if is_warning: log_entry.type = "WARNING"
             
        _dedup_and_add(log_entry, state)
    
    # 4. Recurse (Deep traversal)
    # Only recurse if we didn't just consume the children as details for an error
    # (Actually in Godot Debugger, errors are usually leaf nodes OR parent nodes with stack children.
    #  We don't want to double-count children if we just added them to details.)
    
    if not (is_error or is_warning):
        var sub_child = item.get_first_child()
        while sub_child:
            _scrape_tree(sub_child, state)
            sub_child = sub_child.get_next()


func _parse_scraped_text(text: String) -> Dictionary:
    var type = "INFO"
    var is_warning = false
    
    # Check for keywords
    var upper_text = text.to_upper()
    if "ERROR" in upper_text: 
        type = "ERROR"
    elif "WARNING" in upper_text: 
        type = "WARNING"
        is_warning = true
    
    var lines = text.strip_edges().split("\n")
    var message = lines[0]
    
    # Filter out generic tags and find first meaningful line
    for line in lines:
        var l = line.strip_edges()
        if l == "" or l == "<GDScript Error>" or l == "<GDScript Warning>" or l == "GDScript Error" or l == "GDScript Warning":
            continue
        # ignore pure generated separators
        if l == "--- Sub-Items ---" or l.begins_with("Tooltip:"):
            continue 
             
        message = l
        break

    return {
        "time": Time.get_time_string_from_system() + " (Scraped)",
        "type": type,
        "is_warning": is_warning,
        "message": message,
        "details": "Source: Scraped from Editor UI\nRaw Data:\n" + text
    }


func _get_type_color(type_name: String) -> Color:
    # Return the color for a specific type
    var type_u = type_name.to_upper()
    
    if type_u == "ERROR" or type_u == "SCRIPT_ERROR" or type_u == "SHADER_ERROR":
        return Color(1, 0.4, 0.4)  # Red
    elif type_u == "WARNING":
        return Color(1, 1, 0.4)  # Yellow
    elif type_u == "SCRIPT":
        return Color(0.7, 0.5, 1.0)  # Purple/Blue
    elif type_u == "SHADER":
        return Color(0.4, 1.0, 1.0)  # Cyan
    else:
        return Color(0.7, 0.7, 0.7)  # Gray for info


func _apply_type_filter(type_name: String) -> void:
    # Filter to show only this type
    _search_bar.text = ""
    
    # Disable all toggles (with null checks for safety)
    if _err_toggle:
        _err_toggle.button_pressed = false
    if _warn_toggle:
        _warn_toggle.button_pressed = false
    if _info_toggle:
        _info_toggle.button_pressed = false
    
    # Enable only the selected type
    var type_u = type_name.to_upper()
    if type_u == "ERROR" or type_u == "SCRIPT_ERROR" or type_u == "SHADER_ERROR":
        if _err_toggle:
            _err_toggle.button_pressed = true
    elif type_u == "WARNING":
        if _warn_toggle:
            _warn_toggle.button_pressed = true
    else:
        if _info_toggle:
            _info_toggle.button_pressed = true
    
    _apply_filter()


func _format_details_section(details: String) -> String:
    # Format the details section with bold headers and clickable file links
    var lines = details.split("\n")
    var result = ""
    
    for line in lines:
        var trimmed = line.strip_edges()
        
        # Skip empty lines
        if trimmed == "":
            result += "\n"
            continue
        
        # Look for file/location patterns
        # - res://path/to/file.gd:123
        # - /path/to/file.gd:123
        # - file.gd:123
        
        var file_pattern = RegEx.new()
        file_pattern.compile("(.*?)(res://[\\w./\\-]+\\.[a-z]+|/?[\\w./\\-]+\\.[a-z]+)(?::(\\d+))?(.*)")
        
        var match = file_pattern.search(trimmed)
        if match and match.get_string(2):  # Has file
            var before = match.get_string(1).strip_edges()
            var filepath = match.get_string(2)
            var line_num = match.get_string(3) if match.get_string(3) else "1"
            var after = match.get_string(4).strip_edges()
            
            # Format as bold header with clickable link
            var line_text = "[b]" + before + " " if before else "[b]"
            line_text += "[url=file:" + filepath + "::" + line_num + "][u][color=#6db3f2]" + filepath + ":" + line_num + "[/color][/u][/url]"
            line_text += "[/b] " + after if after else "[/b]"
            result += line_text + "\n"
        else:
            # Regular line - make it bold if it looks like a section header
            if ("Location" in trimmed or "File" in trimmed or "Line" in trimmed or 
                "Stack" in trimmed or "Function" in trimmed or "Source" in trimmed):
                result += "[b]" + line + "[/b]\n"
            else:
                result += line + "\n"
    
    return result


func _open_file_in_editor(file_path: String, line_num: int) -> void:
    # Open the file in the Godot editor at the specified line
    # This mimics Godot's built-in error click behavior
    
    # Resolve the file path - it might be relative to project root
    var full_path = file_path
    
    # Check if it's relative or absolute
    if not file_path.begins_with("res://") and not file_path.begins_with("/"):
        # Try as relative to project
        full_path = "res://" + file_path.trim_prefix("/")
    
    if not FileAccess.file_exists(full_path):
        # Try alternative paths
        if FileAccess.file_exists("res://" + file_path):
            full_path = "res://" + file_path
        elif FileAccess.file_exists(ProjectSettings.globalize_path("res://") + file_path):
            full_path = ProjectSettings.globalize_path("res://") + file_path
    
    # Get the script resource
    var script = load(full_path)
    if script:
        # Open in editor via EditorInterface
        var editor_iface = _get_editor_interface()
        if editor_iface:
            editor_iface.edit_script(script, line_num)
    else:
        push_warning("Could not open script: " + full_path)


func _get_editor_interface() -> EditorInterface:
    # Get EditorInterface through the plugin reference or hierarchy
    if not Engine.is_editor_hint():
        return null
    
    # 1. Try passing the plugin property
    if plugin and plugin.has_method("get_editor_interface"):
        return plugin.get_editor_interface()
        
    # 2. Try global keyword (Godot 4.3+)
    # We use expression to avoid compile error on older versions if it doesn't exist
    var expr = Expression.new()
    if expr.parse("EditorInterface") == OK:
        var result = expr.execute([], self)
        if result is EditorInterface:
            return result
            
    # 3. Try finding in parent hierarchy
    var current = get_parent()
    while current:
        if current.has_method("get_editor_interface"):
            return current.get_editor_interface()
        current = current.get_parent()
    
    return null


func _apply_column_widths() -> void:
    if not is_instance_valid(_tree):
        return

    var n := _tree.columns
    if _col_widths.size() != n:
        _col_widths.resize(n)

    # Apply per-column minimums and current widths
    for i in range(n):
        var min_w := 30
        if i < configs.size():
            min_w = int(configs[i].min_w)

        var target_w := max(min_w, int(_col_widths[i]))
        _col_widths[i] = target_w

        _tree.set_column_expand(i, false)
        _tree.set_column_custom_minimum_width(i, target_w)

    # Let the last column take remaining space
    if n > 0:
        _tree.set_column_expand(n - 1, true)

    # Force redraw/layout refresh (Tree has no queue_sort; minimum_size_changed is a signal)
    _tree.queue_redraw()

    _tree.call_deferred("queue_redraw")

    # Keep separator overlay in sync
    _update_col_sep_overlay()
    # _tree.call_deferred("queue_redraw")



func _header_height_px() -> float:
    # Approx header height in editor UI; tweak if needed (24/26/28).
    return 24.0


func _on_tree_gui_input(ev: InputEvent) -> void:
    if not is_instance_valid(_tree):
        return

    var header_h := _header_height_px()

    if ev is InputEventMouseMotion:
        var m := ev as InputEventMouseMotion

        # Dragging a separator
        if _resize_drag_col != -1:
            var dx := m.position.x - _resize_drag_start_x
            var new_w := int(_resize_drag_start_w + dx)
            var min_w := 30
            if _resize_drag_col >= 0 and _resize_drag_col < configs.size():
                min_w = int(configs[_resize_drag_col]["min_w"])
            new_w = max(min_w, new_w)
            _col_widths[_resize_drag_col] = new_w
            _apply_column_widths()
            _tree.accept_event()
            return

        # Cursor feedback when hovering a separator in the header
        if m.position.y <= header_h:
            var x_acc := 0.0
            # Separators between columns 0..n-2
            for c in range(_tree.columns - 1):
                x_acc += float(_col_widths[c])
                if abs(m.position.x - x_acc) <= _resize_hit_px:
                    _tree.mouse_default_cursor_shape = Control.CURSOR_HSIZE
                    return

        _tree.mouse_default_cursor_shape = Control.CURSOR_ARROW
        return

    if ev is InputEventMouseButton:
        var b := ev as InputEventMouseButton
        if b.button_index != MOUSE_BUTTON_LEFT:
            return

        # Release
        if not b.pressed:
            _resize_drag_col = -1
            return

        # Header-only click
        if b.position.y > header_h:
            return

        # Detect click near a separator
        var x_acc := 0.0
        for c in range(_tree.columns - 1):
            x_acc += float(_col_widths[c])
            if abs(b.position.x - x_acc) <= _resize_hit_px:
                _resize_drag_col = c
                _resize_drag_start_x = b.position.x
                _resize_drag_start_w = int(_col_widths[c])
                _tree.accept_event()
                return


func _update_col_sep_overlay() -> void:
    if not is_instance_valid(_tree) or not is_instance_valid(_col_sep_overlay):
        return

    var header_h := _header_height_px()

    # Overlay covers only the header area
    _col_sep_overlay.position = Vector2(0, 0)
    _col_sep_overlay.size = Vector2(_tree.size.x, header_h)

    _col_sep_overlay.queue_redraw()


func _draw_col_separators(ci: CanvasItem) -> void:
    # Draw subtle vertical lines at each column boundary
    if not _show_separators:
        return

    var header_h := _header_height_px()

    # Pick a color that works in the editor (light line with some transparency)
    var line_color := Color(1, 1, 1, 0.18)

    var x_acc := 0.0
    for c in range(_tree.columns - 1):
        x_acc += float(_col_widths[c])
        # 1px line
        ci.draw_line(Vector2(x_acc, 2), Vector2(x_acc, header_h - 2), line_color, 1.0)
        # optional: make it a tiny bit more visible by adding a darker twin line
        ci.draw_line(Vector2(x_acc + 1, 2), Vector2(x_acc + 1, header_h - 2), Color(0, 0, 0, 0.12), 1.0)

class ColumnSeparatorOverlay extends Control:
    var owner_ui: Node

    func _draw() -> void:
        if owner_ui and owner_ui.has_method("_draw_col_separators"):
            owner_ui._draw_col_separators(self)

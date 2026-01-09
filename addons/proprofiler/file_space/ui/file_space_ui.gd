###############################################################
# addons/proprofiler/file_space/ui/file_space_ui.gd
# Main file space tab: hierarchy tree + breakdown chart
###############################################################

class_name FileSpaceUI
extends VBoxContainer

const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")
const FileSpaceAnalyzer = preload("res://addons/proprofiler/file_space/file_space_analyzer.gd")
const FileSpaceData = preload("res://addons/proprofiler/file_space/file_space_data.gd")
const FileSpaceTree = preload("res://addons/proprofiler/file_space/ui/file_space_tree.gd")
const FileSpaceChart = preload("res://addons/proprofiler/file_space/ui/file_space_chart.gd")


var analyzer: FileSpaceAnalyzer
var tree_view: FileSpaceTree
var chart_view: FileSpaceChart
var status_label: Label
var scan_button: Button
var progress_bar: ProgressBar
var last_scan_time: float = 0.0
var progress_tween: Tween
var current_filter: String = ""  # Current category filter

# File selection and actions
var selected_file_path: String = ""
var selected_file_ext: String = ""
var action_buttons: Dictionary = {}  # {action_id: {button, exts}}


func _ready() -> void:
    add_theme_constant_override("separation", ProfilerDesign.MARGIN_SMALL)
    custom_minimum_size = Vector2(0, 600)
    
    analyzer = FileSpaceAnalyzer.new()
    analyzer.scan_completed.connect(_on_scan_completed)
    analyzer.scan_started.connect(_on_scan_started)
    
    _build_ui()
    _show_initial_state()


func _build_ui() -> void:
    # ──────────────── Header / Controls ────────────────
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", ProfilerDesign.MARGIN_STANDARD)
    header.custom_minimum_size = Vector2(0, ProfilerDesign.HEIGHT_STAT_ROW)
    add_child(header)
    
    # Title
    var title = Label.new()
    title.text = "Disk Usage Analysis"
    title.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_TITLE)
    title.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT)
    header.add_child(title)
    
    header.add_child(Control.new())  # Spacer
    
    # Scan button
    scan_button = Button.new()
    scan_button.text = "🔍 Scan Project"
    scan_button.custom_minimum_size = Vector2(120, ProfilerDesign.HEIGHT_BUTTON)
    scan_button.pressed.connect(_on_scan_pressed)
    header.add_child(scan_button)
    
    # Status label
    status_label = Label.new()
    status_label.text = "Ready"
    status_label.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_SMALL)
    status_label.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT_DIM)
    status_label.custom_minimum_size = Vector2(200, 0)
    header.add_child(status_label)
    
    # ──────────────── Progress Bar ────────────────
    progress_bar = ProgressBar.new()
    progress_bar.value = 0
    progress_bar.custom_minimum_size = Vector2(0, 6)
    progress_bar.modulate.a = 0.6
    progress_bar.visible = false
    add_child(progress_bar)
    
    # ──────────────── Divider ────────────────
    var divider = Control.new()
    divider.custom_minimum_size = Vector2(0, 1)
    add_child(divider)
    
    # ──────────────── Content: Split view ────────────────
    var split = HSplitContainer.new()
    split.custom_minimum_size = Vector2(0, 400)
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(split)
    
    # Left: Tree view
    tree_view = FileSpaceTree.new()
    tree_view.file_selected.connect(set_selected_file)
    split.add_child(tree_view)
    
    # Middle: Chart + legend
    var middle_panel = VBoxContainer.new()
    middle_panel.add_theme_constant_override("separation", ProfilerDesign.MARGIN_SMALL)
    split.add_child(middle_panel)
    
    chart_view = FileSpaceChart.new()
    middle_panel.add_child(chart_view)
    
    # Legend + Actions in scrollable container
    var legend_scroll = ScrollContainer.new()
    legend_scroll.custom_minimum_size = Vector2(600, 0)  # Width for legend + actions
    legend_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Fill vertical space
    legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    legend_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    middle_panel.add_child(legend_scroll)
    
    var legend_with_actions = _create_legend_with_actions()
    legend_scroll.add_child(legend_with_actions)


func _create_legend_with_actions() -> HBoxContainer:
    var container = HBoxContainer.new()
    container.add_theme_constant_override("separation", ProfilerDesign.MARGIN_STANDARD)
    container.custom_minimum_size = Vector2(600, 0)
    
    # ──────────────── Left: Legend ────────────────
    var legend = VBoxContainer.new()
    legend.add_theme_constant_override("separation", ProfilerDesign.MARGIN_TINY)
    legend.custom_minimum_size = Vector2(300, 0)
    
    var title = Label.new()
    title.text = "File Type Legend (click to filter)"
    title.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_HEADING)
    title.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT)
    legend.add_child(title)
    
    var types = [
        {"name": "Images", "ext": "png"},
        {"name": "Videos", "ext": "mp4"},
        {"name": "Audio", "ext": "ogg"},
        {"name": "Code", "ext": "gd"},
        {"name": "Scenes", "ext": "tscn"},
        {"name": "Data", "ext": "json"},
        {"name": "Shaders", "ext": "gdshader"},
        {"name": "Fonts", "ext": "ttf"},
    ]
    
    # Add "Clear Filter" button
    var clear_btn = Button.new()
    clear_btn.text = "✕ Clear Filter"
    clear_btn.custom_minimum_size = Vector2(0, 36)
    clear_btn.pressed.connect(_on_filter_clear)
    legend.add_child(clear_btn)
    
    for type_info in types:
        var item = Button.new()
        item.custom_minimum_size = Vector2(0, 40)
        
        var hbox = HBoxContainer.new()
        hbox.add_theme_constant_override("separation", ProfilerDesign.MARGIN_STANDARD)
        
        var swatch = ColorRect.new()
        swatch.color = ProfilerDesign.get_type_color(type_info["ext"])
        swatch.custom_minimum_size = Vector2(16, 16)
        hbox.add_child(swatch)
        
        var label = Label.new()
        label.text = type_info["name"]
        label.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_SMALL)
        label.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT_DIM)
        hbox.add_child(label)
        
        item.add_child(hbox)
        item.flat = true
        item.alignment = HORIZONTAL_ALIGNMENT_LEFT
        item.pressed.connect(_on_legend_filter.bindv([type_info["name"]]))
        legend.add_child(item)
    
    container.add_child(legend)
    
    # ──────────────── Divider ────────────────
    var divider = Control.new()
    divider.custom_minimum_size = Vector2(1, 0)
    container.add_child(divider)
    
    # ──────────────── Right: Actions ────────────────
    var actions_panel = _create_actions_panel()
    container.add_child(actions_panel)
    
    return container


func _create_actions_panel() -> VBoxContainer:
    var actions = VBoxContainer.new()
    actions.add_theme_constant_override("separation", ProfilerDesign.MARGIN_TINY)
    actions.custom_minimum_size = Vector2(280, 0)
    
    var title = Label.new()
    title.text = "⚙️ Actions (select file)"
    title.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_HEADING)
    title.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT)
    actions.add_child(title)
    
    # Action button definitions: {id, label, applies_to_extensions}
    var action_defs = [
        {"id": "resize", "label": "📄 Resize Image (÷2)", "exts": ["png", "jpg", "jpeg", "bmp"]},
        {"id": "convert_jpg", "label": "🔄 Convert to JPG", "exts": ["png", "bmp"]},
        {"id": "resize_video", "label": "🎥 Resize Video (÷2)", "exts": ["mp4", "webm", "mov", "ogv"]},
        {"id": "compress_audio", "label": "🔊 Compress Audio", "exts": ["mp3", "ogg", "wav"]},
        {"id": "open_explorer", "label": "📂 Open in Explorer", "exts": []},  # Works on any file
    ]
    
    for action in action_defs:
        var btn = Button.new()
        btn.text = action["label"]
        btn.custom_minimum_size = Vector2(0, 40)
        btn.disabled = true  # Start disabled
        btn.pressed.connect(_on_action_pressed.bindv([action["id"]]))
        actions.add_child(btn)
        action_buttons[action["id"]] = {"button": btn, "exts": action["exts"]}
    
    # Add spacer
    actions.add_child(Control.new())
    
    # Status label
    var status = Label.new()
    status.text = "Click a file in the tree"
    status.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_SMALL)
    status.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT_DIM)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD
    actions.add_child(status)
    
    return actions


func _on_scan_started() -> void:
    progress_bar.visible = true
    progress_bar.value = 0
    progress_bar.show_percentage = false
    
    # Kill any existing tween
    if progress_tween:
        progress_tween.kill()
    
    # Animate progress bar in a loop (indeterminate style)
    progress_tween = create_tween()
    progress_tween.set_loops(0)  # Infinite loop
    progress_tween.set_trans(Tween.TRANS_LINEAR)
    progress_tween.tween_property(progress_bar, "value", 100.0, 1.5)
    progress_tween.tween_property(progress_bar, "value", 0.0, 0.0)


func _on_scan_pressed() -> void:
    scan_button.disabled = true
    status_label.text = "Scanning..."
    status_label.add_theme_color_override("font_color", ProfilerDesign.COLOR_WARN)
    
    analyzer.start_scan()


func _on_scan_completed(result: FileSpaceData.AnalysisResult) -> void:
    scan_button.disabled = false
    
    # Stop progress animation
    if progress_tween:
        progress_tween.kill()
    progress_bar.visible = false
    
    # Update status
    last_scan_time = result.scan_time_ms
    status_label.text = "Scanned in %.0f ms • %s total" % [result.scan_time_ms, ProfilerDesign.format_bytes(result.total_size_bytes)]
    status_label.add_theme_color_override("font_color", ProfilerDesign.COLOR_GOOD)
    
    # Update tree with filter applied
    var folders_to_display = analyzer.get_filtered_root_folders() if not current_filter.is_empty() else result.root_folders
    var display_total = 0
    for folder in folders_to_display:
        display_total += folder.size_bytes
    tree_view.update_tree(folders_to_display, display_total)
    
    # Update chart
    var sorted_cats = analyzer.get_sorted_categories()
    chart_view.update_chart(sorted_cats)


func _show_initial_state() -> void:
    # Show empty tree with message
    var empty_folders = []
    tree_view.update_tree(empty_folders, 0)
    
    # Show empty chart with message
    chart_view.update_chart([])


func _on_legend_filter(category: String) -> void:
    current_filter = category
    analyzer.set_category_filter(category)
    
    # Update tree with filtered data
    var filtered_folders = analyzer.get_filtered_root_folders()
    var total_bytes = 0
    for folder in filtered_folders:
        total_bytes += folder.size_bytes
    tree_view.update_tree(filtered_folders, total_bytes)
    
    # Update chart
    var sorted_cats = analyzer.get_sorted_categories()
    chart_view.update_chart(sorted_cats)


func _on_filter_clear() -> void:
    current_filter = ""
    analyzer.set_category_filter("")
    
    # Redraw with all data
    if analyzer.analysis_result.root_folders.size() > 0:
        tree_view.update_tree(analyzer.analysis_result.root_folders, analyzer.analysis_result.total_size_bytes)
        var sorted_cats = analyzer.get_sorted_categories()
        chart_view.update_chart(sorted_cats)


func _on_tree_item_selected() -> void:
    # Called when user selects a file in the tree
    # Get selected item from tree_view if it has selection tracking
    # This will be connected from the tree view
    pass


func set_selected_file(file_path: String, file_ext: String) -> void:
    """Called when a file is selected in the tree"""
    selected_file_path = file_path
    selected_file_ext = file_ext.to_lower()
    
    # Update button states based on file extension
    _update_action_buttons()


func _update_action_buttons() -> void:
    """Enable/disable action buttons based on selected file type"""
    if selected_file_path.is_empty():
        # No file/folder selected, disable all actions
        for action_id in action_buttons:
            action_buttons[action_id]["button"].disabled = true
        return
    
    # Check if it's a folder (no extension) or a file
    var is_folder = selected_file_ext.is_empty()
    
    # Enable/disable based on file type
    for action_id in action_buttons:
        var action_data = action_buttons[action_id]
        var allowed_exts = action_data["exts"]
        
        if is_folder:
            # Folder selected - enable ALL actions (they work recursively)
            action_data["button"].disabled = false
        else:
            # File selected - enable only if extension matches
            if allowed_exts.is_empty():
                # Actions with empty exts list work on any file
                action_data["button"].disabled = false
            else:
                # Enable only if extension is in allowed list
                action_data["button"].disabled = not selected_file_ext in allowed_exts


func _on_action_pressed(action_id: String) -> void:
    """Handle action button press"""
    if selected_file_path.is_empty():
        print("No file selected for action: ", action_id)
        return
    
    match action_id:
        "resize":
            _action_resize_image()
        "convert_jpg":
            _action_convert_to_jpg()
        "resize_video":
            _action_resize_video()
        "compress_audio":
            _action_compress_audio()
        "open_explorer":
            _action_open_explorer()


func _action_resize_image() -> void:
    """Resize image(s) to half resolution. Works on single files or all images in folder."""
    if selected_file_ext.is_empty():
        # It's a folder - resize all images inside
        _batch_resize_images_in_folder()
    else:
        # Single image file
        _resize_single_image(selected_file_path)


func _resize_single_image(image_path: String) -> void:
    """Resize a single image to half dimensions"""
    if not ResourceLoader.exists(image_path):
        print("[Error] Image not found: ", image_path)
        return
    
    var img = Image.new()
    var error = img.load(image_path)
    if error != OK:
        print("[Error] Failed to load image: ", image_path)
        return
    
    var new_width = maxi(img.get_width() / 2, 1)
    var new_height = maxi(img.get_height() / 2, 1)
    img.resize(new_width, new_height)
    
    error = img.save_png(image_path)
    if error == OK:
        print("[✓] Resized: ", image_path, " to ", new_width, "x", new_height)
    else:
        print("[Error] Failed to save resized image: ", image_path)


func _batch_resize_images_in_folder() -> void:
    """Recursively resize all images in selected folder"""
    print("[Action] Batch resize images in folder: ", selected_file_path)
    var image_exts = ["png", "jpg", "jpeg", "bmp"]
    var count = 0
    
    var files = _get_all_files_recursive(selected_file_path, image_exts)
    for file_path in files:
        _resize_single_image(file_path)
        count += 1
    
    print("[✓] Batch resize complete: ", count, " images processed")


func _action_convert_to_jpg() -> void:
    """Convert image(s) to JPG. Works on single files or all convertible images in folder."""
    if selected_file_ext.is_empty():
        # It's a folder - convert all images inside
        _batch_convert_to_jpg_in_folder()
    else:
        # Single image file
        _convert_single_to_jpg(selected_file_path)


func _convert_single_to_jpg(image_path: String) -> void:
    """Convert a single image to JPG"""
    if not ResourceLoader.exists(image_path):
        print("[Error] Image not found: ", image_path)
        return
    
    var img = Image.new()
    var error = img.load(image_path)
    if error != OK:
        print("[Error] Failed to load image: ", image_path)
        return
    
    var jpg_path = image_path.get_basename() + ".jpg"
    error = img.save_jpg(jpg_path)
    if error == OK:
        print("[✓] Converted: ", image_path, " → ", jpg_path)
    else:
        print("[Error] Failed to save JPG: ", jpg_path)


func _batch_convert_to_jpg_in_folder() -> void:
    """Recursively convert all images in selected folder to JPG"""
    print("[Action] Batch convert to JPG in folder: ", selected_file_path)
    var image_exts = ["png", "bmp"]
    var count = 0
    
    var files = _get_all_files_recursive(selected_file_path, image_exts)
    for file_path in files:
        _convert_single_to_jpg(file_path)
        count += 1
    
    print("[✓] Batch convert complete: ", count, " images processed")


func _action_resize_video() -> void:
    """Resize video(s) to half dimensions using ffmpeg. Works on single files or all videos in folder."""
    if selected_file_ext.is_empty():
        # It's a folder - resize all videos inside
        _batch_resize_videos_in_folder()
    else:
        # Single video file
        _resize_single_video(selected_file_path)


func _resize_single_video(video_path: String) -> void:
    """Resize a single video to half dimensions using ffmpeg"""
    if not ResourceLoader.exists(video_path):
        print("[Error] Video not found: ", video_path)
        return
    
    var ext = video_path.get_extension().to_lower()
    var output_path = video_path.get_basename() + "_resized." + ext
    
    # Build ffmpeg command with codec support for different formats
    var cmd: String
    if ext == "ogv":
        # OGV (Theora) needs specific codec parameters
        cmd = "ffmpeg -i \"%s\" -vf scale=iw/2:ih/2 -c:v libtheora -q:v 7 -c:a libvorbis \"%s\" -y" % [video_path, output_path]
    else:
        # Generic command for MP4, WebM, MOV, etc.
        cmd = "ffmpeg -i \"%s\" -vf scale=iw/2:ih/2 -c:v libx264 -crf 23 -c:a aac \"%s\" -y" % [video_path, output_path]
    
    print("[Action] Resizing video with ffmpeg...")
    print("[Command] ", cmd)
    var result = OS.execute("cmd.exe", ["/C", cmd])
    
    if result == 0:
        print("[✓] Video resized: ", video_path, " → ", output_path)
    else:
        print("[Error] ffmpeg failed. Make sure ffmpeg is installed and in PATH. Try: choco install ffmpeg")


func _batch_resize_videos_in_folder() -> void:
    """Recursively resize all videos in selected folder"""
    print("[Action] Batch resize videos in folder: ", selected_file_path)
    var video_exts = ["mp4", "webm", "mov", "ogv"]
    var count = 0
    
    var files = _get_all_files_recursive(selected_file_path, video_exts)
    for file_path in files:
        _resize_single_video(file_path)
        count += 1
    
    print("[✓] Batch resize videos complete: ", count, " videos processed")


func _action_compress_audio() -> void:
    """Compress audio file(s). Works on single files or all audio in folder."""
    if selected_file_ext.is_empty():
        # It's a folder - compress all audio inside
        _batch_compress_audio_in_folder()
    else:
        # Single audio file
        _compress_single_audio(selected_file_path)


func _compress_single_audio(audio_path: String) -> void:
    """Compress a single audio file using ffmpeg"""
    if not ResourceLoader.exists(audio_path):
        print("[Error] Audio not found: ", audio_path)
        return
    
    var output_path = audio_path.get_basename() + "_compressed." + audio_path.get_extension()
    var cmd = "ffmpeg -i \"%s\" -b:a 128k \"%s\" -y" % [audio_path, output_path]
    
    print("[Action] Compressing audio with ffmpeg...")
    print("[Command] ", cmd)
    var result = OS.execute("cmd.exe", ["/C", cmd])
    
    if result == 0:
        print("[✓] Audio compressed: ", audio_path, " → ", output_path)
    else:
        print("[Error] ffmpeg failed. Ensure ffmpeg is installed and in PATH")


func _batch_compress_audio_in_folder() -> void:
    """Recursively compress all audio in selected folder"""
    print("[Action] Batch compress audio in folder: ", selected_file_path)
    var audio_exts = ["mp3", "ogg", "wav"]
    var count = 0
    
    var files = _get_all_files_recursive(selected_file_path, audio_exts)
    for file_path in files:
        _compress_single_audio(file_path)
        count += 1
    
    print("[✓] Batch compress audio complete: ", count, " files processed")


func _action_open_explorer() -> void:
    """Open file or folder in Windows Explorer"""
    if selected_file_path.is_empty():
        return
    
    var is_folder = selected_file_ext.is_empty()
    var target_path = selected_file_path.replace("/", "\\")
    
    if is_folder:
        # For folders, use shell_open directly
        OS.shell_open(target_path)
        print("[✓] Opened folder in Explorer: ", target_path)
    else:
        # For files, use explorer /select command
        var cmd = "explorer /select,\"%s\"" % target_path
        var result = OS.create_process("explorer.exe", ["/select", target_path])
        if result >= 0:
            print("[✓] Opened file in Explorer: ", target_path)
        else:
            print("[Error] Failed to open explorer")


func _get_all_files_recursive(folder_path: String, extensions: Array) -> Array:
    """Recursively get all files with given extensions in folder"""
    var result = []
    var dir = DirAccess.open(folder_path)
    
    if dir == null:
        print("[Error] Cannot open folder: ", folder_path)
        return result
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.begins_with("."):
            file_name = dir.get_next()
            continue
        
        var file_path = folder_path.path_join(file_name)
        
        if dir.current_is_dir():
            # Recurse into subdirectories
            var sub_files = _get_all_files_recursive(file_path, extensions)
            result.append_array(sub_files)
        else:
            # Check if file extension matches
            var ext = file_name.get_extension().to_lower()
            if ext in extensions:
                result.append(file_path)
        
        file_name = dir.get_next()
    
    return result

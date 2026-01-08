proprofiler
===========

Lightweight Godot addon for profiling and simple performance inspection during development.

Requirements
- Godot 4.5 or newer — the `Logs` tab relies on engine support introduced in https://github.com/godotengine/godot/pull/91006.

Quick install
- Place the `proprofiler` folder under your project's `addons/` folder.
- Enable the plugin: Project -> Project Settings -> Plugins -> enable `ProProfiler`.

Overview (Tabs)
- Logs: Centralizes editor/runtime logs and debug output to make troubleshooting easier. Requires Godot 4.5+ (see PR above).
- CPU Usage: Not implemented — current Godot APIs do not expose enough per-process game data to safely provide this to addons.
- Disk Usage: Shows asset and file-size breakdowns to help locate heavy assets and reduce build/runtime footprint.

Usage
- Enable the plugin and open the addon's UI from the Editor, or use the in-game controls for runtime captures.
- Use `Logs` to gather recent runtime messages. Use `Disk Usage` to scan project folders and identify large assets.


Contributing
- Contributions welcome. Follow the project's style.
- Keep PRs focused, include tests or manual verification steps, and document behavioral changes in the PR description.

License
- See the repository `LICENSE` file: [LICENSE](../../LICENSE)

Support
- Open issues and PRs on the repository; include Godot version and reproduction steps when relevant.

Notes
- This addon is targeted at development workflows. Keep it disabled in release exports.


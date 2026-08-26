# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.1-alpha] - 2026-08-25

### Fixed
- Fixed reversed turn left/turn right actions by correcting swapped `LEFT`/`RIGHT` constants in `TurnAction` (`LEFT = -1`, `RIGHT = 1`).

### Changed
- Default `viewport_ratio` changed from `3.0` to `2.0` for a 2:1 vertical split between the 3D viewport and the action bar.
- `MainLayout` now sets `SIZE_EXPAND_FILL` on both ViewportFrame and BottomBar so that stretch ratios are respected in the VBoxContainer.

## [0.2.0-alpha] - 2026-08-25

### Added
- **SettingsManager autoload** — New `ConfigFile`-based settings system that persists to `res://settings.cfg` (dev) or `user://settings.cfg` (export). Manages three setting sections: layout, display, and audio. Emits `settings_changed` signal for live updates.
- **MainLayout script** — New `main_layout.gd` drives all UI proportions from SettingsManager config ratios. Calculates `HSplitContainer.split_offset` from `viewport_ratio` / `party_panel_ratio` at startup and on window resize. Sets `size_flags_stretch_ratio` and minimum floors dynamically.
- **Config file (`settings.cfg`)** — User-editable config with layout ratios (`viewport_ratio`, `party_panel_ratio`, `action_bar_ratio`), minimum sizes, display options (fullscreen, vsync, MSAA, resolution scale), and audio volumes (master, music, SFX).
- **CHANGELOG.md** — This file.

### Changed
- Layout proportions are now config-driven instead of hardcoded. The HSplitContainer split offset, stretch ratios for ViewportFrame/BottomBar, and minimum sizes for all panels are read from `settings.cfg`.
- `project.godot` version updated from `0.1.0-alpha` to `0.2.0-alpha`.
- `VERSION` file updated to `0.2.0-alpha`.
- `main.tscn` now uses `main_layout.gd` script. Removed hardcoded `split_offset`, `size_flags_stretch_ratio`, and `custom_minimum_size` from layout nodes.
- `viewport_frame.gd` simplified to just enable `stretch`; sizing is now handled by `main_layout.gd`.

## [0.1.0-alpha] - 2026-08-25

### Added
- **Project scaffolding** — Godot 4.4+ project with `.gitignore`, `project.godot`, folder structure, `VERSION` file, `icon.svg`, and updated `README.md`.
- **Core scripts** — `GameManager` autoload (game state, party of 4 default characters), `TurnManager` (input-to-action dispatch), `Action` base class, `MovementAction`, `TurnAction`.
- **Data layer** — `DataRegistry` autoload for loading and caching JSON data packs from `res://packs/base/records/`.
- **UI system** — `PartyDisplay` (4 member slots with HP bars), `ActionBar` (6 movement buttons), `ViewportFrame` (SubViewportContainer wrapping the 3D world).
- **3D grid world** — `GridWorld` script with 8x8 test dungeon, grid-snapped first-person camera, collision detection. `WallTile` (brown BoxMesh) and `FloorTile` (green PlaneMesh) scenes.
- **JSON data packs** — `pack.json` metadata, weapons, consumables, enemies, classes, spells, and dungeon definitions under `packs/base/records/`.
- **Scene hierarchy** — `main.tscn` (HSplitContainer layout), `viewport_frame.tscn` (SubViewportContainer), `party_display.tscn`, `action_bar.tscn`, `grid_world.tscn`, `wall_tile.tscn`, `floor_tile.tscn`.
- **Input mapping** — WASD + QE for movement/turning/strafing, plus arrow key alternatives.
- **Turn-based movement** — Grid-locked movement where enemies/NPCs only move when the player moves.

### Fixed
- `$` path references in `viewport_frame.gd`.
- World node moved inside SubViewport for proper 3D rendering context.
- Switched from `TextureRect` to `SubViewportContainer` for correct viewport display.
- Fixed `Array[Dictionary]` typing issues in `GameManager`.
- Fixed `_build_grid_mesh()` destroying WorldEnvironment and DirectionalLight3D during cleanup by using a `CELLS_TO_KEEP` exclusion list (later replaced with tracked `_dynamic_children` array).
- Resolved `SubViewportContainer` getting zero height by correcting `size_flags_vertical` from `12` (EXPAND|SHRINK_BEGIN) to `5` (EXPAND|FILL).
- Added explicit `SubViewport` size to prevent 0x0 viewport rendering.
- Corrected `load_steps` in `grid_world.tscn` from 2 to 6 to ensure all sub_resources load properly.
- Brightened environment lighting — changed `ambient_light_source` from sky-sampled (near-black) to flat color mode, disabled fog, increased light energies, moved OmniLight3D under Camera3D to follow the player.
- Fixed reversed forward/backward movement by rotating movement directions based on player facing in `GridWorld._rotate_for_facing()`.
- Replaced fragile name-string-based child cleanup in `_build_grid_mesh()` with a tracked `_dynamic_children` array.

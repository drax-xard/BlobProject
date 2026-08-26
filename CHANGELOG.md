# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.3.0-alpha] - 2026-08-25

### Added
- **Combat system** — Full turn-based combat with enemy AI, initiative order, and XP/gold rewards
- **CombatManager** (`scripts/core/combat_manager.gd`) — Central combat coordinator:
  - Agility-based turn order for party and enemies
  - Physical damage formula: `strength × weapon_mult − defense × armor_mult ± 2`, minimum 1
  - Critical hits: `agility × 0.5%` chance, 1.5× damage
  - Defending halves incoming damage for one round
  - Spell casting with MP cost validation and school-based effects (destruction/holy = damage, restoration = healing)
  - Item usage from inventory during combat
  - Flee mechanic: success chance based on party vs enemy agility
  - Enemy AI: targets party member with lowest HP
  - Level-up on XP gain with stat growth from class data
  - Victory: distribute XP, gold, and random loot from enemy loot tables
- **Combat actions** — Attack, Defend, Magic, Item, Flee with precondition validation
- **Encounter trigger** — Random encounters on movement using dungeon floor's `encounter_rate` and weighted `encounter_tables` (easy/medium/hard tiers by floor)
- **Combat UI** (`scenes/ui/combat_ui.tscn`, `scripts/ui/combat_ui.gd`) — Full-screen overlay with:
  - Enemy list with live HP bars
  - Scrolling combat log
  - Per-character command selection (Attack, Magic, Defend, Item, Flee)
  - Target selection for attacks, spells, and items
  - Spell selection when character knows multiple spells
  - MP cost validation before casting
  - Victory/defeat screen with XP/gold summary

### Changed
- GridWorld `try_move()` now checks for random encounters after each successful movement
- `encounter_ended` signal no longer auto-transitions game state — CombatUI handles state transition on "Continue" click

## [0.2.4-alpha] - 2026-08-25

### Added
- **Inventory system** — Full item management with add/remove/has/get methods
- **Equipment system** — Equip/unequip items to character slots with stat requirement validation
- **Inventory UI** (`scenes/ui/inventory_panel.tscn`) — Full-screen overlay with:
  - Party member selector (keys 1-4)
  - Character stats display (HP, MP, all combat stats, spells)
  - Equipment slots display (6 slots per character)
  - Scrollable item list with quantities
  - Equip/Use/Drop actions (keyboard: Enter/U/D or click)
  - Item info panel showing description and value
  - Gold display
- **Consumable usage** — Health potions and mana potions work from inventory
- Signal: `GameManager.inventory_changed()` emitted on any inventory modification

## [0.2.3-alpha] - 2026-08-25

### Fixed
- **GridWorld startup timing** — Dungeon load now waits for DataRegistry to finish loading via `party_changed` signal, preventing fallback to default grid on first load
- **Data validation crashes** — Safe field access with `get()` and type checks throughout, preventing crashes on malformed JSON

### Added
- **DebugLog** (`scripts/core/debug_log.gd`) — File-based debug logging to `user://logs/debug.log` with info/warn/error/data_issue levels
- Data shape validation for all record types (classes, equipment, consumables, spells, enemies, dungeons)
- Missing required fields logged with record ID, field name, expected type, and actual value
- Startup and data load progress logged to debug.log
- Party initialization logs character stats on creation
- GridWorld logs dungeon dimensions on successful load

## [0.2.2-alpha] - 2026-08-25

### Changed
- **Party stats derived from class data** — Character HP, MP, and all combat stats are now loaded from class JSON records instead of being hardcoded
- **Dungeon grid loaded from data** — GridWorld reads dimensions from dungeon JSON records, replacing hardcoded 8x8 test grid
- **Startup sequencing fixed** — DataRegistry loads all JSON data before GameManager initializes, ensuring data is available at game start

### Added
- `GameManager.current_dungeon_id` and `current_floor` track dungeon progression
- `GridWorld.load_dungeon(dungeon_id, floor)` public method for loading dungeon floors
- `GridWorld._generate_border_grid()` extracted for reusable grid generation
- Input bindings: `open_inventory` (I), `pause_game` (Escape)
- Pause and inventory state toggles in TurnManager

## [0.2.1-alpha] - 2026-08-25

### Added
- **Development plan** (`docs/DEVELOPMENT_PLAN.md`) — Comprehensive implementation roadmap covering 7 phases, 25 tasks, with file paths, acceptance criteria, and dependency graph for AI agent compatibility
- **Project documentation** (`docs/`) — 13 Markdown files covering all game systems:
  - `docs/README.md` — Project index and overview
  - `docs/architecture.md` — System architecture, autoloads, data flow, signal architecture
  - `docs/data-formats.md` — Complete JSON record schemas for all 6 content types
  - `docs/mod-pack-system.md` — Pack structure, loading, dependencies, override system
  - `docs/settings.md` — SettingsManager API, config format, default values
  - `docs/systems/turn-and-action.md` — Turn loop, action pattern, input mapping
  - `docs/systems/grid-world.md` — 3D grid, coordinate system, camera, movement
  - `docs/systems/party-and-characters.md` — Character stats, equipment, level-up design
  - `docs/systems/combat.md` — Turn-based combat system design (planned)
  - `docs/systems/inventory.md` — Inventory and equipment design (planned)
  - `docs/systems/dialogue.md` — NPC dialogue system design (planned)
  - `docs/systems/save-load.md` — Game persistence design (planned)
  - `docs/systems/procedural-dungeons.md` — Dungeon generation design (planned)

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

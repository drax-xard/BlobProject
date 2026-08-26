# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.6.1-alpha] - 2026-08-26

### Fixed
- **Save position preserved** — Player position now correctly restored after loading a save
- **Double dungeon load eliminated** — load_dungeon only called once via game_loaded signal
- **Slot info shows party level** — Save slot display shows "Lv.X" from party data instead of floor number
- **Input conflict resolved** — SaveLoadMenu uses game_state_changed signal instead of competing with TurnManager for Escape key
- **Escape navigation** — From save/load sub-menus, Escape returns to pause menu; from pause menu, Escape resumes
- **Pause menu buttons visible** — Fixed _slot_list being hidden before buttons were added
- **Delete button added** — "X" button per non-empty save slot with confirmation
- **Load menu accessible** — Save/Load now available from pause menu
- **clear_pack key matching** — Fixed broken cache key matching in ResLoader
- **Type compatibility** — party/inventory changed to untyped Array for JSON load compatibility; explicit Dictionary type used in party_display
- **Detailed save/load logging** — Full save data contents logged to debug.log for verification

## [0.6.0-alpha] - 2026-08-26

### Added
- **SaveManager** (`scripts/core/save_manager.gd`) — Autoload for persistent game state
  - `save_game(slot)` / `load_game(slot)` / `delete_save(slot)`
  - `get_save_info(slot)` / `has_save(slot)` / `get_all_save_slots()`
  - Saves party, inventory, gold, dungeon_id, floor, turn_count, player position/facing
  - JSON format at `user://saves/save_<slot>.json` with version and timestamp
  - 5 save slots
- **SaveLoadMenu** (`scripts/ui/save_load_menu.gd` + `.tscn`) — Overlay save/load UI
  - 5 slots showing party names, floor, gold, timestamp
  - Save mode with overwrite confirmation
  - Load mode with confirmation
  - Escape key opens save menu during exploration
- `GameManager.game_loaded` signal emitted after loading a save
- GridWorld reloads dungeon on `game_loaded` signal

### Changed
- Phase 5 marked complete in development plan

## [0.5.0-alpha] - 2026-08-26

### Added
- **ResourceLoader** (`scripts/core/resource_loader.gd`) — Static class for loading and caching game resources from mod packs
  - `load_texture()`, `load_audio()`, `load_scene()` with per-pack resolution
  - `get_or_load()` for cached generic access
  - Placeholder generation for missing resources (colored "MISSING" rectangles for textures, silent AudioStream for audio)
  - Pack manifest loading and asset list queries via `get_asset_list()` and `has_asset()`
  - Cache management: `clear_cache()`, `clear_pack()`
- **Pack assets structure** — `packs/base/assets/{textures,audio,scenes}/` directories created
- **Pack asset declarations** — `pack.json` extended with full asset list (18 textures, 12 audio, scenes)
- **Stair/chest textures** — GridWorld special tile markers now load textures from pack via ResLoader, falling back to colored boxes
- **Party portraits** — PartyDisplay loads class-specific portrait textures via ResLoader, falling back to colored rectangles

### Changed
- **Phase 5 expanded** — Development plan Phase 5 now includes resource loader (Tasks 5.1-5.3) alongside save/load (Tasks 5.4-5.5)

## [0.4.1-alpha] - 2026-08-26

### Fixed
- **Armor damage reduction** — Physical damage now correctly reads the defender's body armor instead of the attacker's
- **Heal-item crash** — Added bounds check on target index before using heal consumables in combat
- **Level-up infinite loop** — `_check_level_up` now guards against `xp_to_next` reaching 0 or stalling at 1
- **Flee logging** — Successful flee no longer logs "Defeat..."; added `fled` parameter to `_end_encounter`
- **Actions after flee** — Turn resolution loop now checks `encounter_active` to stop after a successful flee
- **Spell damage calc** — Uses `.get()` with fallback for the `energy` stat instead of raw dict access
- **Combat UI button overlap** — Command panel hidden during target/spell/item sub-selections to prevent conflicting clicks
- **Combat UI stale state** — `_pending_action_type` and `_pending_action_params` cleared when Continue is pressed
- **Dungeon generator infinite loop** — Room connection uses `INF` instead of a fixed cap for distance comparison
- **Dungeon fallback positions** — Stairs positions use grid center instead of (1,1) which could be a wall
- **Grid bounds checks** — `check_tile_interaction` and `_open_chest` now validate player position before grid access
- **GameLog null crash** — Added null checks for `current_scene` and `is_inside_tree()` before accessing CombatManager
- **Dead code removed** — `_find_stairs_down_pos` and `_selecting_target` removed

### Added
- **Game log** (`scenes/ui/game_log.tscn`, `scripts/ui/game_log.gd`) — Scrollable event log below the party display showing combat messages, dungeon events, chest finds, and party status changes
- `GameManager.game_event(text, color)` signal for any system to emit log messages

## [0.4.0-alpha] - 2026-08-26

### Added
- **BSP dungeon generator** (`scripts/world/dungeon_generator.gd`) — Binary Space Partitioning algorithm that generates connected rooms and corridors from width/height/seed
  - Recursive splitting with configurable min room size
  - Random room placement within BSP leaf nodes
  - L-shaped corridor connections between sibling rooms (nearest-first linking)
  - Deterministic generation via seed (same seed = same layout)
- **Special tile system** — Extended cell values: 0=floor, 1=wall, 2=door, 3=stairs_up, 4=stairs_down, 7=chest
  - Stairs up placed in first room, stairs down in last room
  - 0-2 chests placed in random middle rooms
  - Visual markers: green for stairs, gold for chests
- **Floor transitions** — Walking onto stairs_down loads the next floor, stairs_up loads the previous floor
  - Player position resets to stairs_up on the new floor
  - GameManager.current_floor tracked across transitions
- **Chest interaction** — Opening a chest removes it from the grid and awards a health potion + random gold
- `GridWorld.is_walkable()` now uses `DungeonGenerator.CELL_WALL` constant instead of hardcoded `0`

### Changed
- GridWorld now uses `DungeonGenerator` instead of hardcoded border grid when a dungeon is loaded
- Dungeon dimensions from JSON records now drive actual BSP generation (10x10, 12x12, 14x14)

## [0.3.1-alpha] - 2026-08-26

### Fixed
- **MP lost on invalid spell target** — MP is now deducted only after target validation, preventing wasted MP on dead or out-of-range targets
- **Defending flag never cleared** — `clear_defending()` is now called at the start of each combat round so damage reduction doesn't persist permanently
- **Combat log scroll race** — Replaced `await` with `call_deferred` to prevent scroll position jumping when multiple log entries are emitted in the same frame
- Removed unused `current_turn_idx` variable from CombatManager

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

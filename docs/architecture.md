# System Architecture

This document covers the core architecture of BlobProject: autoload singletons, the scene tree, data flow, the action pattern, and the signal graph.

---

## Autoloads

Three singletons are registered in `project.godot` and loaded in order at startup. Because Godot loads autoloads sequentially, each can rely on the ones above it being ready.

### 1. SettingsManager (`scripts/core/settings_manager.gd`)

**Loaded first.** Reads `settings.cfg` from disk, applies display and audio settings, and exposes a typed getter/setter API for every setting.

| Section | Keys | Defaults |
|---------|------|----------|
| `layout` | `viewport_ratio`, `party_panel_ratio`, `action_bar_ratio`, `viewport_min_height`, `action_bar_min_height`, `party_panel_min_width` | 2.0, 1.0, 1.0, 200, 40, 200 |
| `display` | `fullscreen`, `vsync`, `msaa`, `resolution_scale` | false, true, 0, 1.0 |
| `audio` | `master_volume`, `music_volume`, `sfx_volume` | 80, 70, 80 |

**Key API:**

```gdscript
SettingsManager.get_layout(key: String) -> Variant
SettingsManager.set_layout(key: String, value: Variant)  # saves + emits
SettingsManager.get_display(key: String) -> Variant
SettingsManager.set_display(key: String, value: Variant)  # saves + applies + emits
SettingsManager.get_audio(key: String) -> Variant
SettingsManager.set_audio(key: String, value: Variant)    # saves + applies + emits
```

Sets emit `settings_changed(section: String)` after persisting. In dev builds the config file lives at `res://settings.cfg`; in exports it moves to `user://settings.cfg`.

### 2. GameManager (`scripts/core/game_manager.gd`)

**Loaded second.** Owns the global game state machine and the party data. All other systems query GameManager to decide what input is allowed.

**State machine:**

```gdscript
enum GameState {
    MENU,
    EXPLORING,
    COMBAT,
    DIALOGUE,
    INVENTORY,
    PAUSED,
}
```

`current_state` gates every input path. Only `EXPLORING` accepts movement input; `COMBAT` will accept combat actions once implemented, and so on.

**Party storage:**

```gdscript
var party: Array[Dictionary] = []   # up to 4 characters
```

Each dictionary holds: `id`, `name`, `class_id`, `level`, `hp`, `max_hp`, `mp`, `max_mp`, `strength`, `defense`, `vitality`, `energy`, `agility`, `luck`, `xp`, `xp_to_next`, `equipment` (slot-keyed dict), `spells` (Array[String]), `skills` (Array[String]).

On `_ready()` GameManager connects to `DataRegistry.all_data_loaded` signal. Once data is ready, `start_new_game()` is called, which populates a default party of four characters (Roland, Elara, Aldric, Shade) with stats derived from class JSON records, sets `current_dungeon_id = "dungeon_01"`, and transitions to `EXPLORING` state. GridWorld waits for `party_changed` before loading the dungeon, ensuring data is available.

**Key API:**

```gdscript
GameManager.start_new_game() -> void
GameManager.get_party_member(index: int) -> Dictionary
GameManager.heal_party_member(index: int, amount: int) -> void
GameManager.damage_party_member(index: int, amount: int) -> void
GameManager.is_party_alive() -> bool
GameManager.get_version() -> String
```

### 3. DataRegistry (`scripts/data/data_registry.gd`)

**Loaded third.** Loads all JSON data from the active pack into a flat dictionary indexed by record ID. Provides query methods for game systems.

**Internal state:**

```gdscript
var _cache: Dictionary = {}                         # id -> record dict
var _base_pack_path: String = "res://packs/base/records"
```

`load_all_data()` iterates over the five categories (`items`, `enemies`, `classes`, `dungeons`, `spells`), reads every `.json` file in the corresponding subdirectory, and inserts each record that has an `"id"` field into `_cache`.

**Key API:**

```gdscript
DataRegistry.get_record(record_id: String) -> Dictionary
DataRegistry.get_records_by_category(category: String) -> Array[Dictionary]
DataRegistry.has_record(record_id: String) -> bool
DataRegistry.get_all_ids() -> Array[String]
```

Records without an `"id"` field are silently skipped. Duplicate IDs overwrite the earlier entry.

### 4. DebugLog (`scripts/core/debug_log.gd`)

**Not an autoload — a static utility class.** Writes structured log entries to `user://logs/debug.log` for post-session debugging. Also prints to Godot console.

```gdscript
DebugLog.info("message")       # [INFO]
DebugLog.warn("message")       # [WARN] + push_warning
DebugLog.error("message")      # [ERROR] + push_error
DebugLog.data_issue(record_id, field, expected, got)  # [DATA] — for validation failures
```

Creates the log directory and file on first write. Each entry is timestamped per-session.

---

## Scene Tree

```
Main (Control)                              [main_layout.gd]
├── TurnManager (Node)                      [turn_manager.gd]
├── HSplitContainer
│   ├── LeftPanel (VBoxContainer)
│   │   ├── ViewportFrame (SubViewportContainer)  [viewport_frame.gd]
│   │   │   └── SubViewport (own_world_3d)
│   │   │       └── World (Node3D)          [grid_world.gd]
│   │   │           ├── Camera3D
│   │   │           └── (dynamic wall/floor tiles)
│   │   └── BottomBar (HBoxContainer)
│   │       └── ActionBar                   [action_bar.gd]
│   └── RightPanel (PanelContainer)
│       └── PartyDisplay                    [party_display.gd]
└── VersionLabel (Label)
```

**Key points:**

- `Main` is a full-screen `Control` that manages layout ratios via SettingsManager.
- The 3D world lives inside a `SubViewport` with its own world, keeping it isolated from the 2D UI.
- `TurnManager` is a plain `Node` child of Main. It is **not** inside the SubViewport.
- `ActionBar` constructs six movement buttons at runtime and forwards actions to `TurnManager.process_ui_action()`.
- `PartyDisplay` builds four character panels at runtime, each with a name label, HP bar, and HP text. It listens to `GameManager.party_changed`.

---

## Data Flow

### JSON on disk to in-memory cache

```
packs/base/records/**/*.json
        │
        ▼
DataRegistry.load_all_data()
        │
        ▼
DataRegistry._cache: { "sword_iron": {...}, "goblin": {...}, ... }
        │
        ▼
Game systems call DataRegistry.get_record("sword_iron")
```

### Player input to world mutation

```
InputEventKey
        │
        ▼
TurnManager._input()          ← only runs in EXPLORING state
        │
        ▼
TurnManager._resolve_input()  ← maps key to Action subclass
        │
        ▼
TurnManager._process_player_action(action)
        │
        ├── action.execute(world)   ← e.g. MovementAction calls GridWorld.try_move()
        ├── action_performed.emit(action)
        ├── GameManager.turn_count += 1
        └── _turn_ended()           ← turn_processed.emit()
```

### Settings propagation

```
SettingsManager.set_display("fullscreen", true)
        │
        ├── apply_display()        ← immediately changes window mode
        ├── save_settings()        ← persists to settings.cfg
        └── settings_changed.emit("display")
                │
                ▼
        MainLayout._on_settings_changed("layout")  ← recalculates split ratios
```

---

## Action Pattern

Actions are the core abstraction for anything that advances the game by one turn. They are **RefCounted** objects, not Nodes, so they are lightweight and composable.

### Base class

```gdscript
# scripts/core/action.gd
class_name Action
extends RefCounted

var actor_index: int

func _init(p_actor_index: int = -1) -> void:
    actor_index = p_actor_index

func execute(_world: Node) -> bool:
    return false

func get_action_name() -> String:
    return "action"
```

### Concrete subclasses

| Class | Fields | Delegates to |
|-------|--------|--------------|
| `MovementAction` | `direction: Vector2i` | `GridWorld.try_move(actor_index, direction)` |
| `TurnAction` | `turn_direction: int` (LEFT=-1, RIGHT=1) | `GridWorld.try_turn(actor_index, turn_direction)` |

**Usage in TurnManager:**

```gdscript
func _resolve_input(event: InputEventKey) -> Action:
    if event.is_action_pressed("move_forward"):
        return MovementAction.new(0, Vector2i.UP)
    elif event.is_action_pressed("turn_left"):
        return TurnAction.new(0, TurnAction.LEFT)
    # ...
    return null
```

**Future actions** will follow the same pattern: `AttackAction`, `SpellAction`, `UseItemAction`, `InteractAction`, etc. Each subclasses `Action`, stores its parameters, and implements `execute(world)`.

---

## Input Mapping

Defined in `project.godot` under `[input]`:

| Action | Keys |
|--------|------|
| `move_forward` | W, Up Arrow |
| `move_backward` | S, Down Arrow |
| `turn_left` | Q, Left Arrow |
| `turn_right` | E, Right Arrow |
| `strafe_left` | A |
| `strafe_right` | D |

TurnManager only processes input when `GameManager.current_state == EXPLORING` and `is_turn_active == false`. After an action executes, `is_turn_active` is set to `true` and cleared at the end of the turn, preventing input during transitions.

---

## Signal Architecture

### GameManager

| Signal | Emitted when |
|--------|-------------|
| `party_changed()` | Any party member's stats change, or a new game starts |
| `_turn_started(turn_number: int)` | Reserved for future use |
| `_turn_ended(turn_number: int)` | Reserved for future use |

### TurnManager

| Signal | Emitted when |
|--------|-------------|
| `action_performed(action: Action)` | After any action executes successfully |
| `turn_processed(turn_number: int)` | At the end of every turn, after the counter increments |

### GridWorld

| Signal | Emitted when |
|--------|-------------|
| `player_moved(new_position: Vector2i)` | Player successfully moves to a new cell |
| `player_turned(new_facing: int)` | Player rotates to a new facing |

### SettingsManager

| Signal | Emitted when |
|--------|-------------|
| `settings_changed(section: String)` | After any setter saves and applies a change (section is `"layout"`, `"display"`, or `"audio"`) |

### DataRegistry

| Signal | Emitted when |
|--------|-------------|
| `data_loaded(category: String)` | After one category directory finishes loading |
| `all_data_loaded()` | After all categories are loaded |

---

## Grid World (`scripts/world/grid_world.gd`)

The world is a flat 2D integer grid rendered as 3D tiles:

```gdscript
const CELL_SIZE: float = 2.0
enum Facing { NORTH, EAST, SOUTH, WEST }

var grid_data: Array[Array] = []    # 0 = floor, 1 = wall
var player_grid_pos: Vector2i
var player_facing: int = Facing.NORTH
```

Movement is facing-relative: `Vector2i.UP` always means "forward relative to current facing." The `_rotate_for_facing()` helper translates logical directions into grid-space offsets.

The camera sits at `(player_x * CELL_SIZE, CELL_SIZE * 0.8, player_y * CELL_SIZE)` and rotates 90 degrees per facing. Wall and floor tiles are loaded from packed scenes (`wall_tile.tscn`, `floor_tile.tscn`) and placed as children of the World node.

---

## File Layout

```
BlobProject/
├── addons/                    # Third-party plugins
├── docs/                      # This documentation
├── packs/
│   └── base/
│       ├── pack.json          # Pack manifest
│       └── records/
│           ├── classes/       # Character class definitions
│           ├── dungeons/      # Dungeon layouts and encounter tables
│           ├── enemies/       # Enemy stat blocks
│           ├── items/         # Weapons, armor, consumables
│           └── spells/        # Spell definitions
├── scenes/
│   ├── main.tscn              # Root scene
│   ├── ui/                    # UI sub-scenes
│   └── world/                 # 3D tile scenes
├── scripts/
│   ├── core/                  # Autoloads + action pattern
│   ├── data/                  # DataRegistry
│   ├── ui/                    # UI controllers
│   └── world/                 # GridWorld + tile scripts
├── settings.cfg               # Runtime config (dev path)
├── project.godot              # Engine config + autoloads
└── VERSION                    # Current version string
```

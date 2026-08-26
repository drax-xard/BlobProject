# Development Plan

> **Audience:** AI coding agents and human developers.
> Each task includes: what to build, which files to modify/create, acceptance criteria, and technical notes.
> Tasks within a phase are ordered by dependency. Complete them top-to-bottom.

---

## Current State (v0.3.0-alpha)

The project is a working Godot 4.4+ prototype with:
- 3D first-person viewport with camera, lighting, and grid rendering
- Turn-based movement (forward, backward, strafe, turn) via keyboard and UI buttons
- 4-character party display with stats derived from class data
- Configurable layout ratios via `settings.cfg`
- JSON data loading system (`DataRegistry`) with classes, items, spells, enemies, dungeons
- Full inventory and equipment system with UI overlay
- Turn-based combat with enemy AI, spell casting, items, and flee
- Random encounters with weighted encounter tables
- Autoloads: `SettingsManager`, `GameManager`, `DataRegistry`

**What does NOT work yet:**
- No procedural dungeon generation (uses hardcoded border grid)
- No save/load
- No NPC interaction or dialogue
- No shop/merchant system

---

## Phase 1: Data Integration (Bridge existing systems) ✅ COMPLETE

> **Goal:** Make the existing JSON data actually drive the game.
> **Depends on:** Nothing (start here).
> **Status:** Completed in v0.2.2-alpha.

### Task 1.1: Load dungeon data into GridWorld ✅

**Files modified:** `scripts/world/grid_world.gd`

**What to do:**
- Remove the hardcoded `_build_test_dungeon()` method
- Add `load_dungeon(dungeon_id: String, floor: int) -> void` public method
- Look up the dungeon record via `DataRegistry.get_record(dungeon_id)`
- Read `floor_data[floor - 1]` for width/height
- Generate a simple rectangular room grid (placeholder until Phase 4 procedural generation)
- Store `current_dungeon_id` and `current_floor` in `GameManager`
- On `_ready()`, call `load_dungeon("dungeon_01", 1)` instead of building test grid

**Acceptance criteria:**
- Game loads and displays the grid from `dungeon_01.json` floor 1 data
- Grid dimensions match `floor_data[0].width` and `floor_data[0].height`
- Player can move within the generated grid
- No hardcoded grid values remain

**Technical notes:**
- GridWorld's `_build_dynamic_children()` calls `_build_grid_mesh()` after setting `grid_data`
- The dungeon JSON floor_data has: `floor`, `width`, `height`, `encounter_rate`, `enemy_pool`, `music`
- For now, generate a bordered rectangle: walls on perimeter, floor inside

### Task 1.2: Load default party from class data ✅

**Files modified:** `scripts/core/game_manager.gd`

**What to do:**
- Replace `_init_default_party()` to look up class records from `DataRegistry`
- For each default party member, load the class record and derive `max_hp`, `max_mp`, starting stats from `base_stats`
- Store `class_id` reference in each character dictionary
- Add starting equipment assignments (e.g., Roland → sword_iron, shield_wood)

**Acceptance criteria:**
- Party members have stats derived from their class JSON records
- Each character has `class_id`, `equipment`, `spells` fields
- `max_hp` and `max_mp` are set from base_stats
- Game runs without errors

**Technical notes:**
- Class records are in `packs/base/records/classes/classes.json`
- Each class has `base_stats` with hp, mp, strength, defense, vitality, energy, agility, luck
- Character dictionaries currently have: id, name, level, hp, max_hp, mp, max_mp, strength, defense, vitality, energy, agility, luck
- Add fields: `class_id`, `xp`, `xp_to_next`, `equipment`, `spells`, `skills`

### Task 1.3: Wire up DataRegistry loading at startup ✅

**Files modified:** `scripts/core/game_manager.gd`, `scripts/data/data_registry.gd`

**What to do:**
- Ensure `DataRegistry.load_all_data()` is called before `GameManager.start_new_game()`
- Verify all 5 categories load without errors (items, enemies, classes, dungeons, spells)
- Add a startup sequence: SettingsManager → DataRegistry.load_all_data() → GameManager.start_new_game()

**Acceptance criteria:**
- All JSON records are accessible via `DataRegistry.get_record()` at game start
- No loading errors in the output console
- `DataRegistry.get_all_ids()` returns all IDs from all JSON files

**Technical notes:**
- `DataRegistry._base_pack_path` points to `res://packs/base/records/`
- Categories are hardcoded: `["items", "enemies", "classes", "dungeons", "spells"]`
- The `_cache` dictionary is flat — all record IDs are globally unique

---

## Phase 2: Inventory & Equipment ✅ COMPLETE

> **Goal:** Players can manage items, equip gear, see stats change.
> **Depends on:** Phase 1 (party loaded from data with equipment slots).
> **Status:** Completed in v0.2.4-alpha.

### Task 2.1: Add inventory data to GameManager ✅

**Files modified:** `scripts/core/game_manager.gd`

**What to do:**
- Add `inventory: Array[Dictionary]` — each entry: `{ "id": String, "quantity": int }`
- Add `gold: int = 0`
- Add public methods:
  - `add_item(item_id: String, qty: int = 1) -> void`
  - `remove_item(item_id: String, qty: int = 1) -> bool`
  - `has_item(item_id: String) -> bool`
  - `get_item_quantity(item_id: String) -> int`
  - `get_inventory() -> Array[Dictionary]`
  - `equip_item(character_index: int, item_id: String) -> bool`
  - `unequip_item(character_index: int, slot: String) -> bool`
- `equip_item` validates slot compatibility and stat requirements, swaps items
- Emit `inventory_changed` signal on any modification

**Acceptance criteria:**
- Items can be added/removed from inventory programmatically
- Equipment can be equipped/unequipped with slot validation
- Signal fires on changes
- Unit-testable via GDScript (manually verify in console)

### Task 2.2: Create inventory UI ✅

**Files created:** `scenes/ui/inventory_panel.tscn`, `scripts/ui/inventory_panel.gd`
**Files modified:** `scenes/main.tscn`

**What to do:**
- Create a panel that shows/hides when GameManager.state == INVENTORY
- Display party members on left, selected member's equipment on right
- Show inventory list below with item names, quantities
- Context actions: Equip, Use, Drop (keyboard-driven initially)
- Use signals from GameManager to refresh display

**Acceptance criteria:**
- Pressing I (or future inventory key) opens inventory overlay
- Shows all items in party inventory with quantities
- Shows equipped items per character
- Equip/unequip updates both the data and display
- Closing returns to previous state

**Technical notes:**
- Use a Control node overlay on top of the viewport
- Keep it simple: list-based UI, no icons yet
- GameState.INVENTORY already exists — use it to gate input

---

## Phase 3: Combat System ✅ COMPLETE

> **Goal:** Random encounters trigger turn-based combat.
> **Depends on:** Phase 1 (dungeon data, enemy records), Phase 2 (inventory for loot/items in combat).

### Task 3.1: Create combat manager

**Files to create:** `scripts/core/combat_manager.gd`

**What to do:**
- Create a new Node script (add as child of Main or TurnManager)
- Properties:
  - `encounter_active: bool = false`
  - `enemies: Array[Dictionary] = []` — active enemy instances
  - `turn_order: Array` — combined party + enemy initiative order
  - `current_actor_index: int` — whose turn it is
  - `combat_log: Array[String]` — battle log entries
- Methods:
  - `start_encounter(enemy_ids: Array[String]) -> void` — initialize combat
  - `resolve_player_action(action: Action) -> void` — process a player command
  - `resolve_enemy_turns() -> void` — AI for all enemies
  - `check_combat_end() -> String` — returns "ongoing", "victory", or "defeat"
  - `end_encounter() -> void` — distribute XP/gold/loot, return to EXPLORING
- Signals: `encounter_started`, `turn_resolved`, `encounter_ended(victory: bool)`

**Acceptance criteria:**
- Combat can be started programmatically with enemy IDs
- Turns resolve in agility-based order
- Combat ends when all enemies or all party members are dead
- XP and gold are distributed on victory

### Task 3.2: Create combat actions

**Files to create:** `scripts/core/combat_action.gd` (or multiple files)

**What to do:**
- Create `AttackAction` extending Action:
  - `target_index: int` — which enemy to attack
  - `execute()` calculates damage using strength, weapon, defense
- Create `DefendAction` extending Action:
  - Sets a "defending" flag that halves incoming damage this round
- Create `MagicAction` extending Action:
  - `spell_id: String`, `target_index: int`
  - Validates MP cost, applies spell effects
- Create `UseItemAction` extending Action:
  - `item_id: String`, `target_index: int`
  - Uses consumable from inventory
- Create `FleeAction` extending Action:
  - Escape chance based on party agility vs enemy agility

**Acceptance criteria:**
- Each action validates preconditions (MP, items, alive targets)
- Damage formula: `strength * weapon_mult - defense * armor_mult + random(-2, 2)`
- Minimum 1 damage always
- Critical hit: agility * 0.5% chance, 1.5x damage

### Task 3.3: Encounter trigger system

**Files to modify:** `scripts/world/grid_world.gd`, `scripts/core/game_manager.gd`

**What to do:**
- After each successful move in `try_move()`, roll against `encounter_rate`
- Use dungeon floor data's `encounter_rate` (e.g., 0.15)
- If triggered: select enemy from floor's `encounter_tables` using weighted random
- Call `combat_manager.start_encounter(selected_enemies)`
- Set `GameManager.current_state = GameState.COMBAT`

**Acceptance criteria:**
- Moving in a dungeon occasionally triggers combat
- Encounter rate matches dungeon floor data
- Enemy selection uses the weighted encounter tables
- State transitions correctly to COMBAT

**Technical notes:**
- `dungeon_01.json` floor_data[0] has encounter_rate: 0.15, enemy_pool: ["goblin", "slime"]
- Encounter tables have easy/medium/hard tiers with weighted entries
- Tier selection: floor 1 = easy, floor 2 = medium, floor 3 = hard (or based on party level)

### Task 3.4: Combat UI

**Files to create:** `scenes/ui/combat_ui.tscn`, `scripts/ui/combat_ui.gd`

**What to do:**
- Overlay UI shown when state == COMBAT
- Layout:
  - Top: enemy list with HP bars
  - Middle: combat log (scrolling text)
  - Bottom: party member command selection (for each character in order)
- Command menu per character: Attack, Magic, Defend, Item, Flee
- Attack/Magic/Item: show target selection (enemy list)
- Process commands sequentially through turn order

**Acceptance criteria:**
- Enemy HP visible and updating in real-time
- Combat log shows all actions
- Player can select commands for each party member
- Enemy turns resolve automatically after all party commands
- Victory/defeat screen with XP/gold summary

---

## Phase 4: Procedural Dungeon Generation

> **Goal:** Replace hardcoded grid with BSP-generated dungeons.
> **Depends on:** Phase 1 (dungeon data loading).

### Task 4.1: BSP dungeon generator

**Files to create:** `scripts/world/dungeon_generator.gd`

**What to do:**
- Create a static class or Node with `generate(width: int, height: int, seed: int) -> Array[Array]`
- Implement BSP algorithm:
  1. Start with full rectangle
  2. Recursively split (4-6 times)
  3. Place rooms in leaf nodes (random size within bounds)
  4. Connect sibling rooms with L-shaped corridors
  5. Place stairs in first and last rooms
- Return 2D grid array compatible with GridWorld's `grid_data`

**Acceptance criteria:**
- Generated grid has connected rooms and corridors
- All rooms are reachable from any other room
- Grid dimensions match input width/height
- Same seed produces same layout
- No isolated floor sections

**Technical notes:**
- Cell values: 0 = floor, 1 = wall (current system)
- CELL_SIZE = 2.0 in grid_world.gd
- Grid coordinates: `grid_data[y][x]`
- Room placement must respect grid bounds

### Task 4.2: Place special tiles

**Files to modify:** `scripts/world/dungeon_generator.gd`, `scripts/world/grid_world.gd`

**What to do:**
- Extend cell value system: 0=floor, 1=wall, 2=door, 3=stairs_up, 4=stairs_down, 7=chest
- Place stairs_down in last generated room
- Place stairs_up on all floors except first
- Optionally place 1-2 chests in random rooms
- Update `grid_world.gd` to recognize new cell types in `is_walkable()`
- Add interaction method for special tiles

**Acceptance criteria:**
- Stairs appear in the dungeon and are visually distinct
- Player can interact with stairs (future: floor transitions)
- Chests are interactable (future: give loot)
- `is_walkable()` returns false for walls, true for everything else

### Task 4.3: Floor transitions

**Files to modify:** `scripts/world/grid_world.gd`, `scripts/core/game_manager.gd`

**What to do:**
- When player steps on stairs_down, load next floor
- `load_dungeon(dungeon_id, current_floor + 1)` generates new grid
- Player position resets to stairs_up location on new floor
- Store floor state for return (or regenerate)
- Update `GameManager.current_floor`

**Acceptance criteria:**
- Walking onto stairs_down triggers floor transition
- New floor is generated and displayed
- Player appears at stairs_up position
- GameManager tracks current floor

---

## Phase 5: Save/Load System

> **Goal:** Player progress persists across sessions.
> **Depends on:** Phases 1-3 (all game state that needs saving).

### Task 5.1: Create SaveManager autoload

**Files to create:** `scripts/core/save_manager.gd`
**Files to modify:** `project.godot` (add autoload)

**What to do:**
- Create new autoload: `SaveManager`
- Properties: `save_path: String = "user://saves/"`
- Methods:
  - `save_game(slot: int) -> bool`
  - `load_game(slot: int) -> bool`
  - `delete_save(slot: int) -> bool`
  - `get_save_info(slot: int) -> Dictionary` — metadata only
  - `has_save(slot: int) -> bool`
  - `get_all_save_slots() -> Array[Dictionary]`
- Save file format: JSON at `user://saves/save_<slot>.json`
- Create save directory on first save if missing

**Acceptance criteria:**
- Save/load works for all game state (party, inventory, gold, location, floor, flags)
- Multiple save slots supported
- Save files include version and timestamp
- Loading restores exact game state

**Technical notes:**
- Save format documented in `docs/systems/save-load.md`
- Game flags stored as Dictionary
- Location stores: dungeon_id, floor, grid_pos, facing

### Task 5.2: Save/Load UI

**Files to create:** `scenes/ui/save_load_menu.tscn`, `scripts/ui/save_load_menu.gd`

**What to do:**
- Menu accessible from pause screen or main menu
- Shows save slots with: party summary, location, play time, timestamp
- Save: select empty or existing slot, confirm overwrite
- Load: select existing slot, confirm
- Delete: select slot, confirm

**Acceptance criteria:**
- Menu shows all save slots with metadata
- Save creates/overwrites files correctly
- Load restores game state and returns to gameplay
- Delete removes save file

---

## Phase 6: NPC Dialogue System

> **Goal:** NPCs in towns/dungeons with branching dialogue.
> **Depends on:** Phase 2 (inventory for shops), Phase 5 (save flags).

### Task 6.1: NPC data format and loader

**Files to create:** `packs/base/records/npcs/npcs.json`, update `scripts/data/data_registry.gd`

**What to do:**
- Add NPC JSON format (see `docs/systems/dialogue.md`)
- Add "npcs" to DataRegistry's category list
- Create example NPC (blacksmith with shop)

**Acceptance criteria:**
- NPC records load via DataRegistry
- Dialogue tree structure is valid
- Shop inventory references valid item IDs

### Task 6.2: Dialogue manager

**Files to create:** `scripts/core/dialogue_manager.gd`

**What to do:**
- Parse dialogue tree from NPC record
- Track current node and available choices
- Evaluate conditions (has_item, quest_complete, etc.)
- Apply effects (give_item, set_flag, etc.)
- Signals: `dialogue_started(npc_id)`, `dialogue_ended()`, `choice_made(choice_data)`

**Acceptance criteria:**
- Dialogue progresses through nodes correctly
- Conditions gate available choices
- Effects execute on choice selection
- Dialogue ends when next is null

### Task 6.3: Dialogue UI

**Files to create:** `scenes/ui/dialogue_panel.tscn`, `scripts/ui/dialogue_panel.gd`

**What to do:**
- Overlay shown when state == DIALOGUE
- NPC portrait area
- Text display with typewriter effect
- Numbered choice list
- Keyboard navigation (1-9 for choices)

**Acceptance criteria:**
- Dialogue text displays correctly
- Choices are selectable via keyboard
- UI shows/hides with dialogue state

---

## Phase 7: Polish & Integration

> **Goal:** Connect all systems into a cohesive game loop.
> **Depends on:** Phases 1-6.

### Task 7.1: Main menu

**Files to create:** `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`

**What to do:**
- Title screen with options: New Game, Continue, Settings, Quit
- New Game: start fresh party, enter first dungeon
- Continue: load most recent save
- Settings: open settings panel
- Quit: exit game

### Task 7.2: Pause menu

**Files to create:** `scenes/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd`

**What to do:**
- Accessible via Escape key
- Options: Resume, Save, Load, Settings, Quit to Menu
- Save/Load opens SaveLoadMenu
- Settings opens settings panel

### Task 7.3: HUD improvements

**Files to modify:** `scripts/ui/party_display.gd`, `scripts/ui/action_bar.gd`

**What to do:**
- Show HP/MP bars for each party member in PartyDisplay
- Update ActionBar buttons based on game state (exploring vs combat)
- Add level display to party members
- Show gold amount somewhere visible

### Task 7.4: Floor transition visuals

**Files to create:** `scripts/ui/transition_overlay.gd`

**What to do:**
- Fade-to-black effect on floor transitions
- "Floor X" text display
- Fade-in after new floor loads

---

## Dependency Graph

```
Phase 1 (Data Integration)
  ├── Task 1.1: Load dungeon data
  ├── Task 1.2: Load party from data
  └── Task 1.3: Wire up DataRegistry

Phase 2 (Inventory) ──→ depends on Phase 1
  ├── Task 2.1: Inventory data model
  └── Task 2.2: Inventory UI ──→ depends on 2.1

Phase 3 (Combat) ──→ depends on Phase 1 + Phase 2
  ├── Task 3.1: Combat manager ──→ depends on 3.2
  ├── Task 3.2: Combat actions ──→ standalone
  ├── Task 3.3: Encounter trigger ──→ depends on 3.1, 1.1
  └── Task 3.4: Combat UI ──→ depends on 3.1

Phase 4 (Procedural Dungeons) ──→ depends on Phase 1
  ├── Task 4.1: BSP generator ──→ standalone
  ├── Task 4.2: Special tiles ──→ depends on 4.1
  └── Task 4.3: Floor transitions ──→ depends on 4.2, 1.1

Phase 5 (Save/Load) ──→ depends on Phases 1-3
  ├── Task 5.1: SaveManager ──→ standalone
  └── Task 5.2: Save/Load UI ──→ depends on 5.1

Phase 6 (Dialogue) ──→ depends on Phase 2 + Phase 5
  ├── Task 6.1: NPC data + loader ──→ depends on 1.3
  ├── Task 6.2: Dialogue manager ──→ depends on 6.1
  └── Task 6.3: Dialogue UI ──→ depends on 6.2

Phase 7 (Polish) ──→ depends on all above
  ├── Task 7.1: Main menu
  ├── Task 7.2: Pause menu
  ├── Task 7.3: HUD improvements
  └── Task 7.4: Transition visuals
```

---

## Quick Reference: Key File Paths

### Scripts (existing)
| File | Purpose |
|------|---------|
| `scripts/core/game_manager.gd` | GameState, party data, game state machine |
| `scripts/core/turn_manager.gd` | Input → Action dispatch, turn loop |
| `scripts/core/settings_manager.gd` | Persistent settings via ConfigFile |
| `scripts/data/data_registry.gd` | JSON data loading and caching |
| `scripts/core/action.gd` | Action base class (RefCounted) |
| `scripts/core/movement_action.gd` | Grid movement action |
| `scripts/core/turn_action.gd` | Grid turning action |
| `scripts/world/grid_world.gd` | 3D grid, camera, dungeon rendering |
| `scripts/ui/main_layout.gd` | Config-driven layout ratios |
| `scripts/ui/viewport_frame.gd` | SubViewportContainer stretch |
| `scripts/ui/party_display.gd` | Party member panels (procedural) |
| `scripts/ui/action_bar.gd` | Movement buttons (procedural) |

### Scripts (to create)
| File | Purpose |
|------|---------|
| `scripts/core/combat_manager.gd` | Combat state, turn resolution, encounter logic |
| `scripts/core/save_manager.gd` | Save/load game state to JSON files |
| `scripts/core/dialogue_manager.gd` | NPC dialogue tree traversal |
| `scripts/world/dungeon_generator.gd` | BSP procedural dungeon generation |
| `scripts/ui/inventory_panel.gd` | Inventory/equipment UI |
| `scripts/ui/combat_ui.gd` | Combat command selection UI |
| `scripts/ui/dialogue_panel.gd` | NPC dialogue display UI |
| `scripts/ui/save_load_menu.gd` | Save/load slot selection UI |
| `scripts/ui/main_menu.gd` | Title screen |
| `scripts/ui/pause_menu.gd` | In-game pause menu |
| `scripts/ui/transition_overlay.gd` | Fade effects |

### Scenes (existing)
| File | Purpose |
|------|---------|
| `scenes/main.tscn` | Main game scene |
| `scenes/ui/viewport_frame.tscn` | 3D viewport container |
| `scenes/ui/party_display.tscn` | Party display panel |
| `scenes/ui/action_bar.tscn` | Action buttons bar |
| `scenes/world/grid_world.tscn` | 3D world with camera |
| `scenes/world/wall_tile.tscn` | Wall mesh |
| `scenes/world/floor_tile.tscn` | Floor mesh |

### Scenes (to create)
| File | Purpose |
|------|---------|
| `scenes/ui/inventory_panel.tscn` | Inventory overlay |
| `scenes/ui/combat_ui.tscn` | Combat UI overlay |
| `scenes/ui/dialogue_panel.tscn` | Dialogue overlay |
| `scenes/ui/save_load_menu.tscn` | Save/load menu |
| `scenes/ui/main_menu.tscn` | Title screen |
| `scenes/ui/pause_menu.tscn` | Pause menu |

### Data files (existing)
| File | Record IDs |
|------|-----------|
| `packs/base/records/classes/classes.json` | warrior, mage, cleric, thief |
| `packs/base/records/items/weapons.json` | sword_iron, sword_steel, staff_wood, dagger_steel, mace_iron, shield_wood, armor_leather, armor_chain, robe_cloth |
| `packs/base/records/items/consumables.json` | potion_health, potion_mana, antidote |
| `packs/base/records/enemies/encounters.json` | goblin, skeleton, slime |
| `packs/base/records/spells/spells.json` | fireball, heal, smite |
| `packs/base/records/dungeons/dungeon_01.json` | dungeon_01 (3 floors) |

---

## Implementation Notes for AI Agents

### Godot conventions to follow
- Use `class_name` for reusable types (Action subclasses)
- Autoloads are accessed globally by name: `GameManager`, `DataRegistry`, `SettingsManager`
- Signals use `snake_case`, emitted with `signal_name.emit(args)`
- `@onready` for node references, `get_node()` for dynamic access
- Scenes are `.tscn` files, scripts are `.gd` files
- JSON is parsed with `JSON.parse_string()`, returns Array or Dictionary
- `RefCounted` for lightweight data objects, `Node` for scene tree objects
- Grid coordinates: `Vector2i(x, y)` where x=column, y=row
- Grid data: `grid_data[y][x]` (row-major order)

### GameState transitions
```
MENU → EXPLORING (new game or load)
EXPLORING → COMBAT (encounter trigger)
EXPLORING → DIALOGUE (NPC interaction)
EXPLORING → INVENTORY (player opens inventory)
EXPLORING → PAUSED (escape key)
COMBAT → EXPLORING (encounter ends)
DIALOGUE → EXPLORING (dialogue ends)
INVENTORY → EXPLORING (inventory closed)
PAUSED → EXPLORING (resume)
PAUSED → MENU (quit to menu)
```

### Testing approach
- No test framework is set up — test manually in Godot editor
- Verify each task by running the game and performing the action
- Check Godot output console for errors
- Data validation: ensure JSON records are loaded correctly by printing `DataRegistry.get_all_ids()`

### Commit strategy
- One commit per task (or small group of related tasks)
- Use conventional commit messages: `feat:`, `fix:`, `refactor:`, `docs:`
- Include task number in commit message for traceability

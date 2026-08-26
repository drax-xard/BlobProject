# Turn & Action System

## Turn Loop

The turn-based loop is driven by player input via `TurnManager` (`scripts/core/turn_manager.gd`):

1. `GameManager.current_state` must be `EXPLORING` (or other valid state)
2. `TurnManager.is_turn_active` must be `false`
3. Player presses a key or clicks a button
4. `TurnManager._resolve_input()` creates an `Action` object
5. `TurnManager._process_player_action()` executes the action:
   - Sets `is_turn_active = true`
   - Finds the `World` node in the scene tree via `find_child("World", true, true)`
   - Calls `action.execute(world)`
   - Emits `action_performed` signal
   - Increments `GameManager.turn_count`
   - Calls `_turn_ended()` which emits `turn_processed` and resets `is_turn_active = false`
6. In the future: after player action, enemy/NPC turns execute

Both keyboard input (`_input`) and UI button presses (`process_ui_action`) converge on the same `_process_player_action()` path, ensuring identical behavior regardless of input method.

## Action Pattern

Base class: `Action` extends `RefCounted` (lightweight, not a Node).

```
class_name Action
extends RefCounted

var actor_index: int          # which party member (0 = leader)

func execute(world: Node) -> bool    # virtual, returns success
func get_action_name() -> String     # virtual, returns identifier
```

The `world` parameter is always the `GridWorld` node, resolved at execution time via `find_child`. This decouples actions from the scene tree structure -- actions are created before the world reference is available.

## Concrete Actions

| Action | Class | Parameters | GridWorld Method | File |
|--------|-------|-----------|-----------------|------|
| Move | `MovementAction` | `direction: Vector2i` | `try_move(actor_index, dir)` | `scripts/core/movement_action.gd` |
| Turn | `TurnAction` | `turn_dir: int` (-1 or 1) | `try_turn(actor_index, dir)` | `scripts/core/turn_action.gd` |
| Attack | _(planned)_ `AttackAction` | `target_index: int` | - | - |
| Spell | _(planned)_ `SpellAction` | `spell_id: String, target` | - | - |
| Use Item | _(planned)_ `UseItemAction` | `item_id: String, target` | - | - |

`TurnAction` defines constants `LEFT = -1` and `RIGHT = 1` for the turn direction.

Both existing actions check `world.has_method(...)` before calling the world method, returning `false` if the method doesn't exist. This makes them safe to use with any world implementation.

## Input Mapping

| Action | Key 1 | Key 2 | Action Created |
|--------|-------|-------|---------------|
| Forward | W | Up Arrow | `MovementAction(0, Vector2i.UP)` |
| Backward | S | Down Arrow | `MovementAction(0, Vector2i.DOWN)` |
| Turn Left | Q | Left Arrow | `TurnAction(0, TurnAction.LEFT)` |
| Turn Right | E | Right Arrow | `TurnAction(0, TurnAction.RIGHT)` |
| Strafe Left | A | - | `MovementAction(0, Vector2i.LEFT)` |
| Strafe Right | D | - | `MovementAction(0, Vector2i.RIGHT)` |

Input actions are defined in `project.godot` and mapped in `TurnManager._resolve_input()`. The `actor_index` is always `0` (party leader) for player input.

## UI Action Path

`ActionBar` (`scripts/ui/action_bar.gd`) provides on-screen buttons as an alternative to keyboard input:

```
Button pressed → _on_button_pressed(action_data) → creates Action → TurnManager.process_ui_action(action)
```

The `process_ui_action()` method applies the same guards as keyboard input (`is_turn_active` and game state check), then delegates to `_process_player_action()`.

Button layout: `^` (forward), `v` (back), `<` (turn left), `>` (turn right), `<=` (strafe left), `=>` (strafe right). Each button is 50×50 minimum size.

## Facing System

Defined in `GridWorld` (`scripts/world/grid_world.gd`) as an enum:

```gdscript
enum Facing { NORTH, EAST, SOUTH, WEST }   # values: 0, 1, 2, 3
```

### Rotation

- Turning: `player_facing = posmod(player_facing + turn_dir, 4)`
  - `TurnAction.LEFT` (-1) rotates counter-clockwise
  - `TurnAction.RIGHT` (1) rotates clockwise

### Camera Rotation

Camera `rotation.y` is set per facing direction:

| Facing | rotation.y | Description |
|--------|-----------|-------------|
| NORTH | `0.0` | Looking along -Z (into the grid) |
| EAST | `-PI / 2` | Looking along +X |
| SOUTH | `PI` | Looking along +Z (back toward origin) |
| WEST | `PI / 2` | Looking along -X |

### Movement Rotation

`_rotate_for_facing()` transforms relative movement directions (UP/DOWN/LEFT/RIGHT) to absolute grid directions based on the current facing. For example, pressing Forward (UP) while facing EAST converts the movement to `Vector2i(1, 0)` (grid +X).

| Facing | UP (forward) | DOWN (backward) | LEFT | RIGHT |
|--------|-------------|----------------|------|-------|
| NORTH | `(0, -1)` | `(0, 1)` | `(-1, 0)` | `(1, 0)` |
| EAST | `(1, 0)` | `(-1, 0)` | `(0, -1)` | `(0, 1)` |
| SOUTH | `(0, 1)` | `(0, -1)` | `(1, 0)` | `(-1, 0)` |
| WEST | `(-1, 0)` | `(1, 0)` | `(0, 1)` | `(0, -1)` |

## Signals

| Signal | Emitted From | Payload | Description |
|--------|-------------|---------|-------------|
| `action_performed` | `TurnManager` | `action: Action` | Fired after action executes |
| `turn_processed` | `TurnManager` | `turn_number: int` | Fired when turn ends |
| `player_moved` | `GridWorld` | `new_position: Vector2i` | Fired after successful move |
| `player_turned` | `GridWorld` | `new_facing: int` | Fired after successful turn |

## Future: Multi-Action Turns

The `pending_actions: Array[Action]` array in `TurnManager` is reserved for future use where a single turn might involve multiple sequential actions (e.g., move + attack). Currently only single-action turns are supported.

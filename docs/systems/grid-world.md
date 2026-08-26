# Grid World System

## Overview

`GridWorld` (`scripts/world/grid_world.gd`) manages the dungeon grid, player position, camera, and mesh building. It extends `Node3D` and is the root node of the world scene (`scenes/world/grid_world.tscn`).

## Grid Data Structure

- `grid_data: Array[Array]` -- 2D array of integers representing cell types
- `grid_width: int` -- number of columns
- `grid_height: int` -- number of rows
- Grid coordinates: `grid_data[y][x]` (row-major, Y is the row index)
- Grid origin: top-left `(0, 0)` is the north-west corner

### Current Cell Values

| Value | Type | Walkable | Description |
|-------|------|----------|-------------|
| 0 | Floor | Yes | Open ground |
| 1 | Wall | No | Solid, blocks movement |

## Coordinate Systems

| System | X axis | Y axis | Z axis |
|--------|--------|--------|--------|
| Grid | East (+X) | South (+Y) | N/A (2D) |
| World | East (+X) | Up (+Y) | South (+Z) |

### Mapping

- Grid X → World X: `grid_x * CELL_SIZE`
- Grid Y → World Z: `grid_y * CELL_SIZE`
- World Y is always the camera height: `CELL_SIZE * 0.8` (= 1.6 units)

Grid Y increases southward (down the array), which maps to the +Z axis in world space. Grid X increases eastward (+X in world space).

## CELL_SIZE

```gdscript
const CELL_SIZE: float = 2.0
```

Each grid cell occupies 2×2 world units. All tile meshes are sized to this constant, ensuring seamless tiling.

## Camera System

### Setup (from `grid_world.tscn`)

| Property | Value |
|----------|-------|
| Type | `Camera3D` |
| FOV | 70° |
| Near clip | 0.1 |
| Far clip | 50.0 |
| Initial position | `(0, 1.6, 0)` |

### Positioning

The camera is positioned at:
```
(grid_x * CELL_SIZE, CELL_SIZE * 0.8, grid_y * CELL_SIZE)
```
= `(grid_x * 2.0, 1.6, grid_y * 2.0)`

### Rotation

Camera `rotation.y` is set per facing direction via `_update_camera()`:

| Facing | rotation.y | Notes |
|--------|-----------|-------|
| NORTH | `0.0` | Default, looking forward into grid |
| EAST | `-PI / 2` | Rotated 90° clockwise |
| SOUTH | `PI` | Rotated 180° |
| WEST | `PI / 2` | Rotated 90° counter-clockwise |

### Lighting

An `OmniLight3D` is attached as a child of `Camera3D`, so it follows the player:

| Property | Value |
|----------|-------|
| Light color | `(1.0, 0.9, 0.7)` (warm white) |
| Light energy | 3.0 |
| Omni range | 12.0 |

### WorldEnvironment

The scene includes a `WorldEnvironment` with:
- Procedural sky (dark blue top, brownish horizon)
- Ambient light: color `(0.6, 0.55, 0.5)`, energy 1.0
- A `DirectionalLight3D` at `(0, 5, 0)` with energy 1.5

## Mesh Building

`_build_grid_mesh()` iterates `grid_data` and instantiates tile scenes for each cell.

### Process

1. Clean up previous dynamic children via `queue_free()`
2. Load `wall_tile.tscn` and `floor_tile.tscn`
3. For each cell in `grid_data[y][x]`:
   - If cell == 1 (wall): instantiate `wall_tile.tscn`, position at `(x * CELL_SIZE, CELL_SIZE * 0.5, y * CELL_SIZE)` -- centered vertically in the cell
   - Else (floor): instantiate `floor_tile.tscn`, position at `(x * CELL_SIZE, 0.0, y * CELL_SIZE)` -- at ground level
4. Track all instantiated nodes in `_dynamic_children: Array[Node]` for cleanup

### Tile Scenes

**Wall Tile** (`scenes/world/wall_tile.tscn`):
- `MeshInstance3D` with `BoxMesh` size `2 × 2 × 2`
- Material color: brown `(0.35, 0.25, 0.18)`
- Roughness: 0.9

**Floor Tile** (`scenes/world/floor_tile.tscn`):
- `MeshInstance3D` with `PlaneMesh` size `2 × 2`
- Material color: dark green `(0.25, 0.3, 0.2)`
- Roughness: 0.8

## Walkability Check

```gdscript
func is_walkable(grid_pos: Vector2i) -> bool
```

Returns `true` only if:
1. `grid_pos.x` is within `[0, grid_width)`
2. `grid_pos.y` is within `[0, grid_height)`
3. `grid_data[grid_pos.y][grid_pos.x] == 0`

Out-of-bounds positions return `false`. Walls (value 1) return `false`.

## Movement

### `try_move(actor_index, direction) -> bool`

1. Rotate the relative direction by the current facing via `_rotate_for_facing()`
2. Calculate `target_pos = player_grid_pos + rotated_direction`
3. Check `is_walkable(target_pos)`
4. If walkable: update `player_grid_pos`, call `_update_camera()`, emit `player_moved`, return `true`
5. If not walkable: return `false` (no state change)

### `try_turn(actor_index, turn_dir) -> bool`

1. Update `player_facing = posmod(player_facing + turn_dir, 4)`
2. Call `_update_camera()`
3. Emit `player_turned`
4. Return `true` (turns always succeed)

### Player Start Position

`_place_player_at_start()` scans the grid for the first walkable cell (value 0) and places the player there. Falls back to `(1, 1)` if no walkable cell is found.

## Signals

| Signal | Payload | Description |
|--------|---------|-------------|
| `player_moved` | `new_position: Vector2i` | Emitted after a successful move |
| `player_turned` | `new_facing: int` | Emitted after a successful turn |

## Test Dungeon

`_build_test_dungeon()` creates an 8×8 grid with walls on all border cells and three interior walls at `(3,3)`, `(4,3)`, and `(3,4)`.

## Future: Cell Types

Planned expansion of `grid_data` values:

| Value | Type | Walkable | Description |
|-------|------|----------|-------------|
| 0 | Floor | Yes | Open ground |
| 1 | Wall | No | Solid, blocks movement |
| 2 | Door | Yes | Can be locked/unlocked |
| 3 | Stairs Up | Yes | Transition to previous floor |
| 4 | Stairs Down | Yes | Transition to next floor |
| 5 | Trap | Yes | Triggers trap event |
| 6 | Water | Yes | Slow movement |
| 7 | Chest | Yes (blocked?) | Interactable, contains loot |
| 8 | NPC | Yes (blocked?) | Occupied by NPC, triggers dialogue |

The `is_walkable()` check will need to be expanded to handle these types -- some walkable cells may be blocked under certain conditions (locked doors, occupied NPC slots).

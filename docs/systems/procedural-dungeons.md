# Procedural Dungeon Generation

> **Status:** Implemented (v0.4.0-alpha)

---

## Overview

Procedural generation for dungeon layouts. Used for replayability and content variety. Hub towns are hand-crafted; combat dungeons use procedural generation.

---

## Generation Algorithm: BSP (Binary Space Partitioning)

1. Start with a rectangular area (floor width x height from dungeon JSON)
2. Recursively split into smaller rectangles (4-8 splits)
3. Place rooms inside each leaf rectangle (random size within bounds)
4. Connect rooms with corridors:
   - Sibling rooms: connect centers with L-shaped corridors
   - Parent rooms: connect with straight corridors
5. Place special tiles: stairs, doors, chests, traps
6. Populate with enemies based on `encounter_rate`

---

## Room Templates (Design)

| Type | Description | Frequency |
|------|-------------|-----------|
| Normal | Standard combat room | 60% |
| Treasure | Contains chest(s) | 15% |
| Trap | Floor hazards | 10% |
| Boss | Large room, boss enemy | 1 per floor |
| Shrine | Healing/buff station | 10% |
| Shop | Merchant NPC | 5% (town floors only) |

---

## Corridor Rules

- Width: 1 cell (can be widened for main paths)
- L-shaped or straight connections
- Can include doors at room entrances
- Dead ends: occasional for exploration variety

---

## Enemy Placement

- Use `encounter_rate` from `floor_data`
- Enemies placed in rooms and corridors
- Higher `encounter_rate` in deeper floors
- Enemy density varies by room type (boss rooms = guaranteed encounter)

---

## Loot Placement

- Treasure rooms: 1-3 chests
- Corridors: occasional hidden chests (luck-based discovery)
- Chest contents: random from floor's loot table, weighted by rarity

---

## Floor Transitions

- **Stairs Down** placed in a room on each floor (except last)
- **Stairs Up** on each floor (except first) connect to previous floor's Stairs Down
- Position: farthest room from the entrance for exploration progression

---

## Thematic Variation (Design)

Different visual and gameplay themes per dungeon:

| Theme | Wall Color | Floor Color | Enemy Types | Special |
|-------|-----------|-------------|-------------|---------|
| Cave | Brown | Dark stone | Goblins, Slimes | Narrow corridors |
| Crypt | Gray | Stone tiles | Skeletons, Ghosts | Trap-heavy |
| Forest | Green | Grass | Wolves, Bandits | Open areas |
| Volcano | Red | Lava rock | Fire elementals | Damage tiles |
| Ice | Blue | Ice/snow | Ice golems | Slippery floors |

---

## Generation Seed

- Each dungeon floor uses a seed for reproducible generation
- Seed derived from: `dungeon_id + floor_number + world_seed`
- Same seed always produces the same layout
- World seed: random on new game, stored in save file

---

## Performance Considerations

- Generate floors on-demand (when player enters)
- Unvisited floors are not generated yet
- Previous floors can be cached or regenerated
- Generation happens in a single frame for small floors (< 20x20)
- Larger floors: consider threaded generation

# Save/Load System

> **Design Document - Not Yet Implemented**
> This document describes a planned system. Nothing below is currently in the codebase.

---

## Overview

Persistent game state saved to user data directory. Supports multiple save slots, auto-save, and manual save/load.

---

## Save File Format (Planned)

JSON file stored at `user://saves/save_<slot>.json`. Structure:

```json
{
  "version": "0.2.1",
  "timestamp": "2026-08-25T14:30:00",
  "play_time": 3600,
  "slot": 1,
  "party": [],
  "inventory": [],
  "gold": 250,
  "location": {
    "dungeon_id": "dungeon_01",
    "floor": 2,
    "grid_pos": [5, 3],
    "facing": 0
  },
  "game_flags": {},
  "quest_progress": {},
  "turn_count": 150
}
```

---

## What to Save

| Category | Fields | Notes |
|----------|--------|-------|
| Party | Full party array | All stats, equipment, spells, skills |
| Inventory | Item list + quantities | Consumables and unequipped equipment |
| Gold | Integer | Party gold |
| Location | Dungeon, floor, position, facing | Where the player is |
| Progress | Turn count, game flags, quests | Story and progression state |
| Meta | Version, timestamp, play time | Save file metadata |

---

## Auto-Save Triggers (Design)

- Floor transition (entering a new dungeon floor)
- After returning to hub town
- Configurable: auto-save can be toggled in settings

---

## Multiple Save Slots

- 3-5 save slots (configurable)
- **Slot 0** reserved for auto-save
- **Slots 1-N** for manual saves
- Save/load UI shows slot info: party summary, location, play time, timestamp

---

## Save/Load API (Design)

```gdscript
# SaveManager autoload (future)
func save_game(slot: int) -> bool
func load_game(slot: int) -> bool
func delete_save(slot: int) -> bool
func get_save_info(slot: int) -> Dictionary  # metadata without full load
func has_save(slot: int) -> bool
```

---

## Version Compatibility

- Save files include game version
- On load: check version compatibility
- Migration functions for breaking changes between versions

### Migration Strategy
```gdscript
# Each version bump that changes save format adds a migration function
var migrations := {
    "0.2.0": migrate_0_1_to_0_2,
    "0.3.0": migrate_0_2_to_0_3,
}

func migrate_save(data: Dictionary) -> Dictionary:
    var save_version = data.get("version", "0.0.0")
    for ver in migrations:
        if save_version < ver:
            data = migrations[ver].call(data)
            data["version"] = ver
    return data
```

---

## Game Flags (Design)

- Dictionary of `string → variant`
- Set by dialogue effects, quest triggers, story events
- Checked by dialogue conditions, quest logic

### Examples
| Flag | Type | Set By | Checked By |
|------|------|--------|------------|
| `"met_blacksmith"` | bool | Dialogue | Dialogue conditions |
| `"defeated_boss_1"` | bool | Combat | Quest logic |
| `"opened_gate_east"` | bool | Puzzle | Door interactions |
| `"party_member_joined"` | string | Story | Dialogue branching |

# NPC Dialogue System

> **Design Document - Not Yet Implemented**
> This document describes a planned system. Nothing below is currently in the codebase.

---

## Overview

Dialogue system for NPC interactions in towns and dungeons. Supports branching conversations, quest triggers, shop access, and conditional text.

---

## NPC Data Format (Planned JSON Schema)

```json
{
  "id": "npc_blacksmith",
  "name": "Gareth the Blacksmith",
  "type": "npc",
  "location": "hub_town",
  "portrait": "blacksmith.png",
  "dialogue_tree": {
    "start": {
      "text": "Welcome to my shop! Looking to buy or sell?",
      "choices": [
        { "text": "Show me your wares.", "next": "shop", "condition": null },
        { "text": "I need information.", "next": "info" },
        { "text": "Goodbye.", "next": null }
      ]
    },
    "info": {
      "text": "The caves to the east are dangerous. Be careful!",
      "choices": [
        { "text": "Thanks for the warning.", "next": "start" }
      ]
    }
  },
  "shop_inventory": ["sword_steel", "armor_chain", "potion_health", "potion_mana"],
  "quest_giver": false
}
```

---

## Dialogue Tree Structure

- Each node has `text` (what the NPC says) and `choices` (player options)
- Each choice has `text`, `next` (node ID or `null` to end), and optional `condition`
- Conditions: check game flags, party state, quest progress
- Effects: can set flags, give items, start quests, open shops

---

## Conditions (Planned)

| Condition | Example | Description |
|-----------|---------|-------------|
| `has_item` | `{"has_item": "key_dungeon"}` | Player has specific item |
| `quest_complete` | `{"quest_complete": "q_goblins"}` | Quest is finished |
| `stat_check` | `{"stat": "strength", "min": 10}` | Character meets stat requirement |
| `gold_check` | `{"gold_min": 100}` | Party has enough gold |
| `game_flag` | `{"flag": "met_blacksmith"}` | Custom flag is set |

---

## Effects (Planned)

| Effect | Example | Description |
|--------|---------|-------------|
| `give_item` | `{"give_item": "potion_health", "qty": 2}` | Add items to inventory |
| `take_item` | `{"take_item": "key_dungeon"}` | Remove items from inventory |
| `give_gold` | `{"give_gold": 50}` | Add gold to party |
| `set_flag` | `{"set_flag": "met_blacksmith"}` | Set a game flag |
| `start_quest` | `{"start_quest": "q_goblins"}` | Begin a quest |
| `open_shop` | `{"shop_id": "blacksmith_shop"}` | Open shop UI |

### Effects in Choice Format
```json
{
  "text": "I accept your quest!",
  "next": "quest_accepted",
  "condition": null,
  "effects": [
    { "start_quest": "q_goblins" },
    { "set_flag": "accepted_goblin_quest" }
  ]
}
```

---

## Dialogue UI (Planned)

- NPC portrait and name at top
- Dialogue text with typewriter effect
- Numbered choices for keyboard/click
- Shop interface when dialogue leads to shop

### UI Layout
```
┌──────────────────────────────────────────────┐
│  [Portrait]  Gareth the Blacksmith           │
├──────────────────────────────────────────────┤
│                                              │
│  "Welcome to my shop! Looking to buy         │
│   or sell?"                                  │
│                                              │
├──────────────────────────────────────────────┤
│  1. Show me your wares.                      │
│  2. I need information.                      │
│  3. Goodbye.                                 │
└──────────────────────────────────────────────┘
```

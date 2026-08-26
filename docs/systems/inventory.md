# Inventory & Equipment System

> **Status: Implemented (v0.2.4-alpha)**
> Core inventory, equipment, gold, and consumable systems are functional. Shop system and UI polish are planned for future phases.

---

## Overview

Party-wide shared inventory for consumables and unequipped items. Individual equipment per character (6 slots each). Gold as currency.

---

## Inventory Structure

```gdscript
# game_manager.gd
var inventory: Array[Dictionary] = []  # [{ "id": "potion_health", "quantity": 5 }, ...]
var gold: int = 0

signal inventory_changed()
signal party_changed()
```

### Core Operations (implemented)

| Function | Description |
|----------|-------------|
| `add_item(item_id, qty)` | Stacks existing items or creates new entries |
| `remove_item(item_id, qty) -> bool` | Decrements quantity; removes entry at zero |
| `has_item(item_id) -> bool` | Check if party owns an item |
| `get_item_quantity(item_id) -> int` | Get count of a specific item |
| `get_inventory() -> Array[Dictionary]` | Return full inventory array |

---

## Item Categories

| Category | Stackable | Equippable | Sellable | Status |
|----------|-----------|------------|----------|--------|
| **Equipment** | No | Yes | Planned | Implemented — 9 items (weapons, shields, armor, robes) |
| **Consumables** | Yes | No | Planned | Implemented — 3 items (health potion, mana potion, antidote) |
| **Key Items** (future) | No | No | No | Not yet implemented — quest items planned for future |

---

## Equipment Slots

| Slot | Accepts | Implemented Items |
|------|---------|-------------------|
| `main_hand` | weapons | Iron Sword, Steel Sword, Wooden Staff, Steel Dagger, Iron Mace |
| `off_hand` | shields, off-hand | Wooden Shield |
| `head` | helms, hats | (none yet) |
| `body` | armor, robes | Leather Armor, Chain Mail, Cloth Robe |
| `legs` | greaves, pants | (none yet) |
| `accessory` | rings, amulets | (none yet) |

---

## Equipment Operations (implemented)

### Equip
1. Validate slot compatibility (reads `slot` from item record)
2. Validate stat requirements (reads `requirements` from item record)
3. If slot was occupied, old item returns to inventory
4. Remove new item from inventory after equipping
5. Emit `inventory_changed` and `party_changed` signals

### Unequip
1. Move equipped item back to inventory
2. Clear the slot
3. Emit signals

### Equipment in Combat
- `main_hand` weapon provides `damage_min`/`damage_max` for physical attacks
- `body` armor provides defense bonus
- `off_hand` shields provide defense reduction against enemy attacks

### Compare (not yet implemented)
- Planned: show stat differences when hovering a new equipment
- Planned: display before/after stats with arrows indicating improvement or regression

---

## Shop System (not yet implemented)

Planned for Phase 6 (dialogue/NPC integration). No shop files or references exist in the codebase yet.

- Shop inventories defined in JSON (per NPC or per town)
- **Buy price**: `item.value` (or modified by shop)
- **Sell price**: `item.value / 2` (rounded down)
- Gold tracked in `GameManager`

### Shop Data Format (planned)
```json
{
  "shop_id": "blacksmith_shop",
  "npc": "npc_blacksmith",
  "inventory": ["sword_steel", "armor_chain", "potion_health", "potion_mana"],
  "buy_multiplier": 1.0,
  "sell_multiplier": 0.5
}
```

---

## Inventory UI (implemented)

Full procedural UI built in `inventory_panel.gd` (393 lines). Toggled via "I" button in action bar.

### Features
- **Party member selector** — buttons for characters 1-4
- **Character stats panel** — Name, Level, HP, MP, STR, DEF, VIT, ENR, AGI, LCK, Spells
- **Equipment panel** — all 6 slots with equipped item names or "(empty)", each with an unequip button
- **Inventory list** — items with name and quantity, selectable via click or arrow keys
- **Gold display** — shown in the inventory header
- **Item info label** — shows name, value, and description of selected item
- **Action buttons**: [E]quip, [U]se, [D]rop
- **Keyboard controls**: 1-4 for party members, Up/Down navigation, Enter to equip, U to use, D to drop, I or Escape to close

### Consumable Usage
- Applies `heal` (HP restore) and `restore_mp` effects with random values from `value_min`/`value_max`
- Used from both inventory screen and combat

### Auto-refresh
- `inventory_changed` and `party_changed` signals trigger UI refresh

### Not yet implemented
- **Filters**: All, Weapons, Armor, Consumables
- **Sort**: by name, value, type
- **Item icons** (currently text-only)
- **Equipment stat comparison** display

---

## Data Flow

```
JSON files (packs/base/records/items/*.json)
    |
    v
DataRegistry (autoload) — loads, validates, caches all records
    |
    v
GameManager (autoload) — owns inventory[], gold, party[] with equipment{}
    |-- add_item() / remove_item() / equip_item() / unequip_item()
    |-- signals: inventory_changed, party_changed
    |
    +---> InventoryPanel (UI) — reads GameManager, shows list/equipment/stats
    +---> CombatManager — reads party equipment for damage calc, distributes gold/loot
    +---> GridWorld — chests add items and gold
    +---> ActionBar / TurnManager — toggle inventory state
```

---

## Item Data Records

Loaded from `packs/base/records/items/` at startup. Validated by `DataRegistry`.

### Weapons (9 items)

| ID | Slot | Damage | Speed | Requirements | Value |
|----|------|--------|-------|--------------|-------|
| `sword_iron` | main_hand | 3–7 | 1.0 | STR 8 | 50 |
| `sword_steel` | main_hand | 5–10 | 1.0 | STR 10 | 150 |
| `staff_wood` | main_hand | 1–3 | 0.8 | ENR 6 | 20 |
| `dagger_steel` | main_hand | 2–5 | 1.5 | AGI 8 | 40 |
| `mace_iron` | main_hand | 4–8 | 0.7 | STR 10 | 80 |
| `shield_wood` | off_hand | DEF 2 | — | — | 25 |
| `armor_leather` | body | DEF 3 | — | AGI 6 | 60 |
| `armor_chain` | body | DEF 6 | — | STR 10 | 200 |
| `robe_cloth` | body | DEF 1 | — | — | 15 |

### Consumables (3 items)

| ID | Effect | Value Range | Value |
|----|--------|-------------|-------|
| `potion_health` | heal | 20–30 HP | 25 |
| `potion_mana` | restore_mp | 15–25 MP | 30 |
| `antidote` | cure_poison | — | 15 |

---

## Known Issues

- **Antidote effect not applied**: `antidote` exists in JSON with `effect: "cure_poison"`, but `_apply_consumable()` has no handler for it — falls through to default "Unknown effect" case.
- **No sell functionality**: Items can be dropped but not sold for gold.
- **No HUD gold display**: Gold is only visible when inventory is open.

---

## Future Enhancements

| Feature | Phase | Notes |
|---------|-------|-------|
| Shop/merchant system | Phase 6 | Buy/sell with NPC shops |
| Equipment stat comparison | TBD | Show before/after stats on equip |
| Inventory filters & sort | TBD | Filter by category, sort by name/value/type |
| Item icons | TBD | Visual icons in inventory list |
| Key items (quest items) | TBD | Non-stackable, non-sellable quest items |
| Head/legs/accessory items | TBD | Expand equipment slots with new item types |
| HUD gold display | TBD | Show gold outside of inventory screen |

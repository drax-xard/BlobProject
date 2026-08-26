# Inventory & Equipment System

> **Design Document - Not Yet Implemented**
> This document describes a planned system. Nothing below is currently in the codebase.

---

## Overview

Party-wide shared inventory for consumables and unequipped items. Individual equipment per character (6 slots each). Gold as currency.

---

## Inventory Structure (Design)

```gdscript
# GameManager would add:
var inventory: Array[Dictionary] = []  # [{ "id": "potion_health", "quantity": 5 }, ...]
var gold: int = 0
```

---

## Item Categories

| Category | Stackable | Equippable | Sellable | Description |
|----------|-----------|------------|----------|-------------|
| **Equipment** | No | Yes | Yes | Weapons and armor. Moved to character equipment slots. |
| **Consumables** | Yes | No | Yes | Potions, scrolls, etc. Removed on use. |
| **Key Items** (future) | No | No | No | Quest items. Don't stack, can't be sold. |

---

## Equipment Slots

| Slot | Accepts | Examples |
|------|---------|---------|
| `main_hand` | weapons | Sword, Staff, Dagger, Mace |
| `off_hand` | shields, off-hand | Wooden Shield |
| `head` | helms, hats | (future) |
| `body` | armor, robes | Leather Armor, Chain Mail, Cloth Robe |
| `legs` | greaves, pants | (future) |
| `accessory` | rings, amulets | (future) |

---

## Equipment Operations

### Equip
1. Validate slot compatibility and stat requirements
2. Move item from inventory to slot
3. If slot was occupied, old item returns to inventory

### Unequip
1. Move item from slot to inventory

### Compare
- Show stat differences when hovering a new equipment
- Display before/after stats with arrows indicating improvement or regression

---

## Shop System (Design)

- Shop inventories defined in JSON (per NPC or per town)
- **Buy price**: `item.value` (or modified by shop)
- **Sell price**: `item.value / 2` (rounded down)
- Gold tracked in `GameManager`

### Shop Data Format (Planned)
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

## Inventory UI (Design)

- Grid or list of items with icons, names, quantities
- **Filters**: All, Weapons, Armor, Consumables
- **Sort**: by name, value, type
- **Context menu**: Use, Equip, Drop, Info

### UI Layout
```
┌──────────────────────────────────────────────┐
│  INVENTORY                    Gold: 250      │
├──────────────────────────────────────────────┤
│  [All] [Weapons] [Armor] [Consumables]      │
├──────────────────────────────────────────────┤
│  ⚔️ Iron Sword         x1    Value: 120     │
│  🛡️ Wooden Shield      x1    Value: 80      │
│  🧪 Health Potion      x5    Value: 25      │
│  🧪 Mana Potion        x3    Value: 30      │
│  📜 Scroll of Fire     x1    Value: 60      │
├──────────────────────────────────────────────┤
│  [Use]  [Equip]  [Drop]  [Info]             │
└──────────────────────────────────────────────┘
```

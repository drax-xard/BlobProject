# Data Formats

All game content is defined in JSON files stored under `packs/<pack_id>/records/`. At startup, `DataRegistry` scans each category directory, reads every `.json` file, and indexes all records by their `id` field into a flat cache. Both JSON array (`[{...}, {...}]`) and single-object (`{...}`) formats are supported.

Categories are scanned in this order: `items`, `enemies`, `classes`, `dungeons`, `spells`.

---

## Character Class

**File:** `classes/classes.json`

Defines a playable character class with starting stats, level-up growth, and equipment slots.

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"warrior"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"class"` |
| `base_stats` | object | Yes | Starting stat values (see [Stats](#stats) below) |
| `stat_growth` | object | Yes | Stat increase per level (see [Stats](#stats) below) |
| `equipment_slots` | array | Yes | Slots this class can equip into |
| `description` | string | Yes | Flavor text |

### Stats

All stat values are integers. Eight stats are used across the system:

| Stat | Description |
|---|---|
| `hp` | Maximum hit points. Determines how much damage a character can take. |
| `mp` | Maximum mana points. Spent to cast spells. |
| `strength` | Physical attack power. Increases weapon damage and determines melee requirements. |
| `defense` | Reduces incoming physical damage. |
| `vitality` | Governs HP regeneration and maximum HP scaling. |
| `energy` | Governs MP regeneration and maximum MP scaling. |
| `agility` | Affects turn order, dodge chance, and determines weapon speed thresholds. |
| `luck` | Increases critical hit chance, loot quality, and gold drops. |

### Valid Equipment Slots

`main_hand`, `off_hand`, `head`, `body`, `legs`, `accessory`

### Example

```json
{
  "id": "warrior",
  "name": "Warrior",
  "type": "class",
  "base_stats": {
    "hp": 45,
    "mp": 10,
    "strength": 12,
    "defense": 10,
    "vitality": 10,
    "energy": 6,
    "agility": 8,
    "luck": 6
  },
  "stat_growth": {
    "hp": 8,
    "mp": 2,
    "strength": 2,
    "defense": 2,
    "vitality": 2,
    "energy": 1,
    "agility": 1,
    "luck": 1
  },
  "equipment_slots": ["main_hand", "off_hand", "head", "body", "legs", "accessory"],
  "description": "A stalwart fighter who excels in melee combat and can take significant punishment."
}
```

---

## Weapon

**File:** `items/weapons.json`

Melee or ranged weapons equipped in a weapon slot. Weapons and armor share the same file; they are differentiated by the `type` field (`"weapon"` vs `"armor"`).

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"sword_iron"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"weapon"` |
| `slot` | string | Yes | Equipment slot (`main_hand`, `off_hand`, etc.) |
| `damage_min` | int | Yes | Minimum damage dealt per hit |
| `damage_max` | int | Yes | Maximum damage dealt per hit |
| `speed` | float | Yes | Attack speed multiplier (1.0 = normal, >1.0 = fast, <1.0 = slow) |
| `requirements` | object | Yes | Minimum stat requirements to equip. Empty object `{}` for no requirements. |
| `value` | int | Yes | Gold value for buying/selling |
| `description` | string | Yes | Flavor text |

### Example

```json
{
  "id": "sword_iron",
  "name": "Iron Sword",
  "type": "weapon",
  "slot": "main_hand",
  "damage_min": 3,
  "damage_max": 7,
  "speed": 1.0,
  "requirements": { "strength": 8 },
  "value": 50,
  "description": "A sturdy iron blade. Reliable and well-balanced."
}
```

---

## Armor

**File:** `items/weapons.json` (same file as weapons)

Protective equipment that provides defense bonuses. Armor records use `type: "armor"` and are stored alongside weapons.

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"shield_wood"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"armor"` |
| `slot` | string | Yes | Equipment slot (`off_hand`, `head`, `body`, `legs`, `accessory`) |
| `defense` | int | Yes | Defense bonus granted when equipped |
| `requirements` | object | Yes | Minimum stat requirements to equip. Empty object `{}` for no requirements. |
| `value` | int | Yes | Gold value for buying/selling |
| `description` | string | Yes | Flavor text |

### Example

```json
{
  "id": "shield_wood",
  "name": "Wooden Shield",
  "type": "armor",
  "slot": "off_hand",
  "defense": 2,
  "requirements": {},
  "value": 25,
  "description": "A basic wooden shield. Offers minimal protection."
}
```

### Additional Slots

Armor can appear in multiple equipment slots. The `slot` field determines which slot the armor occupies:

| Slot | Examples |
|---|---|
| `off_hand` | Shields |
| `head` | Helmets, hoods |
| `body` | Chain mail, robes, leather armor |
| `legs` | Greaves, leather pants |
| `accessory` | Amulets, rings |

---

## Consumable

**File:** `items/consumables.json`

Usable items that provide an effect when consumed. Consumables are single-use items.

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"potion_health"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"consumable"` |
| `effect` | string | Yes | Effect type (see below) |
| `value_min` | int | No | Minimum effect strength (optional) |
| `value_max` | int | No | Maximum effect strength (optional) |
| `value` | int | Yes | Gold value for buying/selling. Also used as a fixed effect value when `value_min`/`value_max` are omitted. |
| `description` | string | Yes | Flavor text |

### Effect Types

| Effect | Description |
|---|---|
| `heal` | Restores HP. Uses `value_min`/`value_max` range if provided, otherwise restores a fixed amount. |
| `restore_mp` | Restores MP. Uses `value_min`/`value_max` range if provided, otherwise restores a fixed amount. |
| `cure_poison` | Removes the poison status effect from a character. |

### Examples

```json
{
  "id": "potion_health",
  "name": "Health Potion",
  "type": "consumable",
  "effect": "heal",
  "value_min": 20,
  "value_max": 30,
  "value": 25,
  "description": "Restores 20-30 HP when consumed."
}
```

```json
{
  "id": "antidote",
  "name": "Antidote",
  "type": "consumable",
  "effect": "cure_poison",
  "value": 15,
  "description": "Cures poison status effects."
}
```

---

## Spell

**File:** `spells/spells.json`

Spells that characters can learn and cast. Spells are split into two variants: **damage spells** (with `damage_min`/`damage_max`) and **healing spells** (with `heal_min`/`heal_max`). A spell record uses one variant or the other, never both.

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"fireball"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"spell"` |
| `school` | string | Yes | Magic school (see below) |
| `mp_cost` | int | Yes | Mana required to cast |
| `damage_min` | int | Cond. | Minimum damage (damage spells only) |
| `damage_max` | int | Cond. | Maximum damage (damage spells only) |
| `heal_min` | int | Cond. | Minimum healing (healing spells only) |
| `heal_max` | int | Cond. | Maximum healing (healing spells only) |
| `range` | int | Yes | Cast range in tiles (0 = self/adjacent) |
| `target` | string | Yes | Targeting mode (see below) |
| `level_required` | int | Yes | Minimum character level to learn this spell |
| `description` | string | Yes | Flavor text |

### Magic Schools

| School | Description |
|---|---|
| `destruction` | Offensive elemental magic (fire, ice, lightning). Deals damage to enemies. |
| `restoration` | Healing and recovery magic. Restores HP and cures ailments. |
| `holy` | Divine magic. Deals damage to enemies, especially undead. |

### Target Types

| Target | Description |
|---|---|
| `single` | Targets a single enemy |
| `single_ally` | Targets a single party member |
| `all_enemies` | Targets all enemies in the encounter |
| `self` | Only targets the caster |

### Damage Spell Example

```json
{
  "id": "fireball",
  "name": "Fireball",
  "type": "spell",
  "school": "destruction",
  "mp_cost": 8,
  "damage_min": 10,
  "damage_max": 18,
  "range": 3,
  "target": "single",
  "level_required": 1,
  "description": "Hurls a ball of fire at a single enemy."
}
```

### Healing Spell Example

```json
{
  "id": "heal",
  "name": "Heal",
  "type": "spell",
  "school": "restoration",
  "mp_cost": 6,
  "heal_min": 15,
  "heal_max": 25,
  "range": 0,
  "target": "single_ally",
  "level_required": 1,
  "description": "Restores health to a single ally."
}
```

---

## Enemy

**File:** `enemies/encounters.json`

Defines an enemy type with stats, rewards, and loot.

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"goblin"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"enemy"` |
| `level` | int | Yes | Enemy difficulty level |
| `hp` | int | Yes | Hit points |
| `mp` | int | Yes | Mana points (0 if enemy cannot cast) |
| `strength` | int | Yes | Physical attack power |
| `defense` | int | Yes | Damage reduction |
| `agility` | int | Yes | Affects turn order and dodge |
| `xp_reward` | int | Yes | Experience points awarded on defeat |
| `gold_reward` | object | Yes | Gold dropped. Contains `min` and `max` keys for a random range. |
| `loot_table` | array | Yes | Array of consumable `id` strings dropped on defeat. May be empty. |
| `description` | string | Yes | Flavor text |

### Example

```json
{
  "id": "goblin",
  "name": "Goblin",
  "type": "enemy",
  "level": 1,
  "hp": 15,
  "mp": 0,
  "strength": 5,
  "defense": 2,
  `agility`: 8,
  "xp_reward": 25,
  "gold_reward": { "min": 5, "max": 15 },
  "loot_table": ["potion_health"],
  "description": "A small, cunning creature that lurks in dark places."
}
```

---

## Dungeon

**File:** `dungeons/dungeon_01.json` (one file per dungeon)

Defines a dungeon with floor layout data and encounter tables.

### Top-Level Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier (e.g., `"dungeon_01"`) |
| `name` | string | Yes | Display name |
| `type` | string | Yes | Always `"dungeon"` |
| `floors` | int | Yes | Total number of floors |
| `difficulty` | int | Yes | Overall difficulty rating (1 = easy, higher = harder) |
| `description` | string | Yes | Flavor text |
| `floor_data` | array | Yes | Array of floor configuration objects (see below) |
| `encounter_tables` | object | Yes | Weighted encounter tables by difficulty tier |

### Floor Data Fields

Each object in `floor_data` defines a single floor of the dungeon:

| Field | Type | Required | Description |
|---|---|---|---|
| `floor` | int | Yes | Floor number (1-indexed) |
| `width` | int | Yes | Grid width in tiles |
| `height` | int | Yes | Grid height in tiles |
| `encounter_rate` | float | Yes | Probability of an encounter per step (0.0-1.0) |
| `enemy_pool` | array | Yes | Array of enemy `id` strings that can appear on this floor |
| `music` | string | Yes | Music track key played on this floor |

### Encounter Tables

`encounter_tables` is an object with difficulty tiers as keys (`"easy"`, `"medium"`, `"hard"`). Each tier contains an array of possible encounters with weighted selection:

| Field | Type | Description |
|---|---|---|
| `enemies` | array | Array of enemy `id` strings in this encounter |
| `weight` | int | Relative probability weight. Higher = more likely. Selection is proportional: a weight of 60 vs 40 means 60% vs 40% chance. |

The system selects an encounter by summing all weights in a tier and picking randomly proportional to each entry's weight.

### Example

```json
{
  "id": "dungeon_01",
  "name": "The Goblin Caves",
  "type": "dungeon",
  "floors": 3,
  "difficulty": 1,
  "description": "A network of caves infested with goblins and other vermin.",
  "floor_data": [
    {
      "floor": 1,
      "width": 10,
      "height": 10,
      "encounter_rate": 0.15,
      "enemy_pool": ["goblin", "slime"],
      "music": "ambient_caves"
    },
    {
      "floor": 2,
      "width": 12,
      "height": 12,
      "encounter_rate": 0.25,
      "enemy_pool": ["goblin", "skeleton"],
      "music": "ambient_caves"
    },
    {
      "floor": 3,
      "width": 14,
      "height": 14,
      "encounter_rate": 0.35,
      "enemy_pool": ["skeleton", "goblin"],
      "music": "ambient_caves_deep"
    }
  ],
  "encounter_tables": {
    "easy": [
      { "enemies": ["goblin"], "weight": 60 },
      { "enemies": ["slime"], "weight": 40 }
    ],
    "medium": [
      { "enemies": ["goblin", "goblin"], "weight": 40 },
      { "enemies": ["skeleton"], "weight": 30 },
      { "enemies": ["goblin", "slime"], "weight": 30 }
    ],
    "hard": [
      { "enemies": ["skeleton", "goblin"], "weight": 50 },
      { "enemies": ["skeleton", "skeleton"], "weight": 30 },
      { "enemies": ["goblin", "goblin", "slime"], "weight": 20 }
    ]
  }
}
```

---

## Adding New Records

To add a new record to the game:

1. **Choose the correct category directory** under `packs/<pack_id>/records/`. Valid categories are: `classes`, `items`, `spells`, `enemies`, `dungeons`.
2. **Choose the correct file.** Use the existing files to determine where your record belongs:
   - Character classes go in `classes/classes.json`
   - Weapons and armor go in `items/weapons.json`
   - Consumables go in `items/consumables.json`
   - Spells go in `spells/spells.json`
   - Enemies go in `enemies/encounters.json`
   - Dungeons go in `dungeons/dungeon_<NN>.json`
3. **Append your record** to the JSON array in the file. Use the same `type` field as existing records in that file.
4. **Ensure the `id` is globally unique** across all packs. `DataRegistry` indexes records by `id` into a flat cache, so duplicate IDs will silently override.
5. **Validate your JSON** before launching. A parse error will log a warning and skip the file.

For overriding existing records, see [Pack Priority & Override System](mod-pack-system.md#pack-priority--override-system).

# Party & Character System

## Party Structure

The party is stored in `GameManager.party`, an `Array[Dictionary]` holding up to **4** character records.

- Each character is a **plain Dictionary**, not a class instance, for easy JSON serialization and save-file compatibility.
- The maximum party size of 4 is enforced by the `PartyDisplay` UI.
- Any modification to the party array emits `GameManager.party_changed`.

```gdscript
# Access the party
var party: Array[Dictionary] = GameManager.party

# Get a specific member
var member: Dictionary = GameManager.get_party_member(0)

# Listen for changes
GameManager.party_changed.connect(_on_party_changed)
```

## Character Record Schema

Each character dictionary contains the following fields:

```gdscript
{
    "id": "warrior_01",          # Unique ID string
    "name": "Roland",            # Display name
    "class_id": "warrior",       # Reference to class record
    "level": 1,                  # Current level

    # Vitals
    "hp": 45,                    # Current hit points
    "max_hp": 45,                # Maximum hit points
    "mp": 10,                    # Current mana points
    "max_mp": 10,                # Maximum mana points

    # Combat stats
    "strength": 12,              # Physical damage, melee weapon requirements
    "defense": 10,               # Physical damage reduction
    "vitality": 10,              # HP bonus, HP regen, poison resistance
    "energy": 6,                 # Spell power, MP bonus, magic item requirements
    "agility": 8,                # Turn order, evasion, critical hit chance
    "luck": 6,                   # Loot quality, critical hits, rare encounters

    # Progression
    "xp": 0,                     # Current experience points
    "xp_to_next": 100,           # XP needed for next level

    # Loadout
    "equipment": {
        "main_hand": "sword_iron",   # Main hand weapon
        "off_hand": "shield_wood",   # Off hand weapon/shield
        "head": "",                  # Headgear
        "body": "armor_leather",     # Body armor
        "legs": "",                  # Leg armor
        "accessory": "",             # Accessory
    },
    "spells": [],                # Array of spell ID strings
    "skills": ["power_strike"],  # Array of skill ID strings
}
```

## Stat Definitions

| Stat | Key | Effects |
|------|-----|---------|
| **HP** | `hp` | Hit points. When reduced to 0, the character is incapacitated and cannot act in combat. |
| **MP** | `mp` | Mana points. Spent to cast spells. Regenerates between encounters (TBD). |
| **Strength** | `strength` | Determines physical attack damage and which melee weapons the character can equip. |
| **Defense** | `defense` | Reduces incoming physical damage. |
| **Vitality** | `vitality` | Contributes to max HP, governs HP regeneration rate, and provides resistance to poison and similar status effects. |
| **Energy** | `energy` | Determines spell damage and power, contributes to max MP, and gates magic item requirements. |
| **Agility** | `agility` | Determines turn order initiative in combat, increases evasion chance, and contributes to critical hit chance. |
| **Luck** | `luck` | Affects loot quality, critical hit chance, and the chance to encounter rare enemies or events. |

## Default Party

The game starts with four characters initialized in `GameManager._init_default_party()`:

| Slot | Name | Class ID | Role | Key Stats |
|------|------|----------|------|-----------|
| 1 | Roland | `warrior` | Tank / Melee DPS | High STR, DEF, VIT |
| 2 | Elara | `mage` | Ranged DPS / Blaster | High ENE, MP pool |
| 3 | Aldric | `cleric` | Healer / Support | High VIT, balanced stats |
| 4 | Shade | `thief` | DPS / Utility | High AGI, LCK |

### Starting Equipment

| Character | Main Hand | Off Hand | Body | Other |
|-----------|-----------|----------|------|-------|
| Roland | iron sword | wood shield | leather armor | — |
| Elara | wood staff | — | cloth robe | — |
| Aldric | iron mace | wood shield | chain armor | — |
| Shade | steel dagger | — | leather armor | — |

### Starting Skills & Spells

| Character | Skills | Spells |
|-----------|--------|--------|
| Roland | `power_strike` | — |
| Elara | — | `fireball`, `heal` |
| Aldric | — | `heal`, `smite` |
| Shade | `backstab`, `pick_lock` | — |

## Equipment System

Each character has **6 equipment slots**:

| Slot | Key | Examples |
|------|-----|----------|
| Main Hand | `main_hand` | Swords, daggers, maces, staves |
| Off Hand | `off_hand` | Shields, off-hand weapons |
| Head | `head` | Helmets, hoods, crowns |
| Body | `body` | Armor, robes |
| Legs | `legs` | Greaves, leggings |
| Accessory | `accessory` | Rings, amulets |

### How It Works

- Items reference their compatible slot via a `"slot"` field in the item record.
- **Equipping**: validate that the character meets the item's stat requirements, then swap the item into the slot. If a different item was equipped, it returns to inventory.
- **Unequipping**: remove the item from the slot and return it to inventory.
- **Stat bonuses** from equipped items are added to the character's base stats during combat calculations (not stored directly on the character record).

## Level-Up System

### XP Curve

The XP required for the next level follows a power curve:

```
xp_to_next = base_xp * (level ^ exponent)
```

With typical values of `base_xp = 100` and `exponent = 1.5`:

| Level | XP to Next | Total XP |
|-------|-----------|----------|
| 1 → 2 | 100 | 100 |
| 2 → 3 | 283 | 383 |
| 3 → 4 | 520 | 903 |
| 4 → 5 | 800 | 1,703 |

### On Level Up

1. Each stat increases by the `stat_growth` values defined in the character's class record.
2. HP and MP maximums increase based on class growth rates (may be fixed or randomized within a range — TBD).
3. Current HP and MP may be fully restored on level up (TBD).

### Limits

- Max level is TBD (likely 20 or 50).

## Party Management API

These functions are available on `GameManager`:

```gdscript
get_party_member(index: int) -> Dictionary
```
Returns the character dictionary at the given party index, or an empty dictionary if the index is out of bounds.

```gdscript
heal_party_member(index: int, amount: int) -> void
```
Restores `amount` HP to the character at `index`, clamped to `max_hp`. Emits `party_changed`.

```gdscript
damage_party_member(index: int, amount: int) -> void
```
Reduces `amount` HP from the character at `index`, clamped to a minimum of 0. Emits `party_changed`.

```gdscript
is_party_alive() -> bool
```
Returns `true` if any party member has HP > 0, `false` if the entire party is incapacitated.

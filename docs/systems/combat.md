# Combat System

> **Design Document -- Not Yet Implemented**
> This document describes the planned combat system. The `GameState.COMBAT` state exists in `GameManager` but no combat logic is currently in the codebase.

## Overview

Turn-based combat triggered by random encounters while exploring dungeons. Party of 4 vs. 1-4 enemies. Classic blobber-style: the player issues commands for each party member, then all actions resolve in speed order.

## Encounter Trigger

Each dungeon floor has an `encounter_rate` (e.g., `0.15` = 15% per step). On each successful player movement step:

1. Roll a random value against `encounter_rate`
2. If triggered: select an encounter from the floor's `encounter_tables` based on difficulty tier
3. Difficulty tier is selected based on floor number and party average level
4. `GameManager.state` transitions from `EXPLORING` to `COMBAT`

Movement commands (`try_move`) would return `false` during combat, preventing movement until the encounter ends. The existing `TurnManager._input()` guard on `GameManager.current_state != EXPLORING` already blocks movement input during other states.

## Combat Flow

### 1. Encounter Start

- Display enemy group on screen
- Show combat UI (replaces exploration UI)
- Transition `GameManager.state` to `COMBAT`

### 2. Command Phase

Player selects an action for each living party member (index 0-3 in `GameManager.party`):

| Command | Description |
|---------|-------------|
| **Attack** | Physical attack targeting one enemy |
| **Magic** | Cast a spell, costs MP. Uses character's `spells` array |
| **Defend** | Reduce damage taken this round by 50% |
| **Item** | Use a consumable from inventory |
| **Flee** | Attempt to escape. Success chance based on party agility |

### 3. Resolution Phase

Actions execute in speed order:

1. Calculate **initiative** for each combatant: `agility + random(0, agility)`
2. Sort all combatants (party + enemies) by initiative, highest first
3. Execute each action in order
4. Check for defeated enemies or party members (HP <= 0)

### 4. End Check

| Condition | Result |
|-----------|--------|
| All enemies HP ≤ 0 | **Victory** -- award XP, gold, loot |
| All party members HP ≤ 0 | **Game Over** |
| Otherwise | Return to Command Phase |

## Damage Formula

```
base_damage = attacker.strength * weapon_multiplier
reduction   = defender.defense * armor_multiplier
raw_damage  = base_damage - reduction
final_damage = max(1, raw_damage + random(-2, 2))
```

### Critical Hit

- Chance: `attacker.agility * 0.5`% per attack
- Damage multiplier: 1.5×
- Applies to physical attacks only (planned)

### Magical Damage

- Uses `attacker.energy` instead of `attacker.strength`
- Ignores physical `defense` stat
- Reduced by target's `energy` defense stat (planned)

## Spell Resolution

Spells are referenced by ID from each character's `spells` array (e.g., `"fireball"`, `"heal"`, `"smite"`).

1. Check MP cost against caster's current MP
2. Deduct MP
3. Apply spell effects based on spell record fields:

| Field | Description |
|-------|-------------|
| `damage_min` / `damage_max` | Damage range (damage spells) |
| `heal_min` / `heal_max` | Heal range (heal spells) |
| `target_type` | `single`, `single_ally`, `all_enemies`, `self` |

### Damage Spells

- Roll damage between `damage_min` and `damage_max`
- Reduced by target's energy defense
- Example: `fireball` (mage), `smite` (cleric)

### Heal Spells

- Roll heal between `heal_min` and `heal_max`
- Applied to target ally (or self)
- Cannot exceed `max_hp`
- Example: `heal` (mage, cleric)

### Future: Status Effects

Planned additions to spell effects:
- Poison (damage over time)
- Stun (skip turn)
- Buff (increase stats temporarily)
- Debuff (decrease enemy stats temporarily)

## XP and Loot Distribution

### XP

- Sum of all defeated enemies' `xp_reward`
- Split equally among living party members
- Remainder XP is lost (no fractional XP)

### Gold

- Each enemy rolls `gold_reward.min` to `gold_reward.max`
- Total gold added to party gold pool

### Loot

- Each enemy rolls against its `loot_table`
- ~10% chance per loot table entry
- Loot items added to party inventory

### Level Up

- Check each character: `xp >= xp_to_next`
- Apply stat growth based on class
- Recalculate `xp_to_next` for next level
- Check again in case of large XP gains (multi-level)

## Default Party

The party is defined in `GameManager._init_default_party()` (`scripts/core/game_manager.gd`):

| Index | Name | Class | HP | MP | STR | DEF | ENG | AGI |
|-------|------|-------|----|----|-----|-----|-----|-----|
| 0 | Roland | warrior | 45 | 10 | 12 | 10 | 6 | 8 |
| 1 | Elara | mage | 25 | 40 | 4 | 4 | 14 | 8 |
| 2 | Aldric | cleric | 35 | 30 | 8 | 8 | 10 | 6 |
| 3 | Shade | thief | 30 | 15 | 8 | 6 | 6 | 14 |

Each character has class-specific spells, skills, and starting equipment stored in their party dictionary.

## Enemy AI (Planned)

Simple behavior patterns assigned per enemy type:

| Pattern | Behavior |
|---------|----------|
| **Aggressive** | Always attacks the party member with lowest current HP |
| **Defensive** | Attacks a random party member; 20% chance to defend instead |
| **Healer** _(future)_ | Heals wounded allies; attacks if all allies are full HP |
| **Boss** | Uses special attacks on a rotation; phases at HP thresholds |

Enemy definitions would include: name, HP, stats, XP reward, gold reward, loot table, AI pattern.

## Combat UI (Planned)

| Area | Content |
|------|---------|
| **Top** | Enemy display area -- sprite/model for each enemy, HP bar |
| **Middle** | Battle viewport (3D view or combat scene) |
| **Bottom-left** | Party HP/MP display for all 4 members |
| **Bottom-right** | Command menu -- per-character action selection |
| **Overlay** | Battle log -- scrolling text of action results |

The combat UI would replace the exploration `ActionBar` during `COMBAT` state. The existing state-based UI switching in `TurnManager._input()` provides the hook for this transition.

## Integration Points

### Existing Code

- `GameManager.GameState.COMBAT` enum value already defined
- `TurnManager._input()` already gates on `current_state != EXPLORING`
- `GameManager.party` array holds all character data (stats, HP, MP, spells)
- `GameManager.damage_party_member()` and `heal_party_member()` already exist
- `GameManager.is_party_alive()` checks if any member has HP > 0

### Needed Additions

- Encounter system (per-floor encounter tables, trigger logic)
- Enemy data definitions (stats, AI, loot)
- Combat state machine (command phase, resolution phase, end check)
- Combat UI scene and scripts
- Spell/equipment data registry
- Damage calculation functions
- XP/loot/level-up logic

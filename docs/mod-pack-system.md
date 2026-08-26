# Mod Pack System

BlobProject stores all game content in **mod packs** under the `packs/` directory. The base game ships with a `base` pack, but any number of packs can be added. Packs are loaded automatically by `DataRegistry` at startup, and records are merged into a single flat cache using ID-based override rules.

---

## Pack Structure

```
packs/
└── <pack_id>/
    ├── pack.json              # Pack metadata
    └── records/
        ├── classes/
        │   └── classes.json
        ├── items/
        │   ├── weapons.json
        │   └── consumables.json
        ├── spells/
        │   └── spells.json
        ├── enemies/
        │   └── encounters.json
        └── dungeons/
            └── dungeon_01.json
```

Only the category directories that contain data need to exist. A pack can provide any subset of categories — for example, a mod that only adds weapons only needs `records/items/weapons.json`.

---

## pack.json Schema

Every pack must have a `pack.json` in its root directory.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique pack identifier. Must match the folder name. |
| `name` | string | Yes | Human-readable pack name |
| `version` | string | Yes | Semantic version string (e.g., `"0.1.0"`) |
| `description` | string | Yes | Brief description of the pack's contents |
| `author` | string | Yes | Pack author or team name |
| `dependencies` | array | Yes | Array of pack IDs this pack depends on. Empty array `[]` for no dependencies. |

### Example

```json
{
  "id": "base",
  "name": "BlobProject Base Content",
  "version": "0.1.0",
  "description": "Core game content for BlobProject",
  "author": "BlobProject Team",
  "dependencies": []
}
```

---

## How DataRegistry Loads Packs

`DataRegistry` (located at `scripts/data/data_registry.gd`) is an autoloaded `Node` that loads all game data at startup.

### Loading Process

1. **Scan category directories.** `DataRegistry` iterates through a hardcoded list of categories: `items`, `enemies`, `classes`, `dungeons`, `spells`.
2. **Read all `.json` files** in each category directory. Non-JSON files and subdirectories are ignored.
3. **Parse JSON.** Each file is parsed as either a JSON array or a single JSON object. Both formats are accepted.
4. **Index by `id`.** Every record that has an `id` field is stored in the `_cache` dictionary keyed by that `id`. If a record's `id` matches an existing entry, the later record silently overrides the earlier one.
5. **Emit signals.** `data_loaded` is emitted after each category completes. `all_data_loaded` is emitted after all categories are processed.

### API

| Method | Description |
|---|---|
| `get_record(record_id: String) -> Dictionary` | Returns the record for a given `id`, or an empty dictionary if not found. |
| `get_records_by_category(category: String) -> Array[Dictionary]` | Returns all records whose `type` field matches the given category string. |
| `has_record(record_id: String) -> bool` | Returns `true` if a record with the given `id` exists. |
| `get_all_ids() -> Array[String]` | Returns all cached record IDs. |

---

## Pack Priority & Override System

### How It Works

- Multiple packs can define records with the same `id`.
- Pack loading order determines priority: **last loaded wins**. If a mod pack is loaded after the base pack, its records override any base records with the same `id`.
- Records with unique `id` values are simply added to the cache with no conflict.

### Use Cases

| Scenario | How It Works |
|---|---|
| Override a base item | Create a record with the same `id` in your mod pack's `items/weapons.json`. Your version replaces the base version. |
| Add new items | Use a unique `id` that doesn't exist in any other pack. |
| Modify enemy stats | Re-define the enemy `id` in your mod pack with adjusted stat values. |
| Replace a dungeon | Re-define the dungeon `id` with new floor data and encounter tables. |

### Important Notes

- Overrides are **not merged** — the entire record is replaced. You cannot partially override a record; you must provide the complete record with your desired values.
- Override behavior is **silent** — there is no warning or error when an ID collision occurs.
- `get_records_by_category` queries by the `type` field, not by file path, so overridden records will appear in the correct category regardless of which pack defined them.

---

## Creating a New Mod Pack

### Step-by-Step

1. **Create the pack folder.** Add a new directory under `packs/` using a lowercase, underscore-separated ID:

   ```
   packs/my_awesome_mod/
   ```

2. **Create `pack.json`** with your pack metadata:

   ```json
   {
     "id": "my_awesome_mod",
     "name": "My Awesome Mod",
     "version": "0.1.0",
     "description": "Adds cool new stuff to the game",
     "author": "YourName",
     "dependencies": []
   }
   ```

3. **Create the `records/` subdirectory** and any category folders you need:

   ```
   packs/my_awesome_mod/
   ├── pack.json
   └── records/
       ├── items/
       ├── spells/
       └── enemies/
   ```

4. **Add JSON files** following the schemas documented in [data-formats.md](data-formats.md). Each file must be a valid JSON array of record objects or a single record object.

5. **Launch the game.** `DataRegistry` will automatically detect and load your pack's files on startup. Check the console output for any JSON parse warnings.

### Directory Layout Examples

A mod that only adds weapons:

```
packs/my_awesome_mod/
├── pack.json
└── records/
    └── items/
        └── weapons.json
```

A mod that adds new enemies and overrides an existing dungeon:

```
packs/my_awesome_mod/
├── pack.json
└── records/
    ├── enemies/
    │   └── encounters.json
    └── dungeons/
        └── dungeon_01.json
```

---

## Dependencies (Future Design)

The `dependencies` field in `pack.json` is defined but not yet enforced by the loading system. The intended behavior is:

- `dependencies` is an array of pack `id` strings that must be loaded before this pack.
- Before loading, the system should validate that all listed dependencies exist.
- If a required dependency is missing, loading should fail with a clear error message.
- Dependencies are checked recursively — if pack A depends on pack B which depends on pack C, all three must be present.

### Example

```json
{
  "id": "expansion_pack",
  "name": "Dark Depths Expansion",
  "version": "1.0.0",
  "description": "Deep dungeon content for advanced players",
  "author": "Expansion Team",
  "dependencies": ["base"]
}
```

This would require the `base` pack to be present before `expansion_pack` can be loaded.

---

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Pack not loading | Missing or malformed `pack.json` | Ensure `pack.json` exists in the pack root and is valid JSON with all required fields |
| Records not appearing | JSON parse error in record file | Check the console for `DataRegistry` warnings. Validate JSON syntax. |
| Records overriding unexpectedly | ID collision with another pack | Verify that all `id` values are globally unique across packs, or verify the override is intended. |
| Category directory not scanned | Directory name doesn't match expected categories | Valid category names: `items`, `enemies`, `classes`, `dungeons`, `spells` |

# BlobProject

**A moddable grid-based first-person dungeon crawler**

---

| Key | Value |
|-----|-------|
| Engine | Godot 4.4+ |
| Language | GDScript |
| Data | JSON |
| License | GPLv3 |
| Status | **Alpha 0.2.2-alpha** |

---

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/BlobProject.git
   cd BlobProject
   ```
2. Open the project folder in **Godot 4.4** or later.
3. Press **Play** (F5) to launch.

The game starts immediately with a four-character party in a test dungeon. Move with **W/S** or arrow keys, turn with **Q/E**, and strafe with **A/D**.

---

## Table of Contents

| Document | Description |
|----------|-------------|
| [docs/architecture.md](architecture.md) | System architecture, autoloads, scene tree, data flow, signal map |
| [docs/data-formats.md](data-formats.md) | All JSON record schemas and field references |
| [docs/mod-pack-system.md](mod-pack-system.md) | Pack structure, loading, dependencies, and swapping |
| [docs/settings.md](settings.md) | SettingsManager API, config file format, defaults |
| [docs/systems/turn-and-action.md](systems/turn-and-action.md) | Turn loop, action pattern, input mapping |
| [docs/systems/grid-world.md](systems/grid-world.md) | 3D grid, movement, camera, dungeon rendering |
| [docs/systems/party-and-characters.md](systems/party-and-characters.md) | Party management, character stats, equipment |
| [docs/systems/combat.md](systems/combat.md) | Turn-based combat system design |
| [docs/systems/inventory.md](systems/inventory.md) | Inventory and equipment system design |
| [docs/systems/dialogue.md](systems/dialogue.md) | NPC dialogue system design |
| [docs/systems/save-load.md](systems/save-load.md) | Game persistence design |
| [docs/systems/procedural-dungeons.md](systems/procedural-dungeons.md) | Dungeon generation design |

---

## Modding Philosophy

BlobProject is built around a **data-driven** design. All game content lives in JSON files under `packs/`, separated from the engine code:

- **All content is JSON.** Items, enemies, spells, classes, dungeons, and encounters are defined as JSON records. No GDScript changes are needed to add new content.
- **Swapable packs.** Content is organised into self-contained packs (`packs/base/`, `packs/dlc/`, etc.). Packs declare metadata, version, and dependencies in a `pack.json` manifest. Swapping a pack replaces the content it provides.
- **Open format.** JSON schemas are documented and simple. Anyone can author a new pack with a text editor.

To add a new enemy, create a JSON record in a pack's `records/enemies/` directory. To create an entirely new dungeon, write a dungeon JSON and drop it into `records/dungeons/`. The engine picks it up automatically.

---

## License

BlobProject is released under the **GNU General Public License v3.0**. See [LICENSE](../LICENSE) for the full text.

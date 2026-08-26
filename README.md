# BlobProject

A moddable and extensible grid-based first-person dungeon crawler — old-school blobber party, turn-based movement and combat.

## Status

**Alpha 0.2.3-alpha** — Data-driven party and dungeons, debug logging, data validation.

## Requirements

- [Godot Engine 4.4+](https://godotengine.org/download) (Standard version)

## Getting Started

1. Download and install [Godot 4.4+](https://godotengine.org/download)
2. Clone this repository
3. Open `project.godot` in the Godot editor
4. Press **F5** to run

## Controls

| Key | Action |
|-----|--------|
| W / Up Arrow | Move forward |
| S / Down Arrow | Move backward |
| Q / Left Arrow | Turn left |
| E / Right Arrow | Turn right |
| A | Strafe left |
| D | Strafe right |

## Project Structure

```
BlobProject/
├── addons/                  # Plugins (modding, data tools)
├── packs/                   # Mod packs (content definitions)
│   └── base/                # Core game content
│       ├── pack.json        # Pack metadata
│       └── records/         # JSON data (items, enemies, classes, etc.)
├── scenes/                  # Godot scene files
│   ├── main.tscn            # Main game scene
│   ├── ui/                  # UI scenes
│   └── world/               # 3D world scenes
├── scripts/                 # GDScript source code
│   ├── core/                # Game loop, state, turn system
│   ├── data/                # Data loading and registry
│   ├── ui/                  # UI controllers
│   └── world/               # World/grid management
├── project.godot            # Godot project file
├── VERSION                  # Current version string
└── LICENSE                  # GPLv3
```

## Modding

All game content is defined in JSON files under `packs/base/records/`. To create a mod:

1. Create a new folder under `packs/` (e.g., `packs/my_mod/`)
2. Add a `pack.json` with your mod metadata
3. Add JSON record files under `records/`
4. Records override base game entries by matching `id` fields

## License

This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

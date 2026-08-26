# Settings System

## Overview

`SettingsManager` (`scripts/core/settings_manager.gd`) is an autoload singleton that manages persistent user settings. It uses Godot's `ConfigFile` class for INI-style storage.

- **Dev builds** store the config at `res://settings.cfg` (inside the project, useful for version control)
- **Export builds** store the config at `user://settings.cfg` (in the user data directory)

On `_ready()`, the manager loads existing settings (falling back to defaults for any missing keys), writes the config file if it doesn't exist yet, then applies display and audio settings to the engine.

## Config File Format

The config file is an INI-style file managed by Godot's `ConfigFile` class. It contains three sections:

```ini
[layout]
viewport_ratio=2.0
party_panel_ratio=1.0
action_bar_ratio=1.0
viewport_min_height=200
action_bar_min_height=40
party_panel_min_width=200

[display]
fullscreen=false
vsync=true
msaa=0
resolution_scale=1.0

[audio]
master_volume=80
music_volume=70
sfx_volume=80
```

## API Reference

### Signal

| Signal | Parameters | Description |
|--------|------------|-------------|
| `settings_changed` | `section: String` | Emitted by every setter after saving. `section` is one of `"layout"`, `"display"`, or `"audio"`. |

### Layout

```gdscript
get_layout(key: String) -> Variant
```
Returns the value for `key` from the layout section, or `null` if the key doesn't exist.

```gdscript
set_layout(key: String, value: Variant) -> void
```
Sets the value for `key` in the layout section, saves to disk, and emits `settings_changed("layout")`.

### Display

```gdscript
get_display(key: String) -> Variant
```
Returns the value for `key` from the display section.

```gdscript
set_display(key: String, value: Variant) -> void
```
Sets the value for `key` in the display section, saves to disk, calls `apply_display()`, and emits `settings_changed("display")`.

### Audio

```gdscript
get_audio(key: String) -> Variant
```
Returns the value for `key` from the audio section.

```gdscript
set_audio(key: String, value: Variant) -> void
```
Sets the value for `key` in the audio section, saves to disk, calls `apply_audio()`, and emits `settings_changed("audio")`.

### Core Methods

```gdscript
save_settings() -> void
```
Writes the current in-memory state of all three sections to the config file on disk.

```gdscript
load_settings() -> void
```
Reads the config file from disk and populates the in-memory dictionaries. Any key present in the defaults but missing in the file retains its default value. If the file doesn't exist or can't be loaded, defaults are used unchanged.

```gdscript
apply_display() -> void
```
Applies the current display settings to the engine:
- Sets window mode to fullscreen or windowed.
- Sets vsync mode to enabled or disabled.
- Sets MSAA level on the root viewport (0, 2x, 4x, or 8x).

```gdscript
apply_audio() -> void
```
Applies the current master volume to the AudioServer master bus (bus index 0). Converts the 0-100 integer to a dB value via `linear_to_db`. Mutes the bus when volume is 0.

## Default Values

| Section | Key | Default | Type | Description |
|---------|-----|---------|------|-------------|
| layout | `viewport_ratio` | `2.0` | float | Stretch ratio for the 3D viewport in the left VBoxContainer |
| layout | `party_panel_ratio` | `1.0` | float | Stretch ratio for the party panel (right side) |
| layout | `action_bar_ratio` | `1.0` | float | Stretch ratio for the action bar (bottom of left panel) |
| layout | `viewport_min_height` | `200` | int | Minimum pixel height for the 3D viewport |
| layout | `action_bar_min_height` | `40` | int | Minimum pixel height for the action bar |
| layout | `party_panel_min_width` | `200` | int | Minimum pixel width for the party panel |
| display | `fullscreen` | `false` | bool | Whether the game runs in fullscreen |
| display | `vsync` | `true` | bool | Whether vertical sync is enabled |
| display | `msaa` | `0` | int | MSAA sample count (0, 2, 4, or 8) |
| display | `resolution_scale` | `1.0` | float | Resolution scale (reserved for future use) |
| audio | `master_volume` | `80` | int | Master volume, 0-100 |
| audio | `music_volume` | `70` | int | Music volume, 0-100 (reserved for future use) |
| audio | `sfx_volume` | `80` | int | SFX volume, 0-100 (reserved for future use) |

## How Layout Ratios Work

The UI uses a nested container layout:

- The main scene has an `HSplitContainer` dividing the left panel (game view + action bar) from the right panel (party info).
- The left panel is a `VBoxContainer` holding the `ViewportFrame` (3D viewport) and the `BottomBar` (action bar).

Both the `HSplitContainer` and the inner `VBoxContainer` use `SIZE_EXPAND_FILL` with `size_flags_stretch_ratio` to control proportional sizing.

### Split Calculation

The HSplitContainer's `split_offset` is recalculated on every window resize:

```
viewport_pct = viewport_ratio / (viewport_ratio + party_panel_ratio)
split_offset = (container_width * viewport_pct) - container_width
```

With defaults (`viewport_ratio=2.0`, `party_panel_ratio=1.0`):
- `viewport_pct = 2/3 ≈ 0.667`
- The viewport gets roughly 67% of the width, the party panel gets 33%.

### VBox Ratios

Within the left panel, the same formula applies vertically:
- Viewport gets `viewport_ratio / (viewport_ratio + action_bar_ratio)` of the height.
- Default 2:1 gives the viewport 2/3 and the action bar 1/3 of the left panel height.

### Minimum Sizes

The `viewport_min_height`, `action_bar_min_height`, and `party_panel_min_width` values act as floor constraints so that panels never collapse below a usable size at extreme window dimensions.

## Adding New Settings

To add a new setting to an existing section:

1. **Add the default value** to the appropriate dictionary in `settings_manager.gd`:
   ```gdscript
   # Example: add a new key to the display section
   var defaults_display := {
       "fullscreen": false,
       "vsync": true,
       "msaa": 0,
       "resolution_scale": 1.0,
       "my_new_setting": 42,  # <-- add here
   }
   ```

2. **That's it for storage.** The `load_settings()` and `save_settings()` methods iterate over all keys in each dictionary automatically, so the new key is picked up with no further changes.

3. **Read it** using `SettingsManager.get_display("my_new_setting")`.

4. **Write it** using `SettingsManager.set_display("my_new_setting", new_value)`.

5. **React to changes** by connecting to the `settings_changed` signal:
   ```gdscript
   func _ready() -> void:
       SettingsManager.settings_changed.connect(_on_settings_changed)

   func _on_settings_changed(section: String) -> void:
       if section == "display":
           var value = SettingsManager.get_display("my_new_setting")
           # apply the new setting
   ```

To add an entirely new section, create a new `defaults_*` dictionary and add a corresponding `get_*`/`set_*` pair following the same pattern as the existing ones.

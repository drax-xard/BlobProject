Initial project notes:

The idea is to create a moddable and extensible grid-based first-person dungeon crawler, old-school blobber party, turn-based movement and combat. 

A few starting concepts:
1) Both the player party, NPCs and enemies move one step at a time. Each step depends on the player’s input (meaning that enemies and npcs only move when the player moves).
2) Platform-agnostic. Should be playable both on PC (windows/linux/Mac) and mobile. 
3) The main interface should be inspired by old school rpg blobbers, with a first-person “game world” viewport section, a party list section and a section that includes movement, inventory and action buttons.
4) The interface should adapt to both “landscape” (horizontal) and “portrait” (vertical) modes to help with mobile integration.
5) All the content should be editable and mod-friendly. Items, npc, enemies, levels, everything should be defined in an accesible format (xml? Json? Other? tell me what are the best options)
6) If possible, avoid big game engines, please suggest options.
7) Player party of up to 4 characters. Each character has its own stats, equipped gear slots, spells and skills.
8) The game world should have both exploration dungeons with increasing danger levels and peaceful “hub towns” with merchants, quest-givers and other non-combat content.
9) Suggest where procedural generation could help with content creation.
10) Include the ability to swap entire “mod-packs” to create significantly different experiences.
11) Use the best development and versioning practices to promote good, modular, bug-free code.

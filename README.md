# Zone Loading System

This is a dynamic zone loading system for Godot you can use in your games. This allows to have an infinite game world without loading screen (after the initial loading).

![Test image](screenshots/world.png)

- Every zone is inside a trigger area.
- When the player enters a trigger area, the zone is loaded and attached to the world
- Connected zones are zones that are overlapping the current zone, they are detected automatically.
- All connected zones are automatically loaded and instanced by a background thread, so that attaching the zone to the tree is very fast.
- When leaving a zone, it is detached from the tree but stays in memory. Zones that are not current or connected are freed from memory.

## pros
- No loading screen during the game.
- Works for 2D and 3D.
- The next zone is loading in background mode while the player explores the current map.
- Connected zones are automatically detected.

## cons
- Need to manually split the game world into zones and set triggers.
- Zones need to be carfully designed so that they are occluded when not visible (needs turns and twists).

Please report issues and feel free to contribute and help me improve this demo :)

![Test image](screenshots/demo.png)

# Zone Loading System

This is a dynamic zone loading system for Godot you can use in your games, it can be used in 2D or 3D.
This system allows to have an infinite game world without loading screen (after the initial loading).

![Test image](screenshots/world.png)

- Every zone sits inside a trigger area that completely englobes the zone.
- When the player enters a trigger area, the corresponding zone is loaded (if not already) and attached to the world.
- When the player exits the area, the zone is removed from the tree but stays in memory, allowing to go back and forth quickly between the two zones. When the zone is not directly connected to an area the player is in, it is then freed from memory and unloaded.
- Connected zones are zones that are overlapping the current zone, this is detected automatically, no need to register the connections.
- Zones that are connected to the current zone(s) are automatically loaded in memory and instanced in background, so that they are ready when the player enters a new zone.

## pros
- No loading screen during the game.
- Works for 2D and 3D.
- The next zone is loading in background mode while the player explores the current map.
- Connected zones are automatically detected.

## cons
- Need to manually split the game world into zones and set triggers.
- Zones need to be carfully designed so that they are occluded when not visible (needs turns and twists).

## Contribute

Please report any issues here: https://godotforums.org/discussion/23868/zone-loading-system
You are free to contribute and improve this demo and do whatever you want with the code, this is a [Creative Commons](https://creativecommons.org/publicdomain/zero/1.0/)

![Test image](screenshots/demo.png)

Portal Co-op v46

This build addresses the immediate v45 issues:
- Host / Join / Leave buttons restored
- World stays hidden until a session is active
- Host spawns immediately on host start
- Client world appears only after connection/session becomes active
- Local player camera is claimed from the spawned local player

Important:
- Steam transport is still isolated in SteamNet.gd and the active validation transport is the demo ENet path
- This build prioritizes working lobby/world lifecycle and spawn/camera behavior
- MultiplayerSynchronizer remains in the player scene but is not used for active movement sync in v46


v47 note:
- MultiplayerSynchronizer is re-enabled for movement sync.
- Player nodes are still created deterministically from SessionState inside the persistent root.
- Synchronizer publishing is gated until all peers report their player nodes exist.


v50 note:
- Added a scrollable Steam lobby list with Join buttons to the right of the menu buttons.
- Hardcoded SteamMultiplayerPeer host creation to the known-good create_host(0, []) path first, with conservative fallbacks.
- Hardcoded SteamMultiplayerPeer client creation to create_client(host_steam_id, 0) first, then create_client(host_steam_id).
- Included steam_appid.txt with 480 for validation.


v51 note:
- This build switches SteamMultiplayerPeer calls to the 1-argument signatures your editor build expects.
- Host now uses create_host(0).
- Client now uses create_client(host_steam_id).


v52 note:
- Joining a Steam lobby no longer shows the room immediately.
- The room/session UI now appears only after the Godot multiplayer connection is established.


v53 note:
- Host lobby creation no longer falls through the client join path when Steam reports the local creator as having joined the lobby.
- Lobby browser layout was widened and placeholder text no longer collapses vertically.


v54 note:
- The Steam lobby browser now rebuilds from Steam's current lobby cache and requests metadata before filtering by version/name.
- This is intended to make the lobby you just created show up reliably in the list.


v55 note:
- Removed the invalid getLobbiesList() call and rewrote the lobby browser around callback data and index-based lookup for this GodotSteam build.


v56 note:
- Fixed a Steam lobby browser callback loop that could cause severe system lag after pressing Steam Host.
- Lobby metadata is now requested once per lobby during refresh instead of on every rebuild.


v57 note:
- Steam host now creates PUBLIC lobbies so they are discoverable in the lobby browser. Steam docs indicate friends-only lobbies are not shown in the browser; public lobbies are. citeturn447903search4turn586797search1
- The browser is filtered to lobbies that have your Steam friends in them using the friends API pattern based on friend game/lobby info. citeturn586797search0turn586797search4


v58 M1 note:
- Added the milestone 1 data resource layer for generated levels, themes, catalog data, and per-player progress.
- No generation, interaction, or unlock flow is wired yet in this build.


v58 M2 note:
- Added the image importer for converting source PNG data into a LevelDefinition.
- This build still does not generate runtime level geometry yet.


v58 M3 note:
- Added the first runtime generator pass for building a themed rectangular room and generated tiles from imported level data.
- This milestone does not yet wire the generator into the live holding-room-to-level flow.


v58 M4 note:
- Added host-seeded active session state for generated levels.
- Session state can now seed completed tiles from host progress and reapply them to a generated level root.


v58 M5 note:
- Refined completed tile visuals so completed states are easier to read.
- Completed tiles now show a subtly floating and pulsing glass orb using the source image color.


v58 M6 note:
- Forest and Lava now use the generated-level pipeline.
- Added random-color image assets in 16x16, 32x32, 64x64, and 512x512 sizes.


v58 M6 typed fix note:
- Replaced inferred local variable declarations where practical to avoid warning-as-error type inference failures.


v58 M6 fix 2 note:
- Fixed imported-image loading for export-safe level image usage.
- Fixed GeneratedTile null-node setup issue during generation.


v58 M6 fix 3 note:
- Fixed the remaining LevelImageImporter PNG-load warning.
- Disabled SpringArm collision retraction to reduce/stop jump+forward camera flicker.


v58 M6 more muted note:
- Tile colors were made much more muted than before.
- Forest and Lava theme muting values were increased.


v58 orb size/position fix note:
- Completed orb diameter now matches tile width.
- Completed orb center now sits at the tile top height.


v58 pastel/chalky tile update:
- Tile colors are now softer, more pastel, and more chalky.
- Tile surfaces are more matte.


v58 tile color + orb core update:
- Tile colors keep more body and hue than the last build.
- Completed orbs now have a more opaque inner core inside the translucent shell.


v58 M7 note:
- Added local save/load plumbing for generated-level progress.
- Generated level creation now seeds session tile state from loaded local progress.
- Saving currently happens when leaving the session.


v58 M8 note:
- Added the first playable co-op tile completion loop.
- In generated levels, incomplete tiles in front of the local player can now be highlighted and completed with F.
- Host validates completions and broadcasts them to peers.


v58 M9 note:
- Added a more visible tile highlight and a thrown-orb completion effect.
- Authoritative tile completions now visually read like the player threw an orb into the tile.


v58 M9 highlight/camera polish:
- Highlight now has more of a crosshair look.
- Tile targeting range is shorter.
- Players now show a front cone for facing direction.
- Mouse look and wheel zoom were added.


v58 M9 facing cone fix:
- Replaced the unsupported ConeMesh resource with a CylinderMesh-based cone.


v58 M9 input/targeting/facing fix:
- Right-click mouse look is now hold-to-rotate.
- Facing cone placement was adjusted to be less intrusive.
- Tile targeting now prefers medium distance ahead of the player.


v58 M10 note:
- Camera/player orientation was corrected so the avatar now faces away from the camera again.
- Facing cone was flipped to match the player's forward direction.
- Tile targeting now prefers medium-distance forward targets more strongly, including diagonal cases.


v58 M10 camera/movement fix:
- Right-click now orbits the camera around the player without rotating the player.
- Movement directions were corrected.


v58 M11 note:
- Added autosave and save-if-dirty behavior for generated-level progress.
- Active session progress now merges back into local save data on autosave, session end, and quit.


v58 M12 note:
- A and D now rotate the player.
- Sideways walking/strafe movement was removed.


v58 save persistence fix:
- Fixed saved tile completions not reappearing after reopening the same level.


v58 turning/camera fix:
- A and D turning directions were swapped.
- A and D now rotate only the player and not the camera orbit.


v58 M13 note:
- Added color-code gameplay, color cycling, minimap, and progress HUD.
- Thrown projectiles now use the selected color captured at throw time and only complete matching tiles.


v58 M13 controls / cone / tile label fix:
- Player keyboard rotation direction was reversed.
- Facing cone now attaches to the player with the narrow end pointing forward.
- Tile text now sits much closer to the tile and is larger.


v58 M13 cone / tile text / movement tuning:
- Facing cone moved higher on the player.
- Tile code text now sits flat on the tile.
- Rotation speed increased slightly and movement speed reduced slightly.

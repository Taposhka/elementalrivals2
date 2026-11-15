# Element — current build

Run project.godot in Godot 4.7.2 and press F5. The entry scene is flag_demo.tscn,
using combat_arena.gd.

## Interface

The match fills the viewport. Only the timer, countdown and pause control are permanent screen UI.
Health and energy are drawn directly above living fighters. Player markers remain anchored to
their feet in either facing direction. No player names, role paragraphs, floating spell names,
damage captions, minimap captions or HUD panels are shown during combat.
Menus use short Russian actions and colored elemental icons. Settings retain only functional labels.

The landscape design size is 1280 x 720; portrait uses 720 x 1280. Canvas expansion,
viewport resizing and camera zoom support other aspect ratios without stretching the map.
Local two-player mode splits horizontally in landscape and vertically in portrait.
Mobile screen orientation follows the sensor. Controls respect the platform safe area.

## Input

Desktop: WASD, mouse/Space, Q fusion; P2 arrows, Enter, Right Shift.
Esc pauses or closes menus. F11, Alt+Enter, or Command+Enter toggles desktop fullscreen.
Gamepad: left stick moves, right stick aims, right trigger/right shoulder attacks,
left shoulder casts fusion, Start opens the match menu.

Android/iOS source supports two independent floating touch sticks and a separate fusion control.
Touch movement and aim can operate at the same time. Releasing movement does not release attack.
Menus and pause reset touch input. Desktop auto mode switches input after a real touch, and
returns to keyboard/mouse when used. Settings allow Auto/On/Off and persist that choice.
Mobile menu targets are enlarged. Android Back opens/closes the match menu instead of quitting.
Offline focus loss pauses. Online menus suppress local input while remote players continue.

## Combat

All elements retain 100 HP. Fire retains its rapid short-range burst and mobility.
Basic attacks were reduced in area and width:

| Element | Basic reach | Detail |
| --- | --- | --- |
| Fire | 96 | 34 damage on dash contact, 0.12 s dash, 0.24 s cooldown, 18 energy |
| Water | 300 | Three small shots; flood zones expand to radius 56, at most six per team |
| Ice | 380 | 17 damage, 18% slow for 0.9 s |
| Thunder | 660 | 29 damage, fast precision shot |
| Wind | 330 / 205 / 94 | 15 / 22 / 32 damage, narrowing range and widening attack, short dash |

All 15 fusions remain. Charges are shared by teammates.
Successful casts have an 8 s team cooldown. Bot teams wait at least 20 s between successful casts,
wait at the start, require a visible enemy, avoid overlapping their active fields, and do not spend
a human teammate's charge or cast solely at the flag shield.
Cooldown state is replicated to clients. Network protocol version is 11; all peers need this build.

## Verification

Godot checks: verify_upgrade.gd, verify_roles.gd, verify_minimal.gd and verify_role_network.gd.
Rendered captures cover desktop, wide, 4:3 and portrait windows, menus and touch controls.
Simulated multi-touch verifies independent movement/aim, release handling and pause reset.
A local host/client run verifies remote touch input, field/combo state and cooldown replication.

Testing was performed on Windows. Real Android, iOS and macOS devices and native exports were not
tested or produced. Gamepad event handling is implemented but was not tested on physical hardware.
Windows/Web export presets predate this change; native mobile and macOS exports need their normal
platform setup/signing. Source files contain no code comments.

Preview images are in qa/. Pre-change project code is in before-minimal-ui.zip.
Earlier backups are before-fusion-upgrade.zip and before-element-roles.zip.

Godot references used for resolution and input implementation:
https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html
https://docs.godotengine.org/en/stable/classes/class_displayserver.html


## Internet matchmaking and damaging fire dash

Online now opens an automatic queue without IP entry or manual host/join controls.
The included authoritative server creates independent rooms, starts at four players immediately
or with two after five seconds, and fills remaining slots with bots. Cancellation removes the
queued connection. A disconnected fighter is controlled by a bot.

The client and server have been tested together locally with multiple real game clients.
The public endpoint is deliberately empty until a hosting account is connected and the server
is deployed. Railway/Docker deployment files and a source archive are included. See server/README.md.
No permanent public service has been deployed yet.

Fire's basic attack is now a 96-unit dash that damages enemies along its actual movement path.
There is no separate cone attack or projectile. Each enemy, guard or shield can be hit once per
dash; teammates and invulnerable enemies are excluded. A stopped dash cannot deal ghost damage.
The flame trail is replicated to online clients. Movement/collision checks use swept segments.

Verification: verify_fire_dash.gd, verify_matchmaking.gd, verify_online_screen.gd,
verify_roles.gd, verify_minimal.gd and verify_upgrade.gd. All source comments remain removed.
Pre-change backup: before-matchmaking.zip.


## Combat feedback and supplied art

Added First Blood, Double/Triple/Quadra/Penta Kill, Killing Spree, Rampage, Unstoppable, Godlike and Shutdown. Multi-kills use a six-second window; Shutdown ends a streak of at least three kills. The supplied transparent WOW image appears briefly with the event. Kill attribution covers projectiles, Fire dash, reactions, flood zones and fusions; events replicate without replaying on repeated snapshots.

Prepared sixteen short WAV cues from all ten supplied MP3 recordings, trimming delays and applying level/fade control. Source names and cut positions are in assets/audio/manifest.json. Direct listening was unavailable in this session; audio was decoded and its waveform, levels and duration were checked. The original Downloads files are unchanged.

Supplied Fire, Water and Ice icons replace their old glyphs in selection and above fighters. The existing clean lightning is retained at the user's request. Crystal Volcano now uses the supplied six-frame sprite sheet with a fixed baseline and transparent background.

Movement is faster, respawn is 2.25 seconds, contact recoil is shorter, energy recovery is quicker, and normal hits no longer stop movement. Subtle camera impact respects Reduced Flashes. Source code remains comment-free. Backup: before-combat-feedback.zip.

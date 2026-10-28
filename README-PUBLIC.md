# ミーム大乱闘 — MEME CLASH v0.39.0

A work-in-progress 2D meme fighting game by Kashin Ou. Japanese game interface.
Seven playable characters, CPU battles, local two-player battles, directional skills, aerial attacks, special attacks, and training.

## Play
Use a desktop browser with WebGL 2 and a keyboard. Click the game first to enable keyboard/audio. Press Enter to confirm and Escape to go back/pause. This release does not provide touch combat controls.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | A / D | Left / Right |
| Up direction | W | Up |
| Guard / down | S | Down |
| Attack | J | 1 |
| Jump | K | 2 |
| Dash | L | 3 |
| Skill | U | 4 |
| Special | I | 5 |
| Escape while being hit | O | 6 |

W/S + J or U select directional attacks/skills. W + I is the upward special; S + I is the super special. Aerial U/I use air skills. Specials and escapes require sufficient Qi and the correct state. F1 opens the guide from the home screen. During a battle, press Escape and open the guide from the pause menu. F3 shows detailed controls; F11 toggles fullscreen. P2 numeric keypad is supported. Controls can be changed in Settings.

## Build from source
Install Godot 4.7.1 standard (not .NET) and its official 4.7.1 export templates.
Open project.godot in Godot, or use:

    godot --headless --path . --import
    mkdir -p ../build/web
    godot --headless --path . --export-release Web ../build/web/index.html
    python3 tools/split_web_pack.py ../build/web

Serve the entire ../build/web directory over HTTP(S); do not open index.html with file://. The Web preset explicitly uses the single-threaded template, so cross-origin isolation headers are not required. Keep all generated Web files together. The final packaging script splits the large resource pack into ordered files below itch.io's 200 MB per-file HTML5 limit. It verifies the reassembled SHA-256 before shipping. The loader streams into one destination buffer, then uses the official engine init/preloadFile/start API; it does not request index.pck a second time. Current total unpacked Web content is below 500 MB. To upload to itch.io, ZIP the contents with index.html at the archive root.

This is the corresponding source for the v0.39.0 Web release. The game uses desktop v0.39.0 plus a Web-only window compatibility fix: browser canvas dimensions remain owned by the HTML host while the game switches between menu and battle aspect ratios. Native window behavior and combat code are unchanged. Unused previous-generation character images, development tests, screenshots, import caches, generated prompt metadata, and private working records are omitted. Sprite/animation JSON and the resource images needed by the shipped build remain included. There is no change to attack timing, damage, character designs, or skill effects in this packaging step.

## Licenses and credits
The combined derivative game code is GNU GPL version 3 or later. See LICENSE-BVN.txt, NOTICE-BVN.txt, SOURCE_REFERENCES.txt, and third_party/5DPLAY-BVN/ for upstream attribution and modification records. Source-based gameplay adaptations refer to 5DPLAY Game Studio's BleachVsNaruto; this is an independent project.
Godot engine: MIT (LICENSES.txt). Noto Sans JP: SIL OFL (assets/fonts/OFL.txt). Original upstream game character artwork, maps, music, voice recordings, and SWF files are not included.

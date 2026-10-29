# v0.2.0

Initial tagged release.

## Features
- FOUR MORE BOSSES arcade with keyboard polish and 25-player co-op (#3) (71c27dd)
- initial Rampage scaffold for Toast raid arcade (8b11bc0)

## Rampage — FOUR MORE BOSSES!

First published release for **World of Warcraft: The Burning Crusade Classic 2.5.6 (Interface 20506)**, CurseForge project **1772524**. Includes the approved keyboard/graphics/25-player build and the full-lobby admission fix.

### Play
- `/rampage solo`, or open `/rampage` in a party/raid: **Host & Start**, **Join Game** or **Spectate**. Shared city destruction, personal fame and four fictional bosses.
- **25 active players / 40 total participants**; 15 spectator spaces when active slots are full. Spectators can switch to play when a slot opens. Full total lobbies visibly disable admission; full active lobbies still offer Spectate.
- Click **PLAY • GRAB KEYS** for WASD/arrows and Space. **Escape releases keys**. Chat/edit focus, hide/leave, combat, modifier shortcuts and interruptions release capture; compact mouse fallback remains. No permanent keybinding changes. Check key behavior in a safe area first.
- Original warm city/monster graphics, expressive poses, boss health/shield, local highlight, hover roster, pooled dust/rubble/stage/victory effects and fit-to-screen UI.
- Optional **Local BM** is **OFF by default**. When enabled it uses your separately installed BlasterMaster sound mappings, including None/mute. No BlasterMaster/game sound files are bundled. Only throttled local impacts and major transitions play, on the SFX channel; no global volume changes.

### Upgrade and known limitations
- **Everyone must install this same R2 build.** Original four-player R1 playtest clients are incompatible. Extract the single `Rampage` folder into `Interface/AddOns` and reload only when safe.
- Complete authoritative worlds are sent every **1.25 seconds (0.8 Hz)** with bounded addon-message traffic. Animation is smoother, but remote action feedback can lag; **no client prediction or low-latency action-game claim**. Large simultaneous joins can take tens of seconds (90s bounded timeout).
- Host combat pauses the shared game; guest combat disables that guest's input. No host migration. Host departure ends the session. Switching to spectate removes that avatar's current score; saved personal best remains.
- **38 automated checks**, including a lossy/reordered 40-node simulation, plus **9 Lua 5.1 grammar checks**. Test execution uses Fengari Lua 5.3 semantics, not WoW's native VM. The requester demonstrated original solo MVP gameplay; **new native keyboard/focus/taint, audio and large live raid behavior remain manual checks**. See bundled QA.md. Especially test chat, Escape, combat, Alt-Tab/taskbar focus and two-client response before a large raid.

Original geometric/pixel-style art and fictional encounters; not affiliated with the classic Rampage game's owners. No copied classic-game audio/art is distributed.


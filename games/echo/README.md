# ECHO

A time-loop puzzle platformer built with Phaser 4. Press **R** and the run you just played
becomes an echo that repeats it exactly. Your past selves hold plates, become stairs, and stay
behind in pits so the next you can reach the exit.

- Every echo adds a polyrhythmic voice to the music.
- Revisit the title screen and your previous visit is still walking around.
- Echoes are one-way platforms: walk and jump through them, land on their heads.

## Play

```sh
# from the repository root (so the node_modules fallback for Phaser resolves)
python3 -m http.server 8765
open http://localhost:8765/games/echo/
```

Controls: arrows / A D to move, Space / W / Up to jump, R to rewind, Backspace to erase the last
echo, Esc to clear all echoes, M to mute. Touch devices get on-screen buttons.

## Layout

| File | Role |
|---|---|
| `core.js` | Pure deterministic simulation: physics, plates, doors, one-way echoes. No Phaser. |
| `levels.js` | 7 levels plus the title room, as 32x18 tile maps. |
| `render.js` | Procedural drawing (no image assets). |
| `audio.js` | Web Audio synth: sound effects and echo-driven music. |
| `game.js` | Phaser scene: title, play, rewind, clear montage, ending. |

## Test

```sh
node --test games/echo/test/*.test.js
```

Every level ships with a scripted input solution that the tests replay through the simulation,
so a level edit that makes a puzzle unsolvable (or solvable with too few echoes) fails the suite.

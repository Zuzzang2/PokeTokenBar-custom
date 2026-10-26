# 메아리 spike art

Generated for the 메아리 mini game with the OpenAI Images API (`gpt-image-2`, 2026-10-26).
All images are original compositions (no game assets); prompts asked for "2010-era handheld
RPG" pixel art with no characters, creatures, logos, or text, matching `assets/battle`.

| File | What | Notes |
|---|---|---|
| `forest_day.png` | Daytime forest ruin backdrop | 1536×1024; scaled to cover the 480×270 play frame |
| `forest_night.png` | Night forest ruin with aurora | Ending screen backdrop |
| `stone.png` | Tileable mossy stone bricks | Sampled at 90 px for wall tiles |
| `shrine.png` | Exit shrine on flat magenta | `EchoArt` keys the magenta out at load time (the model has no transparent output) |

`scripts/build-app.sh` copies the PNGs into `Contents/Resources/echo`.

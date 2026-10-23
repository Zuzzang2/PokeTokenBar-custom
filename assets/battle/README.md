# Battle spike art

Generated for the battle/plaza spike with the OpenAI Images API (`gpt-image-1`, 2026-10-22).
All images are original compositions (no game assets); prompts asked for "2010-era handheld
RPG" style pixel art with no characters, logos, or text in the backgrounds.

| File | What | Notes |
|---|---|---|
| `town.png` | Town map (plaza, six houses, pond with bridge, tree border) | 1536×1024; `PlazaMap` collision shapes are measured from it |
| `battle_field.png` | Battle field with two platforms | Downscaled to 960×640; `BattleSceneView` platform coordinates match it |
| `trainers/t1_*.png`, `trainers/t2_*.png` | Trainer walking frames (down/right/up × 2) | Cut from `source/` sheets by connected components; left = mirrored right |
| `trainers/local/*.png` | Team-profile characters (pig, lupin, bunny, dino, bear, green, otter) | Generated with `gpt-image-1` image edits from teammates' profile pictures; depict third-party characters, for internal use only |
| `source/` | Raw generated sprite sheets | Not bundled |

`scripts/build-app.sh` copies everything except `source/` into `Contents/Resources/battle`.

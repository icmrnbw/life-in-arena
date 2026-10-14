# Emberpit

A single-player hero arena survival game for Android, built with Godot 4.6. It's an original game inspired by classic hero arena custom maps.

- 3 heroes with distinct playstyles. Each has 4 skills you rank up.
  - Ashwarden builds zones out of totems and walls.
  - Riftdancer runs on momentum and combos.
  - Hivemother commands a brood.
- 20 waves, with bosses on waves 5, 10, 15 and 20, and 3 lives.
- A camp between waves with a shop of 18 items, including recipes.
- Touch controls: a joystick, tap-to-cast and drag-to-aim.
- All art is procedural and original, generated in code.

## Install (Android)
Download `builds/emberpit-0.1.0-debug.apk` on your phone, allow installing from unknown sources, and open it. It's debug-signed and arm64 only.

## Develop
- Open the folder in Godot 4.6. The renderer is GL Compatibility.
- `tools/setup_env.sh` rebuilds the export environment (Godot, templates and a minimal Android SDK).
- `tools/export_android.sh` exports `build/emberpit-debug.apk`.
- `tests/run_all.sh` runs the logic and flow tests.

## Docs
- `CONTRACT.md`: the code/art API and the test hooks.
- `qa/report.md`: QA results.

# Emberpit

A single-player hero arena survival game for Android, built with Godot 4.6. It's an original game inspired by classic hero arena custom maps.

- 3 heroes with distinct playstyles. Each has 4 skills you rank up.
  - Ashwarden builds zones out of totems and walls.
  - Riftdancer runs on momentum and combos.
  - Hivemother commands a brood.
- 20 waves, with bosses on waves 5, 10, 15 and 20, and 3 lives.
- The Pit fights back:
  - From wave 4, elite enemies spawn with an affix: Frenzied (fast), Volatile (explodes on death, step out of the glow) or Warding (shields nearby foes, kill it first).
  - A wave that drags on enrages the survivors: they hit harder and move faster.
  - Hexcaster bolts halve your healing for a few seconds (your HP bar turns purple).
  - Shieldbearers stun with a telegraphed shield bash every third swing, and Gnawers hit harder in packs.
  - A wounded Pit Brute charges twice in a row, and a wounded Hollow Choir fires denser rings.
  - Buffers hang back behind the pack and must die first: the Ward Chanter (wave 9+) makes nearby foes immune, the War Drummer (wave 7+) doubles their damage.
  - Enemies hit 10% harder than in 0.2.0, and a bit less in the late waves (bosses 10% harder).
- Barrels in the arena:
  - Three barrel pens. Smash one barrel (tap it, or push into it) and fight from inside: the pack has to come through the gap one at a time. Wide enemies smash the barrels beside the gap, a sealed pen gets broken open, and bosses crash straight through.
  - Powder kegs blow up shortly after you break them, hurting every enemy nearby (and you, if you stay close).
  - Everything is restored at the start of each wave.
- The title screen shows the Riftdancer resting by a bonfire, with the menu on the right.
- Press and hold a skill button in a fight to read what it does (releasing doesn't cast).
- After a crash, the title screen offers a Copy report button with the crash trail.
- A camp between waves with a shop of 18 items, including recipes.
- Touch controls: a joystick, tap-to-cast and drag-to-aim.
- All art is procedural and original, generated in code.

## Install (Android)
Download `builds/emberpit-0.3.0-debug.apk` on your phone, allow installing from unknown sources, and open it. It's debug-signed and arm64 only.

## Develop
- Open the folder in Godot 4.6. The renderer is GL Compatibility.
- `tools/setup_env.sh` rebuilds the export environment (Godot, templates and a minimal Android SDK).
- `tools/export_android.sh` exports `build/emberpit-debug.apk`.
- `tests/run_all.sh` runs the logic and flow tests.

## Docs
- `CONTRACT.md`: the code/art API and the test hooks.
- `qa/report.md`: QA results.

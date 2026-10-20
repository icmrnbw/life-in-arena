# Emberpit

A single-player hero arena survival game for Android, built with Godot 4.6. It's an original game inspired by classic hero arena custom maps.

- 10 heroes with distinct playstyles. Each has 4 skills you rank up.
  - Ashwarden builds zones out of totems and walls.
  - Riftdancer runs on momentum and combos.
  - Hivemother commands a brood.
  - Sanguine pays for skills with HP, heals by hitting, and hits harder the lower his HP.
  - Snarewright lays traps, timed blast charges and tripwires.
  - Twinhide shifts between a spirit caster and a beast, each with its own Q and W.
  - Gravekeeper raises skeletons from the graves enemies leave behind.
  - Stoneshaper knocks enemies into pillars, walls and each other.
  - Gunsmith shoots from long range with a 8-round magazine, a scattergun blast and a mortar.
  - Sunspeaker builds Radiance by standing still and channels beams.
- Hero select is a roster grid with each hero's playstyle tag, difficulty and skills.
- 20 waves, with bosses on waves 5, 10, 15 and 20, and 3 lives.
- Every wave has a name and a twist, shown in camp before it starts (for example Bloodthirsty: their hits heal them; Spellwarded: they take half magic damage; Phantoms: they dodge a third of weapon attacks; Powder Keg: elites explode).
- Every regular wave is led by a captain: a bigger, named version of the wave's signature enemy with a telegraphed slam and a gold bounty.
- Wave 20 is a gauntlet: at 75%, 50% and 25% HP the Warden steps back and echoes of the Pit Brute, the Twin Matrons and the Hollow Choir return. He comes back when they fall.
- Waves 1-12 hit much harder than before, and gold income is up, so you have to shop to keep pace. Skills and dodging alone won't carry the early game.
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
Download `builds/emberpit-0.4.4-debug.apk` on your phone, allow installing from unknown sources, and open it. It's debug-signed and arm64 only.

## Develop
- Open the folder in Godot 4.6. The renderer is GL Compatibility.
- `tools/setup_env.sh` rebuilds the export environment (Godot, templates and a minimal Android SDK).
- `tools/export_android.sh` exports `build/emberpit-debug.apk`.
- `tests/run_all.sh` runs the logic and flow tests.

## Docs
- `CONTRACT.md`: the code/art API and the test hooks.
- `qa/report.md`: QA results.

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
  - Shieldbearers block shots from the front, but they turn slowly (and slow down to turn), so a ranged hero can circle round and shoot them in the back.
  - A wounded Pit Brute charges twice in a row, and a wounded Hollow Choir fires denser rings.
  - Buffers hang back behind the pack and must die first: the Ward Chanter (wave 9+) makes nearby foes immune, the War Drummer (wave 7+) doubles their damage.
  - Enemies hit 10% harder than in 0.2.0, and a bit less in the late waves (bosses 10% harder).
- Barrels in the arena:
  - Three big barrel stacks fill corners of the arena, like in Life in Arena. Smash your way in (tap a barrel, or push into it) to dig a corridor and fight from its end: foes can only follow single file, and one can't swing past the one in front of it. A corridor one barrel wide fits every hero and regular foes; Shieldbearers, Bloaters and big elites have to chew it wider. Seal yourself in and foes break in; bosses crash straight through.
  - Powder kegs are packed into the stacks and stand loose near the north gates. They blow up shortly after you break them, hurting every enemy nearby (and you, if you stay close), and blast a crater in the stack.
  - Everything is restored at the start of each wave.
- The title screen shows the Riftdancer resting by a bonfire, with the menu on the right.
- The (i) button next to pause opens a card with every skill's description, rank, mana and cooldown (the game pauses while it's open). Holding a skill button no longer shows its description, so it can't rank a skill up by accident.
- A Heroes screen on the title menu shows every hero's model on a turntable (drag to spin, tap it or the buttons below to see it run, attack and cast), their skills, and their skins. Skins come in rarities (Common, Uncommon, Rare, Mythical, Legendary); each hero has a Classic look plus three example recolours. Uncommon and Mythical ones can be equipped now; Legendary ones can only be previewed until there's a store. The equipped skin is the one you play with.
- Replayability:
  - Your progress is saved on the phone. You start with the Ashwarden, Riftdancer and Hivemother; the other seven heroes unlock by playing (clear wave 3, beat the Pit Brute, clear 20 waves in total, clear wave 8 with two heroes, defeat 1,000 enemies, beat the Twin Matrons, beat the Hollow Choir). Hero select shows how to unlock each one.
  - A run in progress is saved every time you're back in camp. If the app closes, Continue on the title screen picks it up from that camp.
  - Play opens a mode list: Classic (20 waves), Random Hero (any hero, even locked ones, +150 gold), Endless (past the Warden the waves and bosses keep coming, tougher each lap), Daily Run (the same hero, seed and twist for everyone that day, such as Glass Cannon or Swarm), Practice (any hero, any start wave, 99,999 gold, no lives lost, nothing recorded) and Training.
  - Difficulty tiers: Normal (gentler foes, more gold), Hard (the tuning so far) and Extreme (one life, tougher foes, less gold, elites from wave 2; unlocks after clearing wave 10 on Hard).
  - Every run gets a score. The Records screen shows totals, best waves per tier, Endless and the Daily Run, and every hero's record.
- Training: the first time you press Play, the game offers a guided run with the Ashwarden. A coach card gives one step at a time and waits for you to do it: walk, learn and cast a skill, buy an item, fight a pack, level up, dig into a barrel stack, and dodge a captain's slam. You can't fall, and you can skip it at any time. It's also under Play.
- After a crash, the title screen offers a Copy report button with the crash trail.
- Weather: every wave rolls its weather, and you can already see it falling in camp, so the shop visit can answer it. From wave 3, a regular wave sometimes turns mid-fight.
  - Rain: everyone moves 10% slower, fire deals 40% less. Thunderstorm: rain plus telegraphed lightning that hurts foes and you alike.
  - Fog: shots reach 30% less far, yours and the Hexcasters'. Gale: wind pushes everyone, shots with the wind hit 30% harder, into it 30% softer.
  - Emberfall: fire deals 50% more and embers set patches of sand alight. Blood Moon (wave 8+): foes hit harder and move faster, but drop 30% more gold.
- A camp between waves with a shop of 28 items, including recipes. Cleaving Axe's splash only works on melee hits and Splinter Quiver's ricochet only on shots (anyone can buy them; the other kind just gets the stats), and range bonuses only lengthen shots. Hooded Lantern and Oilskin Cloak answer the weather.
- Touch controls: a joystick, tap-to-cast and drag-to-aim.
- All art is procedural and original, generated in code.
- Music: three original medieval-style tunes, composed and synthesized in code by `tools/compose_music.py` (no samples or third-party recordings, so nothing to license). A tavern tune (lute, recorder, harp, drone; D Dorian) plays on the title screen and in camp, a battle tune (shawm, lute, tabor drum; E Dorian) during waves, and a boss tune (war drums, low voices, bell; D Phrygian) on boss waves. Tunes crossfade, duck while paused, and have their own Music toggle on the title and pause screens.

## Install (Android)
Download `builds/emberpit-0.5.2-debug.apk` on your phone, allow installing from unknown sources, and open it. It's debug-signed and arm64 only.

## Develop
- Open the folder in Godot 4.6. The renderer is GL Compatibility.
- `tools/setup_env.sh` rebuilds the export environment (Godot, templates and a minimal Android SDK).
- `tools/export_android.sh` exports `build/emberpit-debug.apk`.
- `tests/run_all.sh` runs the logic and flow tests.

## Docs
- `CONTRACT.md`: the code/art API and the test hooks.
- `qa/report.md`: QA results.

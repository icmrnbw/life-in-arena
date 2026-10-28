# Emberpit

A single-player hero arena survival game for Android, built with Godot 4.6. It's an original game inspired by classic hero arena custom maps.

- 18 heroes with distinct playstyles. Each has 4 skills you rank up. Each hero deals mostly physical or magic damage (shown on hero select), so a team can cover foes that shrug off one kind.
  - 0.6 added Duelist (parry timing), Vanguard (Rage instead of mana, taunts), Nightblade (backstabs, Vanish), Skyspear (a thrown spear that stays planted until recalled), Frostweaver (Chill and Freeze; frozen foes are brittle, so physical hits deal ~50% more), Stormcaller (chains that grow per jump), Alchemist (gold as fuel; acid corrodes armor) and Chronomancer (Rewind, Time Stop).
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
  - Hexcaster bolts halve your healing for a few seconds (your HP bar turns purple). The bolts are slow and only curve a little: the caster glows purple as it winds up, then sidestep, or put a pillar or barrels between you and it.
  - Shieldbearers stun with a telegraphed shield bash every third swing, and Gnawers hit harder in packs.
  - Shieldbearers block shots from the front, but they turn slowly (and slow down to turn), so a ranged hero can circle round and shoot them in the back.
  - A wounded Pit Brute charges twice in a row, and a wounded Hollow Choir fires denser rings.
  - Buffers hang back behind the pack and must die first: the Ward Chanter (wave 9+) makes nearby foes immune, the War Drummer (wave 7+) doubles their damage.
- Damage types matter (0.5.13). Every hit is physical, magic or pure. Armor cuts physical damage, magic resist cuts magic, and some foes are weak to one type:
  - Iron Hulk (wave 6+): heavy plate shrugs off half of physical damage, but magic hits it 50% harder.
  - Veilwraith (wave 8+): spells mostly pass through it (55% magic resist), weapons cut it apart. Its touch is magic, so armor doesn't stop it.
  - Shieldbearers, Burrowers and Drummers are armored and a little weak to magic; Hexcasters and Ward Chanters resist magic and are soft to weapons. Bosses lean one way too: the Pit Brute is plated, the Hollow Choir and the Matrons resist magic.
  - Hits show "Resisted" or "Weak!", the first meeting with each foe explains it, and the camp preview lists which of the next wave's foes are weak to what.
  - Wave 12 is now Iron Tide: every foe wears extra plate. Waves 8 and 16 bring Veilwraiths.
  - Five new items to adapt: Sundering Pick and Armorbreaker (physical damage ignores armor), Null Shard and Voidglass Focus (magic ignores magic resist), Spellward Mantle (you take 25% less magic damage).
  - Enemies hit 10% harder than in 0.2.0, and a bit less in the late waves (bosses 10% harder).
- Barrels in the arena:
  - Three big barrel stacks fill corners of the arena, like in Life in Arena. Smash your way in (tap a barrel, or push into it) to dig a corridor and fight from its end: foes can only follow single file, and one can't swing past the one in front of it. A corridor one barrel wide fits every hero and regular foes; Shieldbearers, Bloaters and big elites have to chew it wider. Seal yourself in and foes break in; bosses crash straight through.
  - Powder kegs are packed into the stacks and stand loose near the north gates. They blow up shortly after you break them, hurting every enemy nearby (and you, if you stay close), and blast a crater in the stack.
  - Everything is restored at the start of each wave.
- The title screen shows the Riftdancer resting by a bonfire, with the menu on the right.
- The (i) button next to pause opens a card with every skill's description, rank, mana and cooldown (the game pauses while it's open). Holding a skill button no longer shows its description, so it can't rank a skill up by accident.
- A Heroes screen on the title menu shows every hero's model on a turntable (drag to spin, tap it or the buttons below to see it run, attack and cast), their skills, and their skins. Skins come in rarities (Common, Uncommon, Rare, Mythical, Legendary); each hero has a Classic look plus three example recolours. Uncommon and Mythical ones can be equipped now; Legendary ones can only be previewed until there's a store. The equipped skin is the one you play with.
- Replayability:
  - Your records are saved on the phone. Every hero and every tier is open from the start (the unlock-by-playing rules in `scripts/modes.gd` stay in the code, off, in case they're wanted later).
  - A run in progress is saved every time you're back in camp. If the app closes, Continue on the title screen picks it up from that camp.
  - Play opens a mode list: Classic (20 waves), Random Hero (the game picks your hero, +150 gold), Endless (past the Warden the waves and bosses keep coming, tougher each lap), Daily Run (the same hero, seed and twist for everyone that day, such as Glass Cannon or Swarm), Practice (any hero, any start wave, 99,999 gold, no lives lost, nothing recorded) and Training.
  - Difficulty tiers: Normal (gentler foes, more gold), Hard (the tuning so far) and Extreme (one life, tougher foes, less gold, elites from wave 2).
  - 0.6.1 adds a second arena, Rimefang Hollow (frozen look, five pillars, two gates low on the flanks, two barrel stacks by the spawn), picked under Arena for Classic, Random Hero, Endless and Practice (`scripts/maps.gd`; test hook `--map=hollow`).
  - 0.6.1 adds Delve (experimental, Diablo style): 10 depths of a generated dungeon (`scripts/delve.gd`, art in `art/dungeon.gd`). Foes sleep in packs and wake when you come close or hit one; the lair at the end holds the guardian (a captain, or the Pit Brute / Twin Matrons / Hollow Choir on depths 3, 6, 10). Ember wells heal once, side-room chests hold gold, a minimap marks the lair. Depth d is fought at wave 2d, so stats, shop and Training scale like Classic. Test hooks `--mode=delve --seed=N`.
  - Every run gets a score. The Records screen shows totals, best waves per tier, Endless and the Daily Run, and every hero's record.
- Training: the first time you press Play, the game offers a guided run with the Ashwarden. A coach card gives one step at a time and waits for you to do it: walk, learn and cast a skill, buy an item, fight a pack, level up, dig into a barrel stack, and dodge a captain's slam. You can't fall, and you can skip it at any time. It's also under Play.
- After a crash, the title screen offers a Copy report button with the crash trail.
- Weather: every wave rolls its weather, and you can already see it falling in camp, so the shop visit can answer it. From wave 3, a regular wave sometimes turns mid-fight.
  - Rain: everyone moves 10% slower, fire deals 40% less. Thunderstorm: rain plus telegraphed lightning that hurts foes and you alike.
  - Fog: shots reach 30% less far, yours and the Hexcasters'. Gale: wind pushes everyone, shots with the wind hit 30% harder, into it 30% softer.
  - Emberfall: fire deals 50% more and embers set patches of sand alight. Blood Moon (wave 8+): foes hit 15% harder and move 10% faster.
- The arena changes in boss fights. A boss slam on a pillar, or a boss charge into one, knocks it over into a rubble wall that blocks movement and shots and crushes whatever is under it; a charge into a pillar also stuns the boss for 3 seconds, so bait the Pit Brute into one. When the Warden changes phase, the outer ring of the floor cracks and falls into the void 3 seconds later (radius 22, then 18, then 15): foes on it fall, you scramble back in and lose 20% health. Everything is rebuilt for the next wave. `--arena=topple` or `--arena=crumble` forces either in any wave for testing.
- A camp between waves with a shop of 28 items, including recipes. Cleaving Axe's splash only works on melee hits and Splinter Quiver's ricochet only on shots (anyone can buy them; the other kind just gets the stats), and range bonuses only lengthen shots. Hooded Lantern and Oilskin Cloak answer the weather.
- Training, the shop's fourth tab (like Life in Arena's stat shop), turns spare gold into permanent stats with no slot: Strength, Agility, Intellect, HP regen and mana regen from wave 3; damage, armor and attack speed from wave 5; max HP and cooldowns from wave 10. Each rank costs a little more than the last and only Focus (cooldowns) has a cap, so late-game gold always has a use. The Tome of Might gives +5 primary attribute for a flat 500, so it overtakes your primary attribute's training rank once that costs more.
- Touch controls: a joystick, tap-to-cast and drag-to-aim.
- All art is procedural and original, generated in code.
- Music: three original medieval-style tunes, composed and synthesized in code by `tools/compose_music.py` (no samples or third-party recordings, so nothing to license). A tavern tune (lute, recorder, harp, drone; D Dorian) plays on the title screen and in camp, a battle tune (shawm, lute, tabor drum; E Dorian) during waves, and a boss tune (war drums, low voices, bell; D Phrygian) on boss waves. Tunes crossfade, duck while paused, and have their own Music toggle on the title and pause screens.

## Install (Android)
Download `builds/emberpit-0.5.13-debug.apk` on your phone, allow installing from unknown sources, and open it. It's debug-signed and arm64 only.

## Develop
- Open the folder in Godot 4.6. The renderer is GL Compatibility.
- `tools/setup_env.sh` rebuilds the export environment (Godot, templates and a minimal Android SDK).
- `tools/export_android.sh` exports `build/emberpit-debug.apk`.
- `tests/run_all.sh` runs the logic, regression and flow tests (`--soak` adds the quick crash soak). GitHub Actions runs it plus a soak on every push (`.github/workflows/tests.yml`; start it by hand with "full" ticked for every hero in every scenario).
- `tests/test_regressions.gd`: one test per bug that reached phones (Twin Matron kills, camp return, wave replay after a death, hero model after respawn, late hits after a cleared wave, Sanguine bleeds on the Hollow Choir), plus every hero through casts, a boss kill, a death and a respawn. Add a test here for each crash you fix.
- `tools/soak.py`: crash soak. Runs the bot through heroes x scenarios (bosses 5/10/15/20, Endless, Daily, deaths and replays, arena changes) with the `--soak` monitor (`scripts/soak.gd`) and reports crashes, hangs, script errors, freezes, the hero under the ground or stuck in its death pose, skipped waves, stuck phases, NaN positions and node leaks to `qa/soak/<time>/report.md`. `--full` = every hero in every scenario, `--render` adds GL runs under xvfb, `--repeat N` for rare bugs.

## Docs
- `CONTRACT.md`: the code/art API and the test hooks.
- `qa/report.md`: QA results.

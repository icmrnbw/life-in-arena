# Emberpit build contract (code ⇄ visuals ⇄ QA)

Native Android game built with **Godot 4.6** (GDScript only). Deliverable: a debug-signed APK.
Design source: /mnt/project-files/plan/mvp-plan.md (heroes, skills, items, enemies, waves, art direction).
Where this contract and the plan disagree, this contract wins.

## Environment
- Godot binary: `godot` (4.6.stable, at /opt/godot). Android export templates are installed. The orchestrator owns Android export; agents don't export.
- Project root: `/home/claude/emberpit` (local disk, fast). It gets synced to /mnt/project-files/emberpit by the orchestrator; don't work in /mnt/project-files directly.
- Renderer: **GL Compatibility** (OpenGL ES 3 on phones). Don't use features the Compatibility renderer lacks (no SDFGI, no volumetric fog, no SSAO/SSR; glow/bloom, fog, ShaderMaterial, GPUParticles3D and CPUParticles3D are fine — prefer CPUParticles3D for safety).
- Run with rendering (screenshots): `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path /home/claude/emberpit -- <args>` (llvmpipe works; audio errors are harmless).
- Logic only: `godot --headless --path /home/claude/emberpit -- <args>`.
- First run after adding files: `godot --headless --path /home/claude/emberpit --import` to import resources.
- Parse check: `godot --headless --path /home/claude/emberpit --check-only --script res://path.gd` (or just run and read errors).
- Base resolution 1280×720, stretch `canvas_items` + `expand`, landscape (sensor). Phones are ~20:9; UI must anchor to edges and survive 2400×1080, 2340×1080, 1920×1080 and 1600×720 windows. Respect `DisplayServer.get_display_safe_area()`.
- Performance target: 60 fps on a mid-range 2021 Android phone with 60–80 enemies. Keep draw calls low: share meshes/materials; use MultiMeshInstance3D for repeated static props; no realtime shadows on enemies (blob shadows); at most one DirectionalLight3D with shadows (optional) and ≤ 4 OmniLights.

## File ownership
| Path | Owner |
|---|---|
| `scripts/**`, `scenes/**`, `project.godot` (except the `Art` autoload line and `[rendering]` section) | code agent |
| `art/**` (scripts, shaders, procedural models, theme, icons), `scenes/art_preview.tscn` | visuals agent |
| `tests/**`, `qa/**` | QA agent |
| `CONTRACT.md`, `export_presets.cfg`, `tools/**` | orchestrator |

## World layout (meters, y up, ground y=0, forward −Z)
- Arena: circle centered (0,0), radius 22. Wall ring 22..24, impassable.
- Pillars (impassable cylinders, radius 1.6): (-9, -6), (9, -6), (0, 10). (x, z)
- Gates (enemy spawns at the wall): N (0,-22), E (22,0), W (-22,0), NE (15.5,-15.5). South faces the camp, no gate.
- Camp: circle centered (0, 40), radius 9, not connected by walking (heroes teleport). Shop (-4, 42), Fountain (4, 42), hero spawn (0, 37).
- Camera: Camera3D perspective, FOV 45, offset (0, 18, 14) from the hero, looking at it; fixed yaw.

## `Art` autoload (art/art.gd, visuals agent)
All functions must exist and never crash on unknown input (fall back to a generic look).
```gdscript
func setup_environment(world_env_parent: Node) -> void   # adds WorldEnvironment (sky/background, ambient, fog, glow, tonemap) + DirectionalLight3D
func build_world(parent: Node3D) -> Dictionary            # arena, walls, pillars, gates, camp, shop, fountain, props; returns {"shop": Node3D, "fountain": Node3D}
func create_unit(kind: String) -> Node3D                  # returns a node with the UnitVisual API below
func create_projectile(kind: String) -> Node3D            # visual only; code moves it; may have `func tick(dt)`
func fx(name: String, opts: Dictionary) -> Node            # spawns an effect into the current scene (Art keeps a reference to the 3D root set via set_fx_root)
func set_fx_root(root: Node3D) -> void
func icon(id: String) -> Texture2D                         # skill/item/portrait/misc icons, 128×128, cached
func make_theme() -> Theme                                 # UI theme for all Controls (panels, buttons, labels, progress bars)
var palette: Dictionary                                    # "ember","gold","hp","mana","xp","danger","text","dim","panel","frame" -> Color
```
UnitVisual API (on the returned Node3D; origin at feet, facing −Z; code moves/rotates it):
```gdscript
var radius: float; var height: float
func set_state(s: String) -> void   # "idle","run","attack","cast","hit","death","spawn"
func flash(c: Color) -> void         # brief tint for damage/heal
func set_tint(c: Color) -> void      # persistent tint (e.g. second Matron, elite enemies); Color.WHITE = none
```
Animations are procedural (tweens / _process on pivot nodes). "death" ends collapsed or dissolved; code frees the node ~1.2 s after setting "death". "attack" and "cast" play once then return to the previous loop state.

Unit kinds: heroes `ashwarden`, `riftdancer`, `hivemother`, `sanguine`, `snarewright`, `twinhide` (caster form), `twinhide_beast` (beast form, radius 0.6, height 2.1), `gravekeeper`, `stoneshaper`, `gunsmith`, `sunspeaker` (~1.8 m; a hero gets its coloured ground ring from `UnitVisual.HERO_RING`, else from `Art.palette[kind]` for any non-enemy rig); enemies `gnawer`, `shieldbearer`, `hexcaster`, `burrower`, `bloater`; bosses `pit_brute`, `matron`, `hollow_choir`, `warden` (2.5–4× hero); summons `broodling`, `ember_totem`, `afterimage`, `choir_add`, `skeleton` (1.4 m biped), and static props (style "totem": no walk cycle, glow pulse, "attack" = a pulse/snap) `snare_trap` (r 0.5, h 0.3), `blast_charge` (r 0.45, h 0.6, lit fuse), `boulder` (r 0.9, h 1.6, centred at y 0.8; code may move/rotate the node), `stone_pillar` (r 0.9, h 2.6).
Projectile kinds: `fire_bolt`, `spit`, `hex_bolt`, `boss_orb`, `hero_bolt`, `bullet`, `crossbow_bolt`, `spirit_lance`, `grave_bolt`, `blood_bolt` (all face −Z = travel direction; unknown kinds fall back to a generic bolt).

Fx names; opts use Vector3 world positions (y ignored unless meaningful). Persistent fx return a Node with `func stop()` and optional `func set_params(opts)`; one-shot fx free themselves.
| name | opts | kind |
|---|---|---|
| `hit` | pos, color? | one-shot |
| `death_burst` | pos, color?, size? | one-shot |
| `level_up` | pos | one-shot |
| `heal` | pos | one-shot |
| `gold` | pos, amount | one-shot floating coin/number |
| `damage_number` | pos, amount, crit? , color? | one-shot floating number |
| `teleport` | pos, color? | one-shot |
| `telegraph_circle` | pos, radius, duration, color? | persistent, fills over duration, auto-stops; set_params({pos?, radius?, color?}) |
| `telegraph_line` | from, to, width, duration | persistent, auto-stops |
| `aim_circle` / `aim_line` | pos / from,to,width | persistent until stop(); skill aiming indicator (set_params each frame) |
| `ash_wall` | from, to, duration | persistent |
| `tether_pull` | pos, radius, color? | one-shot |
| `foundry_aura` | target: Node3D, duration | persistent |
| `slip_trail` | from, to, color? | one-shot |
| `mark` | target: Node3D, color? | persistent until stop() |
| `shatter` | pos, color? | one-shot |
| `rift_strike` | pos | one-shot |
| `brood_hatch` | pos | one-shot |
| `rally_marker` | pos, duration, color? | persistent |
| `sacrifice_explosion` | pos, radius, color? | one-shot |
| `carapace` | target, duration | persistent |
| `bloater_pool` | pos, radius, duration | persistent |
| `beam` | from, to, width, duration, color? | persistent; set_params({from, to, width?, color?}) each frame |
| `slam` | pos, radius, color? (crack glow + flash) | one-shot |
| `fountain_heal` | pos | one-shot |
| `buff_aura` | target: Node3D, radius?, color? | persistent until stop() |
| `cone` | pos, dir: Vector3, range, angle (degrees, full width), color | one-shot sweeping wedge + sparks (cleaves, blasts, shoves) |
| `zone` | pos, radius, duration, color | persistent ground circle with rim + motes; duration <= 0 = until stop(); set_params({pos?, radius?, color?}) |
| `ring_burst` | pos, radius, color | one-shot expanding shockwave + dust/sparks |
| `stone_ridge` | from, to, duration | persistent sandstone wall rising along the segment, auto-stops |
| `blood_burst` | pos, size? | one-shot crimson splash |
| `trap_snap` | pos | one-shot jaws snapping + olive sparks |
| `explosion` | pos, radius, color? | one-shot fiery blast (bigger than hit) |
| `soul_wisp` | from, to | one-shot mint wisp flying along an arc |
| `form_shift` | pos | one-shot violet swirl + leaves |
| `grave_marker` | pos, duration, size? (default 0.95 m), color? | persistent tiny mint tombstone glyph, one decal, no particles; fades over the last 1.5 s, auto-stops; up to 24 live (oldest recycled) |

Icon ids: skills `ember_totem`, `ash_wall`, `tether_pull`, `foundry_heart`, `slip`, `shatter_mark`, `afterimage`, `rift_cascade`, `brood`, `rally_pheromone`, `volatile_sacrifice`, `queens_carapace`; items `iron_knuckles`, `swift_gloves`, `hide_vest`, `vigor_charm`, `focus_pendant`, `runners_boots`, `stout_belt`, `sage_circlet`, `emberbrand`, `bulwark_plate`, `wayfarer_treads`, `hivecore_sigil`, `bloodthirst_fang`, `wardens_aegis`, `healing_draught`, `mana_draught`, `tome_of_might`, `phoenix_feather`; portraits `portrait_ashwarden`, `portrait_riftdancer`, `portrait_hivemother`; wave-2 skills `crimson_cleave`, `blood_rush`, `hemorrhage`, `undying_pact`, `snare_trap`, `blast_charge`, `tripwire`, `killing_field`, `spirit_lance`, `moonwell`, `rend`, `pounce`, `shift`, `twin_fury`, `raise_dead`, `corpse_blast`, `grave_chill`, `open_graves`, `rock_shove`, `stone_ridge`, `quake`, `avalanche`, `hot_reload`, `scattershot`, `mortar`, `deadeye`, `sunbeam`, `solar_flare`, `sanctum`, `dawn_lance`; portraits `portrait_sanguine`, `portrait_snarewright`, `portrait_twinhide`, `portrait_gravekeeper`, `portrait_stoneshaper`, `portrait_gunsmith`, `portrait_sunspeaker`; misc `gold`, `life`, `attack`, `armor`, `speed`, `pause`, `shop`.

## UI
Code builds all UI (Control nodes, in scenes or code) and applies `Art.make_theme()` to the root Control. Use theme type variations visuals will define: `PanelContainer` variants `"FramePanel"`, `"DarkPanel"`; `Button` variants `"PrimaryButton"`, `"SkillButton"`, `"ShopItemButton"`; `Label` variants `"TitleLabel"`, `"BannerLabel"`, `"SmallLabel"`; `ProgressBar` variants `"HpBar"`, `"ManaBar"`, `"XpBar"`, `"BossBar"`, `"FlowBar"`. If a variation is missing, the default theme still works. Use `Art.palette` for any colors code sets directly. Touch targets ≥ 96 px in the 1280×720 base (≈ 48 dp). Default font: Godot's built-in; visuals may set font sizes/outline/shadow in the theme (no downloaded fonts).

## Debug / test hooks (code agent provides; QA relies on them)
Command-line user args after `--`:
- `--hero=<id>` start a run immediately with that hero (skip menus)
- `--wave=<n>` start at wave n (with level/gold appropriate for that wave)
- `--autoplay` bot plays: moves toward/around enemies, kites, casts skills when ready, levels skills, buys recommended items in prep, skips prep
- `--timescale=<x>` Engine.time_scale
- `--god` invulnerable hero
- `--quit-after=<seconds>` quit after N real seconds
- `--report=<path>` on quit/run end write JSON: {hero, result, wave_reached, level, gold_earned, kills, deaths, lives_left, duration_s, avg_fps, min_fps, errors}
- `--screenshot-dir=<dir>` + `--screenshot-every=<seconds>` save viewport PNGs periodically
- `--scene=menu|hero_select|shop|hud|play|records|offer|training` open a specific screen for screenshot review (`play` takes `--mode=<id>` to preselect a mode)
- `--mode=classic|random|endless|daily|practice|training` and `--tier=normal|hard|extreme` set the run's mode and tier (`--date=YYYY-MM-DD` picks a Daily Run's day). See `scripts/modes.gd`.
- `--weather=<id>` pin one weather for the whole run (ids in `DB.WEATHER`); `--arena=topple|crumble` force the boss-fight arena changes in any wave (pillars at 3 s and 5 s, rim at 3 s and 12 s).
- `--soak`: crash soak monitor (`scripts/soak.gd`); adds a `soak` section (issues, camp-visit node counts, longest frame) to the `--report` JSON. `--soak-freeze-ms=<ms>` (default 1500) and `--soak-wave-limit=<sim s>` (default 600) tune it. Driven by `tools/soak.py`.
- `--profile`: let a `--hero` run update the saved profile (records, unlocks, saved run); off by default so bot runs don't touch it. Tests point `Profile.use_paths()` at test files.
A global `Game` (autoload or the main node) exposes `state` Dictionary (phase, wave, lives, gold, level, enemies_alive).

## IP rules (QA enforces)
No Blizzard/Warcraft names, assets, icons, fonts, sounds, UI frame layouts, or recognizable character designs. No "Life in Arena" anywhere. Everything procedural/original. Look: "resemble Warcraft but smooth enough for modern mobile gaming" = chunky stylized fantasy, saturated hand-painted-feel color, readable silhouettes, warm ember light, smooth 60 fps.

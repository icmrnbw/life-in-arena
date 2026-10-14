# Emberpit QA report, round 1 (2026-10-07)

Verdict: playable MVP, conditional pass. 0 blockers, 5 majors, 12 minors, 8 polish.
Logic tests 369/369 pass; flow and touch tests 60/64 pass. All 3 heroes win wave 20 with the smart bot; the passive bot loses at waves 7–10. IP audit clean.

Majors (being fixed in round 2):
- M1 joystick sticks after pause/focus loss (scripts/ui/touch_controls.gd, scripts/main.gd)
- M2 shop icons shrink to dots on long item names (scripts/ui/shop_ui.gd, hud.gd)
- M3 draw calls 150–340 vs ≤120 budget (art/world.gd, unit_visual.gd, fx.gd)
- M4 units small / low contrast; enemy HP bars stack into a wall (run.gd camera, art rigs, world_bars.gd)
- M5 APK older than the app icon; re-export after fixes (tools/export_android.sh)

Minors and polish: touch target sizes, tap-to-focus on the left side, badge vs cast hit areas, Android back on menus,
HUD overlap at 16:9/4:3, banner covering the hero, small text, boss wave skipped by dying, balance curve,
O(n²) sim hot spots, cancelled touch casting, screenshot hook timing, centre grate looking like a telegraph,
hero card space, level badge, small damage numbers, joystick visibility on grass, HUD panel opacity, flat victory screen.

Screenshots: qa/screens/. Tests: tests/run_all.sh.

# Round 2 (re-test after fixes)

Verdict: ship. All round-1 majors fixed (M5 resolved by re-export at 23:55).
- Tests: logic 369/0, flows + touch 64/0.
- Smart bot: all 3 heroes win wave 20 with 0 deaths (lowest HP 60–82%). Passive bot: loses at waves 7–11.
- Draw calls: camp 69 total; busy forced-spawn waves 98–206 (typical ~140), normal waves well under 120.
- N1 shop names breaking mid-word: fixed by the orchestrator (whole-word wrap, smaller font for long names).
Open (minor/polish): balance still easy for skilled play (m9), worst sim frame 11.4 ms at 75 enemies (m11),
empty bottom of hero cards (p3), damage numbers can pile on the hero in melee (N2), Warden can sit under the top HUD (N3),
defeat screen can show wave 0 in a forced edge case, small "+N skill" badge.
Screenshots: qa/screens/r2/.

#!/usr/bin/env python3
"""Emberpit crash soak: runs the autoplay bot through a matrix of heroes and scenarios with the --soak monitor
(scripts/soak.gd) on, and reports crashes, hangs, script errors and monitor issues (freezes, hero under the
ground, skipped waves, stuck phases, NaN positions, node leaks).

  python3 tools/soak.py                 # quick: every scenario, heroes rotated (~10 runs, ~5 min on 4 cores)
  python3 tools/soak.py --full          # every hero x every scenario (~80 runs)
  python3 tools/soak.py --render        # also run some with the GL renderer under xvfb (camp/boss render paths)
  python3 tools/soak.py --heroes riftdancer --scenarios matrons --repeat 5

Exit code 0 = no failures. Writes <out>/report.md, <out>/results.json and logs of failed runs.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name -> (game args, what it covers)
# name -> (game args, what it covers, wave the run must get past for the scenario to count as covered)
# Boss scenarios use --god so the bot always gets to kill the boss (the Matron crash came from boss deaths).
SCENARIOS = {
    "early": (["--wave=1"], "waves 1-6, shop and barrel play", 3),
    "pit_brute": (["--wave=4", "--god"], "boss 5 (Pit Brute) and the camp return after it", 5),
    "matrons": (["--wave=9", "--god"], "boss 10 (Twin Matrons, both deaths)", 10),
    "choir": (["--wave=14", "--god"], "boss 15 (Hollow Choir)", 15),
    "warden": (["--wave=19", "--god"], "boss 20 (Warden gauntlet) and victory", 20),
    "endless": (["--wave=19", "--god", "--mode=endless"], "Endless past wave 20", 21),
    "deaths": (["--wave=8", "--autoplay=passive"], "careless bot: deaths, respawns, wave replays, defeat", 0),
    "arena": (["--wave=9", "--arena=crumble"], "crumbling rim and toppling pillars every wave", 0),
    "daily": (["--mode=daily"], "Daily Run twists", 2),
}

# long boss fights get more time (multiplies --seconds)
LONGER = {"choir": 1.6, "warden": 1.6, "endless": 2.0}

# engine noise that is not a game bug
IGNORE = [
    r"resources still in use at exit",
    r"ObjectDB instances leaked at exit",
    r"at: (cleanup|clear) \(core/",
    r"[Aa]udio",
    r"ALSA",
    r"PulseAudio",
]


def heroes_from_db():
    src = open(os.path.join(ROOT, "scripts/data.gd"), encoding="utf-8").read()
    m = re.search(r"const HERO_ORDER := \[([^\]]*)\]", src)
    return re.findall(r'"(\w+)"', m.group(1))


def godot_bin():
    for b in ("godot", "godot4"):
        for d in os.environ.get("PATH", "").split(os.pathsep):
            if os.path.isfile(os.path.join(d, b)):
                return b
    sys.exit("godot not found on PATH (see tools/setup_env.sh)")


def build_jobs(a, heroes):
    names = a.scenarios or list(SCENARIOS)
    jobs = []
    for rep in range(a.repeat):
        for i, sc in enumerate(names):
            if a.full or a.heroes:
                hs = heroes
            else:
                # quick: one hero per scenario, rotating so every hero gets played across scenarios and repeats
                hs = [heroes[(i + rep * len(names)) % len(heroes)]]
            for h in hs:
                jobs.append({"hero": h, "scenario": sc, "render": False, "rep": rep})
    if a.render:
        # renderer paths: camp returns, boss fx and the arena changes; a few heroes is enough
        for i, sc in enumerate(["matrons", "arena", "deaths"]):
            jobs.append({"hero": heroes[(i * 3) % len(heroes)], "scenario": sc, "render": True, "rep": 0})
    return jobs


def run_job(job, a, out):
    sc_args, _, need = SCENARIOS[job["scenario"]]
    secs = int(a.seconds * LONGER.get(job["scenario"], 1.0))
    tag = "%s_%s%s_%d" % (job["scenario"], job["hero"], "_gl" if job["render"] else "", job["rep"])
    rep_path = os.path.join(out, "runs", tag + ".json")
    log_path = os.path.join(out, "runs", tag + ".log")
    game = ["--hero=" + job["hero"], "--soak", "--timescale=%g" % a.timescale, "--quit-after=%d" % secs,
            "--report=" + rep_path]
    if not any(s.startswith("--autoplay") for s in sc_args):
        game.append("--autoplay")
    game += sc_args
    if job["render"]:
        # llvmpipe draws on the CPU next to other runs, so only flag much longer stalls than on a phone
        game.append("--soak-freeze-ms=5000")
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1600x720x24", godot_bin(), "--audio-driver", "Dummy", "--rendering-driver", "opengl3",
               "--path", ROOT, "--resolution", "1600x720", "--"] + game
    else:
        cmd = [godot_bin(), "--headless", "--audio-driver", "Dummy", "--path", ROOT, "--"] + game
    t0 = time.time()
    hung = False
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=secs + 90)
        rc, text = p.returncode, p.stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as e:
        hung, rc, text = True, None, (e.stdout or b"").decode("utf-8", "replace")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n\n" + text)
    res = {"tag": tag, **job, "rc": rc, "secs": round(time.time() - t0, 1), "problems": [], "warnings": []}
    rep = None
    if os.path.exists(rep_path):
        try:
            rep = json.load(open(rep_path, encoding="utf-8"))
        except ValueError:
            pass
    if hung:
        res["problems"].append("hang: no exit %d s after --quit-after" % 90)
    elif rc is not None and rc < 0:
        res["problems"].append("crash: killed by signal %d" % -rc)
    elif rc not in (0, None):
        res["problems"].append("crash: exit code %d" % rc)
    if rep is None and not hung:
        res["problems"].append("no report written (died before quitting)")
    # script errors: Godot prints "SCRIPT ERROR:" plus the in-game logger catches engine errors during play
    seen = set()
    for line in text.splitlines():
        if ("SCRIPT ERROR" in line or line.startswith("ERROR:")) and not any(re.search(p, line) for p in IGNORE):
            if line not in seen:
                seen.add(line)
                res["problems"].append("error: " + line.strip()[:300])
    if rep:
        # errors are already in the console output above; keep the in-game warnings for the record
        for e in rep.get("errors", []):
            if e.startswith("WARNING") and not any(re.search(p, e) for p in IGNORE):
                res["warnings"].append(e.strip()[:300])
        s = rep.get("soak")
        if s is None and rep.get("result") != "none":
            res["warnings"].append("report has no soak section")
        for i in (s or {}).get("issues", []):
            res["problems"].append("soak: w%s %s %s (x%s)" % (i["wave"], i["what"], i["detail"], i["n"]))
        past = (rep.get("wave_reached") or 0) - (0 if rep.get("result") == "victory" else 1)
        if need and past < need:
            res["warnings"].append("coverage: only got past wave %d (scenario needs %d)" % (past, need))
        res.update({"result": rep.get("result"), "wave_reached": rep.get("wave_reached"), "deaths": rep.get("deaths"),
                    "sim_s": rep.get("duration_s"), "longest_frame_ms": (s or {}).get("longest_frame_ms"),
                    "growth": (s or {}).get("growth")})
    if not res["problems"]:
        os.remove(log_path)
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--full", action="store_true", help="every hero in every scenario")
    ap.add_argument("--render", action="store_true", help="add GL-rendered runs under xvfb")
    ap.add_argument("--heroes", nargs="*", help="only these heroes (all of them in each scenario)")
    ap.add_argument("--scenarios", nargs="*", choices=list(SCENARIOS), help="only these scenarios")
    ap.add_argument("--repeat", type=int, default=1, help="run the matrix N times (bugs that need luck)")
    ap.add_argument("--seconds", type=int, default=75, help="real seconds per run")
    ap.add_argument("--timescale", type=float, default=8.0)
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2)))
    ap.add_argument("--out", default=None, help="output folder (default qa/soak/<time>)")
    a = ap.parse_args()

    heroes = heroes_from_db()
    if a.heroes:
        bad = [h for h in a.heroes if h not in heroes]
        if bad:
            sys.exit("unknown heroes: %s (have %s)" % (bad, heroes))
        heroes = a.heroes
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    out = os.path.abspath(a.out or os.path.join(ROOT, "qa", "soak", stamp))
    os.makedirs(os.path.join(out, "runs"), exist_ok=True)
    jobs = build_jobs(a, heroes)
    print("soak: %d runs, %d at a time, %d s each at x%g -> %s" % (len(jobs), a.jobs, a.seconds, a.timescale, out), flush=True)

    results = []
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for r in ex.map(lambda j: run_job(j, a, out), jobs):
            results.append(r)
            mark = "FAIL" if r["problems"] else ("thin" if any(w.startswith("coverage") for w in r["warnings"]) else "ok  ")
            print("  %s %-28s %s wave %s, %s deaths, %s" % (mark, r["tag"], r.get("result", "?"), r.get("wave_reached", "?"),
                  r.get("deaths", "?"), "; ".join(r["problems"][:2])), flush=True)

    failed = [r for r in results if r["problems"]]
    version = "?"
    m = re.search(r'config/version="([^"]+)"', open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read())
    if m:
        version = m.group(1)
    try:
        commit = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    except OSError:
        commit = "?"
    md = ["# Emberpit soak %s" % stamp, "",
          "Build %s (commit %s). %d runs, %d failed. %d real s per run at x%g." % (version, commit, len(results), len(failed), a.seconds, a.timescale), ""]
    if failed:
        md += ["## Failures", ""]
        for r in failed:
            md.append("- **%s** (%s, wave %s): %s. Log: `runs/%s.log`" % (r["tag"], r.get("result", "?"), r.get("wave_reached", "?"),
                      "; ".join(r["problems"][:6]), r["tag"]))
        md.append("")
    md += ["## All runs", "", "| run | renderer | result | wave | deaths | sim s | longest frame ms | node growth | status |", "|---|---|---|---|---|---|---|---|---|"]
    for r in sorted(results, key=lambda r: r["tag"]):
        g = r.get("growth") or {}
        md.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["tag"], "GL" if r["render"] else "headless", r.get("result", "?"),
                  r.get("wave_reached", "?"), r.get("deaths", "?"), r.get("sim_s", "?"), r.get("longest_frame_ms", "?"),
                  g.get("nodes", "-"), "FAIL" if r["problems"] else "ok"))
    thin = [r for r in results if any(w.startswith("coverage") for w in r["warnings"])]
    if thin:
        md += ["", "Runs that didn't reach their scenario's target (not failures, but that path wasn't exercised): " +
               ", ".join("%s (%s)" % (r["tag"], r.get("wave_reached")) for r in thin)]
    md += ["", "Scenarios:"] + ["- `%s`: %s" % (k, v[1]) for k, v in SCENARIOS.items()]
    open(os.path.join(out, "report.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    json.dump(results, open(os.path.join(out, "results.json"), "w", encoding="utf-8"), indent=1)
    print("\n%d/%d runs clean. Report: %s" % (len(results) - len(failed), len(results), os.path.join(out, "report.md")))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

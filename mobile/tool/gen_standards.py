# Builds the strength standards every rating is placed on (lib/data/standards.g.dart) from the pages fetched into
# data/standards/ (fetch_standards.py) and the mapping in data/standards/map.json, and writes data/standards/README.md,
# the table to review it by. Run from anywhere: python mobile/tool/gen_standards.py
#
# One scale for every exercise. A standard is five tiers, the strength that beats 5, 20, 50, 80 and 95 % of people who
# train the lift, for men and for women at bodyweights 10 kg apart. Strength is the app's own unit: a one-rep max in kg
# (load x (1 + reps/30)), or for a bodyweight exercise its version's share of bodyweight x (1 + reps/30).
#
#  - Sources are combined tier by tier as a weighted geometric mean. strengthlevel.com and Symmetric Strength are measured
#    (lifts people logged) and count fully, less where a sex has few results; FitnessVolt's tables are models (editorial,
#    or a base lift scaled by one ratio) and count a half or a quarter.
#  - A reps page is read through the version it counts: the version's share of bodyweight x (1 + reps/30). Where a tier
#    is "< 1" (short of one rep), the page's one-rep max table says how far short (kilograms of help off bodyweight), or
#    else it is extended from the tiers above it.
#  - An exercise with no page is estimated: its median comes from its beginner start, calibrated by how the starts of the
#    exercises with standards sit against their medians; its tiers are a normal spread as wide as the measured lifts for
#    the same muscles (their middle tiers), split by sex and bodyweight like them.
import json, math, os, re, statistics, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DIR = os.path.join(ROOT, "data", "standards")
OUT = os.path.join(ROOT, "mobile", "lib", "data", "standards.g.dart")
REPORT = os.path.join(DIR, "README.md")

Z = [-1.6449, -0.8416, 0.0, 0.8416, 1.6449]  # the tiers' places: 5, 20, 50, 80, 95 %
GRID = {"man": list(range(50, 141, 10)), "woman": list(range(40, 121, 10))}
REF = {"man": 80, "woman": 65}
SEXES = ("man", "woman")
FV_WEIGHT = {"editorial": 0.5, "model": 0.5, "scaled": 0.25}
# Where untrained adults are centred among people who train, in the spread of the lifters' middle tiers from their median
# (lib/logic/rating.dart): -2 is a little under the lifters' 5 % mark (-1.645). On the barbell lifts that is 0.9 to 0.95
# of the 5 % mark, where studies of untrained adults put them (Heo & Lee 2024; Lee et al. 2017; the Cooper Institute bench
# norms). The same place on every lift, so the same place among lifters rates the same everywhere. map.json can move it
# for a lift a population study measures, as a multiple of that Beginner mark.
EVERYONE = -2.0
ASSIST_REF_KG = 80.0  # lib/logic/ladder.dart: the assisted machine's load is this less the assist


def epley(r): return 1 + r / 30


def dart_shares():
    src = open(os.path.join(ROOT, "mobile", "lib", "logic", "score.dart"), encoding="utf8").read()
    a = src.index("const measuredShare")
    measured = {k: float(v) for k, v in re.findall(r"'([^']+)':\s*([0-9.]+)", src[a:src.index("};", a)])}
    return measured, float(re.search(r"const estimatedStep = ([0-9.]+);", src).group(1))


MEASURED, STEP = dart_shares()


def version_shares(names):
    """lib/logic/score.dart versionShare, for every version of a ladder."""
    s = [MEASURED.get(n) for n in names]
    known = next((i for i, x in enumerate(s) if x is not None), -1)
    if known < 0: return [0.5 * STEP ** i for i in range(len(names))]
    for i in range(known - 1, -1, -1):
        if s[i] is None: s[i] = s[i + 1] / STEP
    for i in range(known + 1, len(names)):
        if s[i] is None: s[i] = s[i - 1] * STEP
    return s


def interp(xs, ys, x):
    """Linear through the points, extended past the ends along the end segments."""
    if len(xs) == 1: return ys[0]
    i = 1
    while i < len(xs) - 1 and x > xs[i]: i += 1
    x0, x1, y0, y1 = xs[i - 1], xs[i], ys[i - 1], ys[i]
    return y0 + (x - x0) / (x1 - x0) * (y1 - y0)


def fill_low(tiers, cap):
    """Tiers that are "< 1" rep, extended down from the two above in log strength against z, under [cap]."""
    t = list(tiers)
    for k in range(4, -1, -1):
        if t[k] is not None: continue
        if k + 2 <= 4 and t[k + 1] and t[k + 2]:
            a, b = math.log(t[k + 1]), math.log(t[k + 2])
            v = math.exp(a - (b - a) * (Z[k + 1] - Z[k]) / (Z[k + 2] - Z[k + 1]))
        elif k + 1 <= 4 and t[k + 1]:
            v = t[k + 1] / 1.4
        else:
            return None
        t[k] = min(v, cap * 0.97) if cap else v
    return t


def percentile_tiers(p):
    """Symmetric Strength's percentiles (10, 25, 50, ...) read at the tiers' places."""
    from statistics import NormalDist
    ks = sorted(p)
    zs = [NormalDist().inv_cdf(k / 100) for k in ks]
    ls = [math.log(p[k]) for k in ks]
    return [math.exp(interp(zs, ls, z)) for z in Z]


class Lib:
    def __init__(self):
        d = json.load(open(os.path.join(ROOT, "data", "library.json"), encoding="utf8"))
        self.ex = {e["id"]: e for e in d["exercises"]}

    def share(self, ex_id, version):
        if version in MEASURED: return MEASURED[version]
        names = [r["name"] for r in self.ex[ex_id]["ladder"]]
        if version not in names: raise KeyError(f"{ex_id}: no version {version!r}")
        return version_shares(names)[names.index(version)]


def page_curves(name, slug, src, lib, ex_id, e):
    """One page as {sex: [(bodyweight, five tiers)]} in the exercise's strength unit, with each sex's weight."""
    page = src[name]["standards"].get(slug)
    if not page: return None
    reps = page["unit"] == "reps"
    ladder = bool(lib.ex[ex_id].get("ladder")) or lib.ex[ex_id].get("assist")
    if reps != bool(ladder): return ("unit", f"{name}:{slug} is in {page['unit']}")
    scale = e.get("scale", 1.0)
    share = lib.share(e.get("of", ex_id) if not lib.ex[ex_id].get("assist") else "pullup", e["version"]) if reps else 1.0
    out, weights = {}, {}
    for sex in SEXES:
        rows = []
        added = {r[0]: r[1:6] for r in page[sex].get("bwAdded", [])}
        for r in page[sex]["bw"]:
            bw, vals = r[0], r[1:6]
            if bw is None: continue
            t = [None if v is None else share * epley(v) * scale for v in vals] if reps else [None if v is None else v * scale for v in vals]
            # "< 1" rep: the one-rep max table says how far short, as kilograms of help off bodyweight
            for k, a in enumerate(added.get(bw, [])):
                if t[k] is None and a is not None and bw + a > 0: t[k] = share * (bw + a) / bw * scale
            t = fill_low(t, share * scale if reps else None)
            if t and all(x and x > 0 for x in t): rows.append((bw, t))
        out[sex] = sorted(rows)
        if name == "strengthlevel":
            n = (page.get("results") or {}).get(sex) or 0
            weights[sex] = max(0.15, min(1.0, n / 5000))
        else:
            weights[sex] = FV_WEIGHT.get(page.get("kind"), 0.4)
    return out, weights, page


def symmetric_curves(lift, src):
    page = src["symmetric"]["standards"].get(lift)
    if not page: return None
    out, weights = {}, {}
    for sex in SEXES:
        classes = sorted(page[sex], key=lambda c: c["bw"])
        rows, n = [], 0
        for i, c in enumerate(classes):
            if c["n"] < 200 or not c["bw"]: continue
            lo = classes[i - 1]["bw"] if i else c["bw"] - 8
            rows.append(((lo + c["bw"]) / 2, percentile_tiers({int(k): v for k, v in c["p"].items() if int(k) < 99})))
            n += c["n"]
        out[sex] = rows
        weights[sex] = max(0.15, min(1.0, n / 5000))
    return out, weights, page


def at_grid(rows, sex):
    """A source's rows read at the grid, in log-log, only where its bodyweights reach (and a little past)."""
    if not rows: return {}
    xs = [math.log(b) for b, _ in rows]
    lo, hi = rows[0][0] - 8, rows[-1][0] + 8
    out = {}
    for bw in GRID[sex]:
        if not lo <= bw <= hi: continue
        out[bw] = [math.exp(interp(xs, [math.log(t[k]) for _, t in rows], math.log(bw))) for k in range(5)]
    return out


def combine(curves, sex):
    """Weighted geometric mean of the sources at each grid bodyweight; gaps extended along the nearest two."""
    got = {}
    for rows, w in curves:
        for bw, t in at_grid(rows, sex).items():
            got.setdefault(bw, []).append((w, t))
    if not got: return None
    table = {bw: [math.exp(sum(w * math.log(t[k]) for w, t in xs) / sum(w for w, _ in xs)) for k in range(5)] for bw, xs in got.items()}
    have = sorted(table)
    for bw in GRID[sex]:
        if bw in table: continue
        a, b = (have[0], have[1]) if bw < have[0] else (have[-2], have[-1])
        if a == b:
            table[bw] = list(table[a]); continue
        table[bw] = [math.exp(interp([math.log(a), math.log(b)], [math.log(table[a][k]), math.log(table[b][k])], math.log(bw))) for k in range(5)]
    for bw in table:  # tiers strictly rising
        for k in range(1, 5):
            table[bw][k] = max(table[bw][k], table[bw][k - 1] * 1.03)
    return [[bw] + table[bw] for bw in GRID[sex]]


def at_ref(table, sex):
    xs = [math.log(r[0]) for r in table]
    return [math.exp(interp(xs, [math.log(r[k + 1]) for r in table], math.log(REF[sex]))) for k in range(5)]


def everyone_z(value, table):
    """A multiple of the Beginner mark a normal spread through the middle tiers puts, as a place in that spread."""
    if value is None: return EVERYONE
    t = at_ref(table, "man")
    sigma = (math.log(t[3]) - math.log(t[1])) / (Z[3] - Z[1])
    return round(Z[0] + math.log(value) / sigma, 3)


def start_strength(lib, e):
    """What the exercise's beginner start is worth: the first start load or version at 10 reps."""
    if e.get("startKg"):
        first = next((x for x in e["startKg"] if x > 0), e["startKg"][-1])  # a start of 0 kg is the bar or machine alone
        kg = ASSIST_REF_KG - e["startKg"][0] if e.get("assist") else first
        return kg * epley(10) if kg > 0 else None
    if e.get("ladder"):
        names = [r["name"] for r in e["ladder"]]
        return version_shares(names)[min(e["start"][0], len(names) - 1)] * epley(10)
    return None


def build():
    lib = Lib()
    plan = json.load(open(os.path.join(DIR, "map.json"), encoding="utf8"))["exercises"]
    src = {n: json.load(open(os.path.join(DIR, f"{n}.json"), encoding="utf8")) if os.path.exists(os.path.join(DIR, f"{n}.json"))
           else {"standards": {}} for n in ("strengthlevel", "fitnessvolt", "symmetric")}
    out, notes = {}, {}
    for ex_id, m in plan.items():
        if ex_id not in lib.ex: sys.exit(f"map.json: unknown exercise {ex_id}")
        curves = {s: [] for s in SEXES}
        used, warn = [], []
        for s in m.get("sources", []):
            s = {"slug": s} if isinstance(s, str) else dict(s)
            site = s.get("site", "both")
            for name, slug in (("strengthlevel", s["slug"]), ("fitnessvolt", s.get("fv", s["slug"]))):
                if site != "both" and site != {"strengthlevel": "sl", "fitnessvolt": "fv"}[name]: continue
                got = page_curves(name, slug, src, lib, ex_id, s)
                if got is None: continue
                if got[0] == "unit":
                    warn.append(got[1]); continue
                rows, weights, page = got
                for sex in SEXES:
                    if rows[sex]: curves[sex].append((rows[sex], weights[sex] * s.get("weight", 1.0)))
                kind = "measured" if name == "strengthlevel" else page.get("kind", "model")
                used.append({"site": name, "slug": slug, "kind": kind, "weight": round(weights["man"] * s.get("weight", 1.0), 2),
                             "version": s.get("version"), "scale": s.get("scale")})
        if m.get("ss"):
            got = symmetric_curves(m["ss"], src)
            if got:
                rows, weights, _ = got
                for sex in SEXES:
                    if rows[sex]: curves[sex].append((rows[sex], weights[sex]))
                used.append({"site": "symmetric", "slug": m["ss"], "kind": "measured", "weight": round(weights["man"], 2)})
        tables = {sex: combine(curves[sex], sex) for sex in SEXES}
        if not used or not all(tables.values()):
            notes[ex_id] = {"warn": warn + ["no usable page: estimated"]}
            continue
        e = lib.ex[ex_id]
        measured = any(u["kind"] == "measured" for u in used)
        basis = "proxy" if m.get("proxy") else ("measured" if measured else "modelled")
        version = next((s.get("version") for s in m["sources"] if isinstance(s, dict) and s.get("version")), None)
        out[ex_id] = {"basis": basis, "man": tables["man"], "woman": tables["woman"],
                      "everyone": everyone_z(m.get("everyone", {}).get("value"), tables["man"]), "version": version,
                      "assist": lib.share("pullup", version) if e.get("assist") else None,
                      "sources": used, "proxy": m.get("proxy"), "why": m.get("everyone", {}).get("why")}
        notes[ex_id] = {"warn": warn}

    # ---- estimated: every other strength exercise the app tracks ----
    def kind(e): return "reps" if e.get("ladder") else "kg"
    grounded = [(i, x) for i, x in out.items() if x["basis"] in ("measured", "modelled") and not lib.ex[i].get("assist")]
    profiles = {}
    for i, x in grounded:
        e = lib.ex[i]
        st = start_strength(lib, e)
        if not st or e["format"] != "reps": continue
        refs = {sex: at_ref(x[sex], sex) for sex in SEXES}
        slope = {sex: (math.log(x[sex][-1][3]) - math.log(x[sex][0][3])) / (math.log(x[sex][-1][0]) - math.log(x[sex][0][0])) for sex in SEXES}
        # the middle tiers only: the Beginner and Elite marks of small lifts are noisy
        p = {"calib": {sex: refs[sex][2] / st for sex in SEXES},
             "sigma": {sex: (math.log(refs[sex][3]) - math.log(refs[sex][1])) / (Z[3] - Z[1]) for sex in SEXES}, "slope": slope}
        for key in (kind(e), (kind(e), e["primary"][0])):
            profiles.setdefault(key, []).append(p)

    def med(ps, f): return statistics.median(f(p) for p in ps)

    estimated = {}
    for i, e in lib.ex.items():
        if e["type"] != "strength" or i in out or not (e.get("startKg") or e.get("ladder")): continue
        st = start_strength(lib, e)
        if not st: continue
        # carries and holds are judged by time or distance, not like the reps lifts of their muscles: they take every lift's
        group = profiles.get((kind(e), e["primary"][0]), []) if e["format"] == "reps" else []
        ps = group if len(group) >= 3 else profiles[kind(e)]
        everything = profiles[kind(e)]
        tables = {}
        for sex in SEXES:
            mid = st * med(everything, lambda p: p["calib"][sex])  # how starts sit against the median, over every exercise
            sigma = med(ps, lambda p: p["sigma"][sex])  # how wide the same muscles' measured lifts spread
            b = med(ps, lambda p: p["slope"][sex])
            tables[sex] = [[bw] + [mid * math.exp(z * sigma) * (bw / REF[sex]) ** b for z in Z] for bw in GRID[sex]]
        estimated[i] = {"basis": "estimated", "man": tables["man"], "woman": tables["woman"], "everyone": EVERYONE, "version": None,
                        "assist": None, "sources": [], "proxy": None, "why": None,
                        "group": e["primary"][0] if ps is group else "all " + kind(e)}
    out.update(estimated)
    return lib, out, notes, src, profiles


def fmt(v): return f"{v:.3g}" if v < 100 else f"{v:.0f}"


def dart_str(s): return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def write(lib, out, notes, src, profiles):
    lines = ["// GENERATED by mobile/tool/gen_standards.py from data/standards/. Do not edit: change map.json or refetch, and",
             "// regenerate. Each row: bodyweight kg, then the strength that beats 5, 20, 50, 80, 95 % of people who train the lift.",
             "part of '../logic/rating.dart';", "",
             "const exerciseStandards = <String, Standard>{"]
    order = [i for i in lib.ex if i in out]
    for i in order:
        x = out[i]
        rows = lambda t: "[" + ", ".join("[" + ", ".join(fmt(v) for v in r) + "]" for r in t) + "]"
        frm = ", ".join(dict.fromkeys({"strengthlevel": "strengthlevel.com", "fitnessvolt": "fitnessvolt.com", "symmetric": "Symmetric Strength"}[u["site"]] for u in x["sources"]))
        a = [f"Basis.{x['basis']}", f"man: {rows(x['man'])}", f"woman: {rows(x['woman'])}"]
        if x["everyone"] != EVERYONE: a.append(f"everyone: {x['everyone']}")
        if x["version"]: a.append(f"version: {dart_str(x['version'])}")
        if x["assist"]: a.append(f"assist: {x['assist']:.4g}")
        if frm: a.append(f"from: {dart_str(frm)}")
        lines.append(f"  {dart_str(i)}: Standard(" + ", ".join(a) + "),")
    lines += ["};", ""]
    open(OUT, "w", encoding="utf8", newline="\n").write("\n".join(lines))

    # ---- the report ----
    from collections import Counter
    c = Counter(x["basis"] for x in out.values())
    r = ["# Strength standards", "",
         "Generated by `mobile/tool/gen_standards.py` from the pages in this folder (fetched by `mobile/tool/fetch_standards.py`,",
         "used with permission from strengthlevel.com and fitnessvolt.com) and `map.json`. Every rating in the app is a place",
         "on these tables: the five tiers beat 5, 20, 50, 80 and 95 % of people who train the lift. Strength is a one-rep max",
         "in kg (load x (1 + reps/30)); for a bodyweight exercise, the version's share of bodyweight x (1 + reps/30).", "",
         f"**{len(out)} exercises**: {c['measured']} measured (strengthlevel.com, Symmetric Strength), {c['modelled']} modelled (FitnessVolt only), "
         f"{c['proxy']} read from a close cousin, {c['estimated']} estimated from their beginner start.", "",
         "Bases: *measured* has lifts people logged behind it; *modelled* only FitnessVolt's model tables; *proxy* is a",
         "cousin exercise's page (why below); *estimated* has no page, so its tiers come from its beginner start, spaced like",
         "the measured lifts for the same muscles.", "",
         "Elite/Beg is how far the top tier is from the bottom: the barbell lifts sit near 2.7, small lifts run wider.", "",
         "| Exercise | Basis | Men 80 kg: Beg / Nov / Int / Adv / Elite | Women 65 kg | Elite/Beg (m) | Sources |",
         "|---|---|---|---|---|---|"]
    for i in order:
        x = out[i]
        m, w = at_ref(x["man"], "man"), at_ref(x["woman"], "woman")
        unit = "" if not x["version"] else f" ({x['version']}, share x Epley)"
        srcs = "; ".join(f"{u['site'][:2]}:{u['slug']}" + (f" ×{u['scale']}" if u.get("scale") else "") + f" w{u['weight']}" for u in x["sources"])
        if x["basis"] == "estimated": srcs = f"start-based, spaced like {x['group']}"
        if x["proxy"]: srcs += f". Proxy: {x['proxy']}"
        r.append(f"| {lib.ex[i]['name']} `{i}`{unit} | {x['basis']} | {' / '.join(fmt(v) for v in m)} | {' / '.join(fmt(v) for v in w)} | {m[4] / m[0]:.2f} | {srcs} |")
    warns = [(i, n["warn"]) for i, n in notes.items() if n.get("warn")]
    if warns:
        r += ["", "## Notes", ""] + [f"- `{i}`: {'; '.join(w)}" for i, w in warns]
    everyone = [(i, x) for i, x in out.items() if x.get("why")]
    r += ["", "## Where everyone else sits", "",
          f"The rating ranks against a mix: three parts people who train, one part everyone. Everyone is centred {-EVERYONE:g} spreads of the lifters'",
          "middle tiers under their median, a little under their 5 % mark: about 0.9 of it on the barbell lifts, where studies",
          "of untrained adults put them. The same place on every lift, unless a population study says otherwise:", ""]+ [f"- `{i}`: {plan_value(i)}x the Beginner mark ({x['everyone']:g} spreads). {x['why']}" for i, x in everyone]
    r += ["", "## Age", "", "Ages scale every table by `ageFactor` in `lib/logic/rating.dart` (masters lifting coefficients). The",
          "strengthlevel.com age tables, as a share of ages 25 to 35, median over every measured exercise and tier:", "",
          "| Age | " + " | ".join(str(a) for a in AGES) + " |", "|---|" + "---|" * len(AGES)]
    for sex in SEXES:
        r.append(f"| {sex} | " + " | ".join(f"{v:.2f}" if v else "" for v in age_curve(src, sex)) + " |")
    open(REPORT, "w", encoding="utf8", newline="\n").write("\n".join(r) + "\n")
    print(f"{len(out)} standards -> {os.path.relpath(OUT, ROOT)}", dict(c))
    for i, w in warns: print(f"  {i}: {'; '.join(w)}")


def plan_value(i): return json.load(open(os.path.join(DIR, "map.json"), encoding="utf8"))["exercises"][i]["everyone"]["value"]


AGES = [15, 20, 40, 50, 60, 70, 80, 90]


def age_curve(src, sex):
    ratios = {a: [] for a in AGES}
    for page in src["strengthlevel"]["standards"].values():
        rows = {r[0]: r[1:6] for r in page[sex]["age"] if r[0] is not None}
        base = [rows.get(a) for a in (25, 30, 35)]
        if not all(base): continue
        for a in AGES:
            if a not in rows: continue
            for k in range(1, 5):
                b = [x[k] for x in base]
                if rows[a][k] and all(b): ratios[a].append(rows[a][k] / (sum(b) / 3))
    return [statistics.median(ratios[a]) if ratios[a] else None for a in AGES]


if __name__ == "__main__":
    write(*build())

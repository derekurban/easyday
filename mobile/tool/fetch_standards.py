# Fetches the strength standards the rating is built from and saves them, parsed, in data/standards/. Used with
# permission from strengthlevel.com and fitnessvolt.com for this personal app (November 2026).
#
#   python mobile/tool/fetch_standards.py            fetch every page data/standards/map.json names (cached)
#   python mobile/tool/fetch_standards.py --fresh    ignore the cache
#
# Sources, all on the same five tiers (Beginner, Novice, Intermediate, Advanced, Elite):
#   strengthlevel.json  strengthlevel.com: from lifts users logged; the tiers are stronger than 5, 20, 50, 80, 95 % of them.
#                       By sex and bodyweight (kg), and by sex and age. Weights in kg (dumbbells: one), or reps.
#   fitnessvolt.json    fitnessvolt.com: model tables, scored on the same 5/20/50/80/95 scale; "editorial" or scaled from a
#                       base lift by one ratio. Pages are in pounds; saved in kg.
#   symmetric.json      Symmetric Strength's self-reported gym lifts, through FitnessVolt's open API (CC BY 4.0): real
#                       percentiles by weight class, for the barbell lifts.
# Pages are fetched one at a time, a second or more apart, and cached outside the repo so a rerun costs nothing.
import html, json, os, re, sys, tempfile, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DIR = os.path.join(ROOT, "data", "standards")
CACHE = os.path.join(tempfile.gettempdir(), "easyday-standards-cache")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
LB = 0.45359237
SYMMETRIC = ["back_squat", "bench_press", "deadlift", "front_squat", "incline_bench_press", "overhead_press", "pendlay_row", "sumo_deadlift"]

_last = {}


def get(url, fresh=False):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, re.sub(r"[^a-z0-9]+", "_", url.lower()))
    if not fresh and os.path.exists(path):
        return open(path, encoding="utf8").read()
    host = url.split("/")[2]
    wait = 1.2 - (time.time() - _last.get(host, 0))
    if wait > 0: time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read().decode("utf8")
    except urllib.error.HTTPError as e:
        body = "" if e.code == 404 else None
        if body is None: raise
    _last[host] = time.time()
    open(path, "w", encoding="utf8").write(body)
    return body


def text(s): return html.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def num(s):
    s = s.replace(",", "").strip()
    if s.startswith("<"): return None  # "< 1": short of one rep
    try: return float(s)
    except ValueError: return None


def rows(table):
    return [[text(c) for c in re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", r, flags=re.S)] for r in re.findall(r"<tr.*?</tr>", table, flags=re.S)]


def strengthlevel(slug, fresh):
    page = get(f"https://strengthlevel.com/strength-standards/{slug}/kg", fresh)
    if not page: return None
    tables = [rows(t) for t in re.findall(r"<table.*?</table>", page, flags=re.S)]
    # bodyweight exercises also have a one-rep max table in kilograms added to (or taken off) bodyweight: "+13 kg"
    added = lambda t: any("kg" in c for r in t[1:] for c in r[1:])
    bw = [t for t in tables if t and t[0][:1] == ["BW"] and not added(t)]
    age = [t for t in tables if t and t[0][:1] == ["Age"] and not added(t)]
    bw_added = [t for t in tables if t and t[0][:1] == ["BW"] and added(t)]
    summary = [t for t in tables if t and t[0][:1] == ["Strength Level"] and len(t[0]) == 2 and t[0][1] in ("Weight", "Reps")]
    stats = {r[0]: r[1] for t in tables if t and t[0][:1] == ["Community lifts"] for r in t if len(r) == 2}
    if len(bw) < 2: return None
    unit = "reps" if summary and summary[0][0][1] == "Reps" else "kg"
    out = {"unit": unit, "name": text(re.search(r"<h1[^>]*>(.*?)</h1>", page, flags=re.S).group(1)) if "<h1" in page else slug}
    for sex, b, a in (("man", bw[0], age[0] if age else None), ("woman", bw[1], age[1] if len(age) > 1 else None)):
        out[sex] = {"bw": [[num(r[0])] + [num(x) for x in r[1:6]] for r in b[1:]],
                    "age": [[num(r[0])] + [num(x) for x in r[1:6]] for r in a[1:]] if a else []}
    if len(bw_added) == 2 and unit == "reps":
        for sex, t in (("man", bw_added[0]), ("woman", bw_added[1])):
            out[sex]["bwAdded"] = [[num(r[0])] + [num(x.replace("kg", "").replace("+", "")) for x in r[1:6]] for r in t[1:]]
    n = lambda k: int(stats[k].replace(",", "")) if k in stats else None
    out["results"] = {"man": n("Male results"), "woman": n("Female results")}
    return out


def fitnessvolt(slug, fresh):
    page = get(f"https://fitnessvolt.com/strength-standards/{slug}/", fresh)
    if not page or 'id="bw-male"' not in page: return None
    body = lambda tid: re.search(rf'<tbody id="{tid}".*?</tbody>', page, flags=re.S)
    plain = html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", re.sub(r"<script.*?</script>|<style.*?</style>", "", page, flags=re.S))))
    reps = "rep targets for" in plain or "change with age, in reps" in plain
    m = re.search(r"is the ([A-Z][\w\-' ]+?) table scaled by a fixed FitnessVolt ratio of ([0-9]*\.?[0-9]+)(?: \(confidence: (high|medium|low)\))?", plain)
    kind = "scaled" if m else ("editorial" if "editorial" in plain else "model")
    out = {"unit": "reps" if reps else "kg", "kind": kind, "name": text(re.search(r"<h1[^>]*>(.*?)</h1>", page, flags=re.S).group(1))}
    if m: out["base"] = {"lift": m.group(1).strip(), "ratio": float(m.group(2)), "confidence": m.group(3)}
    conv = (lambda v: v) if reps else (lambda v: None if v is None else round(v * LB, 2))
    for sex, key in (("man", "male"), ("woman", "female")):
        b, a = body(f"bw-{key}"), body(f"age-{key}")
        out[sex] = {"bw": [[round(num(r[0]) * LB, 1)] + [conv(num(x)) for x in r[1:6]] for r in rows(b.group(0))] if b else [],
                    "age": [[num(r[0])] + [conv(num(x)) for x in r[1:6]] for r in rows(a.group(0))] if a else []}
    return out


def symmetric(lift, fresh):
    out = {"unit": "kg"}
    for sex, key in (("man", "male"), ("woman", "female")):
        d = json.loads(get(f"https://fitnessvolt.com/wp-json/fvss/v1/standards/{lift}?sex={key}&source=gym&unit=kg&format=table", fresh))
        out[sex] = [{"bw": float(re.sub(r"[^0-9.]", "", w["weight_class"]) or 0), "n": w["sample_size"],
                     "p": {int(k[1:]): round(v, 2) for k, v in w["percentiles"].items()}} for w in d["weight_classes"]]
    return out


def main():
    fresh = "--fresh" in sys.argv
    plan = json.load(open(os.path.join(DIR, "map.json"), encoding="utf8"))["exercises"]
    sl, fv = set(), set()
    for e in plan.values():
        for s in e.get("sources", []):
            s = {"slug": s} if isinstance(s, str) else s
            if s.get("site", "both") in ("both", "sl"): sl.add(s["slug"])
            if s.get("site", "both") in ("both", "fv"): fv.add(s.get("fv", s["slug"]))
    found = {}
    for name, slugs, fn in (("strengthlevel", sl, strengthlevel), ("fitnessvolt", fv, fitnessvolt), ("symmetric", SYMMETRIC, symmetric)):
        data = {}
        for i, slug in enumerate(sorted(slugs)):
            d = fn(slug, fresh)
            if d: data[slug] = d
            print(f"{name} {i + 1}/{len(slugs)} {slug}{'' if d else '  (none)'}", flush=True)
        found[name] = data
        # one page a line: small, and a refetch diffs by page
        body = ",\n".join(f"  {json.dumps(k)}: {json.dumps(v, separators=(',', ':'))}" for k, v in sorted(data.items()))
        open(os.path.join(DIR, f"{name}.json"), "w", encoding="utf8", newline="\n").write(
            f'{{"source": {json.dumps(name)}, "fetched": {json.dumps(time.strftime("%Y-%m-%d"))}, "standards": {{\n{body}\n}}}}\n')
    missing = sorted(f"sl:{x}" for x in sl if x not in found["strengthlevel"]) + sorted(f"fv:{x}" for x in fv if x not in found["fitnessvolt"])
    print("missing:", " ".join(missing) or "none")


if __name__ == "__main__":
    main()

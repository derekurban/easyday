# Generates lib/data/exercises.g.dart from data/library.json, the exercise dataset, after checking it against the rules
# in docs/app/EXERCISE_DATA.md. Run from anywhere: python mobile/tool/gen_library.py
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "data", "library.json")
OUT = os.path.join(ROOT, "mobile", "lib", "data", "exercises.g.dart")

MUSCLES = {"chest", "front shoulders", "side shoulders", "rear shoulders", "biceps", "triceps", "forearms", "abs", "obliques",
           "traps", "lats", "upper back", "lower back", "glutes", "outer hips", "inner thighs", "quads", "hamstrings", "calves", "shins"}
FORMATS = {"strength": {"reps", "hold", "carry"}, "power": {"reps"}, "stability": {"reps", "hold", "carry"},
           "cardio": {"steady", "intervals"}, "stretching": {"moving", "held"}}


def equipment_ids():
    import re
    src = open(os.path.join(ROOT, "mobile", "lib", "data", "library.dart"), encoding="utf8").read()
    block = src[src.index("const equipmentGroups"):src.index("];", src.index("const equipmentGroups"))]
    return set(re.findall(r"'(\w+)':", block))


def check(data):
    errs, eq, ids = [], equipment_ids(), set()
    for e in data["exercises"]:
        i, t = e["id"], e["type"]
        if i in ids: errs.append(f"{i}: duplicate id")
        ids.add(i)
        if e.get("format") not in FORMATS.get(t, ()): errs.append(f"{i}: {t} cannot be {e.get('format')}")
        for k in ("primary", "secondary", "targets"):
            for m in e.get(k, []):
                if m not in MUSCLES: errs.append(f"{i}: unknown muscle {m!r}")
        if t == "strength" and not e.get("primary"): errs.append(f"{i}: strength needs a primary muscle")
        if t == "stretching" and not e.get("targets"): errs.append(f"{i}: a stretch needs targets")
        if t == "stretching" and not e.get("seconds"): errs.append(f"{i}: a stretch needs seconds")
        for opt in e.get("needs", [[]]):
            for g in opt:
                if g not in eq: errs.append(f"{i}: unknown equipment {g!r}")
        for g in list(e.get("loadGear", [])) + list(e.get("altLoad", {})):
            if g not in eq: errs.append(f"{i}: unknown equipment {g!r}")
        if e.get("startKg") and (len(e["startKg"]) != 3 or not e.get("stepKg")): errs.append(f"{i}: startKg needs three loads and a stepKg")
        if t in ("strength", "power") and not e.get("ladder") and not e.get("startKg"): errs.append(f"{i}: needs a ladder or starting loads")
        lad = e.get("ladder")
        if lad is not None:
            if len(lad) < 2: errs.append(f"{i}: a ladder needs two versions")
            if len(e.get("start", [])) != 3 or any(not 0 <= r < len(lad) for r in e["start"]): errs.append(f"{i}: start rungs out of range")
    for old, new in data.get("renamed", {}).items():
        if new not in ids: errs.append(f"renamed {old} -> unknown {new}")
    for i, names in data.get("rungHistory", {}).items():
        if i not in ids: errs.append(f"rungHistory: unknown {i}")
    return errs


def dart(v):
    if v is None: return "null"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return "'" + v.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"
    if isinstance(v, list): return "[" + ", ".join(dart(x) for x in v) + "]"
    raise TypeError(v)


def exercise(e):
    a = [f"id: {dart(e['id'])}", f"name: {dart(e['name'])}", f"type: ExerciseType.{e['type']}", f"format: {dart(e['format'])}"]
    if e.get("primary"): a.append(f"primary: {dart(e['primary'])}")
    if e.get("secondary"): a.append(f"secondary: {dart(e['secondary'])}")
    if e.get("targets"): a.append(f"targets: {dart(e['targets'])}")
    a.append(f"needs: {dart(e['needs'])}")
    if e.get("cost"): a.append(f"cost: {e['cost']}")
    a.append(f"rank: {e['rank']}")
    if e.get("startKg"): a += [f"startKg: {dart(e['startKg'])}", f"stepKg: {dart(e['stepKg'])}"]
    if e.get("each"): a.append("each: true")
    if e.get("altLoad"):
        alts = ", ".join(f"{dart(k)}: AltLoad(startKg: {dart(v['startKg'])}, stepKg: {dart(v['stepKg'])}, each: {dart(v['each'])})"
                         for k, v in e["altLoad"].items())
        a.append(f"altLoad: {{{alts}}}")
    if e.get("ladder"):
        rungs = ", ".join("Variant(" + ", ".join([dart(r["name"]), dart(r.get("note")), dart(r.get("how"))]) + ")" for r in e["ladder"])
        extra = f", start: {dart(e['start'])}" + (f", loadGear: {dart(e['loadGear'])}" if e.get("loadGear") else "")
        a.append(f"ladder: Ladder([{rungs}]{extra})")
    if e.get("range"): a.append(f"range: RepRange({e['range'][0]}, {e['range'][1]})")
    if e.get("seconds"): a.append(f"seconds: {e['seconds']}")
    if e.get("perSide"): a.append("perSide: true")
    if e.get("how"): a.append(f"how: {dart(e['how'])}")
    return "  Exercise(" + ", ".join(a) + "),"


def main():
    data = json.load(open(SRC, encoding="utf8"))
    errs = check(data)
    if errs:
        print("\n".join(errs)); sys.exit(1)
    lines = ["// GENERATED by mobile/tool/gen_library.py from data/library.json. Do not edit: change the dataset and regenerate.",
             "// ignore_for_file: prefer_single_quotes", "part of 'library.dart';", "",
             "const builtInExercises = <Exercise>["] + [exercise(e) for e in data["exercises"]] + ["];", "",
             "/// Exercises merged into another one: old id -> the id that replaced it. Saved progress follows the new id.",
             "const exerciseRenames = <String, String>{" + ", ".join(f"{dart(k)}: {dart(v)}" for k, v in data.get("renamed", {}).items()) + "};", "",
             "/// Ladders whose versions moved since saved progress was written (state version 4): the old version names in order.",
             "const rungHistory = <String, List<String>>{"] + [f"  {dart(k)}: {dart(v)}," for k, v in data.get("rungHistory", {}).items()] + ["};", ""]
    open(OUT, "w", encoding="utf8", newline="\n").write("\n".join(lines))
    from collections import Counter
    print(f"{len(data['exercises'])} exercises -> {os.path.relpath(OUT, ROOT)}", dict(Counter(e["type"] for e in data["exercises"])))


if __name__ == "__main__":
    main()

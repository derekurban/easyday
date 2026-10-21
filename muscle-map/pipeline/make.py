# Rebuild the muscle maps end-to-end and verify them.   python make.py
# source/*.png (renders) -> work/ (segmentation) -> ../assets (shipped maps) -> verify.py -> outlines.py -> check_outlines.py
import subprocess, sys, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable
steps = [
    # sources since 2026-10-19 are gpt-image regenerations of the earlier renders (nipples already removed). The male
    # front's outer forearm strips are ~3 px wide diagonals that the 3x3 opening breaks up, so they are kept by point.
    ["segment.py", "female_front"],
    ["segment.py", "female_back"],
    ["segment.py", "male_front", "keep:382,489", "keep:870,490"],
    ["segment.py", "male_back"],
    ["build.py"],
    ["verify.py"],
    ["outlines.py"],         # vector outlines and fills
    ["check_outlines.py"],   # no notches, full coverage, fills contain outlines and stay off neighbours
]
for s in steps:
    print(">", " ".join(s), flush=True)
    r = subprocess.run([PY, "-I", *s])
    if r.returncode: sys.exit(r.returncode)

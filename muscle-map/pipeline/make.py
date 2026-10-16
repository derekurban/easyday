# Rebuild the muscle maps end-to-end and verify them.   python make.py
# source/*.png (renders) -> work/ (segmentation, nipple removal) -> ../assets (shipped maps) -> verify.py
import subprocess, sys, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable
steps = [
    # female nipples sit inside the plate -> biharmonic inpaint during segmentation
    ["segment.py", "female_front", "545,354,17", "699,352,17"],
    ["segment.py", "female_back"],
    # male nipples sit on the pec's lower edge -> edge-profile-preserving repair after segmentation
    ["segment.py", "male_front"],
    ["fix_nipples.py", "male_front", "537,328,17", "712,328,17"],
    ["segment.py", "male_back"],
    ["build.py"],
    ["verify.py"],
]
for s in steps:
    print(">", " ".join(s), flush=True)
    r = subprocess.run([PY, "-I", *s])
    if r.returncode: sys.exit(r.returncode)

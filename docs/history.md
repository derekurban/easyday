# What we tried (Oct 2026) and why we landed on 2D

1. **Procedural 3D mannequin** (three.js, capsule body + IK-driven exercise poses). Animation and contact worked,
   but the body looked like a toy.
2. **Z-Anatomy écorché, rigged** (CC BY-SA anatomy atlas, 511 muscles). Accurate, but the full anatomy/skeleton
   look felt eerie.
3. **Asset search**: catalogued ~76 models across Sketchfab, Fab, TurboSquid, CGTrader, ArtStation, Superhive,
   Gumroad and open-source repos. Nothing was simplified + muscle-segmented + rigged + male/female. Best buys were
   faceless sculpt base meshes (Gk ZPN, Ladosha, Max_3D_Int pairs) needing our own rig and masks.
4. **Procedural clay / plate sculpt on MakeHuman bodies**: lumpy, never matched the reference look.
5. **AI image-to-3D (Tripo) from ChatGPT turnarounds** + Blender cleanup: geometry close, but texture blurry,
   hands broken; cleanup stayed sloppy. A human/AI cleanup pass (Astra) didn't work either.
6. **2D muscle maps from the renders**: what we use. The plate style makes automatic segmentation reliable, the
   result looks exactly like the reference art, ships as ~0.5 MB per view, and highlights any exercise instantly.

Kept from the 3D work, if ever needed: free-exercise-db as the exercise source; multi-view image-to-3D (Tripo
H3.1) as the best AI route; Mixamo/mocap packs for animation.

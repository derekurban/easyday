# Muscle map v2 (October 2026)

The body renders were regenerated with gpt-image from the earlier ones so the plates match the twenty muscle names:
the serratus is folded into the dark base (no app muscle), the upper trapezius (traps) is split from the middle and
lower trapezius (upper back), and the plates read cleanly for segmentation.

- `compare.html`: the comparison board the new maps were approved from (images embedded).
- `*.txt`: the prompts for each view (`front`, `back`, the female `f*`/`f2_*` passes, `hands`), with `common.txt` and
  `fcommon.txt` shared by every view.

The renders themselves are `muscle-map/pipeline/source/`; the shipped maps are `muscle-map/assets/`.

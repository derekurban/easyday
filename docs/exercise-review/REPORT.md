# Review report

Reviewed 338 entries in 8 groups, each by Claude Opus 5.5 and GPT-6.1-Sol (high effort). Result: 324 entries in `corpus5.json`; after the unbiased GPT-6-Astra pass (`../astra/VERDICT.md`), `corpus6.json`; after the owner's calls of 2026-10-21 (`owner_calls.py`: power is explosive work, per-hand dumbbell loads in `altLoad`), `corpus7.json` is the current corpus.

- Both agreed, applied: 31
- Disputed, decided by the adjudicator (DECISIONS.md): 147 (Opus's fix 96, GPT's fix 32, kept as is 19)
- Removed: 14
- Rule changes: rows and rear shoulders (RULES.md), `each` and barbell starting loads (STANDARD.md)

## Removed

- Barbell seal row: Needs a seal-row bench we don't list; raising a bench on boxes (GPT's fix) isn't something to improvise. Rejects 50.
- Cable twist on an exercise ball: A setup difference.
- Cross-body crunch: Two 3-rung ladders of the same twisting crunch; the feet-down version becomes the bicycle ladder's first rung.
- Standing ankle-weight leg curl: Fails the strength test; true to type over coverage.
- Clean pull: Niche for everyday people; a fast deadlift for growth. Rejects 18 and 116.
- Jefferson squat: Same grounds as the trimmed kneeling barbell squat.
- Overhead squat: Expert lift, fails the strength test.
- Weighted sissy squat: Added load is what loadGear past the top rung is for. Makes 54 moot.
- Single-arm kettlebell overhead squat: A shoulder-stability skill filed as leg strength.
- Seated cable chest press: A setup note; keep the standing entry.
- Flat bench cable fly: Same line of pull and tags; a setup note.
- Push-up to side plank: Someone growing their chest picks push-ups, and a brief side plank between reps is neither strength nor stability work; 30 is moot.
- EZ bar curl: Same curl; one entry that takes either bar is cleaner.
- Kettlebell Z press: Seated on the floor is a setup note under the standard.

## Follow-ups beyond the findings

- Pallof press and side plank: `each` back to false (two hands, bodyweight).
- Entries that need the Olympic bar lifted to the 20 kg bar: good_morning: startKg [15.0, 20.0, 30.0] -> [20.0, 25.0, 35.0]; seated_good_morning: startKg [10, 15, 20] -> [20, 25, 30]; bb_suitcase_pull: startKg [10, 20, 30] -> [20, 30, 40]; bb_rear_delt_row: startKg [10, 15, 20] -> [20, 25, 30]; bb_push_press: startKg [10, 15, 20] -> [20, 25, 30].
- Barbell wrist curl, reverse wrist curl, prone barbell raise and barbell pullover take the EZ bar (a light bar) and keep their light loads.
- Landmine press, landmine row and T-bar row now list the barbell.
- Thoracic rotation, couch stretch and thread the needle rewritten side-neutral (they were left-side text from the routine).
- Dragon flag negatives reset with bent knees.
- `elbows_back` renamed `doorway_chest_stretch` with the doorway text.
- The routine's 'Shoulder circles' now maps to arm circles (straight-arm circles); shoulder rolls stay their own stretch.

## App follow-ups (not data)

- Ladder rungs cannot list their own gear, so versions that need a ball, band or bench were dropped from no-gear ladders. If rungs ever carry `needs`, they can come back.
- Entries that take a bar or dumbbells (shrug, upright row, skull crusher, preacher curl, farmer's carry with a trap bar) now carry the other implement's load in `altLoad`; the app picks it by the implement the location has and labels dumbbell loads "per hand".
- The machine-assisted pull-up's load runs backwards (less assistance is harder); its progression must subtract. Pre-existing in the shipped app.
- Smith and landmine loads are plates added; show them as "+kg" so a 0 start reads as the empty bar.
- The builder must skip a muscle cleanly when no strength exercise at the location trains it.

## Applied: both reviewers agreed

| Exercise | Check | Before | After | Why |
|---|---|---|---|---|
| Triceps dips | cost | 2 | 4 | Upright bar dips move the whole bodyweight on the arms, the same demand as dips (cost 4) and ring dips (cost 4) and more than push-ups (anchor 3); 2 puts it with lat pulldowns and cable rows. |
| Active hamstring stretch | format | held | moving | The text has you straighten and bend the knee repeatedly with only brief pauses, which is a moving (active) stretch, and the name says active. |
| Butterfly forward rock | format | held | moving | Name and text both describe folding forward and returning upright repeatedly, which is a moving stretch. |
| Pallof press | format | {"each": false} | {"each": true} | The set is done on each side ('Do both sides'), and the standard sets each when the count is per side; standing_cable_twist, the same side-on cable setup, already has each true. |
| Side plank | format | {"each": false} | {"each": true} | The hold is done on each side ('then switch sides'), so the seconds are per side and the standard sets each to true; band_hip_abduction and turkish_get_up in this group already do. |
| Cat-cow | how | Start on your hands and knees. Gently round your back toward the ceiling and spread your s… | Start on your hands and knees, hands under your shoulders and knees under your hips. Slowl… | The entry is named Cat-cow, is a moving drill and stands in for the routine's Cat-cow, but the text describes only the cat (rounding) and tells you to hold it. |
| Monster walk | how | Place bands above your knees and around your ankles, with your feet wide enough to keep li… | Loop a light band above your knees and stand with your feet apart and knees slightly bent,… | The main how puts bands at both knees and ankles, which is the third rung; a user on the first rung ('Light band above the knees only') reads two contradicting setups. |
| Overhead triceps extension | how | One dumbbell held overhead with both hands. Lower it behind your head by bending only the … | Hold one dumbbell overhead with both hands, or face away from a low cable with a rope behi… | needs allows a cable on its own, but the text only describes the dumbbell version, so someone with just a cable gets instructions they cannot follow. |
| Band good morning | ladder | Light band good mornings → Medium band good mornings → Heavy band good mornings → Doubled band good mornings | Light band good mornings → Medium band good mornings → Heavy band good mornings → Doubled band good mornings | Every rung's how (which the app shows in place of the base how) puts the band across the back of the neck, contradicting the base text's 'away from your neck'; a band pulling down on the cervical spine is the setup coaches tell people to avoid. |
| Bodyweight squat | ladder | Box squats → Bodyweight squats → Squat jumps → Paused squats → Tempo squats → Cossack squats → Pistol squats to a box | Box squats → Bodyweight squats → Paused squats → Tempo squats → Cossack squats → Pistol squats to a box | A jump is power, not strength: the rung's own note says to stop when jumps or landings deteriorate, so it is never taken close to failure, and the corpus already files jumps and hops as power (box_jump, single_leg_hop). |
| Chin-ups | ladder | Assisted chin-ups → Negative chin-ups → Chin-ups → Paused chin-ups → Chin-up with knee raise → Chest-to-bar chin-ups → Towel-assisted one-arm chin-ups | Assisted chin-ups → Negative chin-ups → Chin-ups → Paused chin-ups → Chest-to-bar chin-ups → Towel-assisted one-arm chin-ups | Curling the knees up during the pull adds a hanging knee raise (abs) to the rep. |
| Monster walk | ladder | Knee-band monster walks → Ankle-band monster walks → Two-band monster walks → Stronger-band monster walks | Knee-band monster walks → Ankle-band monster walks → Two-band monster walks → Stronger-band monster walks | The two-band note refers the user to an unspecified source that is not part of the exercise instructions. |
| Push-ups | ladder | Wall push-ups → Incline push-ups → Knee push-ups → Push-ups → Plyometric push-ups → Feet-elevated push-ups → Archer push-ups → One-arm push-ups | Wall push-ups → Incline push-ups → Knee push-ups → Push-ups → Feet-elevated push-ups → Archer push-ups → One-arm push-ups | A plyometric push-up loads the chest no more than a push-up; it is a power drill, not a harder strength version, so it is not a real step up in a ladder worked in 6-10 rep sets close to failure, and explosive reps landing on tired wrists are a poor way to chase failure. |
| Sit-ups | ladder | Crunches → Exercise-ball crunch → Long-arm crunch → Sit-ups → Slow sit-ups → Band-resisted decline sit-up → Straight-leg sit-ups → Seated knee tucks → Bent-knee V-ups → V-ups | Crunches → Long-arm crunch → Sit-ups → Slow sit-ups → Straight-leg sit-ups → Bent-knee V-ups → V-ups | Exercise-ball crunch and band-resisted decline sit-up need gear the exercise (needs [[]]) does not list, and rungs cannot carry gear. |
| Step-ups | ladder | Low step-ups → Step-ups → High step-ups → Slow step-downs → Low step-up hops | Low step-ups → Step-ups → High step-ups → Slow step-downs | A jump is power, not strength: the rung's own note says to stop when jumps or landings deteriorate, so it is never taken close to failure, and the corpus already files jumps and hops as power (box_jump, single_leg_hop). |
| Barbell hip thrust | load | {"startKg": [30.0, 40.0, 60.0], "stepKg": 5.0} | {"startKg": [30.0, 40.0, 60.0], "stepKg": 2.5} | The smallest practical jump on a barbell is 2.5 kg (1.25 kg plates), which every other barbell entry uses, bb_glute_bridge included. |
| Landmine press | load | {"each": false} | {"each": true} | It is pressed one arm at a time and the text says to do both sides, so the count is per side; the standard sets each true when the count is per side, as for landmine_push_press, kb_press and kb_z_press. |
| Hanging knee raise | needs | [["pullup_bar"], ["dip_bars"]] | [["pullup_bar"]] | Every text says hang from the bar, and the top rung is toes to bar; on dip bars you support yourself on your arms and cannot do that rung. |
| 90/90 hip switch | tags | none | glutes / outer hips | Targets are empty, so the stretching block can never pick this stretch and the standard requires the muscles lengthened. |
| Backward sled drag | tags | quads / forearms | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Couch stretch | tags | none | quads | Targets are empty, so the stretching block can never pick this stretch and the standard requires the muscles lengthened. |
| Deep squat hold | tags | none | inner thighs / glutes / calves | Targets are empty, so the stretching block can never pick this stretch and the standard requires the muscles lengthened. |
| Forward sled drag | tags | glutes / quads / hamstrings / calves | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Hamstring sweep | tags | none | hamstrings / calves | Targets are empty, so the stretching block can never pick this stretch and the standard requires the muscles lengthened. |
| Kettlebell sumo high pull | tags | glutes / hamstrings / traps / quads / side shoulders | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Kettlebell thruster | tags | quads / glutes / front shoulders / inner thighs / side shoulders / triceps / traps | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Landmine thruster | tags | quads / glutes / front shoulders / inner thighs / chest / triceps / abs | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Medicine ball slam | tags | abs / obliques / lats | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Mountain climbers | tags | abs / obliques | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |
| Pigeon | tags | none | glutes | Targets are empty, so the stretching block can never pick this stretch and the standard requires the muscles lengthened. |
| Sled push | tags | quads / glutes / calves | none | STANDARD.md, Muscle tags: 'Cardio: no tags.' These are left over from when the movement was tagged as strength. |

## Applied: disputed, decided

| Exercise | Check | Before | After | Decision |
|---|---|---|---|---|
| Barbell seal row | belongs | kept, needs [["barbell", "bench_flat"]] | drop | A barbell can't reach full arm length under a normal flat bench. Needs a seal-row bench we don't list; raising a bench on boxes (GPT's fix) isn't something to improvise. Rejects 50. |
| Clean pull | belongs | keep | drop | An Olympic-lifting accessory that needs coaching. Niche for everyday people; a fast deadlift for growth. Rejects 18 and 116. |
| Jefferson squat | belongs | kept | drop | Niche strongman squat with a twisting load on the spine. Same grounds as the trimmed kneeling barbell squat. |
| Overhead squat | belongs | kept as a quads/glutes strength exercise | drop | Limited by shoulder and ankle mobility, never by the legs. Expert lift, fails the strength test. |
| Push-up to side plank | belongs | kept as a strength exercise | drop | A push-up with a brief side plank attached. Someone growing their chest picks push-ups, and a brief side plank between reps is neither strength nor stability work; 30 is moot. |
| Single-arm kettlebell overhead squat | belongs | kept as a quads/glutes strength exercise | drop | A light bell overhead caps the load far below what strains the legs. A shoulder-stability skill filed as leg strength. |
| Standing ankle-weight leg curl | belongs | keep | drop | A 1-2 kg ankle weight never takes the hamstrings near failure. Fails the strength test; true to type over coverage. |
| Barbell rear delt row | cost | 4 | 3 | Rear delt row is lighter than a barbell row. 3, like the dumbbell bent-over row. |
| Close-grip push-ups | cost | 2 | 3 | Push-ups anchor at 3. Close grip is no easier. |
| Glute bridge hold | cost | not set | 1 | No cost set. 1. |
| Kettlebell sumo high pull | cost | 4 | 3 | Rated with barbell lifts. 3, like the swing. |
| Sit-up press | cost | 3 | 1 | A sit-up with a light weight. 1, like weighted crunches. |
| Smith machine row | cost | 4 | 3 | Smith entries sit one below their free-bar version. 3. |
| Suspension row | cost | 2 | 3 | Suspension row is the inverted row's twin. 3. |
| Wall slides | cost | not set | 1 | No cost set. 1. |
| Cable twist on an exercise ball | duplicate | separate entry | merge into standing_cable_twist | Same cable rotation as the standing cable twist, lying on a ball. A setup difference. |
| Cross-body crunch | duplicate | separate entry | merge into bicycle_crunch; keep 'Short cross-body crunch' (both feet down, one shoulder tu… | Merge the cross-body crunch into the bicycle crunch? Two 3-rung ladders of the same twisting crunch; the feet-down version becomes the bicycle ladder's first rung. |
| EZ bar curl | duplicate | EZ bar curl | merge into bb_curl; use needs [["barbell"], ["ez_bar"]], retain bb_curl's existing load fi… | EZ bar curl vs barbell curl. Same curl; one entry that takes either bar is cleaner. |
| Flat bench cable fly | duplicate | separate entry from cable_fly | merge into cable_fly; add to its how: 'You can also lie on a flat bench between low pulley… | Lying vs standing cable fly. Same line of pull and tags; a setup note. |
| Kettlebell Z press | duplicate | Kettlebell Z press | merge into kb_press; retain its existing load fields and replace its how with: Stand tall,… | Kettlebell Z press vs kettlebell press. Seated on the floor is a setup note under the standard. |
| Seated cable chest press | duplicate | separate entry from cable_chest_press | merge into cable_chest_press; add to its how: 'You can also sit on an upright bench betwee… | Seated vs standing cable chest press. A setup note; keep the standing entry. |
| Weighted sissy squat | duplicate | separate entry | merge into sissy_squat: add loadGear ["weight_plate"] to its ladder and keep the plate-at-… | The sissy squat holding a plate. Added load is what loadGear past the top rung is for. Makes 54 moot. |
| 90/90 hip switch | format | {"format": "moving", "seconds": null} | {"format": "moving", "seconds": 30} | Routine move has no seconds. 30 s; the stretching picker will need a time. |
| Couch stretch | format | {"format": "held", "seconds": null} | {"format": "held", "seconds": 30} | Routine move has no seconds. 30 s per side. |
| Deep squat hold | format | {"format": "held", "seconds": null} | {"format": "held", "seconds": 30} | Routine move has no seconds. 30 s. |
| Hamstring sweep | format | {"format": "moving", "seconds": null} | {"format": "moving", "seconds": 30} | Routine move has no seconds. 30 s. |
| Landmine row | format | {"each": false} | {"each": true} | each = true for one-arm rows. One hand holds the bar end, like the dumbbell row; same as 75. |
| Pigeon | format | {"format": "held", "seconds": null} | {"format": "held", "seconds": 30} | Routine move has no seconds. 30 s per side. |
| Thoracic rotation | format | {"format": "moving", "seconds": null} | {"format": "moving", "seconds": 30} | Routine move has no seconds. 30 s. |
| Thread the needle | format | {"format": "held", "seconds": null} | {"format": "held", "seconds": 30} | Routine move has no seconds. 30 s per side. |
| Cable reverse crunch | how | Lie facing a low cable with a secure ankle attachment and knees bent. Bring your knees inw… | Lie on your back with your feet toward a low cable, the attachment secured around your ank… | 'Facing a low cable' reads as face down. Clearer setup. |
| Cross-body straight-leg stretch | how | Lie on your back with a band around one foot and raise that leg with the knee softly strai… | Lie on your back and raise one leg with the knee softly straight, holding the outside of t… | Matches needs [[]]. Hand, band or towel. |
| Forward sled drag | how | Fasten the sled straps to a suitable waist harness and face away from the sled. Lean forwa… | Face away from the sled and hold its tow straps just behind your hips, with enough space f… | Text needs a harness we don't list. Hold the straps instead. |
| Kettlebell front squat | how | Hold a kettlebell racked at one shoulder and keep your ribs down. Squat as deep as you can… | Hold one kettlebell at your shoulder in the rack position, elbow tucked and ribs down. Squ… | Jargon about a two-bell option the load can't express. One bell, switch sides. |
| Kettlebell sumo high pull | how | Set a kettlebell between your feet in a wide stance and grip it with both hands. Drive thr… | Stand wide with a kettlebell between your feet, push your hips back and take the handle in… | No flat-back cue on a fast pull from the floor. Safety. |
| Lateral bound | how | Start on one leg with your hips and knee slightly bent. Push sideways and land on the othe… | Stand with your hips and knees slightly bent. Push off sideways and land with your knee ov… | Says one leg; the first rung is two feet. Text matches the ladder. |
| Pigeon | how | Left shin across in front of you, right leg straight behind. Fold forward over the front l… | From hands and knees, bring one knee forward and place that foot toward the opposite hip, … | Assumes you know how to get into it. Learnable for beginners. |
| Single-dumbbell close-grip press | how | Rest your shoulders across a flat bench with your feet planted, holding one dumbbell secur… | Lie on a flat bench with your feet planted, holding one dumbbell in both hands above your … | Shoulders-on-bench bridge makes the hips a limit. Lie along the bench like the other presses. |
| Sliding leg curl | how | Lie on your back with your heels on towels on a smooth floor. Lift your hips, slide your h… | Lie on your back with your heels on towels on a smooth floor. Lift your hips, slide your h… | Point to the negative instead of the floor rung. Follows 137: the text pointed at the dropped floor rung. |
| Standing chest stretch | how | Stand tall and rest your hands on your lower back. Ease your elbows back until you feel a … | Stand in a doorway and rest one forearm on the frame with the elbow at shoulder height. St… | Hands-behind-back is a weak chest stretch, near the biceps stretch. Doorway is the standard pec stretch and what the routine used. |
| Standing torso twist | how | Stand with your feet hip-width apart and hands on your hips. Turn your chest gently to one… | Stand with your feet hip-width apart and your arms crossed over your chest. Slowly turn yo… | Format says moving, text says hold. Make the text the moving twist. |
| Wall handstand hold | how | Hands shoulder width, body as straight as the variant allows. Push the floor away and hold… | Hands shoulder width, a short step out from a wall. Kick or walk up until your heels rest … | Never mentions the wall. Text matches the named exercise. |
| World's greatest stretch | how | Step into a comfortable lunge with your hands beside the front foot and pause briefly. Eas… | Step into a long lunge and put both hands on the floor inside your front foot. Ease the el… | Drops the arm turn that defines the drill. Restores it. |
| Band calf raise | ladder | Light band calf raises → Medium band calf raises → Heavy band calf raises → Doubled-band calf raises | Light band calf raises → Medium band calf raises → Heavy band calf raises → Doubled-band calf raises | 'Doubled band' could be easier than heavy. Say: heavy band plus another. |
| Band squat | ladder | Light band squats → Medium band squats → Heavy band squats → Doubled-band squats | Light band squats → Medium band squats → Heavy band squats → Doubled-band squats | Same. Same. |
| Bodyweight triceps extension | ladder | Triceps extensions on a counter → Triceps extensions on a low bar or table → Triceps extensions on the floor → Triceps extensions on the floor, knees up | Triceps extensions on a counter → Triceps extensions on a low bar or table → Triceps extensions on the floor → Triceps extensions on the floor, knees up | On the floor, your forearms reach the floor, not your head. Accurate text. |
| Calf raise | ladder | Calf raises on the floor → Calf raises on an edge → Paused calf raises on an edge → Single-leg calf raises → Paused single-leg calf raises | Calf raises on the floor → Calf raises on an edge → Paused calf raises on an edge → Single-leg calf raises → Paused single-leg calf raises | Paused single-leg rung has no note. Add '2 seconds at the top'. |
| Close-grip push-ups | ladder | Incline close-grip push-ups → Knee close-grip push-ups → Close-grip push-ups → Feet-elevated close-grip push-ups → Paused close-grip push-ups | Incline close-grip push-ups → Knee close-grip push-ups → Close-grip push-ups → Paused close-grip push-ups → Feet-elevated close-grip push-ups | Paused rung after feet-elevated. Paused before feet-elevated, as 131. |
| Dead bug | ladder | Dead bug, arms only → Dead bug, legs only → Dead bug → Slow dead bug → Dead bug with heel taps | Dead bug, arms only → Dead bug, legs only → Dead bug → Slow dead bug → Dead bug with heel taps | Note says 3 s, text says 3 s out, pause, 3 s back. Match. |
| Dips | ladder | Assisted dips → Negative dips → Dips → Paused dips → Deep dips | Assisted dips → Negative dips → Dips → Paused dips → Deep dips | Pause cue tacked on at the end. Wording. |
| Exercise ball leg curl | ladder | Ball curl, hips down → Ball curl negatives → Ball leg curls → Paused ball leg curls → Single-leg ball leg curls | Ball curl negatives → Ball leg curls → Paused ball leg curls → Single-leg ball leg curls | Drop the hips-down first rung. A new user starts at rung 0; with the hips on the floor that rung trains nothing. Bridge negatives with a short slide are the real entry. |
| Glute bridge | ladder | Glute bridges → Paused glute bridges → Ball-supported hip bridges → Band-resisted glute bridges → Feet-elevated glute bridges → Single-leg glute bridges → Single-leg feet-elevated glute bridges | Glute bridges → Paused glute bridges → Feet-elevated glute bridges → Single-leg glute bridges → Single-leg feet-elevated glute bridges | Ball and band rungs need gear the exercise doesn't list (both flagged). Both drop those; Opus keeps feet-elevated (a chair works), GPT drops it too. |
| Inverted row | ladder | Knees-bent inverted row → Inverted row → Feet-elevated inverted row → Paused inverted row → Single-arm inverted row | Knees-bent inverted row → Inverted row → Paused inverted row → Feet-elevated inverted row → Single-arm inverted row | Paused rung sits above feet-elevated (both flagged). Paused before feet-elevated, as in the pull-up and chin-up ladders; GPT would keep the order and elevate the paused rung. |
| Nordic curl | ladder | Band-assisted nordic curls → Nordic negatives → Nordic curls, partial → Nordic curls → Paused nordic curls | Assisted Nordic curls → Nordic negatives → Nordic curls, partial → Nordic curls → Paused nordic curls | A chest band anchored in front pulls you down, not up. Safety. |
| Pike push-ups | ladder | Short pike push-ups → Pike push-ups → Feet-elevated pike push-ups → Wall handstand push-ups, partial → Wall handstand push-ups | Short pike push-ups → Pike push-ups → Feet-elevated pike push-ups → Wall handstand push-ups, partial → Wall handstand push-ups | Head position and controlled contact. Safety on the handstand rungs. |
| Plank | ladder | Knee plank → Plank → Forearm plank hip lifts → Feet-elevated plank → Long-lever plank → RKC plank | Knee plank → Plank → Feet-elevated plank → Long-lever plank | Hip-lift rung (both flagged). Both drop it; GPT also drops the RKC plank, a max-tension hold, which isn't light stability work. |
| Reverse crunch | ladder | Reverse crunches, knees bent → Reverse crunches → Slow reverse crunches → Tuck-to-straight-leg hip raise → Straight-leg reverse crunches → Decline reverse crunch → Dragon flag negatives | Reverse crunches, knees bent → Reverse crunches → Slow reverse crunches → Straight-leg reverse crunches → Dragon flag negatives | Decline and tuck rungs (both flagged). Both drop those; Opus keeps the knees-bent entry rung. Take GPT's dragon-flag-negative text too. |
| Russian twist | ladder | Russian twists, feet down → Russian twists, feet up → Slow Russian twists → Russian twists with a weight held out | Russian twists, feet down → Russian twists, feet up → Slow Russian twists | Last rung needs a weight. Drop it; loadGear covers added weight. |
| Sliding leg curl | ladder | Floor heel slides → Bridge slide-out negatives → Sliding leg curls → Single-leg sliding curls | Bridge slide-out negatives → Sliding leg curls → Single-leg sliding curls | Drop the floor heel-slide first rung. As 132: the floor rung trains nothing. |
| Split squat | ladder | Supported split squats → Split squats → Split squat jumps → Walking lunges → Rear-foot-elevated split squats → Suspended split squats → Paused rear-foot-elevated split squats → Alternating jump lunges | Supported split squats → Split squats → Walking lunges → Rear-foot-elevated split squats → Paused rear-foot-elevated split squats | Jump rungs and suspension rung (both flagged). Both drop the jumps (power) and the suspension rung; Opus keeps walking lunges, which need nothing and are a real step. |
| Barbell Bulgarian split squat | load | {"startKg": [10, 20, 30], "each": true} | {"startKg": [20, 30, 40], "each": false} | A barbell can't start at 10 kg; not per hand. 20/30/40, each false. |
| Barbell deficit reverse lunge | load | {"startKg": [10, 20, 30], "each": true} | {"startKg": [20, 30, 40], "each": false} | Same. 20/30/40, each false. |
| Barbell lateral split squat | load | {"startKg": [10, 20, 30], "each": true} | {"startKg": [20, 30, 40], "each": false} | Same. 20/30/40, each false. |
| Barbell lunge | load | {"startKg": [10, 20, 30], "each": true} | {"startKg": [20, 30, 40], "each": false} | Same. 20/30/40, each false. |
| Barbell reverse wrist curl | load | {"startKg": [5, 7.5, 10], "stepKg": 1} | {"startKg": [5, 7.5, 10], "stepKg": 2.5} | 1 kg barbell steps need 0.5 kg plates. Step 2.5. |
| Barbell step-up | load | {"startKg": [10, 20, 30], "each": true} | {"startKg": [20, 30, 40], "each": false} | Same. 20/30/40, each false. |
| Barbell wrist curl | load | {"startKg": [5, 10, 15], "stepKg": 1} | {"startKg": [5, 10, 15], "stepKg": 2.5} | Same. Step 2.5. |
| Cable front raise | load | {"startKg": [1, 2.5, 5], "stepKg": 1} | {"startKg": [2.5, 5, 7.5], "stepKg": 2.5} | Cable stacks start and step at 2.5. 2.5/5/7.5, step 2.5. |
| Cable shoulder external rotation | load | {"startKg": [1, 2.5, 5], "stepKg": 1} | {"startKg": [2.5, 5, 7.5], "stepKg": 2.5} | Cable stacks start at 2.5. 2.5/5/7.5, step 2.5. |
| Cable wrist curl | load | {"startKg": [2.5, 5, 7.5], "stepKg": 1} | {"startKg": [2.5, 5, 7.5], "stepKg": 2.5} | Same. Step 2.5. |
| Dumbbell clean | load | {"startKg": [2, 4, 6], "stepKg": 1} | {"startKg": [4, 6, 10], "stepKg": 2} | Too light and in 1 kg steps. 4/6/10, step 2. |
| Dumbbell reverse wrist curl | load | {"startKg": [1, 2, 3], "stepKg": 0.5} | {"startKg": [1, 2, 3], "stepKg": 1} | Light dumbbells step by 1 kg. Step 1. |
| Dumbbell wrist curl | load | {"startKg": [2, 4, 6], "stepKg": 0.5} | {"startKg": [2, 4, 6], "stepKg": 1} | Same. Step 1. |
| Hack squat | load | {"startKg": [40, 60, 80]} | {"startKg": [20, 40, 60]} | 40 kg plus the sled is a lot for a first session. 20/40/60, as the Smith squat. |
| High cable curl | load | {"startKg": [2.5, 5, 7.5], "stepKg": 1} | {"startKg": [2.5, 5, 7.5], "stepKg": 2.5} | Cable steps. Step 2.5. |
| Kettlebell windmill | load | {"startKg": [2, 4, 6], "stepKg": 2} | {"startKg": [4, 8, 12], "stepKg": 2} | Kettlebells rarely come under 4 kg. 4/8/12. |
| Landmine row | load | {"each": false, "startKg": [15.0, 20.0, 30.0], "stepKg": 2.5} | {"each": true, "startKg": [15.0, 20.0, 30.0], "stepKg": 2.5} | each = true. Same as 40. |
| Pistol squat, kettlebell | load | {"startKg": [2, 4, 8], "stepKg": 2, "each": true} | {"startKg": [4, 8, 12], "stepKg": 4, "each": false} | 2 kg bells are rare; one bell isn't per hand. 4/8/12, step 4, each false. |
| Prone barbell front raise | load | {"startKg": [2.5, 5, 10], "stepKg": 1} | {"startKg": [5, 7.5, 10], "stepKg": 2.5} | No barbell weighs 2.5 kg. 5/7.5/10, step 2.5. |
| Smith machine Bulgarian split squat | load | {"each": true} | {"each": false} | One bar, not per hand. each false. |
| Smith machine single-leg squat | load | {"each": true} | {"each": false} | One bar, not per hand. each false. |
| Standing loaded calf raise | load | {"startKg": [10, 20, 30]} | {"startKg": [20, 30, 50]} | A barbell can't start at 10 kg. 20/30/50. |
| Turkish get-up | load | {"startKg": [2, 4, 8], "stepKg": 1} | {"startKg": [2, 4, 8], "stepKg": 2} | Kettlebells don't step by 1 kg. Step 2. |
| Wrist roller | load | {"startKg": [1, 2.5, 5], "stepKg": 0.5} | {"startKg": [1.25, 2.5, 5], "stepKg": 1.25} | Plates come in 1.25 kg. 1.25/2.5/5, step 1.25. |
| Zercher squat | load | {"startKg": [10, 20, 30]} | {"startKg": [20, 30, 40]} | A barbell can't start at 10 kg. 20/30/40. |
| Assisted pull-ups | name | Assisted pull-ups | Machine-assisted pull-ups | Clashes with the pull-up ladder's first rung. Machine-assisted pull-ups. |
| Chest-supported scapular shrug | name | Chest-supported scapular shrug | Chest-supported scapular retraction | It's a retraction; 'shrug' invites the wrong movement. Chest-supported scapular retraction. |
| Gentle upper-trap stretch | name | Gentle upper-trap stretch | Side neck stretch | 'Gentle' is a cue, not a name. Side neck stretch. |
| Hip thrust, dumbbell | name | Hip thrust, dumbbell | Dumbbell hip thrust | Name order. Dumbbell hip thrust. |
| Lying knee-over twist | name | Lying knee-over twist | Lying spinal twist | Unfamiliar name. Lying spinal twist. |
| Seated glute and torso stretch | name | Seated glute and torso stretch | Seated spinal twist | Unfamiliar name. Seated spinal twist. |
| Shoulder rolls | name | Shoulder circles | Shoulder rolls | The text describes shoulder rolls. Shoulder rolls. |
| Side-lying external rotation | name | Side-lying external rotation | Side-lying dumbbell external rotation | The family names its gear. Side-lying dumbbell external rotation. |
| Single-arm landmine push press | name | Single-arm landmine push press | Landmine push press | 'Single-arm' implies a two-arm default. Landmine push press. |
| Standing chest stretch | name | Standing chest stretch | Doorway chest stretch | Follows 126. Doorway chest stretch. |
| Toe raise | name | Toe raise | Tibialis raise | 'Toe raise' often means a calf raise. Tibialis raise. |
| Barbell bench press | needs | [["barbell", "bench_flat"]] | [["barbell", "squat_rack", "bench_flat"]] | A barbell bench press needs a rack to unrack from. Same as the floor press; home_full and gyms have one. |
| Belt squat | needs | [["dip_belt", "box"], ["dip_belt", "bench_flat"]] | [["dip_belt", "box", "weight_plate"], ["dip_belt", "bench_flat", "weight_plate"]] | A dip belt needs plates to hang. Add weight_plate. |
| Calf raise | needs | [["calf_machine"], ["box"], []] | [[]] | The bodyweight calf raise lists a calf machine. Any stair works; needs nothing. |
| Close-grip bench press | needs | [["barbell", "bench_flat"]] | [["barbell", "squat_rack", "bench_flat"]] | Needs a rack. As 55. |
| Cross-body straight-leg stretch | needs | [["band"]] | [[]] | Doesn't need a band; a hand or towel works. Goes with 127. |
| Decline barbell bench press | needs | [["barbell", "bench_decline"]] | [["barbell", "squat_rack", "bench_decline"]] | Needs a rack. As 55. |
| Incline barbell bench press | needs | [["barbell", "bench_incline"]] | [["barbell", "squat_rack", "bench_incline"]] | Needs a rack. As 55. |
| Landmine press | needs | [["landmine"]] | [["barbell", "landmine"]] | A landmine needs a barbell in it. Apply to every landmine entry (row, twist too). |
| Overhead press | needs | [["barbell"]] | [["barbell", "squat_rack"]] | The press starts from a rack. Same as push press and front squat. |
| Pallof press | needs | [["cable"], ["band"]] | [["cable"]] | Band option can't follow a kg prescription. Keep the cable; a band Pallof would be its own ladder entry. Rejects 124. |
| Preacher curl | needs | [["ez_bar", "bench_incline"], ["dumbbell", "bench_incline"]] | [["ez_bar", "preacher_bench"], ["dumbbell", "preacher_bench"], ["dumbbell", "bench_incline… | Neither option lists the preacher bench (both flagged). Opus keeps the dumbbell versions; GPT drops them over load units (see 59). |
| Smith machine shoulder press | needs | [["smith"]] | [["smith", "bench_incline"], ["smith", "bench_flat"]] | Seated Smith press needs a bench (both flagged). Opus also allows a flat bench; both work. |
| Standing loaded calf raise | needs | [["calf_machine"], ["smith"], ["barbell", "squat_rack"]] | [["calf_machine"], ["smith", "box"], ["barbell", "squat_rack", "box"]] | Smith and barbell versions need an edge to stand on. Add box to those options. |
| Arm circles | tags | front shoulders / rear shoulders / chest | side shoulders / front shoulders / rear shoulders | Chest isn't moved or lengthened in small arm circles. All three delts drive it. |
| Barbell lateral split squat | tags | quads / glutes / inner thighs / lower back | inner thighs / glutes / quads / lower back | Lateral lunges should be filed under inner thighs. RULES says inner thighs and glutes primary for lateral lunges. |
| Forward and backward leg swings | tags | hamstrings | hamstrings / quads | The back swing stretches the hip flexors too. Matches side leg swings tagging both ends. |
| Front and lateral raise | tags | front shoulders / side shoulders | side shoulders / front shoulders | Side shoulders limit the load, so they lead. The lighter muscle sets the dumbbell. |
| Front squat | tags | quads / glutes / inner thighs / lower back / abs / upper back | quads / glutes / inner thighs / lower back / abs | Upper back isn't strained in a front squat. The bar rests on the shoulders; erectors are already tagged. |
| Glute bridge hold | tags | none | glutes / hamstrings | No tags. Glutes, hamstrings, as the other bridges. |
| Hands-and-knees hip circles | tags | inner thighs / glutes | outer hips / glutes / inner thighs | Fire-hydrant circles are driven by the outer hips. Main movers lead for moving drills. |
| Kettlebell clean and jerk | tags | glutes / hamstrings / quads / front shoulders / triceps / traps / obliques | glutes / hamstrings / front shoulders / quads / triceps / traps / obliques | Clean and jerk ranks quads above front shoulders, unlike its clean and jerk parts. Family consistency. |
| Lateral bound | tags | glutes / quads / calves / outer hips | glutes / outer hips / quads / calves | Outer hips are what a lateral bound is picked for. Display-only tags; the sideways push and landing is the point. |
| Lateral lunge | tags | quads / glutes / inner thighs | inner thighs / glutes / quads | Lateral lunges should be filed under inner thighs. RULES says inner thighs and glutes primary. |
| Push-up to side plank | tags | chest / front shoulders / triceps / obliques | chest / front shoulders / triceps | Obliques aren't strained by a brief side plank. Only matters if 9 keeps it. |
| Sit-up press | tags | abs / front shoulders / triceps | abs | Front shoulders and triceps pressing 2-6 kg aren't strained. RULES: a strong muscle moving a light load is not trained. |
| Thoracic rotation | tags | none | upper back / obliques | No targets (both flagged; Opus adds upper back). Upper back is what people use it for; it lets the picker choose it after upper-back days. |
| Thread the needle | tags | none | upper back / rear shoulders | No targets (both flagged; GPT adds obliques). The trunk turn is mild; upper back and rear shoulders are the stretch. |
| Wall slides | tags | none | upper back | No tags. Upper back (lower traps), as the Y raise. |
| World's greatest stretch | tags | inner thighs / glutes / hamstrings / calves | glutes / inner thighs / hamstrings / quads | The long lunge stretches the rear hip flexors; calves barely. Quads replaces calves. |
| Zercher squat | tags | quads / glutes / inner thighs / lower back / upper back / abs | quads / glutes / inner thighs / lower back / abs | Upper back isn't strained in a Zercher squat. Same as the front squat. |

## Kept as is

| Exercise | Check | Proposed by | Why kept |
|---|---|---|---|
| Triceps dips | duplicate | Opus | Merge triceps dips into dips? Different first primary (triceps vs chest) and coaching; the standard keeps entries apart when the angle changes what grows. |
| Single-leg hop | format | Opus | each = true for one-leg hops. Bodyweight: no load to show per hand; the text says both sides. |
| Standing torso twist | format | GPT | Standing torso twist: moving or held? Take Opus's 128 instead: keep it moving and fix the text. |
| Clean pull | how | GPT | Rewrite as power. Follows 5 (drop). |
| Pallof press | how | GPT | Add the band setup. Follows 65 (cable only). |
| Preacher curl | how | GPT | Describe only the EZ bar. Follows 63. |
| Shrug | how | GPT | Tell dumbbell users the load is a total. Follows 59: an app fix, not a text one. |
| Skull crusher | how | GPT | Describe only the EZ bar. Follows 59. |
| Upright row | how | GPT | Same. Follows 59. |
| Overhead press | load | GPT | Start the overhead press at 10 kg. A standard bar is 20 kg; 20 is already the empty bar. |
| Barbell seal row | needs | GPT | Add a box to raise the bench. Follows 3 (drop). |
| Farmer's carry | needs | GPT | Drop the trap bar option because the load is per hand. As 59. |
| Skull crusher | needs | GPT | Drop the dumbbell option because the load is a bar total. Load units for bar-or-dumbbell entries are an app fix (show per hand), not a reason to drop the dumbbell version. Same for 60, 120, 121, 122, 123. |
| Weighted sissy squat | needs | Opus | Rack isn't needed; a dumbbell works too. Moot if merged (12). |
| Band row | tags | GPT | Remove rear shoulders from rows to the ribs. Follows 1. |
| Chest-supported machine row | tags | GPT | Remove rear shoulders from rows to the ribs. Follows 1. |
| Smith machine row | tags | GPT | Remove rear shoulders from rows to the ribs. Follows 1. |
| T-bar row | tags | GPT | Remove rear shoulders from rows to the ribs. Follows 1. |
| Clean pull | type | GPT | Clean pull to power? Moot if dropped (5). |

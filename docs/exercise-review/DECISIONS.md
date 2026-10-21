# Decisions on the disputed findings

147 findings where the reviewers did not agree (most: one flagged it, the other passed it). 31 findings both agreed on were applied as agreed (REPORT.md lists them).

The owner delegated these calls to the adjudicator (Claude Fable 5.1). Each row gives the issue, where each reviewer stood, and the decision with its reason. The full proposals are in `match.json` under the same key; `apply.py` applied them.

## Rules

These change how many items are judged; the items they decide point back here.

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 1 | Barbell row | RULES.md says rear shoulders are secondary only in high, flared rows, but ten rows to the ribs carry them. | change (doubtful) | fine as is | **Opus's fix**: Rear delts extend the shoulder in any row that ends with the elbow behind you; change the rule's wording, keep the tags. Rejects 19, 20, 21, 22. |
| 2 | Barbell lunge | `each` should mean the load is per hand, not that the count is per side. | change (doubtful) | fine as is | **Opus's fix**: The app only uses `each` to print 'kg each'; a barbell lunge would read '20 kg each'. each = the load is held in one hand. Undoes the agreed each changes on the Pallof press (two hands) and side plank (bodyweight); landmine press and landmine row keep it (one hand on the bar end). |

## Drop or merge

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 3 | Barbell seal row | A barbell can't reach full arm length under a normal flat bench. | change (wrong) | fine as is | **Opus's fix**: Needs a seal-row bench we don't list; raising a bench on boxes (GPT's fix) isn't something to improvise. Rejects 50. |
| 4 | Standing ankle-weight leg curl | A 1-2 kg ankle weight never takes the hamstrings near failure. | change (doubtful) | fine as is | **Opus's fix**: Fails the strength test; true to type over coverage. |
| 5 | Clean pull | An Olympic-lifting accessory that needs coaching. | change (doubtful) | fine as is | **Opus's fix**: Niche for everyday people; a fast deadlift for growth. Rejects 18 and 116. |
| 6 | Jefferson squat | Niche strongman squat with a twisting load on the spine. | change (doubtful) | fine as is | **Opus's fix**: Same grounds as the trimmed kneeling barbell squat. |
| 7 | Single-arm kettlebell overhead squat | A light bell overhead caps the load far below what strains the legs. | change (wrong) | fine as is | **Opus's fix**: A shoulder-stability skill filed as leg strength. |
| 8 | Overhead squat | Limited by shoulder and ankle mobility, never by the legs. | change (wrong) | fine as is | **Opus's fix**: Expert lift, fails the strength test. |
| 9 | Push-up to side plank | A push-up with a brief side plank attached. | change (doubtful) | fine as is | **Opus's fix**: Someone growing their chest picks push-ups, and a brief side plank between reps is neither strength nor stability work; 30 is moot. |
| 10 | Cable twist on an exercise ball | Same cable rotation as the standing cable twist, lying on a ball. | change (doubtful) | fine as is | **Opus's fix**: A setup difference. |
| 11 | Cross-body crunch | Merge the cross-body crunch into the bicycle crunch? | change (doubtful) | fine as is | **Opus's fix**: Two 3-rung ladders of the same twisting crunch; the feet-down version becomes the bicycle ladder's first rung. |
| 12 | Weighted sissy squat | The sissy squat holding a plate. | change (doubtful) | fine as is | **Opus's fix**: Added load is what loadGear past the top rung is for. Makes 54 moot. |
| 13 | Seated cable chest press | Seated vs standing cable chest press. | change (doubtful) | fine as is | **Opus's fix**: A setup note; keep the standing entry. |
| 14 | Flat bench cable fly | Lying vs standing cable fly. | change (doubtful) | fine as is | **Opus's fix**: Same line of pull and tags; a setup note. |
| 15 | Triceps dips | Merge triceps dips into dips? | change (doubtful) | fine as is | **Kept as is**: Different first primary (triceps vs chest) and coaching; the standard keeps entries apart when the angle changes what grows. |
| 16 | EZ bar curl | EZ bar curl vs barbell curl. | fine as is | change (doubtful) | **GPT's fix**: Same curl; one entry that takes either bar is cleaner. |
| 17 | Kettlebell Z press | Kettlebell Z press vs kettlebell press. | fine as is | change (wrong) | **GPT's fix**: Seated on the floor is a setup note under the standard. |
| 18 | Clean pull | Clean pull to power? | fine as is | change (doubtful) | **Kept as is**: Moot if dropped (5). |

## Muscle tags

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 19 | Band row | Remove rear shoulders from rows to the ribs. | fine as is | change (wrong) | **Kept as is**: Follows 1. |
| 20 | Chest-supported machine row | Remove rear shoulders from rows to the ribs. | fine as is | change (wrong) | **Kept as is**: Follows 1. |
| 21 | Smith machine row | Remove rear shoulders from rows to the ribs. | fine as is | change (wrong) | **Kept as is**: Follows 1. |
| 22 | T-bar row | Remove rear shoulders from rows to the ribs. | fine as is | change (wrong) | **Kept as is**: Follows 1. |
| 23 | Kettlebell clean and jerk | Clean and jerk ranks quads above front shoulders, unlike its clean and jerk parts. | change (doubtful) | fine as is | **Opus's fix**: Family consistency. |
| 24 | Lateral bound | Outer hips are what a lateral bound is picked for. | change (doubtful) | fine as is | **Opus's fix**: Display-only tags; the sideways push and landing is the point. |
| 25 | Sit-up press | Front shoulders and triceps pressing 2-6 kg aren't strained. | change (wrong) | fine as is | **Opus's fix**: RULES: a strong muscle moving a light load is not trained. |
| 26 | Barbell lateral split squat | Lateral lunges should be filed under inner thighs. | change (doubtful) | fine as is | **Opus's fix**: RULES says inner thighs and glutes primary for lateral lunges. |
| 27 | Front squat | Upper back isn't strained in a front squat. | change (wrong) | fine as is | **Opus's fix**: The bar rests on the shoulders; erectors are already tagged. |
| 28 | Lateral lunge | Lateral lunges should be filed under inner thighs. | change (doubtful) | fine as is | **Opus's fix**: RULES says inner thighs and glutes primary. |
| 29 | Zercher squat | Upper back isn't strained in a Zercher squat. | change (wrong) | fine as is | **Opus's fix**: Same as the front squat. |
| 30 | Push-up to side plank | Obliques aren't strained by a brief side plank. | change (doubtful) | fine as is | **Opus's fix**: Only matters if 9 keeps it. |
| 31 | Front and lateral raise | Side shoulders limit the load, so they lead. | change (doubtful) | fine as is | **Opus's fix**: The lighter muscle sets the dumbbell. |
| 32 | Glute bridge hold | No tags. | change (doubtful) | fine as is | **Opus's fix**: Glutes, hamstrings, as the other bridges. |
| 33 | Wall slides | No tags. | change (doubtful) | fine as is | **Opus's fix**: Upper back (lower traps), as the Y raise. |
| 34 | Arm circles | Chest isn't moved or lengthened in small arm circles. | change (doubtful) | fine as is | **Opus's fix**: All three delts drive it. |
| 35 | Forward and backward leg swings | The back swing stretches the hip flexors too. | change (doubtful) | fine as is | **Opus's fix**: Matches side leg swings tagging both ends. |
| 36 | Hands-and-knees hip circles | Fire-hydrant circles are driven by the outer hips. | change (doubtful) | fine as is | **Opus's fix**: Main movers lead for moving drills. |
| 37 | Thoracic rotation | No targets (both flagged; Opus adds upper back). | change (wrong) | change (wrong) | **Opus's fix**: Upper back is what people use it for; it lets the picker choose it after upper-back days. |
| 38 | Thread the needle | No targets (both flagged; GPT adds obliques). | change (wrong) | change (wrong) | **Opus's fix**: The trunk turn is mild; upper back and rear shoulders are the stretch. |
| 39 | World's greatest stretch | The long lunge stretches the rear hip flexors; calves barely. | change (doubtful) | fine as is | **Opus's fix**: Quads replaces calves. |

## Format and timing

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 40 | Landmine row | each = true for one-arm rows. | change (wrong) | fine as is | **Opus's fix**: One hand holds the bar end, like the dumbbell row; same as 75. |
| 41 | Single-leg hop | each = true for one-leg hops. | change (doubtful) | fine as is | **Kept as is**: Bodyweight: no load to show per hand; the text says both sides. |
| 42 | 90/90 hip switch | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s; the stretching picker will need a time. |
| 43 | Couch stretch | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s per side. |
| 44 | Deep squat hold | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s. |
| 45 | Hamstring sweep | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s. |
| 46 | Standing torso twist | Standing torso twist: moving or held? | fine as is | change (wrong) | **Kept as is**: Take Opus's 128 instead: keep it moving and fix the text. |
| 47 | Pigeon | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s per side. |
| 48 | Thoracic rotation | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s. |
| 49 | Thread the needle | Routine move has no seconds. | fine as is | change (wrong) | **GPT's fix**: 30 s per side. |

## Gear

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 50 | Barbell seal row | Add a box to raise the bench. | fine as is | change (wrong) | **Kept as is**: Follows 3 (drop). |
| 51 | Belt squat | A dip belt needs plates to hang. | fine as is | change (wrong) | **GPT's fix**: Add weight_plate. |
| 52 | Calf raise | The bodyweight calf raise lists a calf machine. | change (polish) | fine as is | **Opus's fix**: Any stair works; needs nothing. |
| 53 | Standing loaded calf raise | Smith and barbell versions need an edge to stand on. | fine as is | change (wrong) | **GPT's fix**: Add box to those options. |
| 54 | Weighted sissy squat | Rack isn't needed; a dumbbell works too. | change (doubtful) | fine as is | **Kept as is**: Moot if merged (12). |
| 55 | Barbell bench press | A barbell bench press needs a rack to unrack from. | fine as is | change (wrong) | **GPT's fix**: Same as the floor press; home_full and gyms have one. |
| 56 | Close-grip bench press | Needs a rack. | fine as is | change (wrong) | **GPT's fix**: As 55. |
| 57 | Decline barbell bench press | Needs a rack. | fine as is | change (wrong) | **GPT's fix**: As 55. |
| 58 | Incline barbell bench press | Needs a rack. | fine as is | change (wrong) | **GPT's fix**: As 55. |
| 59 | Skull crusher | Drop the dumbbell option because the load is a bar total. | fine as is | change (wrong) | **Kept as is**: Load units for bar-or-dumbbell entries are an app fix (show per hand), not a reason to drop the dumbbell version. Same for 60, 120, 121, 122, 123. |
| 60 | Farmer's carry | Drop the trap bar option because the load is per hand. | fine as is | change (wrong) | **Kept as is**: As 59. |
| 61 | Landmine press | A landmine needs a barbell in it. | fine as is | change (wrong) | **GPT's fix**: Apply to every landmine entry (row, twist too). |
| 62 | Overhead press | The press starts from a rack. | change (doubtful) | fine as is | **Opus's fix**: Same as push press and front squat. |
| 63 | Preacher curl | Neither option lists the preacher bench (both flagged). | change (doubtful) | change (wrong) | **Opus's fix**: Opus keeps the dumbbell versions; GPT drops them over load units (see 59). |
| 64 | Smith machine shoulder press | Seated Smith press needs a bench (both flagged). | change (wrong) | change (wrong) | **Opus's fix**: Opus also allows a flat bench; both work. |
| 65 | Pallof press | Band option can't follow a kg prescription. | change (wrong) | fine as is | **Opus's fix**: Keep the cable; a band Pallof would be its own ladder entry. Rejects 124. |
| 66 | Cross-body straight-leg stretch | Doesn't need a band; a hand or towel works. | change (doubtful) | fine as is | **Opus's fix**: Goes with 127. |

## Difficulty

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 67 | Barbell rear delt row | Rear delt row is lighter than a barbell row. | change (doubtful) | fine as is | **Opus's fix**: 3, like the dumbbell bent-over row. |
| 68 | Smith machine row | Smith entries sit one below their free-bar version. | change (doubtful) | fine as is | **Opus's fix**: 3. |
| 69 | Suspension row | Suspension row is the inverted row's twin. | change (doubtful) | fine as is | **Opus's fix**: 3. |
| 70 | Kettlebell sumo high pull | Rated with barbell lifts. | change (doubtful) | fine as is | **Opus's fix**: 3, like the swing. |
| 71 | Sit-up press | A sit-up with a light weight. | change (doubtful) | fine as is | **Opus's fix**: 1, like weighted crunches. |
| 72 | Close-grip push-ups | Push-ups anchor at 3. | fine as is | change (wrong) | **GPT's fix**: Close grip is no easier. |
| 73 | Glute bridge hold | No cost set. | change (polish) | fine as is | **Opus's fix**: 1. |
| 74 | Wall slides | No cost set. | change (polish) | fine as is | **Opus's fix**: 1. |

## Starting loads

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 75 | Landmine row | each = true. | fine as is | change (wrong) | **GPT's fix**: Same as 40. |
| 76 | Dumbbell clean | Too light and in 1 kg steps. | change (doubtful) | fine as is | **Opus's fix**: 4/6/10, step 2. |
| 77 | Kettlebell windmill | Kettlebells rarely come under 4 kg. | change (doubtful) | fine as is | **Opus's fix**: 4/8/12. |
| 78 | Barbell Bulgarian split squat | A barbell can't start at 10 kg; not per hand. | change (wrong) | fine as is | **Opus's fix**: 20/30/40, each false. |
| 79 | Barbell deficit reverse lunge | Same. | change (wrong) | fine as is | **Opus's fix**: 20/30/40, each false. |
| 80 | Barbell lateral split squat | Same. | change (wrong) | fine as is | **Opus's fix**: 20/30/40, each false. |
| 81 | Barbell lunge | Same. | change (wrong) | fine as is | **Opus's fix**: 20/30/40, each false. |
| 82 | Barbell step-up | Same. | change (wrong) | fine as is | **Opus's fix**: 20/30/40, each false. |
| 83 | Hack squat | 40 kg plus the sled is a lot for a first session. | change (doubtful) | fine as is | **Opus's fix**: 20/40/60, as the Smith squat. |
| 84 | Pistol squat, kettlebell | 2 kg bells are rare; one bell isn't per hand. | change (doubtful) | fine as is | **Opus's fix**: 4/8/12, step 4, each false. |
| 85 | Smith machine Bulgarian split squat | One bar, not per hand. | change (doubtful) | fine as is | **Opus's fix**: each false. |
| 86 | Smith machine single-leg squat | One bar, not per hand. | change (doubtful) | fine as is | **Opus's fix**: each false. |
| 87 | Standing loaded calf raise | A barbell can't start at 10 kg. | change (doubtful) | fine as is | **Opus's fix**: 20/30/50. |
| 88 | Zercher squat | A barbell can't start at 10 kg. | change (wrong) | fine as is | **Opus's fix**: 20/30/40. |
| 89 | Barbell reverse wrist curl | 1 kg barbell steps need 0.5 kg plates. | change (doubtful) | fine as is | **Opus's fix**: Step 2.5. |
| 90 | Barbell wrist curl | Same. | change (doubtful) | fine as is | **Opus's fix**: Step 2.5. |
| 91 | Cable front raise | Cable stacks start and step at 2.5. | change (doubtful) | fine as is | **Opus's fix**: 2.5/5/7.5, step 2.5. |
| 92 | Cable wrist curl | Same. | change (doubtful) | fine as is | **Opus's fix**: Step 2.5. |
| 93 | Dumbbell reverse wrist curl | Light dumbbells step by 1 kg. | change (doubtful) | fine as is | **Opus's fix**: Step 1. |
| 94 | Dumbbell wrist curl | Same. | change (doubtful) | fine as is | **Opus's fix**: Step 1. |
| 95 | High cable curl | Cable steps. | change (doubtful) | fine as is | **Opus's fix**: Step 2.5. |
| 96 | Overhead press | Start the overhead press at 10 kg. | fine as is | change (doubtful) | **Kept as is**: A standard bar is 20 kg; 20 is already the empty bar. |
| 97 | Prone barbell front raise | No barbell weighs 2.5 kg. | change (doubtful) | fine as is | **Opus's fix**: 5/7.5/10, step 2.5. |
| 98 | Wrist roller | Plates come in 1.25 kg. | change (doubtful) | fine as is | **Opus's fix**: 1.25/2.5/5, step 1.25. |
| 99 | Cable shoulder external rotation | Cable stacks start at 2.5. | change (doubtful) | fine as is | **Opus's fix**: 2.5/5/7.5, step 2.5. |
| 100 | Turkish get-up | Kettlebells don't step by 1 kg. | change (doubtful) | fine as is | **Opus's fix**: Step 2. |

## Names

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 101 | Assisted pull-ups | Clashes with the pull-up ladder's first rung. | change (polish) | fine as is | **Opus's fix**: Machine-assisted pull-ups. |
| 102 | Hip thrust, dumbbell | Name order. | change (polish) | fine as is | **Opus's fix**: Dumbbell hip thrust. |
| 103 | Toe raise | 'Toe raise' often means a calf raise. | change (doubtful) | fine as is | **Opus's fix**: Tibialis raise. |
| 104 | Single-arm landmine push press | 'Single-arm' implies a two-arm default. | change (polish) | fine as is | **Opus's fix**: Landmine push press. |
| 105 | Side-lying external rotation | The family names its gear. | change (polish) | fine as is | **Opus's fix**: Side-lying dumbbell external rotation. |
| 106 | Chest-supported scapular shrug | It's a retraction; 'shrug' invites the wrong movement. | change (doubtful) | fine as is | **Opus's fix**: Chest-supported scapular retraction. |
| 107 | Seated glute and torso stretch | Unfamiliar name. | change (polish) | fine as is | **Opus's fix**: Seated spinal twist. |
| 108 | Standing chest stretch | Follows 126. | change (polish) | fine as is | **Opus's fix**: Doorway chest stretch. |
| 109 | Lying knee-over twist | Unfamiliar name. | change (polish) | fine as is | **Opus's fix**: Lying spinal twist. |
| 110 | Shoulder rolls | The text describes shoulder rolls. | change (polish) | fine as is | **Opus's fix**: Shoulder rolls. |
| 111 | Gentle upper-trap stretch | 'Gentle' is a cue, not a name. | change (polish) | fine as is | **Opus's fix**: Side neck stretch. |

## How-to text

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 112 | Forward sled drag | Text needs a harness we don't list. | fine as is | change (wrong) | **GPT's fix**: Hold the straps instead. |
| 113 | Kettlebell sumo high pull | No flat-back cue on a fast pull from the floor. | change (doubtful) | fine as is | **Opus's fix**: Safety. |
| 114 | Lateral bound | Says one leg; the first rung is two feet. | change (polish) | fine as is | **Opus's fix**: Text matches the ladder. |
| 115 | Cable reverse crunch | 'Facing a low cable' reads as face down. | change (polish) | fine as is | **Opus's fix**: Clearer setup. |
| 116 | Clean pull | Rewrite as power. | fine as is | change (doubtful) | **Kept as is**: Follows 5 (drop). |
| 117 | Sliding leg curl | Point to the negative instead of the floor rung. | fine as is | change (wrong) | **GPT's fix**: Follows 137: the text pointed at the dropped floor rung. |
| 118 | Kettlebell front squat | Jargon about a two-bell option the load can't express. | change (polish) | fine as is | **Opus's fix**: One bell, switch sides. |
| 119 | Single-dumbbell close-grip press | Shoulders-on-bench bridge makes the hips a limit. | change (doubtful) | fine as is | **Opus's fix**: Lie along the bench like the other presses. |
| 120 | Skull crusher | Describe only the EZ bar. | fine as is | change (wrong) | **Kept as is**: Follows 59. |
| 121 | Preacher curl | Describe only the EZ bar. | fine as is | change (wrong) | **Kept as is**: Follows 63. |
| 122 | Shrug | Tell dumbbell users the load is a total. | fine as is | change (wrong) | **Kept as is**: Follows 59: an app fix, not a text one. |
| 123 | Upright row | Same. | fine as is | change (wrong) | **Kept as is**: Follows 59. |
| 124 | Pallof press | Add the band setup. | fine as is | change (wrong) | **Kept as is**: Follows 65 (cable only). |
| 125 | Wall handstand hold | Never mentions the wall. | change (polish) | fine as is | **Opus's fix**: Text matches the named exercise. |
| 126 | Standing chest stretch | Hands-behind-back is a weak chest stretch, near the biceps stretch. | change (doubtful) | fine as is | **Opus's fix**: Doorway is the standard pec stretch and what the routine used. |
| 127 | Cross-body straight-leg stretch | Matches needs [[]]. | change (doubtful) | fine as is | **Opus's fix**: Hand, band or towel. |
| 128 | Standing torso twist | Format says moving, text says hold. | change (wrong) | fine as is | **Opus's fix**: Make the text the moving twist. |
| 129 | Pigeon | Assumes you know how to get into it. | fine as is | change (doubtful) | **GPT's fix**: Learnable for beginners. |
| 130 | World's greatest stretch | Drops the arm turn that defines the drill. | change (wrong) | fine as is | **Opus's fix**: Restores it. |

## Ladders

| # | Exercise | Issue | Opus | GPT | Decision |
|---|---|---|---|---|---|
| 131 | Inverted row | Paused rung sits above feet-elevated (both flagged). | change (doubtful) | change (doubtful) | **Opus's fix**: Paused before feet-elevated, as in the pull-up and chin-up ladders; GPT would keep the order and elevate the paused rung. |
| 132 | Exercise ball leg curl | Drop the hips-down first rung. | fine as is | change (wrong) | **GPT's fix**: A new user starts at rung 0; with the hips on the floor that rung trains nothing. Bridge negatives with a short slide are the real entry. |
| 133 | Glute bridge | Ball and band rungs need gear the exercise doesn't list (both flagged). | change (wrong) | change (wrong) | **Opus's fix**: Both drop those; Opus keeps feet-elevated (a chair works), GPT drops it too. |
| 134 | Nordic curl | A chest band anchored in front pulls you down, not up. | fine as is | change (wrong) | **GPT's fix**: Safety. |
| 135 | Reverse crunch | Decline and tuck rungs (both flagged). | change (wrong) | change (wrong) | **Opus's fix**: Both drop those; Opus keeps the knees-bent entry rung. Take GPT's dragon-flag-negative text too. |
| 136 | Russian twist | Last rung needs a weight. | fine as is | change (wrong) | **GPT's fix**: Drop it; loadGear covers added weight. |
| 137 | Sliding leg curl | Drop the floor heel-slide first rung. | fine as is | change (wrong) | **GPT's fix**: As 132: the floor rung trains nothing. |
| 138 | Band calf raise | 'Doubled band' could be easier than heavy. | fine as is | change (doubtful) | **GPT's fix**: Say: heavy band plus another. |
| 139 | Band squat | Same. | fine as is | change (doubtful) | **GPT's fix**: Same. |
| 140 | Split squat | Jump rungs and suspension rung (both flagged). | change (wrong) | change (wrong) | **Opus's fix**: Both drop the jumps (power) and the suspension rung; Opus keeps walking lunges, which need nothing and are a real step. |
| 141 | Calf raise | Paused single-leg rung has no note. | change (polish) | fine as is | **Opus's fix**: Add '2 seconds at the top'. |
| 142 | Bodyweight triceps extension | On the floor, your forearms reach the floor, not your head. | change (wrong) | fine as is | **Opus's fix**: Accurate text. |
| 143 | Close-grip push-ups | Paused rung after feet-elevated. | fine as is | change (doubtful) | **GPT's fix**: Paused before feet-elevated, as 131. |
| 144 | Dips | Pause cue tacked on at the end. | fine as is | change (polish) | **GPT's fix**: Wording. |
| 145 | Pike push-ups | Head position and controlled contact. | fine as is | change (wrong) | **GPT's fix**: Safety on the handstand rungs. |
| 146 | Dead bug | Note says 3 s, text says 3 s out, pause, 3 s back. | fine as is | change (polish) | **GPT's fix**: Match. |
| 147 | Plank | Hip-lift rung (both flagged). | change (wrong) | change (wrong) | **GPT's fix**: Both drop it; GPT also drops the RKC plank, a max-tension hold, which isn't light stability work. |

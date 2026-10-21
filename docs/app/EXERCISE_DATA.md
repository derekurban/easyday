# Exercise data

The rules for the exercise library: what each entry and field means and when it is right. `EXERCISES.md` is how the
app uses the library; this is how to edit it. The library was reviewed against these rules in October 2026
(`docs/exercise-review/`).

## Where it lives

- **`data/library.json`** is the source of truth: every exercise, stretch and cardio choice, in our own words.
- **`python mobile/tool/gen_library.py`** checks it against the rules below that a script can check (types and
  formats, muscle names, equipment ids, loads, ladders) and writes `mobile/lib/data/exercises.g.dart`. Never edit
  the generated file; change the dataset and regenerate.
- `renamed` maps the id of an exercise merged into another to the id that replaced it, so saved progress follows.
  `rungHistory` keeps the old version names of every ladder whose versions moved, so a saved level stays on the same
  version (`remapRung` in `library.dart`, applied once when a save is older than the change).

The repo is public: every name and how-to is written in our own words. Nothing is copied from any website.

## What the library is for

Easyday helps everyday people get fitter: people training at home or in a normal gym, most of them neither athletes
nor experienced lifters. Every entry should be:

- **Reasonable.** A movement an ordinary person can learn from its text and do safely with the gear it lists, and a
  sensible choice for its type's job. Not niche, not a stunt, not an expert lift without a scaled way in.
- **Accurate.** Its type, muscles, equipment, difficulty, starting loads and text match what the movement really is
  and does, by established exercise science and common coaching consensus.
- **True to its type.** An exercise is filed by what it is, never to fill a gap. Some muscles have no strength
  exercise at some locations, and that is accepted: the app skips a muscle it cannot train where you are.

## The five types

Every entry has exactly one type and one format.

| Type | What it is | The test | Formats |
|---|---|---|---|
| **Strength** | Builds muscle. Hard sets taken close to failure, progressed by weight or by version. The only type a workout's exercises are picked from, and so the only one that earns strain points. | Would someone who wanted to grow this muscle pick this exercise for it? | reps, hold, carry |
| **Power** | Explosive work: each rep a quick, all-out exertion, even when it can be done with control (jumps, slams, cleans, snatches, jerks, swings, push presses). A few reps with full rest, done fresh, stopped when the reps slow down. | Is each rep about moving fast? | reps |
| **Stability** | Control and joint care, and light holds that build endurance in a position. Done light, never to failure. | Is the point holding a position or controlling a joint, not growing the muscle? | reps, hold, carry |
| **Cardio** | Heart and lungs, kept going for time. | Do you keep a rhythm going for minutes, or for work-rest rounds? | steady, intervals |
| **Stretching** | Range of motion. | Is the point lengthening a muscle or moving a joint through its range? | moving, held |

Boundaries that come up:

- **Power vs cardio:** if every rep is all-out with full rest, it is power; if you keep a rhythm going for time, it is
  cardio. Jumping jacks are cardio; a box jump and a ball slam are power. Thrusters and high pulls done for time are
  cardio: the drive keeps the rhythm going, it is not an all-out rep.
- **Strength vs power:** a controlled lift taken close to failure is strength; the same muscles driven fast are
  power. The overhead press is strength, the push press is power. A jump is never a version on a strength ladder.
- **Strength vs stability:** a hold or drill is strength only if it is a good way to grow the muscle (a dumbbell
  lateral raise hold, a plate pinch). Core-control holds (plank, side plank, hollow hold) and endurance holds (wall
  sit, glute bridge hold) are stability.
- **Strength vs cardio:** a loaded move done for reps to a hard finish is strength; a move done for time with a light
  load is cardio (kettlebell thruster, sled push).

## Muscle tags

Twenty names, the regions of the body map, and no others:

| Name | Anatomy |
|---|---|
| chest | Pectoralis major |
| front shoulders | Anterior deltoid |
| side shoulders | Lateral deltoid |
| rear shoulders | Posterior deltoid (not the rotator cuff) |
| biceps | Biceps plus brachialis (elbow flexors) |
| triceps | All three triceps heads |
| forearms | Wrist and finger flexors and extensors, brachioradialis: grip and wrist work |
| abs | Rectus abdominis, bracing against extension |
| obliques | Rotation, side bending, anti-rotation, anti-side-bend. Not serratus (it has no region) |
| traps | Upper trapezius only: shrugging, heavy loads held at the sides, upward rotation overhead |
| lats | Latissimus dorsi (and teres major) |
| upper back | Middle and lower trapezius, rhomboids, infraspinatus and teres minor: retraction, depression, external rotation |
| lower back | Spinal erectors |
| glutes | Gluteus maximus |
| outer hips | Gluteus medius and minimus, TFL |
| inner thighs | Adductors |
| quads | Quadriceps (hip flexor stretches are filed here: rectus femoris crosses the hip) |
| hamstrings | Hamstrings |
| calves | Gastrocnemius and soleus |
| shins | Tibialis anterior |

What the tags mean depends on the type:

- **Strength:** the rules below in full. The first primary is the muscle it is filed under. Each set gives 0.20 strain
  points to every primary and 0.10 to every secondary, so a wrong or padded tag paints the body map wrong.
- **Power and stability:** what the movement trains or protects, shown on the card. The same vocabulary and the same
  restraint: primary is the target, secondaries sparse.
- **Stretching:** `targets` are the muscles lengthened (for a moving drill, the joints' main movers taken through
  range). A stretching block picks stretches for strained muscles by them.
- **Cardio:** no tags.

### Strength tags: what a hard set grows

Not which muscles move, and not which produces the most force.

- **Primary: a great exercise to grow this muscle.** A hard set strains it near its limit; it is usually what gives
  out and ends the set, and a lifter who wanted to grow this muscle would pick this exercise for it. 1 to 3; big
  compound lifts often have two or three.
- **Secondary: grows this muscle slowly or subtly; other exercises are better for it.** It works hard but is not what
  limits the set. Usually 0 to 3, at most 4.
- **Left out: used but not strained.** It moves, steadies or holds, but a hard set does not take it near its limit.

Two questions settle most cases: *which muscles give out when the set gets hard?* and *if someone wanted to grow
muscle X, would they choose this exercise?* Mechanics is the cross-check, not the rule. EMG alone is not evidence of
growth; set-counting conventions and longitudinal training studies are.

- **A strong muscle moving a light load is not trained:** lats in a ball slam, traps in a lateral raise below
  shoulder height, quads (rectus femoris as a hip flexor) in sit-ups and leg raises, shoulders pressing a light
  weight on a sit-up.
- **A muscle holding hard without moving can be trained, even as primary:** spinal erectors in deadlifts, good
  mornings and back extensions; the core in carries; grip in carries and heavy deadlifts.
- **Stabilisers** (core under a standing press, outer hips in a lunge, rotator cuff, adductors in most squats) are
  left out unless the exercise is chosen to load them or they commonly limit it (offset and single-arm loads,
  rollouts).

Family rules, so the same movement is tagged the same way everywhere:

- **Grip (forearms):** only where grip commonly limits the set or is held near its limit: the deadlift family,
  carries, shrugs, heavy hangs. Not rows, pulldowns, curls (unless hammer or reverse grip), lunges or RDLs with
  dumbbells.
- **Traps:** shrugs, heavy holds at the sides (deadlift family, farmer's carry, rack pulls), high pulls and upright
  rows, overhead pressing and overhead holds. Not dumbbells held for lunges or calf raises, not rows, not raises below
  shoulder height.
- **Lower back:** primary in deadlifts, good mornings, back extensions, rack pulls and bird dogs; secondary in RDLs,
  bent-over rows, heavy squats and front-loaded squats. Not machines with a back pad.
- **Abs and obliques:** primary in crunches, sit-ups, rollouts, leg raises, slams, rotations, side bends,
  anti-rotation and carries made for the core (suitcase, rack). Secondary only when the exercise loads them hard
  (front squat, overhead carries, single-arm overhead work). Not every standing exercise.
- **Rows:** lats and upper back both primary for most rows; hip-directed rows with tucked elbows are lats primary and
  upper back secondary; high, flared rows are upper back and rear shoulders. Biceps secondary. Rear shoulders:
  secondary in rows pulled to the lower ribs or chest, left out of hip-directed rows, primary only in high, flared
  rows.
- **Vertical pulls:** lats primary; biceps secondary (primary for chin-ups); upper back secondary.
- **Presses:** chest presses are chest primary with front shoulders and triceps secondary; close-grip presses and
  upright dips make triceps primary. Overhead presses are front shoulders primary with side shoulders, triceps and
  traps secondary.
- **Squats and lunges:** quads and glutes primary; inner thighs secondary in deep squats and lunges. Squats and leg
  presses do not train the hamstrings or calves: leave them out. Lateral lunges are inner thighs and glutes primary.
- **Hinges:** hamstrings and glutes primary; lower back as above; quads secondary in deadlifts (trap bar: primary).
- **Raises:** the target delt alone, plus traps only above shoulder height.
- **Curls and extensions:** the target muscle; forearms secondary only for hammer and reverse grips.

## Fields

| Field | Right when |
|---|---|
| `id` | Unique snake_case, short, and never reused. Renaming one means a `renamed` entry. |
| `name` | What people call it in a gym ("Dumbbell lateral raise", "Behind-the-back barbell squat"). Equipment first when that is how people say it. |
| `how` | 1 to 3 short sentences, second person, plain words: the setup, the movement, the one cue that matters, and a safety cue where a failed rep could trap you (rack safeties, Smith stops). Describes the exact version the tags describe. |
| `needs` | Any one inner list fully available lets you do it; `[[]]` means nothing. Everything the movement needs and nothing it doesn't. A bar in a landmine is `barbell` plus `landmine`. |
| `cost` | How much a hard set takes out of the whole body, 1 to 5, shown as easy (1 to 2), medium (3) or hard (4 to 5). Anchors: 1 curls, cable flyes, pushdowns, dead bugs; 2 lat pulldown, cable row, leg press, back extension; 3 dumbbell bench, dumbbell row, push-ups, goblet squat; 4 barbell bench, barbell row, overhead press, pull-ups, RDL; 5 back squat, deadlift, front squat. A Smith machine version sits one below its free-bar version. |
| `format` | How it is done: reps, hold (seconds), carry (steps), steady, intervals, moving, held. |
| `startKg`, `stepKg` | Loaded exercises: three conservative starting loads (new, some experience, experienced) and the smallest practical step for that gear. A new lifter can do clean reps with the first. |
| `each` | The load is on one limb at a time (a dumbbell or kettlebell in one hand, one cable handle, a landmine end, a cuff on one ankle), so the kilograms are per side. A bar, a handle held in both hands and bodyweight or band work are not, even when the count is per side; the text says "do both sides". |
| `altLoad` | The loads with another implement than the main one, by equipment id: see "How loads are written". |
| `assist` | The assisted machine: the loads are the help it gives, most for a new lifter. The app works with what is lifted (an 80 kg reference less the help), so a level up means less help, and shows the help. |
| `ladder` | Bodyweight and band exercises: versions from easiest to hardest, each a real, noticeable step, ordered by difficulty alone. A version goes where its difficulty puts it, between others if that is where it belongs. A version cannot list its own gear, so on a ladder that needs nothing, no version may need a ball, a band or a decline bench (a chair or a step is fine). The last band version keeps the heavy band and adds a second. Each version has its own `how`, or a `note` folded into the main one. |
| `start` | The version each experience starts on: new, some, experienced. |
| `loadGear` | Gear that adds load past the top version (a vest, a backpack, a dip belt). |
| `range` | Bodyweight exercises: the floor for the rep range; for holds, the seconds. |
| `seconds`, `perSide` | Stretches and routine moves: the time per set, or per side when `perSide`. |
| `rank` | Tie-break among equally good picks: lower first. The original library's ranks; new entries 100. |

### How loads are written

Dumbbells and kettlebells are always per hand: the data never gives a combined dumbbell weight, and the app shows
them as "per hand". Bars are the total including the bar, so an exercise that needs the Olympic bar starts at 20 kg
or more; light isolation lifts (wrist curls, the prone bar raise, the pullover) take an EZ bar and keep light loads.
Landmine and Smith entries count the plates added, so they can start at 0. An entry that takes either a bar or
dumbbells (shrug, upright row, skull crusher, preacher curl) gives the bar total in `startKg` and the per-hand dumbbell
loads in `altLoad.dumbbell`; the farmer's carry is the reverse, per hand in `startKg` and the trap bar total in
`altLoad.trap_bar`. The app uses the `altLoad` entry when that implement is what the location has.

### Equipment

The ids are `equipmentGroups` in `mobile/lib/data/library.dart`; `gen_library.py` rejects any other. The vocabulary is
deliberately coarse for everyday gyms: one cable station, one calf machine, one chest press machine.

## Duplicates

Two entries are the same exercise when they train the same thing with the same movement and the difference is a setup
note: grip width, a seat versus kneeling, alternating versus both arms, a machine brand. Keep one and say the
difference in its text if it matters. Entries that differ in where the load sits, the pull or press path, or the
joint angle that changes what grows are different exercises.

## Decisions that stand

- The five types, their names and the tests above.
- No exercise is added, kept or re-typed to cover a muscle or a location. Gaps are fine.
- Power is explosive work: the kettlebell swing, the barbell, kettlebell and landmine push presses and the ball slam
  are power.
- Band pull-apart, standing band hip abduction, plank, side plank, hollow hold, wall handstand hold, wall sit and
  glute bridge hold are stability.
- Prone flutter kicks, sit-up press and low Spiderman plank are strength, kept on purpose.
- The body map has no hip-flexor region; hip flexor stretches are filed under quads.

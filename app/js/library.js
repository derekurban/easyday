// Exercise library, equipment, patterns, goals. Pure data + small pure helpers. No app state here.

// ---------- equipment: the full list a location can have, grouped for the settings screen
export const EQUIPMENT_GROUPS = [
  { name: "Free weights", items: { barbell: "Barbell and plates", ez_bar: "EZ curl bar", trap_bar: "Trap bar", dumbbell: "Dumbbells", kettlebell: "Kettlebells", medicine_ball: "Medicine ball" } },
  { name: "Stations", items: { squat_rack: "Squat rack", bench_flat: "Flat bench", bench_incline: "Incline bench", pullup_bar: "Pull-up bar", dip_bars: "Dip bars", box: "Box or step", landmine: "Landmine" } },
  { name: "Machines", items: { cable: "Cable station", lat_pulldown: "Lat pulldown", row_machine: "Seated row machine", chest_press_machine: "Chest press machine", shoulder_press_machine: "Shoulder press machine", leg_press: "Leg press", hack_squat: "Hack squat", leg_extension: "Leg extension", leg_curl: "Leg curl", smith: "Smith machine", assisted_machine: "Assisted pull-up / dip", back_extension: "Back extension bench", calf_machine: "Calf raise machine" } },
  { name: "Small gear", items: { band: "Resistance bands", suspension: "Suspension trainer", ab_wheel: "Ab wheel", exercise_ball: "Exercise ball", foam_roller: "Foam roller", jump_rope: "Jump rope" } },
  { name: "Cardio", items: { treadmill: "Treadmill", bike: "Bike", rower: "Rower", elliptical: "Elliptical", stairs: "Stair machine" } },
];
export const EQUIPMENT = Object.assign({}, ...EQUIPMENT_GROUPS.map((g) => g.items));
const ALL = Object.keys(EQUIPMENT);

export const TEMPLATES = [
  { id: "gym", name: "Commercial gym", icon: "loc-gym", equipment: ALL },
  { id: "home_full", name: "Home · rack, barbell, bench", icon: "loc-home", equipment: ["barbell", "squat_rack", "bench_flat", "dumbbell", "pullup_bar"] },
  { id: "home_db", name: "Home · dumbbells and a bench", icon: "loc-home", equipment: ["dumbbell", "bench_flat"] },
  { id: "home_kb", name: "Home · a kettlebell", icon: "loc-home", equipment: ["kettlebell"] },
  { id: "home_band", name: "Home · bands and a pull-up bar", icon: "loc-home", equipment: ["band", "pullup_bar"] },
  { id: "hotel", name: "Hotel gym", icon: "loc-hotel", equipment: ["dumbbell", "bench_flat", "cable", "treadmill", "bike"] },
  { id: "none", name: "Nothing", icon: "loc-none", equipment: [] },
];

export const PATTERNS = {
  squat: { name: "Squat", main: true },
  hinge: { name: "Hinge", main: true },
  push: { name: "Push", main: true },
  pull: { name: "Pull", main: true },
  core: { name: "Core", main: false },
  carry: { name: "Carry", main: false },
  arms: { name: "Arms", main: false },
  shoulders: { name: "Shoulders", main: false },
  legs: { name: "Legs", main: false },
};

export const GOALS = {
  strength: { name: "Get stronger", blurb: "Heavier over time. Fewer reps, longer rests.", icon: "goal-strength", main: [4, 6], acc: [6, 10], rest: 150, moveEvery: 4, mains: 3, accs: 1,
    explain: ["Main lifts in sets of 4 to 6 reps", "Two and a half minutes of rest", "One movement day in four", "About 45 minutes a session"] },
  muscle: { name: "Build muscle", blurb: "Moderate reps, steady volume.", icon: "goal-muscle", main: [8, 12], acc: [10, 15], rest: 90, moveEvery: 4, mains: 3, accs: 1,
    explain: ["Main lifts in sets of 8 to 12 reps", "Ninety seconds of rest", "One movement day in four", "About 40 minutes a session"] },
  fit: { name: "Stay fit and mobile", blurb: "Lifting plus plenty of movement.", icon: "goal-fit", main: [10, 15], acc: [12, 20], rest: 60, moveEvery: 2, mains: 3, accs: 1,
    explain: ["Main lifts in sets of 10 to 15 reps", "A minute of rest", "Every other day is a movement day", "About 35 minutes a session"] },
  feel: { name: "Feel better", blurb: "Short sessions, lots of movement. The floor is low.", icon: "goal-feel", main: [10, 15], acc: [12, 20], rest: 60, moveEvery: 2, mains: 2, accs: 1,
    explain: ["Two main lifts, 10 to 15 reps", "A minute of rest", "Every other day is a movement day", "About 25 minutes a session"] },
};

export const EXPERIENCE = {
  new: { name: "New to this", blurb: "Little or no lifting before." },
  some: { name: "Some experience", blurb: "Have lifted on and off." },
  experienced: { name: "Experienced", blurb: "Years of consistent training." },
};

// Exercise fields:
//   needs: any one of the listed equipment sets must be fully available. [[]] = nothing needed.
//   unit: "kg" = loaded (start = conservative kg by experience, step = smallest increment), "bw" = bodyweight level (range shifts +2 reps per level).
//   each: shown "per hand". m: muscles {p: primary, s: secondary} using the body-map groups. how: plain-language cue. ref: free-exercise-db id.
const X = (id, name, pattern, needs, rest) => ({ id, name, pattern, needs, ...rest });
const KG = (start, step, extra = {}) => ({ unit: "kg", step, start: { new: start[0], some: start[1], experienced: start[2] }, ...extra });
const BW = (range, extra = {}) => ({ unit: "bw", range, ...extra });

export const EXERCISES = [
  // ---------- push
  X("bb_bench", "Barbell bench press", "push", [["barbell", "bench_flat"]], { ...KG([20, 30, 40], 2.5), rank: 1, ref: "Barbell_Bench_Press_-_Medium_Grip", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Lie on the bench, feet flat, bar over your chest. Lower it to your mid-chest with elbows about 45 degrees from your body, then press it back up." }),
  X("db_bench", "Dumbbell bench press", "push", [["dumbbell", "bench_flat"]], { ...KG([8, 12, 16], 2, { each: true }), rank: 2, ref: "Dumbbell_Bench_Press", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Lie on the bench with a dumbbell in each hand at chest height. Press both up until your arms are straight, then lower under control." }),
  X("incline_db", "Incline dumbbell press", "push", [["dumbbell", "bench_incline"]], { ...KG([8, 10, 14], 2, { each: true }), rank: 3, ref: "Incline_Dumbbell_Press", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Set the bench to a low incline. Press the dumbbells up from shoulder height until your arms are straight, then lower slowly." }),
  X("db_floor", "Dumbbell floor press", "push", [["dumbbell"]], { ...KG([8, 12, 16], 2, { each: true }), rank: 4, ref: "Dumbbell_Floor_Press", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Lie on the floor, knees bent, dumbbells at chest height with upper arms resting on the floor. Press up, then lower until your arms touch down again." }),
  X("ohp", "Overhead press", "push", [["barbell"]], { ...KG([20, 25, 30], 2.5), rank: 5, ref: "Standing_Military_Press", m: { p: ["shoulders"], s: ["triceps"] },
    how: "Stand with the bar at your collarbones, hands just outside shoulder width. Brace, press straight overhead until your arms lock out, then lower to the start." }),
  X("db_ohp", "Dumbbell shoulder press", "push", [["dumbbell"]], { ...KG([6, 8, 12], 2, { each: true }), rank: 6, ref: "Dumbbell_Shoulder_Press", m: { p: ["shoulders"], s: ["triceps"] },
    how: "Sit or stand with a dumbbell at each shoulder, palms forward. Press both overhead until your arms are straight, then lower to your shoulders." }),
  X("kb_press", "Kettlebell press", "push", [["kettlebell"]], { ...KG([8, 12, 16], 4, { each: true }), rank: 7, ref: "Alternating_Kettlebell_Press", m: { p: ["shoulders"], s: ["triceps"] },
    how: "Hold the kettlebell at your shoulder with the bell resting on the back of your forearm. Press overhead, lock out, and lower it back to the rack position." }),
  X("chest_press", "Machine chest press", "push", [["chest_press_machine"]], { ...KG([20, 30, 40], 5), rank: 8, ref: "Leverage_Chest_Press", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Set the seat so the handles are at mid-chest. Press forward until your arms are nearly straight, then bring the handles back without letting the weight stack touch." }),
  X("smith_bench", "Smith machine bench press", "push", [["smith", "bench_flat"]], { ...KG([20, 30, 40], 2.5), rank: 9, ref: "Smith_Machine_Bench_Press", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Lie on the bench under the bar. Unhook it, lower it to your chest, and press straight back up." }),
  X("dips", "Dips", "push", [["dip_bars"], ["assisted_machine"]], { ...BW([5, 8]), rank: 10, ref: "Dips_-_Chest_Version", m: { p: ["chest"], s: ["shoulders", "triceps"] },
    how: "Support yourself on the bars with straight arms. Lean slightly forward and lower until your upper arms are about parallel with the floor, then push back up." }),
  X("cable_fly", "Cable fly", "push", [["cable"]], { ...KG([5, 8, 12], 2.5, { each: true }), rank: 11, ref: "Cable_Crossover", m: { p: ["chest"], s: ["shoulders"] },
    how: "Stand between the cables with a handle in each hand, slight bend in the elbows. Bring your hands together in front of your chest in an arc, then open slowly." }),
  X("pushup", "Push-ups", "push", [[]], { ...BW([6, 10]), rank: 12, ref: "Pushups", m: { p: ["chest"], s: ["shoulders", "triceps", "abdominals"] },
    how: "Hands under your shoulders, body in a straight line. Lower your chest to just above the floor with elbows tucked about 45 degrees, then push back up. Knees down makes it easier." }),
  X("pike_pushup", "Pike push-ups", "push", [[]], { ...BW([5, 8]), rank: 13, ref: "Handstand_Push-Ups", m: { p: ["shoulders"], s: ["triceps", "chest"] },
    how: "From a push-up position, walk your feet in so your hips are high and your body forms an upside-down V. Bend your elbows to lower the top of your head toward the floor, then press back up." }),
  // ---------- pull
  X("bb_row", "Barbell row", "pull", [["barbell"]], { ...KG([20, 30, 40], 2.5), rank: 1, ref: "Bent_Over_Barbell_Row", m: { p: ["middle back"], s: ["lats", "biceps", "shoulders"] },
    how: "Hinge forward with a flat back until your torso is about 45 degrees, bar hanging at arm's length. Pull it to your lower ribs, squeeze your shoulder blades, and lower under control." }),
  X("db_row", "Dumbbell row", "pull", [["dumbbell"]], { ...KG([10, 14, 18], 2, { each: true }), rank: 2, ref: "Bent_Over_Two-Dumbbell_Row", m: { p: ["middle back"], s: ["lats", "biceps", "shoulders"] },
    how: "Support one hand on a bench or your knee, flat back. Pull the dumbbell to your hip, elbow close to your body, then lower all the way. Do both sides." }),
  X("pulldown", "Lat pulldown", "pull", [["lat_pulldown"], ["cable"]], { ...KG([25, 35, 45], 2.5), rank: 3, ref: "Wide-Grip_Lat_Pulldown", m: { p: ["lats"], s: ["biceps", "middle back", "shoulders"] },
    how: "Grip the bar wider than your shoulders, sit tall. Pull the bar down to your upper chest, leading with your elbows, then let it rise slowly until your arms are straight." }),
  X("cable_row", "Seated cable row", "pull", [["row_machine"], ["cable"]], { ...KG([25, 35, 45], 2.5), rank: 4, ref: "Seated_Cable_Rows", m: { p: ["middle back"], s: ["lats", "biceps", "shoulders"] },
    how: "Sit with knees slightly bent, chest up. Pull the handle to your stomach, squeezing your shoulder blades together, then reach forward under control." }),
  X("pullup", "Pull-ups", "pull", [["pullup_bar"]], { ...BW([3, 6]), rank: 5, ref: "Pullups", m: { p: ["lats"], s: ["biceps", "middle back"] },
    how: "Hang from the bar with palms facing away. Pull until your chin clears the bar, then lower all the way. A band under your feet makes it easier." }),
  X("assisted_pullup", "Assisted pull-ups", "pull", [["assisted_machine"]], { ...KG([40, 30, 20], 5), rank: 6, ref: "Pullups", m: { p: ["lats"], s: ["biceps", "middle back"] },
    how: "Kneel on the pad, grip the handles. Pull until your chin passes your hands, then lower slowly. On this machine, lower weight means harder." }),
  X("kb_row", "Kettlebell row", "pull", [["kettlebell"]], { ...KG([12, 16, 20], 4, { each: true }), rank: 7, ref: "One-Arm_Kettlebell_Row", m: { p: ["middle back"], s: ["lats", "biceps"] },
    how: "Hinge forward with one hand braced on your knee. Row the kettlebell to your hip, pause, and lower. Do both sides." }),
  X("trx_row", "Suspension row", "pull", [["suspension"]], { ...BW([8, 12]), rank: 8, ref: "Inverted_Row_with_Straps", m: { p: ["middle back"], s: ["lats", "biceps"] },
    how: "Lean back holding the handles with straight arms, body in a line. Pull your chest to your hands, then lower. Walk your feet forward to make it harder." }),
  X("band_row", "Band row", "pull", [["band"]], { ...BW([10, 15]), rank: 9, ref: "Inverted_Row", m: { p: ["middle back"], s: ["lats", "biceps"] },
    how: "Anchor the band at chest height or loop it around your feet while seated. Pull the handles to your ribs with elbows tucked, squeeze, and return slowly." }),
  X("inverted_row", "Inverted row", "pull", [[]], { ...BW([6, 10]), rank: 10, ref: "Inverted_Row", m: { p: ["middle back"], s: ["lats", "biceps"] },
    how: "Lie under a sturdy table edge or low bar and grip it. Keep your body straight and pull your chest up to it, then lower. Bend your knees to make it easier." }),
  // ---------- squat
  X("bb_squat", "Barbell back squat", "squat", [["barbell", "squat_rack"]], { ...KG([20, 40, 60], 2.5), rank: 1, ref: "Barbell_Full_Squat", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "lower back", "calves"] },
    how: "Bar on your upper back, feet shoulder width, toes slightly out. Sit down between your knees until your thighs are at least parallel, then drive back up through your whole foot." }),
  X("smith_squat", "Smith machine squat", "squat", [["smith"]], { ...KG([20, 40, 60], 2.5), rank: 2, ref: "Smith_Machine_Squat", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "calves"] },
    how: "Bar on your upper back, feet slightly in front of you. Unhook, squat until your thighs are parallel, and stand back up." }),
  X("goblet", "Goblet squat", "squat", [["dumbbell"], ["kettlebell"]], { ...KG([8, 12, 16], 2), rank: 3, ref: "Dumbbell_Squat", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "abdominals"] },
    how: "Hold one weight against your chest with both hands. Squat as deep as you comfortably can, elbows inside your knees, then stand up." }),
  X("leg_press", "Leg press", "squat", [["leg_press"]], { ...KG([40, 60, 90], 5), rank: 4, ref: "Leg_Press", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "calves"] },
    how: "Feet shoulder width on the platform. Lower the sled until your knees are at about 90 degrees without letting your lower back lift, then press back out without locking your knees." }),
  X("hack_squat", "Hack squat", "squat", [["hack_squat"]], { ...KG([40, 60, 80], 5), rank: 5, ref: "Hack_Squat", m: { p: ["quadriceps"], s: ["glutes", "hamstrings", "calves"] },
    how: "Shoulders under the pads, feet mid-platform. Lower until your thighs are parallel, then press back up." }),
  X("db_split", "Dumbbell split squat", "squat", [["dumbbell"]], { ...KG([6, 8, 12], 2, { each: true }), rank: 6, ref: "Split_Squat_with_Dumbbells", m: { p: ["quadriceps", "glutes"], s: ["hamstrings"] },
    how: "Stand in a long stride with a dumbbell in each hand. Lower your back knee toward the floor, keeping your front shin upright, then stand. Do both sides." }),
  X("step_up", "Step-ups", "squat", [["box"], ["bench_flat"]], { ...BW([8, 12]), rank: 7, ref: "Dumbbell_Step_Ups", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "calves"] },
    how: "Place one whole foot on the box. Push through that foot to stand on top, then step down slowly. Do all reps on one side, then switch." }),
  X("bw_squat", "Bodyweight squat", "squat", [[]], { ...BW([10, 15]), rank: 8, ref: "Bodyweight_Squat", m: { p: ["quadriceps", "glutes"], s: ["hamstrings"] },
    how: "Feet shoulder width, arms out in front for balance. Sit back and down until your thighs are at least parallel, then stand up." }),
  X("bw_split", "Split squat", "squat", [[]], { ...BW([6, 10]), rank: 9, ref: "Split_Squats", m: { p: ["quadriceps", "glutes"], s: ["hamstrings", "calves"] },
    how: "Long stride stance. Lower your back knee toward the floor, front shin upright, then stand. Do both sides." }),
  // ---------- hinge
  X("deadlift", "Deadlift", "hinge", [["barbell"]], { ...KG([40, 60, 80], 2.5), rank: 1, ref: "Barbell_Deadlift", m: { p: ["hamstrings", "glutes", "lower back"], s: ["quadriceps", "traps", "forearms", "lats"] },
    how: "Bar over mid-foot, grip just outside your legs, flat back, chest up. Push the floor away and stand tall with the bar close to your legs, then lower it the same way." }),
  X("trap_deadlift", "Trap bar deadlift", "hinge", [["trap_bar"]], { ...KG([40, 60, 80], 2.5), rank: 2, ref: "Trap_Bar_Deadlift", m: { p: ["hamstrings", "glutes", "quadriceps"], s: ["lower back", "traps", "forearms"] },
    how: "Stand inside the bar, grip the handles, flat back. Stand up tall, then lower it under control. Easier on the back than a straight bar." }),
  X("rdl", "Romanian deadlift", "hinge", [["barbell"]], { ...KG([30, 40, 60], 2.5), rank: 3, ref: "Romanian_Deadlift", m: { p: ["hamstrings", "glutes"], s: ["lower back", "forearms"] },
    how: "Hold the bar at your hips. Push your hips back and lower the bar down your legs with a flat back and soft knees until you feel your hamstrings, then stand up." }),
  X("db_rdl", "Dumbbell Romanian deadlift", "hinge", [["dumbbell"]], { ...KG([10, 14, 18], 2, { each: true }), rank: 4, ref: "Romanian_Deadlift", m: { p: ["hamstrings", "glutes"], s: ["lower back"] },
    how: "Dumbbells in front of your thighs. Push your hips back, keeping the weights close to your legs and your back flat, until your hamstrings stretch. Stand up by squeezing your glutes." }),
  X("kb_swing", "Kettlebell swing", "hinge", [["kettlebell"]], { ...KG([12, 16, 20], 4), rank: 5, ref: "One-Arm_Kettlebell_Swings", m: { p: ["hamstrings", "glutes"], s: ["lower back", "shoulders", "abdominals"] },
    how: "Hike the bell back between your legs, then snap your hips forward to swing it to chest height. Arms stay relaxed; the hips do the work." }),
  X("hip_thrust", "Barbell hip thrust", "hinge", [["barbell", "bench_flat"]], { ...KG([30, 40, 60], 5), rank: 6, ref: "Barbell_Hip_Thrust", m: { p: ["glutes"], s: ["hamstrings"] },
    how: "Upper back on the bench, bar across your hips, feet flat. Drive your hips up until your body is level from shoulders to knees, squeeze, and lower." }),
  X("back_ext", "Back extension", "hinge", [["back_extension"]], { ...BW([10, 15]), rank: 7, ref: "Hyperextensions_Back_Extensions", m: { p: ["lower back", "glutes"], s: ["hamstrings"] },
    how: "Hips on the pad, feet locked in. Hinge down until your torso is below the pad, then raise it until your body is in a straight line. Do not arch past straight." }),
  X("glute_bridge", "Glute bridge", "hinge", [[]], { ...BW([10, 15]), rank: 8, ref: "Single_Leg_Glute_Bridge", m: { p: ["glutes"], s: ["hamstrings"] },
    how: "Lie on your back, knees bent, feet flat. Drive through your heels to lift your hips until your body is straight from shoulders to knees, squeeze, and lower." }),
  X("sl_rdl", "Single-leg Romanian deadlift", "hinge", [[]], { ...BW([6, 10]), rank: 9, ref: "Kettlebell_One-Legged_Deadlift", m: { p: ["hamstrings", "glutes"], s: ["lower back"] },
    how: "Balance on one leg. Hinge forward with a flat back, letting the other leg float behind you, until your torso is near horizontal. Stand back up. Do both sides." }),
  // ---------- core
  X("dead_bug", "Dead bug", "core", [[]], { ...BW([8, 12]), rank: 1, ref: "Dead_Bug", m: { p: ["abdominals"], s: [] },
    how: "Lie on your back, arms straight up, knees over hips. Lower one arm overhead and the opposite leg toward the floor while your lower back stays pressed down. Return and switch." }),
  X("hanging_knee", "Hanging knee raise", "core", [["pullup_bar"], ["dip_bars"]], { ...BW([6, 10]), rank: 2, ref: "Hanging_Leg_Raise", m: { p: ["abdominals"], s: ["forearms"] },
    how: "Hang from the bar. Draw your knees up toward your chest, curling your hips slightly, then lower slowly without swinging." }),
  X("cable_crunch", "Cable crunch", "core", [["cable"]], { ...KG([20, 30, 40], 2.5), rank: 3, ref: "Cable_Crunch", m: { p: ["abdominals"], s: [] },
    how: "Kneel facing the cable with the rope held at your forehead. Crunch your elbows toward your knees by curling your spine, then return slowly." }),
  X("pallof", "Pallof press", "core", [["cable"], ["band"]], { ...KG([10, 15, 20], 2.5), rank: 4, ref: "Pallof_Press", m: { p: ["abdominals"], s: ["shoulders"] },
    how: "Stand side-on to the cable with the handle at your chest. Press it straight out and hold without letting it pull you around, then bring it back. Do both sides." }),
  X("ab_wheel", "Ab wheel rollout", "core", [["ab_wheel"]], { ...BW([5, 8]), rank: 5, ref: "Ab_Roller", m: { p: ["abdominals"], s: ["lats", "shoulders"] },
    how: "Kneel with the wheel under your shoulders. Roll forward as far as you can keep your lower back from sagging, then pull back to the start." }),
  X("mb_slam", "Medicine ball slam", "core", [["medicine_ball"]], { ...BW([8, 12]), rank: 6, ref: "One-Arm_Medicine_Ball_Slam", m: { p: ["abdominals"], s: ["shoulders", "lats"] },
    how: "Raise the ball overhead, then slam it into the floor as hard as you can by folding at the hips. Pick it up and repeat." }),
  X("situp", "Sit-ups", "core", [[]], { ...BW([10, 15]), rank: 7, ref: "Sit-Up", m: { p: ["abdominals"], s: [] },
    how: "Lie on your back with knees bent. Curl up until your chest reaches your thighs, then lower slowly." }),
  // ---------- carry
  X("farmer", "Farmer's carry", "carry", [["dumbbell"], ["kettlebell"], ["trap_bar"]], { ...KG([12, 16, 24], 4, { each: true, repLabel: "steps" }), rank: 1, ref: "Farmers_Walk", m: { p: ["forearms", "traps"], s: ["abdominals", "glutes", "quadriceps"] },
    how: "Pick up a heavy weight in each hand. Stand tall, shoulders back, and walk with short quick steps. Count the steps." }),
  X("suitcase", "Suitcase carry", "carry", [["dumbbell"], ["kettlebell"]], { ...KG([12, 16, 24], 4, { repLabel: "steps" }), rank: 2, ref: "Farmers_Walk", m: { p: ["abdominals", "forearms"], s: ["traps", "glutes"] },
    how: "Carry one heavy weight in one hand like a suitcase and walk without leaning. Switch hands halfway." }),
  // ---------- arms
  X("db_curl", "Dumbbell curl", "arms", [["dumbbell"]], { ...KG([6, 8, 10], 2, { each: true }), rank: 1, ref: "Dumbbell_Bicep_Curl", m: { p: ["biceps"], s: ["forearms"] },
    how: "Stand with dumbbells at your sides, palms forward. Curl them to your shoulders without swinging, then lower slowly." }),
  X("pushdown", "Triceps pushdown", "arms", [["cable"]], { ...KG([15, 20, 25], 2.5), rank: 2, ref: "Triceps_Pushdown", m: { p: ["triceps"], s: [] },
    how: "Elbows pinned to your sides, grip the bar or rope at chest height. Push down until your arms are straight, then let it rise to chest height." }),
  X("ez_curl", "EZ bar curl", "arms", [["ez_bar"]], { ...KG([15, 20, 25], 2.5), rank: 3, ref: "EZ-Bar_Curl", m: { p: ["biceps"], s: ["forearms"] },
    how: "Hold the bar on the angled grips. Curl it to your shoulders keeping your elbows still, then lower slowly." }),
  X("skull_crusher", "Skull crusher", "arms", [["ez_bar", "bench_flat"], ["dumbbell", "bench_flat"]], { ...KG([10, 15, 20], 2.5), rank: 4, ref: "EZ-Bar_Skullcrusher", m: { p: ["triceps"], s: [] },
    how: "Lie on the bench with the bar above your chest. Bend only your elbows to lower it toward your forehead, then straighten your arms." }),
  X("bb_curl", "Barbell curl", "arms", [["barbell"]], { ...KG([15, 20, 25], 2.5), rank: 5, ref: "Barbell_Curl", m: { p: ["biceps"], s: ["forearms"] },
    how: "Hold the bar at your thighs, palms forward. Curl to your shoulders without leaning back, then lower slowly." }),
  X("tri_dips", "Triceps dips", "arms", [["dip_bars"]], { ...BW([5, 8]), rank: 6, ref: "Dips_-_Triceps_Version", m: { p: ["triceps"], s: ["chest", "shoulders"] },
    how: "On the bars with your body upright, lower until your elbows are at 90 degrees, then push back up." }),
  X("bench_dip", "Bench dips", "arms", [["bench_flat"], ["box"]], { ...BW([8, 12]), rank: 7, ref: "Bench_Dips", m: { p: ["triceps"], s: ["chest", "shoulders"] },
    how: "Hands on the bench edge behind you, legs out in front. Bend your elbows to lower your hips toward the floor, then push back up." }),
  X("band_curl", "Band curl", "arms", [["band"]], { ...BW([12, 16]), rank: 8, ref: "Barbell_Curl", m: { p: ["biceps"], s: ["forearms"] },
    how: "Stand on the band, handles in your hands. Curl to your shoulders and lower slowly." }),
  X("diamond_pushup", "Close-grip push-ups", "arms", [[]], { ...BW([5, 8]), rank: 9, ref: "Push-Ups_-_Close_Triceps_Position", m: { p: ["triceps"], s: ["chest", "shoulders"] },
    how: "Push-up position with your hands close together under your chest. Lower with elbows tucked tight, then press up." }),
  // ---------- shoulders
  X("lat_raise", "Lateral raise", "shoulders", [["dumbbell"]], { ...KG([4, 6, 8], 2, { each: true }), rank: 1, ref: "Side_Lateral_Raise", m: { p: ["shoulders"], s: ["traps"] },
    how: "Dumbbells at your sides, slight bend in the elbows. Raise your arms out to the sides until they are level with your shoulders, then lower slowly." }),
  X("face_pull", "Face pull", "shoulders", [["cable"]], { ...KG([10, 15, 20], 2.5), rank: 2, ref: "Face_Pull", m: { p: ["shoulders"], s: ["middle back", "traps"] },
    how: "Rope at face height. Pull it toward your face, elbows high and wide, until your hands are beside your ears. Return slowly." }),
  X("rear_fly", "Rear delt fly", "shoulders", [["dumbbell"]], { ...KG([4, 6, 8], 2, { each: true }), rank: 3, ref: "Reverse_Flyes", m: { p: ["shoulders"], s: ["middle back"] },
    how: "Hinge forward with a flat back, dumbbells hanging below you. Raise your arms out to the sides, squeezing your shoulder blades, then lower." }),
  X("machine_shoulder", "Machine shoulder press", "shoulders", [["shoulder_press_machine"]], { ...KG([15, 20, 30], 5), rank: 4, ref: "Machine_Shoulder_Military_Press", m: { p: ["shoulders"], s: ["triceps"] },
    how: "Seat set so the handles start at shoulder height. Press up until your arms are nearly straight, then lower." }),
  X("band_pull_apart", "Band pull-apart", "shoulders", [["band"]], { ...BW([12, 16]), rank: 5, ref: "Band_Pull_Apart", m: { p: ["shoulders"], s: ["middle back", "traps"] },
    how: "Hold the band in front of you at shoulder height, arms straight. Pull your hands apart until the band touches your chest, then return slowly." }),
  // ---------- legs (accessory)
  X("leg_curl", "Leg curl", "legs", [["leg_curl"]], { ...KG([15, 25, 35], 5), rank: 1, ref: "Lying_Leg_Curls", m: { p: ["hamstrings"], s: ["calves"] },
    how: "Pad just above your heels. Curl your heels toward your glutes, pause, and lower slowly." }),
  X("leg_ext", "Leg extension", "legs", [["leg_extension"]], { ...KG([15, 25, 35], 5), rank: 2, ref: "Leg_Extensions", m: { p: ["quadriceps"], s: [] },
    how: "Pad on your shins. Straighten your legs fully, pause, and lower slowly." }),
  X("calf_raise", "Calf raise", "legs", [["calf_machine"], ["box"], []], { ...BW([12, 20]), rank: 3, ref: "Calf_Raise_On_A_Dumbbell", m: { p: ["calves"], s: [] },
    how: "Stand on the balls of your feet on an edge. Rise as high as you can, pause, then lower your heels below the edge." }),
  X("reverse_lunge", "Reverse lunge", "legs", [[]], { ...BW([8, 12]), rank: 4, ref: "Dumbbell_Rear_Lunge", m: { p: ["quadriceps", "glutes"], s: ["hamstrings"] },
    how: "Step one foot back and lower that knee toward the floor, front shin upright. Push through the front foot to stand. Alternate sides." }),
];

export const byId = Object.fromEntries(EXERCISES.map((e) => [e.id, e]));

export function available(ex, equipment) {
  const have = new Set(equipment);
  return ex.needs.some((set) => set.every((t) => have.has(t)));
}

// Rotation items are written in patterns. mains come first, then accessories.
// Order matters: goals with 2 mains take the first two, so every pattern still shows up across the rotation.
const ITEMS = [
  { name: "Day A", focus: "squat first", mains: ["squat", "push", "pull"], accs: ["core"] },
  { name: "Day B", focus: "hinge first", mains: ["hinge", "pull", "push"], accs: ["carry", "arms"] },
  { name: "Day C", focus: "squat and pull first", mains: ["squat", "pull", "push"], accs: ["shoulders", "legs"] },
  { name: "Day D", focus: "hinge and push first", mains: ["hinge", "push", "pull"], accs: ["arms", "core"] },
];

export const MOVE = {
  cardio: { type: "move", kind: "cardio", name: "Move day", minutes: 20 },
  mobility: { type: "move", kind: "mobility", name: "Mobility day", routine: "reset" },
};

// Build a rotation: lifting items interleaved with movement items according to the goal.
export function buildRotation(goalId, daysPerWeek, { mixShift = 0, floorLowered = false } = {}) {
  const goal = GOALS[goalId];
  const count = daysPerWeek <= 2 ? 2 : daysPerWeek === 3 ? 3 : 4;
  const lifts = ITEMS.slice(0, count).map((it) => ({ type: "lift", name: it.name, focus: it.focus, mains: it.mains.slice(0, goal.mains), accs: floorLowered ? [] : it.accs.slice(0, goal.accs) }));
  const rotation = [];
  let moveEvery = goal.moveEvery;
  if (floorLowered) moveEvery = Math.max(1, Math.min(moveEvery, 2));
  lifts.forEach((l, i) => {
    rotation.push(l);
    if ((i + 1) % moveEvery === 0 || moveEvery === 1) rotation.push(i % 2 === 0 ? MOVE.cardio : MOVE.mobility);
  });
  if (!rotation.some((r) => r.type === "move")) rotation.push(MOVE.cardio);
  for (let n = 0, i = rotation.length - 1; n < mixShift && i >= 0; i--) {
    if (rotation[i].type === "lift" && rotation.filter((r) => r.type === "lift").length > 1) { rotation[i] = n % 2 ? MOVE.cardio : MOVE.mobility; n++; }
  }
  return rotation;
}

export const ROUTINES = {
  reset: { name: "Full body reset", seconds: 40, moves: [
    { n: "Cat-cow", how: "On hands and knees, arch your back up, then let it sag while lifting your head. Slow and steady." },
    { n: "World's greatest stretch, left", how: "Lunge forward with the left foot, drop the right knee, and reach your left elbow toward the floor inside your left foot. Then rotate your left arm up to the ceiling." },
    { n: "World's greatest stretch, right", how: "Same on the other side." },
    { n: "Hip flexor stretch, left", how: "Kneel on the left knee, right foot forward. Tuck your pelvis and shift forward until you feel the front of the left hip." },
    { n: "Hip flexor stretch, right", how: "Same on the other side." },
    { n: "Thoracic rotation, left", how: "On hands and knees, left hand behind your head. Rotate your elbow toward the ceiling, then down toward the opposite wrist." },
    { n: "Thoracic rotation, right", how: "Same on the other side." },
    { n: "Deep squat hold", how: "Sink into the deepest squat you can, heels down, elbows pushing your knees out. Breathe." },
    { n: "Hamstring sweep", how: "Step one heel forward, toes up, and hinge forward sweeping your hands toward the floor. Alternate legs." },
    { n: "Shoulder circles", how: "Big slow circles with straight arms, forward then backward." },
  ] },
  hips: { name: "Hips and hamstrings", seconds: 45, moves: [
    { n: "90/90 hip switch", how: "Sit with one leg bent in front and the other bent to the side, both at 90 degrees. Rotate your knees to the other side without using your hands." },
    { n: "Pigeon, left", how: "Left shin across in front of you, right leg straight behind. Fold forward over the front leg." },
    { n: "Pigeon, right", how: "Same on the other side." },
    { n: "Hamstring sweep", how: "Step one heel forward, toes up, and hinge forward sweeping your hands toward the floor. Alternate legs." },
    { n: "Couch stretch, left", how: "Left knee on the floor against a wall or couch, left foot up the wall, right foot forward. Stand tall and tuck your pelvis." },
    { n: "Couch stretch, right", how: "Same on the other side." },
    { n: "Deep squat hold", how: "Sink into the deepest squat you can, heels down, elbows pushing your knees out. Breathe." },
    { n: "Glute bridge hold", how: "Lie on your back, knees bent. Lift your hips and hold them up, squeezing your glutes." },
  ] },
  upper: { name: "Shoulders and upper back", seconds: 40, moves: [
    { n: "Cat-cow", how: "On hands and knees, arch your back up, then let it sag while lifting your head. Slow and steady." },
    { n: "Thread the needle, left", how: "On hands and knees, slide your left arm under your body, palm up, letting your left shoulder rest on the floor." },
    { n: "Thread the needle, right", how: "Same on the other side." },
    { n: "Wall slides", how: "Back against a wall, arms in a goalpost shape touching the wall. Slide them up and down keeping contact." },
    { n: "Doorway chest stretch", how: "Forearms on a door frame at shoulder height. Step through until you feel the stretch across your chest." },
    { n: "Thoracic rotation, left", how: "On hands and knees, left hand behind your head. Rotate your elbow toward the ceiling, then down toward the opposite wrist." },
    { n: "Thoracic rotation, right", how: "Same on the other side." },
    { n: "Shoulder circles", how: "Big slow circles with straight arms, forward then backward." },
  ] },
};

// Cardio options. `needs` null = always available.
export const CARDIO = [
  { id: "walk", name: "Brisk walk", needs: null },
  { id: "run", name: "Easy run", needs: null },
  { id: "treadmill", name: "Treadmill", needs: "treadmill" },
  { id: "bike", name: "Bike", needs: "bike" },
  { id: "rower", name: "Rower", needs: "rower" },
  { id: "elliptical", name: "Elliptical", needs: "elliptical" },
  { id: "stairs", name: "Stair machine", needs: "stairs" },
  { id: "jump_rope", name: "Jump rope", needs: "jump_rope" },
  { id: "any", name: "Anything that raises the pulse", needs: null },
];
export function cardioFor(equipment) { const have = new Set(equipment); return CARDIO.filter((c) => !c.needs || have.has(c.needs)); }
